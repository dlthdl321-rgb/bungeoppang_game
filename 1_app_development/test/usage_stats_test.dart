import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/owner_account.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/gold_widgets.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'fake_time.dart' show FakeTime;
import 'step02_controller_test.dart' show MemoryRepository;

/// A fake recorder: keeps what would have gone to Firebase Analytics.
class RecordingSink implements UsageStatsSink {
  final events = <(String, Map<String, Object>)>[];
  final switches = <bool>[];
  final properties = <String>[];
  bool throwNow = false, failLater = false;
  List<String> get names => [for (final e in events) e.$1];
  /// 'name {param: value}' lines (maps compare by identity inside records).
  List<String> get lines => [for (final e in events) e.$2.isEmpty ? e.$1 : '${e.$1} ${e.$2}'];
  @override
  Future<void> setEnabled(bool enabled) async => switches.add(enabled);
  @override
  Future<void> log(String name, Map<String, Object> parameters) {
    if (throwNow) throw StateError('analytics broke');
    events.add((name, parameters));
    return failLater ? Future.error(StateError('offline')) : Future.value();
  }
  @override
  Future<void> setUserProperty(String name, String? value) async =>
      properties.add('$name=$value');
}

DevelopmentBalance _config() => DevelopmentBalance.fromJson(
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

CookingSession _bakedPractice(String id) {
  var s = CookingSession.start(id: id, flavor: 'redbean', practice: true,
      fillingSequence: [CookingDirection.left]);
  s = s.pour(s.token, PaintAmount.even); s = s.fill(s.token, CookingDirection.left);
  s = s.pour(s.token, PaintAmount.even); s = s.close(s.token); return s.flip(s.token);
}

/// 26번 5단계: Firebase Analytics 사용 통계(DEC-045·046).
void main() {
  group('기록기', () {
    test('이벤트는 11개 이하(재료 타이쿤 B ingredient_out), 영문 소문자·밑줄 40자 이하, Analytics 예약어가 아니다', () {
      final names = UsageEvent.values.map((e) => e.wireName).toList();
      expect(names.length, lessThanOrEqualTo(11));
      expect(names.toSet().length, names.length);
      for (final n in names) {
        expect(RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(n), isTrue, reason: n);
        expect(n.startsWith('firebase_') || n.startsWith('google_') || n.startsWith('ga_'), isFalse, reason: n);
        expect({'first_open', 'session_start', 'app_remove', 'user_engagement', 'screen_view'}, isNot(contains(n)));
      }
    });
    test('상점·충전 화면은 한국 날짜로 하루 1번, 결제 완료는 매번', () {
      var now = DateTime.utc(2026, 11, 18, 14, 59); // KST 23:59
      final sink = RecordingSink(), usage = UsageStats(sink, now: () => now);
      usage.record(UsageEvent.shopOpen);
      usage.record(UsageEvent.shopOpen);
      usage.record(UsageEvent.payView);
      usage.record(UsageEvent.payDone, {'product_id': 'gold_60'});
      usage.record(UsageEvent.payDone, {'product_id': 'gold_60'});
      now = DateTime.utc(2026, 11, 18, 15); // KST 다음 날 00:00
      usage.record(UsageEvent.shopOpen);
      usage.record(UsageEvent.payView);
      expect(sink.names, ['shop_open', 'pay_view', 'pay_done', 'pay_done', 'shop_open', 'pay_view']);
      expect(sink.events[2].$2, {'product_id': 'gold_60'}, reason: '상품 ID만, 금액 없음');
    });
    test('끄면 아무것도 남기지 않고 Analytics 수집도 끈다, 다시 켜면 이어서 남긴다', () {
      final sink = RecordingSink(), usage = UsageStats(sink);
      usage.setEnabled(false);
      usage.record(UsageEvent.shopOpen);
      usage.observeProgress(const UsageProgress(bakes: 0, sales: 0, level: 1, tutorial: 'cook'),
          const UsageProgress(bakes: 1, sales: 1, level: 3, tutorial: 'done'));
      expect(sink.events, isEmpty);
      expect(sink.switches, [false]);
      usage.setEnabled(true);
      usage.record(UsageEvent.shopOpen);
      expect(sink.switches, [false, true]);
      expect(sink.names, ['shop_open']);
    });
    test('Analytics가 바로 던지거나 나중에 실패해도 게임 쪽으로 오류가 나가지 않는다', () async {
      final sink = RecordingSink()..throwNow = true, usage = UsageStats(sink);
      expect(() => usage.record(UsageEvent.payDone, {'product_id': 'gold_60'}), returnsNormally);
      sink..throwNow = false..failLater = true;
      expect(() => usage.record(UsageEvent.payDone, {'product_id': 'gold_60'}), returnsNormally);
      await Future<void>.delayed(Duration.zero); // 실패한 Future가 잡히지 않으면 테스트가 실패한다
    });
    test('진행 비교: 첫 굽기·첫 판매·안내 끝·Lv.3·5·10을 한 번씩', () {
      final sink = RecordingSink(), usage = UsageStats(sink);
      usage.observeProgress(const UsageProgress(bakes: 0, sales: 0, level: 1, tutorial: 'sell'),
          const UsageProgress(bakes: 1, sales: 1, level: 4, tutorial: 'skipped'));
      usage.observeProgress(const UsageProgress(bakes: 1, sales: 1, level: 4, tutorial: 'skipped'),
          const UsageProgress(bakes: 5, sales: 9, level: 12, tutorial: 'skipped'));
      expect(sink.lines, [
        'first_bake',
        'first_sale',
        'tutorial_done {result: skipped}',
        'level_reached {level: 3}',
        'level_reached {level: 5}',
        'level_reached {level: 10}',
      ]);
    });
  });

  group('첫 실행 동의 전에는 모으지 않음(DEC-126)', () {
    test('동의 전: 설정이 켬이어도 Analytics 수집을 끄고 이벤트를 남기지 않는다, 동의 뒤 켠다', () {
      final sink = RecordingSink(), usage = UsageStats(sink, consented: false);
      usage.setEnabled(true); // GameController.initialize, 기본 켬
      expect(sink.switches, [false]);
      expect([usage.enabled, usage.consented, usage.collecting], [true, false, false]);
      usage.record(UsageEvent.shopOpen);
      usage.observeProgress(const UsageProgress(bakes: 0, sales: 0, level: 1, tutorial: 'cook'),
          const UsageProgress(bakes: 1, sales: 0, level: 1, tutorial: 'cook'));
      expect(sink.events, isEmpty);
      usage.setConsented(true);
      usage.setConsented(true); // 저장마다 알려도 Analytics에는 바뀔 때만
      expect(sink.switches, [false, true]);
      usage.record(UsageEvent.shopOpen);
      expect(sink.names, ['shop_open']);
      // 설정을 끄면 동의가 있어도 끈다.
      usage.setEnabled(false);
      expect(sink.switches, [false, true, false]);
      usage.setEnabled(true);
      // 계정 삭제·재동의가 필요하면 다시 멈춘다.
      usage.setConsented(false);
      expect(sink.switches, [false, true, false, true, false]);
      usage.record(UsageEvent.payDone, {'product_id': 'gold_60'});
      expect(sink.names, ['shop_open']);
    });
    test('설정을 끈 사람은 동의해도 수집을 켜지 않는다', () {
      final sink = RecordingSink(), usage = UsageStats(sink, consented: false);
      usage.setEnabled(false);
      usage.setConsented(true);
      expect(sink.switches, [false, false]);
      expect(usage.collecting, isFalse);
    });
    test('main.dart는 동의 전 상태로 시작하고 매니페스트는 수집 꺼짐이 기본', () {
      expect(File('lib/main.dart').readAsStringSync(), contains('UsageStats(FirebaseUsageStatsSink(), consented: false)'));
      expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
          contains('<meta-data android:name="firebase_analytics_collection_enabled" android:value="false" />'));
    });
    test('UsageOwnerAnalytics는 동의 상태를 기록기에 넘긴다', () {
      final sink = RecordingSink(), usage = UsageStats(sink, consented: false);
      final owner = UsageOwnerAnalytics(usage);
      owner.setConsented(true);
      expect(usage.consented, isTrue);
      expect(sink.switches, [true]);
    });
  });

  group('선택 정보 사용자 속성(2-1단계 연결)', () {
    test('성별·연령대만 gender·age_band로, 선택 안 함·없음은 지운다', () {
      final sink = RecordingSink(), owner = UsageOwnerAnalytics(UsageStats(sink));
      owner.setUserProperties(gender: 'female', ageBand: '20s');
      owner.setUserProperties(gender: 'none', ageBand: 'none');
      owner.setUserProperties();
      expect(sink.properties, [
        'gender=female', 'age_band=20s',
        'gender=null', 'age_band=null',
        'gender=null', 'age_band=null',
      ]);
      expect(sink.events, isEmpty, reason: '사용자 속성은 이벤트가 아님');
    });
  });

  group('Workshop 한 바퀴', () {
    final now = DateTime.utc(2026, 11, 18);
    test('새 설치: 굽기 → 보관 → 영업 → 첫 판매 → 승급, 저장된 명령 뒤에만 남긴다', () async {
      final sink = RecordingSink(), repository = MemoryRepository();
      final c = WorkshopController(_config(), repository, now: () => now, random: Random(7),
          usage: UsageStats(sink, now: () => now));
      await c.initialize();
      expect(sink.events, isEmpty, reason: '새 게임 시작은 이벤트가 아님(first_open은 Analytics가 자동으로)');
      expect(c.state.tutorial, 'cook');

      final first = _bakedPractice('practice-1');
      await c.command(() => c.state.session = first);
      expect(await c.cookingCommand(first.takeOut(first.token, 15000)), isTrue);
      expect(sink.names, ['first_bake']);
      expect(await c.storeResult(true), isTrue);
      final second = _bakedPractice('practice-2');
      await c.command(() => c.state.session = second);
      await c.cookingCommand(second.takeOut(second.token, 15000));
      await c.storeResult(true);
      expect(sink.names, ['first_bake'], reason: '두 번째 굽기는 남기지 않음');

      expect(await c.openBusiness(), isTrue);
      await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(
            id: 'product', flavor: 'redbean', variant: 2, quantity: 2, madeOnBusinessIndex: 1), keep: true);
        c.state.customers.add(CustomerOrder(id: 'customer', remainingMs: 10000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
      });
      // 저장에 실패한 판매는 남기지 않는다.
      repository.fail = true;
      expect(await c.sellToFirstCustomer(), isFalse);
      expect(sink.names, ['first_bake']);
      await c.reloadAfterError();
      expect(await c.sellToFirstCustomer(), isTrue);
      expect(c.state.tutorial, 'done');
      expect(sink.lines.skip(1), ['first_sale', 'tutorial_done {result: done}']);

      // 승급 조건 대신 저장 검사에 맞는 레벨만 바로 올린다.
      Future<bool> reach(int level) => c.command(() {
        for (var n = c.state.level + 1; n <= level; n++) { c.state.claimedLevels.add(n); }
        c.state.level = level;
      });
      expect(await reach(2), isTrue);
      expect(sink.names.where((n) => n == 'level_reached'), isEmpty);
      expect(await reach(3), isTrue);
      expect(await reach(3), isTrue);
      expect(sink.lines.last, 'level_reached {level: 3}');
      expect(sink.names.where((n) => n == 'level_reached'), hasLength(1));
      c.dispose();
    });
    test('안내 건너뛰기는 tutorial_done(skipped)', () async {
      final sink = RecordingSink();
      final c = WorkshopController(_config(), MemoryRepository(), now: () => now, usage: UsageStats(sink));
      await c.initialize();
      expect(await c.skipTutorial(), isTrue);
      expect(sink.lines, ['tutorial_done {result: skipped}']);
      c.dispose();
    });
    test('schema 5 이하 저장을 안내 끝으로 읽는 경로와 다시 열기는 아무것도 남기지 않는다', () async {
      final seed = WorkshopController(_config(), MemoryRepository(), now: () => now);
      await seed.initialize();
      final old = seed.state.toJson()..['schema'] = 5..remove('tutorial')..remove('regularClock')
        ..remove('namedClock')..remove('lastNamedVisitor')..remove('featureIntros')..remove('daily')..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales')..remove('friendBoost');
      seed.dispose();
      final sink = RecordingSink(), repository = MemoryRepository()..saved = old;
      final c = WorkshopController(_config(), repository, now: () => now, usage: UsageStats(sink));
      await c.initialize();
      expect(c.state.tutorial, 'done');
      await c.command(() {});
      c.dispose();
      final again = WorkshopController(_config(), repository, now: () => now, usage: UsageStats(sink));
      await again.initialize();
      again.dispose();
      expect(sink.events, isEmpty);
    });
  });

  group('설정 사용 통계 보내기', () {
    test('기본 켬, 옛 설정은 켬으로 읽고 저장 형식은 그대로', () {
      expect(GameSettings().sendUsageStats, isTrue);
      expect(GameSettings.fromJson({'vibration': true}).sendUsageStats, isTrue);
      final off = GameSettings(sendUsageStats: false);
      expect(GameSettings.fromJson(off.toJson()).sendUsageStats, isFalse);
      expect(() => GameSettings.fromJson({'sendUsageStats': 'no'}), throwsFormatException);
    });
    test('시작할 때 저장된 값을 Analytics에 알리고, 끄면 저장 뒤 수집을 끈다', () async {
      final sink = RecordingSink(), repository = MemoryGameRepository();
      final c = GameController(repository, FakeTime(), usage: UsageStats(sink));
      await c.initialize();
      expect(sink.switches, [true]);
      await c.updateSettings(sendUsageStats: false);
      expect(c.state.settings.sendUsageStats, isFalse);
      expect(sink.switches, [true, false]);
      expect(c.usage.enabled, isFalse);
      c.usage.record(UsageEvent.shopOpen);
      expect(sink.events, isEmpty);
      await c.updateSettings(vibration: false);
      expect(sink.switches, [true, false], reason: '다른 설정은 Analytics 스위치를 건드리지 않음');
      c.dispose();
      final reopened = GameController(repository, FakeTime(), usage: UsageStats(sink));
      await reopened.initialize();
      expect(reopened.state.settings.sendUsageStats, isFalse);
      expect(sink.switches.last, isFalse);
      reopened.dispose();
    });
    testWidgets('황금 충전 탭을 열면 pay_view를 하루 1번', (tester) async {
      final sink = RecordingSink();
      final c = GameController(MemoryGameRepository(), FakeTime(), usage: UsageStats(sink))
        ..state = GameState.initial(DateTime.utc(2026, 11, 18));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: GoldChargeTab(controller: c)))));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: GoldChargeTab(controller: c)))));
      await tester.pump();
      expect(sink.names, ['pay_view']);
      c.dispose();
    });
  });
}
