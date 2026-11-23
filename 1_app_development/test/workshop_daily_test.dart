@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'widget_test.dart' show setUpAccount;
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_daily.dart';
import 'package:todays_bungeoppang/workshop_online.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';
import 'usage_stats_test.dart' show RecordingSink;
import 'workshop_controller_test.dart' show Repository;
import 'workshop_online_test.dart' show Transport;

/// 26번 7단계 — 매일 돌아올 이유: 오늘의 주문서, 출석, 이야기 하루 한 조각,
/// 겨울 행사. Days are KST days of the settled business time.
Map<String, dynamic> _raw() =>
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;

/// Stories ready from the first meeting for 도윤 and 윤하, so the daily limit shows.
DevelopmentBalance _storyConfig() {
  final raw = _raw();
  raw['customer_story_conditions']['npc_doyun'] = {'stage': 0};
  raw['customer_story_conditions']['npc_yunha'] = {'stage': 0};
  return DevelopmentBalance.fromJson(raw);
}

class _Shop {
  final DevelopmentBalance config;
  final Repository repository;
  DateTime now;
  final sink = RecordingSink();
  late final WorkshopController c;
  _Shop(this.config, this.now, {Repository? repository, WorkshopPurchaseGateway? gateway})
      : repository = repository ?? Repository() {
    c = WorkshopController(config, this.repository, now: () => now, random: Random(7), purchaseGateway: gateway,
        monotonicMs: () => 0, usage: UsageStats(sink, now: () => now));
  }
  /// A returning Lv.5 player (guide done) who has met 도윤 and 윤하.
  Future<void> start({bool open = true}) async {
    await c.initialize();
    expect(await c.openBusiness(), isTrue);
    expect(await c.command(() {
      c.state.tutorial = 'done';
      c.state.featureIntros.add('fairy');
      c.state.level = 5;
      c.state.claimedLevels..clear()..addAll([2, 3, 4, 5]);
      c.state.relationships = c.state.relationships
          .visit('known-doyun', 'npc_doyun', c.state.business.businessIndex, c.customerCatalog)
          .visit('known-yunha', 'npc_yunha', c.state.business.businessIndex, c.customerCatalog);
    }), isTrue, reason: c.notice);
    if (!open) expect(await c.closeBusiness(), isTrue);
  }
  Future<void> nextDay([int days = 1]) async {
    if (c.state.business.open) expect(await c.closeBusiness(), isTrue);
    now = now.add(Duration(days: days));
    expect(await c.command(() {}), isTrue, reason: c.error ?? c.notice);
  }
  var _ids = 0;
  Future<void> stock(String flavor, int variant, int quantity) async {
    expect(await c.command(() {
      c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'stock-${_ids++}', flavor: flavor,
          variant: variant, quantity: quantity, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
    }), isTrue, reason: c.notice);
  }
  /// Brings [npc] and sells them what they asked for.
  Future<void> sellTo(String npc) async {
    expect(await c.welcomeCustomer(visitor: npc), isTrue, reason: c.notice);
    final order = c.state.customers.firstWhere((o) => o.customerId == npc);
    for (final line in order.lines) {
      await stock(line.flavor, line.variant ?? 2, line.quantity);
    }
    expect(await c.sellToCustomer(order.id), isTrue, reason: c.notice);
  }
}

