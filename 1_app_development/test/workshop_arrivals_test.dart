import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/customer_notifier.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_arrivals.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_customers.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 26번 5-1단계: 실제 시간 손님(일반 1~15분·네임드 30분~3시간), 자리 상한,
/// 자정 영업일 넘김, 기다림은 켠 순간부터, 저장 schema 7, 기기 안 알림.
class FakeNotifier implements CustomerNotifier {
  final scheduled = <List<PlannedNotice>>[];
  var cancels = 0, permissionAsks = 0;
  bool grant;
  FakeNotifier({this.grant = true});
  @override
  Future<void> schedule(List<PlannedNotice> notices) async => scheduled.add(notices);
  @override
  Future<void> cancelAll() async => cancels++;
  @override
  Future<bool> requestPermission() async { permissionAsks++; return grant; }
}

void main() {
  late DevelopmentBalance config;
  late WorkshopArrivals rules;
  setUp(() {
    config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    rules = WorkshopArrivals.of(config);
  });
  // 2026-11-18 12:00 KST.
  final start = DateTime.utc(2026, 11, 18, 3);
  int ms(DateTime t) => t.millisecondsSinceEpoch;
  DateTime at(int value) => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  int anonymous(WorkshopController c) => c.state.customers.where((o) => o.customerId.startsWith('anonymous_')).length;
  int named(WorkshopController c) => c.state.customers.where((o) => c.customerCatalog.contains(o.customerId)).length;

  /// A player past the guide, business open at [start]. The monotonic clock
  /// stays still, so waiting guests never time out unless a test moves it.
  Future<(WorkshopController, void Function(DateTime))> open({DateTime? from, int Function()? mono}) async {
    var now = from ?? start;
    final c = WorkshopController(config, MemoryRepository(), now: () => now, random: Random(5),
        monotonicMs: mono ?? () => 0);
    await c.initialize();
    expect(await c.command(() => c.state.tutorial = 'done'), isTrue);
    expect(await c.openBusiness(), isTrue);
    return (c, (DateTime t) => now = t);
  }
  Future<void> flush(WorkshopController c) async => expect(await c.command(() {}), isTrue, reason: '${c.error}');

  group('손님 시계', () {
    test('간격은 설정 범위 안이고 같은 시드면 같다', () {
      final seen = <int>{};
      for (var draw = 0; draw < 500; draw++) {
        final clock = ArrivalClock(seed: 77, draws: draw);
        final regular = rules.intervalOf(clock, ArrivalKind.regular), named = rules.intervalOf(clock, ArrivalKind.named);
        expect(regular, inInclusiveRange(rules.regularMin, rules.regularMax));
        expect(named, inInclusiveRange(rules.namedMin, rules.namedMax));
        expect(rules.intervalOf(ArrivalClock(seed: 77, draws: draw), ArrivalKind.regular), regular);
        seen.add(regular ~/ 60000);
      }
      expect(seen.length, greaterThan(10), reason: '1~15분에 고루 퍼짐');
      expect(rules.regularMin, 60000);
      expect(rules.regularMax, 900000);
      expect(rules.namedMin, 1800000);
      expect(rules.namedMax, 10800000);
      expect((rules.regularSlots, rules.namedSlots), (3, 1), reason: 'S5-1-Q1 일반 3+단골 1');
      expect(kstMidnightAfter('2026-11-18'), DateTime.utc(2026, 11, 18, 15));
      expect(ArrivalClock.fromJson(const ArrivalClock(seed: 3, nextAt: 9, draws: 2).toJson()),
          const ArrivalClock(seed: 3, nextAt: 9, draws: 2));
      expect(() => ArrivalClock.fromJson({'seed': -1, 'draws': 0, 'nextAt': null}), throwsFormatException);
    });

    test('1분·15분·3시간: 실제 시간으로 오고 일반 3·네임드 1에서 시계가 멈춘다', () async {
      final (c, setNow) = await open();
      addTearDown(c.dispose);
      final regularAt = c.state.regularClock.nextAt!, namedAt = c.state.namedClock.nextAt!;
      expect(regularAt - ms(start), inInclusiveRange(60000, 900000));
      expect(namedAt - ms(start), inInclusiveRange(1800000, 10800000));
      setNow(start.add(const Duration(seconds: 59)));
      await flush(c);
      expect(c.state.customers, isEmpty, reason: '1분 전에는 아무도 안 옴');
      setNow(at(regularAt));
      await flush(c);
      expect(anonymous(c), 1);
      expect(c.state.regularClock.nextAt! - regularAt, inInclusiveRange(60000, 900000));
      setNow(start.add(const Duration(minutes: 15)));
      await flush(c);
      expect(anonymous(c), greaterThanOrEqualTo(1));
      setNow(start.add(const Duration(hours: 3)));
      await flush(c);
      expect(anonymous(c), 3);
      expect(named(c), 1);
      expect(c.state.customers.firstWhere((o) => c.customerCatalog.contains(o.customerId)).customerId, 'npc_doyun',
          reason: '처음 네임드는 도윤');
      expect(c.state.regularClock.nextAt, isNull, reason: '자리가 차면 멈춤');
      expect(c.state.namedClock.nextAt, isNull);
      expect(c.state.lastNamedVisitor, 'npc_doyun');
      // A freed place starts the clock again from that moment.
      final freedAt = start.add(const Duration(hours: 3, minutes: 1));
      setNow(freedAt);
      expect(await c.command(() => c.state.customers.removeWhere((o) => o.customerId.startsWith('anonymous_'))), isTrue);
      await flush(c);
      expect(c.state.regularClock.nextAt! - ms(freedAt), inInclusiveRange(60000, 900000));
      expect(c.state.namedClock.nextAt, isNull, reason: '네임드 자리는 그대로 참');
    });

    test('기기 시계를 되돌려도 지난 도착이 다시 생기지 않고, 앞당겨도 자리 수에서 막힌다', () async {
      final (c, setNow) = await open();
      addTearDown(c.dispose);
      setNow(start.add(const Duration(minutes: 20)));
      await flush(c);
      final before = c.state.customers.map((o) => o.id).toList(), clocks = (c.state.regularClock, c.state.namedClock);
      setNow(start);
      await flush(c);
      setNow(start.add(const Duration(minutes: 20)));
      await flush(c);
      expect(c.state.customers.map((o) => o.id).toList(), before, reason: '되돌렸다 돌아와도 같은 손님');
      expect((c.state.regularClock, c.state.namedClock), clocks);
      // A year ahead: still only the places, and one business day forward.
      final day = c.state.business.businessIndex;
      setNow(start.add(const Duration(days: 365)));
      await flush(c);
      expect(anonymous(c), 3);
      expect(named(c), 1);
      expect(c.state.business.businessIndex, day + 1, reason: '여러 날 지나도 영업일은 한 번만 넘김(S5-1-Q3)');
    });

    test('영업을 닫으면 손님이 오지 않고 시계가 멈춘다', () async {
      final (c, setNow) = await open();
      addTearDown(c.dispose);
      expect(await c.closeBusiness(), isTrue);
      expect(c.state.regularClock.nextAt, isNull);
      expect(c.state.namedClock.nextAt, isNull);
      setNow(start.add(const Duration(hours: 5)));
      await flush(c);
      expect(c.state.customers, isEmpty);
      expect(c.upcomingArrivals(const Duration(days: 1)), isEmpty);
      expect(await c.openBusiness(), isTrue);
      expect(c.state.regularClock.nextAt! - ms(start.add(const Duration(hours: 5))), inInclusiveRange(60000, 900000),
          reason: '다시 열면 연 시각부터 셈');
    });

    test('KST 자정이 지나면 열린 영업이 저절로 다음 영업일이 되고 재고·미션도 함께 넘어간다', () async {
      // 23:00 KST.
      final evening = DateTime.utc(2026, 11, 18, 14);
      final (c, setNow) = await open(from: evening);
      addTearDown(c.dispose);
      expect(c.state.business.businessIndex, 1);
      expect(await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'old', flavor: 'redbean', variant: 2,
            quantity: 1, madeOnBusinessIndex: 1), keep: true);
        // The named neighbor is due one minute after midnight.
        c.state.namedClock = c.state.namedClock.withNext(ms(DateTime.utc(2026, 11, 18, 15, 1)));
        c.state.regularClock = c.state.regularClock.withNext(ms(DateTime.utc(2026, 11, 18, 14, 10)));
      }), isTrue, reason: '${c.notice} ${c.error}');
      setNow(DateTime.utc(2026, 11, 18, 15, 2));
      await flush(c);
      expect(c.state.business.open, isTrue);
      expect(c.state.business.businessIndex, 2);
      expect(c.state.business.acceptedDay, '2026-11-19');
      expect(c.state.business.permitsProducts(c.now()), isTrue, reason: "'이어서 영업'을 누를 필요 없음");
      expect(c.state.missions.playDays.values.expand((d) => d), contains('2026-11-19'));
      final visit = (c.state.relationships.toJson()['visits'] as Map).values.single as Map;
      expect(visit['day'], 2, reason: '자정 뒤 손님은 새 영업일 손님');
      expect(anonymous(c), greaterThanOrEqualTo(1), reason: '자정 전 일반 손님은 그대로 기다림');
      expect(c.state.inventory.batches.values.single.madeOnBusinessIndex, 1);
    });

    test('손님 기다림 5분은 앱을 켠 순간부터 센다', () async {
      var mono = 0;
      final (c, setNow) = await open(mono: () => mono);
      addTearDown(c.dispose);
      await c.setForeground(false);
      setNow(start.add(const Duration(hours: 3)));
      mono += 10000000; // The monotonic clock ran on in the background.
      await c.setForeground(true);
      expect(c.state.customers, hasLength(4));
      for (final order in c.state.customers) {
        expect(order.remainingMs, c.initialWaitMs(order), reason: '꺼진 동안은 기다림이 줄지 않음');
      }
      expect(c.awayReport!.arrivals, 4);
      mono += 1000;
      await flush(c);
      for (final order in c.state.customers) {
        expect(order.remainingMs, c.initialWaitMs(order) - 1000);
      }
    });

    test('미리보기(알림 예약)와 실제 도착은 같은 손님·같은 순서다', () async {
      for (final seedStart in [start, start.add(const Duration(minutes: 7)), DateTime.utc(2026, 11, 18, 14, 30)]) {
        final (c, setNow) = await open(from: seedStart);
        final planned = c.upcomingArrivals(const Duration(hours: 24));
        expect(planned.where((a) => a.kind == ArrivalKind.regular).length, 3);
        expect(planned.where((a) => a.kind == ArrivalKind.named).length, 1);
        await c.setForeground(false);
        setNow(seedStart.add(const Duration(hours: 24)));
        await c.setForeground(true);
        expect(c.state.customers.map((o) => c.customerCatalog.contains(o.customerId) ? o.customerId : 'regular').toList(),
            planned.map((a) => a.npc ?? 'regular').toList());
        c.dispose();
      }
    });

    test('이야기 장면 중에는 도착을 미뤘다가 장면이 끝나면 처리한다', () async {
      final (c, setNow) = await open();
      addTearDown(c.dispose);
      expect(await c.command(() {
        c.state.relationships = c.state.relationships.visit('prior', 'npc_doyun', 1, c.customerCatalog)
            .completeStory('npc_doyun', 'story_doyun_01', c.customerCatalog, eligible: true);
        c.state.lastNamedVisitor = 'npc_doyun';
      }), isTrue);
      expect(await c.replayCustomerStory('story_doyun_01'), isTrue);
      setNow(start.add(const Duration(hours: 4)));
      await flush(c);
      expect(c.state.customers, isEmpty);
      expect(await c.finishCustomerScene(), isTrue);
      await flush(c);
      expect(c.state.customers, hasLength(4));
      expect(c.state.customers.where((o) => c.customerCatalog.contains(o.customerId)).single.customerId, isNot('npc_doyun'),
          reason: '바로 앞 네임드(도윤)는 빼고 소개');
    });

    test('첫 실행 안내 중에는 도윤이 바로 오고, 첫 판매로 안내가 끝나면 실제 시간 시계가 시작된다', () async {
      final c = WorkshopController(config, MemoryRepository(), now: () => start, random: Random(5), monotonicMs: () => 0);
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.state.tutorial, 'cook');
      expect(await c.openBusiness(), isTrue);
      expect(c.state.regularClock.nextAt, isNull, reason: '안내 중에는 시계 없음');
      for (var i = 0; i < 30 && c.state.customers.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // The arrival command may still be saving (busy) right after the
      // customer shows up; wait so the next command is not refused.
      for (var i = 0; i < 40 && c.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(c.state.customers.single.customerId, 'npc_doyun');
      final order = c.state.customers.single;
      expect(await c.command(() {
        for (final line in order.lines) {
          c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'tutorial-${line.flavor}', flavor: line.flavor,
              variant: line.variant ?? 2, quantity: line.quantity, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
        }
      }), isTrue);
      expect(await c.sellToCustomer(order.id), isTrue, reason: '${c.notice} ${c.error}');
      expect(c.state.tutorial, 'done');
      expect(c.state.regularClock.nextAt, isNotNull);
      expect(c.state.namedClock.nextAt, isNotNull);
    });
  });

  group('저장 schema 7', () {
    test('6→7 이전: 시계는 멈춘 채 만들고 직전 네임드는 관계 기록의 최근 방문, 잘못된 7은 거절', () async {
      final (c, _) = await open();
      addTearDown(c.dispose);
      expect(await c.command(() {
        c.state.relationships = c.state.relationships.visit('v1', 'npc_doyun', 1, c.customerCatalog)
            .visit('v2', 'npc_yunha', 1, c.customerCatalog);
      }), isTrue);
      final saved = c.state.toJson();
      expect(saved['schema'], 8);
      final old = Map<String, dynamic>.from(saved)
        ..['schema'] = 6
        ..remove('regularClock')..remove('namedClock')..remove('lastNamedVisitor')..remove('featureIntros');
      final migrated = WorkshopState.fromJson(old, config);
      expect(migrated.regularClock.nextAt, isNull);
      expect(migrated.namedClock.nextAt, isNull);
      expect(migrated.lastNamedVisitor, 'npc_yunha');
      expect(migrated.toJson()['schema'], 8);
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..remove('namedClock'), config), throwsFormatException);
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(old)..['regularClock'] = saved['regularClock'], config),
          throwsFormatException, reason: '6에 새 필드');
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['lastNamedVisitor'] = 'npc_sua', config),
          throwsFormatException, reason: '만난 적 없는 직전 손님');
      final closed = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      (closed['business'] as Map)['open'] = false;
      expect(() => WorkshopState.fromJson(closed, config), throwsFormatException, reason: '닫힌 가게에 도는 시계');
      final far = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      (far['regularClock'] as Map)['nextAt'] = ms(start) + 86400000;
      expect(() => WorkshopState.fromJson(far, config), throwsFormatException, reason: '최대 간격보다 먼 시계');
      // Reloading an old save starts the clocks from the load.
      final repository = MemoryRepository()..saved = old;
      final again = WorkshopController(config, repository, now: () => start.add(const Duration(minutes: 1)), monotonicMs: () => 0);
      addTearDown(again.dispose);
      await again.initialize();
      expect(again.state.regularClock.nextAt! - ms(start.add(const Duration(minutes: 1))), inInclusiveRange(60000, 900000));
    });
  });

  group('손님 알림', () {
    final quietCases = {
      // Local minute → in the quiet night (22:00~08:00)?
      21 * 60 + 59: false, 22 * 60: true, 0: true, 7 * 60 + 59: true, 8 * 60: false, 12 * 60: false,
    };
    test('밤 10시~아침 8시 판정은 자정을 넘는다', () {
      for (final e in quietCases.entries) {
        expect(inQuietNight(e.key, 1320, 480), e.value, reason: '${e.key}');
      }
      expect(inQuietNight(600, 540, 660), isTrue);
    });
    test('종류별 끔, 일반 최대 3번, 밤 건너뜀, 네임드는 짧은 이름', () {
      final catalog = WorkshopCustomerCatalog.bundled();
      final base = DateTime.utc(2026, 11, 18, 3);
      final arrivals = [
        for (var i = 0; i < 4; i++) PlannedArrival(ArrivalKind.regular, base.add(Duration(minutes: i + 1))),
        PlannedArrival(ArrivalKind.named, base.add(const Duration(hours: 1)), 'npc_doyun'),
        PlannedArrival(ArrivalKind.named, base.add(const Duration(hours: 13)), 'npc_yunha'),
      ];
      // Local minute = UTC + 9h here, so the last one is at 01:00.
      int kst(DateTime t) => (t.hour * 60 + t.minute + 540) % 1440;
      final defaults = planCustomerNotices(arrivals, settings: GameSettings(), config: config, catalog: catalog, localMinute: kst);
      expect(defaults.map((n) => n.body), ['도윤이 찾아왔어요. 따끈한 붕어빵을 기다려요.'],
          reason: '기본: 일반 끔·네임드 켬·밤 끄기 켬');
      expect(defaults.single.title, '오늘의 붕어빵');
      final all = planCustomerNotices(arrivals, settings: GameSettings(notifyRegularGuests: true, quietNightNotices: false),
          config: config, catalog: catalog, localMinute: kst);
      expect(all.where((n) => n.body == regularNoticeBody), hasLength(3), reason: '일반은 최대 3번');
      expect(all.last.body, '윤하 씨가 찾아왔어요. 따끈한 붕어빵을 기다려요.');
      expect(all.map((n) => n.id).toSet(), hasLength(all.length));
      expect(planCustomerNotices(arrivals, settings: GameSettings(notifyNamedGuests: false), config: config, catalog: catalog,
          localMinute: kst), isEmpty);
    });
    test('설정 기본값과 저장: 옛 설정은 기본값(네임드 켬·일반 끔·밤 끄기 켬)으로 읽는다', () {
      final old = GameSettings.fromJson({'vibration': true});
      expect((old.notifyRegularGuests, old.notifyNamedGuests, old.quietNightNotices, old.notificationPromptDone),
          (false, true, true, false));
      final changed = GameSettings(notifyRegularGuests: true, notifyNamedGuests: false, quietNightNotices: false,
          notificationPromptDone: true);
      final back = GameSettings.fromJson(changed.toJson());
      expect((back.notifyRegularGuests, back.notifyNamedGuests, back.quietNightNotices, back.notificationPromptDone),
          (true, false, false, true));
      expect(() => GameSettings.fromJson({'notifyNamedGuests': 'yes'}), throwsFormatException);
    });

    testWidgets('앱을 내리면(paused) 예약하고 켜면 모두 취소, inactive·안내 중에는 예약 없음', (tester) async {
      final account = await mountGame(tester, const Size(390, 844), reduced: true);
      final notifier = FakeNotifier();
      final c = WorkshopController(config, MemoryRepository(), now: () => start, random: Random(5), monotonicMs: () => 0);
      await c.initialize();
      await tester.pumpWidget(GameApp(controller: account, workshop: c, notifier: notifier));
      await tester.pump();
      Future<void> lifecycle(AppLifecycleState state) async {
        tester.binding.handleAppLifecycleStateChanged(state);
        for (var i = 0; i < 5; i++) { await tester.pump(); }
      }
      // During the guide: nothing to schedule.
      await lifecycle(AppLifecycleState.inactive);
      await lifecycle(AppLifecycleState.hidden);
      await lifecycle(AppLifecycleState.paused);
      expect(notifier.scheduled, isNotEmpty);
      expect(notifier.scheduled.every((n) => n.isEmpty), isTrue);
      await lifecycle(AppLifecycleState.hidden);
      await lifecycle(AppLifecycleState.inactive);
      await lifecycle(AppLifecycleState.resumed);
      expect(notifier.cancels, 1);

      expect(await c.command(() => c.state.tutorial = 'done'), isTrue);
      expect(await c.openBusiness(), isTrue);
      notifier.scheduled.clear();
      await lifecycle(AppLifecycleState.inactive);
      expect(notifier.scheduled, isEmpty, reason: 'inactive만으로는 예약하지 않음');
      await lifecycle(AppLifecycleState.hidden);
      await lifecycle(AppLifecycleState.paused);
      final notices = notifier.scheduled.last;
      expect(notices.map((n) => n.body), contains('도윤이 찾아왔어요. 따끈한 붕어빵을 기다려요.'));
      expect(notices.every((n) => n.body != regularNoticeBody), isTrue, reason: '일반 손님 알림 기본 끔');
      final named = c.upcomingArrivals(const Duration(days: 1)).firstWhere((a) => a.kind == ArrivalKind.named);
      expect(notices.firstWhere((n) => n.body.startsWith('도윤')).at, named.at, reason: '알림 시각 = 실제 도착 시각');
      await lifecycle(AppLifecycleState.hidden);
      await lifecycle(AppLifecycleState.inactive);
      await lifecycle(AppLifecycleState.resumed);
      expect(notifier.cancels, 2);
      await tester.pumpWidget(const SizedBox.shrink()); // GameApp disposes the workshop.
    });

    testWidgets('첫 판매 뒤 한 번 알림을 묻고, 거절하면 두 알림이 꺼진 채 안내 문구를 보인다', (tester) async {
      for (final grant in [true, false]) {
        // GameApp disposes both controllers when it goes away: a fresh pair each round.
        final account = await mountGame(tester, const Size(390, 844), reduced: true);
        expect(account.state.settings.notificationPromptDone, isFalse);
        final notifier = FakeNotifier(grant: grant);
        final c = WorkshopController(config, MemoryRepository(), now: () => start, random: Random(5), monotonicMs: () => 0);
        await c.initialize();
        await tester.pumpWidget(GameApp(controller: account, workshop: c, notifier: notifier));
        await tester.pump();
        expect(find.byKey(const Key('notice-prompt')), findsNothing, reason: '판매 전에는 묻지 않음');
        expect(await c.command(() => c.state.tutorial = 'skipped'), isTrue);
        expect(await c.openBusiness(), isTrue);
        expect(await c.welcomeCustomer(), isTrue);
        final order = c.state.customers.single;
        expect(await c.command(() {
          for (final line in order.lines) {
            c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'p-${line.flavor}', flavor: line.flavor,
                variant: line.variant ?? 2, quantity: line.quantity, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
          }
        }), isTrue);
        expect(await c.sellToCustomer(order.id), isTrue);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('notice-prompt')), findsOneWidget);
        expect(find.textContaining('앱을 꺼 둬도 단골손님이 오면'), findsOneWidget);
        await tester.tap(find.byKey(const Key('notice-accept')));
        for (var i = 0; i < 5; i++) { await tester.pump(); }
        expect(notifier.permissionAsks, 1);
        expect(account.state.settings.notificationPromptDone, isTrue);
        expect(account.state.settings.notifyNamedGuests, grant);
        expect(account.state.settings.notifyRegularGuests, isFalse);
        expect(find.text('휴대폰 설정에서 이 앱의 알림을 허용해야 받을 수 있어요.'), grant ? findsNothing : findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byKey(const Key('notice-prompt')), findsNothing, reason: '한 번만 물음');
        await tester.pumpWidget(const SizedBox.shrink()); // GameApp disposes the workshop.
      }
    });
  });
}