void main() {
  _widgets();
  final kst1 = DateTime.utc(2026, 11, 2, 3); // KST 2026-11-02 12:00, no event

  test('사흘 흐름: 1일 주문서·출석 1칸·이야기 1개(두 번째는 예고), 2일 미룬 이야기, 하루 걸러 4일 출석 3칸', () async {
    final shop = _Shop(_storyConfig(), kst1);
    final c = shop.c;
    addTearDown(c.dispose);
    await shop.start();

    // ---- 1일 ----
    expect(c.today, '2026-11-02');
    final order1 = c.dailyOrder!;
    expect(order1.day, '2026-11-02');
    expect(c.state.recipes, contains(order1.flavor));
    expect(['npc_doyun', 'npc_yunha'], contains(order1.npc));
    expect(c.attendanceReady, isTrue);
    expect(c.dailyWaiting, isTrue);
    var buns = c.state.buns;
    expect(await c.stampAttendance(), isTrue);
    // 4차 g7: R = 탭 힘 1 × 2 + 자동 0 = 2/초, 출석 300초 → 600(최소 100보다 큼).
    expect(c.dailyRate, BigInt.two);
    expect(c.state.buns - buns, BigInt.parse('600'), reason: 'R × 300초');
    expect(c.state.daily.stamps, 1);
    expect(await c.stampAttendance(), isFalse, reason: '하루 한 칸');
    expect(c.state.daily.stamps, 1);

    // The order needs its flavor and doneness in stock.
    expect(await c.deliverDailyOrder(), isFalse);
    expect(c.notice, contains('모자라요'));
    await shop.stock(order1.flavor, order1.variant == 1 ? 2 : 1, 5); // wrong doneness
    expect(await c.deliverDailyOrder(), isFalse);
    await shop.stock(order1.flavor, order1.variant, order1.quantity);
    final affinity = c.state.relationships.affinity(order1.npc!);
    buns = c.state.buns;
    expect(await c.deliverDailyOrder(), isTrue, reason: c.notice);
    expect(c.state.buns - buns, BigInt.parse('1200'), reason: 'R 2 × 600초(최소 200보다 큼)');
    expect(c.state.relationships.affinity(order1.npc!) - affinity, 3);
    expect(c.dailyOrder!.done, isTrue);
    expect(c.dailyWaiting, isFalse);
    expect(await c.deliverDailyOrder(), isFalse, reason: '하루 한 번');
    expect(shop.sink.lines, contains('special_order_done {event: none}'));
    expect(WorkshopState.fromJson(shop.repository.stored!, c.config).daily.order!.done, isTrue);

    // One story a day: 도윤's opens, 윤하's waits with a hint.
    await shop.sellTo('npc_doyun');
    expect(c.state.customerScene!['kind'], 'story');
    expect(await c.finishCustomerScene(), isTrue);
    expect(c.storiesOpenedToday, 1);
    await shop.sellTo('npc_yunha');
    expect(c.state.customerScene, isNull);
    expect(c.notice, '내일 윤하 씨가 이야기를 이어 갈 것 같아요.');
    expect(c.state.relationships.stories, {'story_doyun_01'});

    // ---- 2일 ----
    await shop.nextDay();
    expect(await c.openBusiness(), isTrue);
    expect(c.today, '2026-11-03');
    expect(c.dailyOrder!.day, '2026-11-03');
    expect(c.dailyOrder!.done, isFalse);
    expect(c.attendanceReady, isTrue);
    expect(await c.stampAttendance(), isTrue);
    expect(c.state.daily.stamps, 2);
    await shop.sellTo('npc_yunha');
    expect(c.state.customerScene!['kind'], 'story', reason: '미룬 이야기는 다음 날');
    expect(await c.finishCustomerScene(), isTrue);

    // ---- 3일은 건너뛰고 4일 ----
    await shop.nextDay(2);
    expect(c.today, '2026-11-05');
    expect(c.dailyOrder!.day, '2026-11-05', reason: '며칠 비워도 오늘 주문서 하나');
    expect(await c.stampAttendance(), isTrue);
    expect(c.state.daily.stamps, 3, reason: '놓쳐도 이어짐');
    expect(WorkshopState.fromJson(c.state.toJson(), c.config).toJson(), c.state.toJson());
  });

  test('기기 시계를 되돌려도 지난 날짜가 다시 열리지 않고, 앞당기면 하루만 넘어간다', () async {
    final shop = _Shop(_raw().let(DevelopmentBalance.fromJson), kst1);
    final c = shop.c;
    addTearDown(c.dispose);
    await shop.start(open: false);
    expect(await c.stampAttendance(), isTrue);
    await shop.nextDay();
    expect(await c.stampAttendance(), isTrue);
    final order = c.dailyOrder!.toJson();
    shop.now = kst1; // back to day 1
    expect(await c.command(() {}), isTrue);
    expect(c.today, '2026-11-03');
    expect(c.attendanceReady, isFalse);
    expect(await c.stampAttendance(), isFalse);
    expect(c.dailyOrder!.toJson(), order);
    shop.now = kst1.add(const Duration(days: 30));
    expect(await c.command(() {}), isTrue);
    expect(await c.stampAttendance(), isTrue);
    expect(c.state.daily.stamps, 3);
  });

  test('영업 중 자정을 넘기면 새 주문서와 출석이 열린다', () async {
    final shop = _Shop(_raw().let(DevelopmentBalance.fromJson), DateTime.utc(2026, 11, 2, 14, 50)); // KST 23:50
    final c = shop.c;
    addTearDown(c.dispose);
    await shop.start();
    expect(await c.stampAttendance(), isTrue);
    final before = c.dailyOrder!.day;
    shop.now = shop.now.add(const Duration(minutes: 20)); // KST 00:10
    expect(await c.command(() {}), isTrue, reason: c.error);
    expect(c.today, '2026-11-03');
    expect(c.state.business.acceptedDay, '2026-11-03');
    expect(c.dailyOrder!.day, isNot(before));
    expect(c.attendanceReady, isTrue);
  });

  test('오프라인 5일 뒤 돌아오면 출석은 한 칸, 주문서는 오늘 하나, 복귀 안내에 알린다', () async {
    final shop = _Shop(_raw().let(DevelopmentBalance.fromJson), kst1);
    addTearDown(shop.c.dispose);
    await shop.start(open: false);
    expect(await shop.c.stampAttendance(), isTrue);
    final back = _Shop(shop.config, kst1.add(const Duration(days: 5)), repository: shop.repository);
    addTearDown(back.c.dispose);
    await back.c.initialize();
    expect(back.c.awayReport!.newOrder, isTrue);
    expect(back.c.awayReport!.stampReady, isTrue);
    expect(back.c.dailyOrder!.day, '2026-11-07');
    expect(await back.c.stampAttendance(), isTrue);
    expect(await back.c.stampAttendance(), isFalse);
    expect(back.c.state.daily.stamps, 2);
  });

  test('주문서는 날짜와 설치로 고정되고 가진 레시피만 나온다', () {
    final config = DevelopmentBalance.fromJson(_raw());
    final a = makeDailyOrder(config, day: '2026-11-02', runId: 'run-1', flavors: ['redbean'], neighbors: []);
    final b = makeDailyOrder(config, day: '2026-11-02', runId: 'run-1', flavors: ['redbean'], neighbors: []);
    expect(a.toJson(), b.toJson());
    expect(a.npc, isNull, reason: '만난 단골이 없으면 동네 손님');
    final flavors = <String>{}, variants = <int>{}, quantities = <int>{}, days = <String>{};
    for (var d = 1; d <= 60; d++) {
      final day = '2026-12-${(d % 28 + 1).toString().padLeft(2, '0')}';
      final o = makeDailyOrder(config, day: day, runId: 'run-$d', flavors: ['custard', 'redbean'], neighbors: ['npc_doyun']);
      flavors.add(o.flavor); variants.add(o.variant); quantities.add(o.quantity); days.add(o.day);
      expect(o.npc, 'npc_doyun');
    }
    expect(flavors, {'custard', 'redbean'});
    expect(variants, {1, 2, 3});
    expect(quantities, {1, 2});
    expect(makeDailyOrder(config, day: '2026-11-03', runId: 'run-1', flavors: ['redbean'], neighbors: []).day, '2026-11-03');
  });

  test('행사는 설정 날짜 안에서만: 장식·인사·주문 문구, 참여는 한 번만 센다', () async {
    final config = DevelopmentBalance.fromJson(_raw());
    expect(activeSeasonalEvent(config, '2026-12-24')!.kind, 'christmas');
    expect(activeSeasonalEvent(config, '2026-12-20')!.id, 'christmas_2026');
    expect(activeSeasonalEvent(config, '2026-12-26')!.id, 'christmas_2026');
    expect(activeSeasonalEvent(config, '2026-12-27'), isNull);
    expect(activeSeasonalEvent(config, '2026-11-02'), isNull);
    // Dates come only from the config: move the event and it moves.
    final raw = _raw();
    final events = raw['daily_return']['seasonal_events'] as List;
    (events[1] as Map)['start'] = '2026-11-02';
    (events[1] as Map)['end'] = '2026-11-03';
    final moved = DevelopmentBalance.fromJson(raw);
    final shop = _Shop(moved, kst1);
    final c = shop.c;
    addTearDown(c.dispose);
    await shop.start();
    expect(c.seasonalEvent!.id, 'christmas_2026');
    expect(c.dailyOrder!.event, 'christmas_2026');
    expect(c.state.daily.events, {'christmas_2026'});
    await shop.nextDay();
    expect(c.seasonalEvent!.id, 'christmas_2026');
    await shop.nextDay();
    expect(c.seasonalEvent, isNull);
    expect(c.dailyOrder!.event, isNull);
    expect(shop.sink.lines.where((l) => l.startsWith('event_join')).toList(), ['event_join {event: christmas_2026}']);
    // No events at all: nothing changes.
    final none = _raw();
    for (final e in none['daily_return']['seasonal_events'] as List) {
      (e as Map)['start'] = '2020-01-01';
      e['end'] = '2020-01-02';
    }
    expect(activeSeasonalEvent(DevelopmentBalance.fromJson(none), '2026-12-24'), isNull);
  });

  test('행사 기간에도 안내 중이면 아무것도 열리지 않는다', () async {
    final shop = _Shop(DevelopmentBalance.fromJson(_raw()), DateTime.utc(2026, 12, 24, 3));
    final c = shop.c;
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.state.tutorialActive, isTrue);
    expect(c.seasonalEvent, isNull);
    expect(c.attendanceReady, isFalse);
    expect(await c.stampAttendance(), isFalse);
    expect(c.state.daily.events, isEmpty);
  });

  test('출석 7일째: 서버 없으면 붕어빵력, 서버가 있으면 황금 신청이 서버 검증으로 가고 다음은 1칸부터', () async {
    final offline = _Shop(DevelopmentBalance.fromJson(_raw()), kst1);
    addTearDown(offline.c.dispose);
    await offline.start(open: false);
    for (var day = 1; day <= 7; day++) {
      if (day > 1) await offline.nextDay();
      final before = offline.c.state.buns;
      expect(await offline.c.stampAttendance(), isTrue);
      expect(offline.c.state.buns - before, BigInt.parse(day == 7 ? '3600' : '600'), reason: 'R 2 × 1800초 / 300초');
    }
    expect(offline.c.state.pendingGold.keys.where((k) => k.startsWith('attendance:')), isEmpty);

    final transport = Transport();
    final online = _Shop(DevelopmentBalance.fromJson(_raw()), kst1, gateway: WorkshopOnline(transport));
    final c = online.c;
    addTearDown(c.dispose);
    await online.start(open: false);
    for (var day = 1; day <= 7; day++) {
      if (day > 1) await online.nextDay();
      expect(await c.stampAttendance(), isTrue);
    }
    expect(c.state.daily.stamps, 7);
    expect(c.state.pendingGold['attendance:2026-11-08'], attendanceClaim(c.config, '2026-11-08'));
    expect(c.pendingRewardCount, 1);
    expect(await c.syncRewards(), isTrue);
    expect(c.pendingRewardCount, 0);
    expect(transport.results.keys.single, '${c.state.grid.runId}:attendance:2026-11-08');
    expect(WorkshopState.fromJson(c.state.toJson(), c.config).rewardReceipts.keys, ['attendance:2026-11-08']);
    await online.nextDay();
    expect(c.nextStamp, 1);
    expect(await c.stampAttendance(), isTrue);
    expect(c.state.daily.stamps, 1);
    // A forged claim for a day after the last stamp is refused.
    final forged = c.state.toJson();
    (forged['pendingGold'] as Map)['attendance:2026-12-30'] = attendanceClaim(c.config, '2026-12-30');
    expect(() => WorkshopState.fromJson(forged, c.config), throwsFormatException);
  });

  test('저장 schema 10: 9 이하는 빈 매일 기록으로 읽고, 어긋난 기록은 거절한다', () async {
    final shop = _Shop(DevelopmentBalance.fromJson(_raw()), kst1);
    final c = shop.c;
    addTearDown(c.dispose);
    await shop.start();
    expect(await c.stampAttendance(), isTrue);
    final saved = c.state.toJson();
    expect(saved['schema'], workshopSchema);
    expect((saved['daily'] as Map)['stamps'], 1);

    final old = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>..['schema'] = 9..remove('daily')..remove('pantry');
    final migrated = WorkshopState.fromJson(old, c.config);
    expect(migrated.daily.toJson(), WorkshopDaily.empty.toJson());
    expect(migrated.toJson()['schema'], workshopSchema);
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['schema'] = 9, c.config), throwsFormatException,
        reason: '9에 새 필드');
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..remove('daily')..remove('pantry'), c.config), throwsFormatException,
        reason: '10에 기록 없음');

    Map<String, dynamic> broken(void Function(Map<String, dynamic> daily) change) {
      final copy = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      change(copy['daily'] as Map<String, dynamic>);
      return copy;
    }
    for (final (reason, change) in <(String, void Function(Map<String, dynamic>))>[
      ('가지지 않은 맛', (d) => (d['order'] as Map)['flavor'] = 'cocoa'),
      ('익힘 범위', (d) => (d['order'] as Map)['variant'] = 4),
      ('미래 날짜', (d) => d['day'] = '2026-11-09'),
      ('도장과 날짜', (d) => d['stampDay'] = null),
      ('7칸 넘음', (d) => d['stamps'] = 8),
      ('모르는 행사', (d) => d['events'] = ['halloween']),
      ('보상만 있음', (d) => (d['order'] as Map)['reward'] = '200'),
      ('친밀도 기록 없는 완료', (d) => (d['order'] as Map)..['reward'] = '200'..['businessIndex'] = 1),
    ]) {
      expect(() => WorkshopState.fromJson(broken(change), c.config), throwsFormatException, reason: reason);
    }
  });
}

void _widgets() {
  Future<(WorkshopController, _Shop)> mount(WidgetTester tester, {DateTime? at}) async {
    final account = await setUpAccount(tester, const Size(390, 844), reduced: true);
    final shop = _Shop(DevelopmentBalance.fromJson(_raw()), at ?? DateTime.utc(2026, 11, 2, 3));
    await shop.start();
    // Feature cards already seen: they would cover the home.
    await shop.c.command(() => shop.c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes',
        'specialOrders', 'fishCosmetics', 'freshness']));
    await tester.pumpWidget(GameApp(controller: account, workshop: shop.c));
    await tester.pump();
    return (shop.c, shop);
  }

  testWidgets('카운터 옆 오늘 쪽지: 출석 도장 → 주문서 납품, 빨간 점이 사라진다', (tester) async {
    final (c, shop) = await mount(tester);
    expect(find.byKey(const Key('daily-ticket')), findsOneWidget);
    expect(find.byKey(const Key('daily-ticket-dot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-ticket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-card')), findsOneWidget);
    expect(find.byKey(const Key('attendance-reward-buns')), findsOneWidget);
    await tester.tap(find.byKey(const Key('attendance-stamp')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance-done')), findsOneWidget);
    expect(find.byKey(const Key('attendance-count')), findsOneWidget);
    final order = c.dailyOrder!;
    expect(tester.widget<Text>(find.byKey(const Key('daily-order-what'))).data, contains('${order.quantity}개'));
    await shop.stock(order.flavor, order.variant, order.quantity);
    await tester.pump();
    await tester.tap(find.byKey(const Key('daily-order-deliver')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-order-done')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('daily-card')))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-ticket-dot')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('오늘 창 (3차 H33~H39): 출석 보상 글·일일 미션·주간 도전 기간·보상 받기', (tester) async {
    final (c, _) = await mount(tester);
    await tester.tap(find.byKey(const Key('daily-ticket')));
    await tester.pumpAndSettle();
    // H39: the seventh stamp's reward in words, from the settings.
    final rules = c.config.section('daily_return')['attendance'] as Map<String, dynamic>;
    expect(tester.widget<Text>(find.byKey(const Key('attendance-goal-text'))).data, startsWith('${rules['cycle_days']}번 출석하면'));
    expect(find.textContaining('하루를 걸러도'), findsNothing);
    // H33: the week from Monday to Sunday in words.
    expect(find.byKey(const Key('missions-daily')), findsOneWidget);
    expect(find.byKey(const Key('missions-weekly')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('missions-weekly-period'))).data, '11월 2일(월) ~ 11월 8일(일)');
    expect(tester.widget<Text>(find.byKey(const Key('weekly-left'))).data, '7일 남음');
    // H35: a finished mission shows '보상 받기'; others only their reward.
    expect(find.byKey(const Key('mission-daily-taps-claim')), findsNothing);
    final target = int.parse(((c.config.section('mission_targets')['daily'] as Map)['taps'] as Map)['target'] as String);
    await c.command(() => c.state.missions = c.state.missions.observe(c.now(), taps: target));
    await tester.pump();
    expect(find.text('보상 신청'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('mission-daily-taps-claim')));
    await tester.tap(find.byKey(const Key('mission-daily-taps-claim')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-daily-taps-claimed')), findsOneWidget);
    expect(c.state.missions.claims.keys, contains(c.state.missions.claimKey('daily', 'taps')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('오늘 쪽지 카드 골든 (크리스마스 행사 중)', (tester) async {
    final (c, _) = await mount(tester, at: DateTime.utc(2026, 12, 24, 3));
    expect(c.seasonalEvent!.kind, 'christmas');
    await tester.tap(find.byKey(const Key('daily-ticket')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-event')), findsOneWidget);
    expect(find.byKey(const Key('daily-order-note')), findsOneWidget);
    await expectLater(find.byKey(const Key('daily-card')), matchesGoldenFile('goldens/workshop_daily_card_390x844.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('매일 보상 기준 R = 탭 힘 × rate_taps_per_second + 자동/초, 최소값은 그대로 (4차 g7)', () {
    final config = DevelopmentBalance.fromJson(_raw());
    expect(DevelopmentBalance.integer(config.section('daily_return'), 'rate_taps_per_second'), 2);
    // 제안 시뮬레이션 Lv.10 무렵: 탭 98 · 자동 53/초 → R 249(1분 수입 14,940 = R × 60).
    final r = dailyIncomeRate(config, tapRate: BigInt.from(98), autoRate: BigInt.from(53));
    expect(r, BigInt.from(249));
    expect(dailyBuns(r, 600, BigInt.from(200)), BigInt.from(149400), reason: '주문서 = 수입 10분치');
    expect(dailyBuns(BigInt.zero, 600, BigInt.from(200)), BigInt.from(200), reason: '최소값');
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
