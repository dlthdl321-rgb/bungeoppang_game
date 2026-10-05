import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'package:todays_bungeoppang/support_state.dart';
import 'package:todays_bungeoppang/support_rules.dart';
import 'controller_test.dart' show FakeTime;
import 'economy_persistence_test.dart' show JsonRepository;
import 'economy_simulation_test.dart' show SlowRepository;
import 'level_missions_test.dart' show atLevel, setRate;

void fund(GameController c, [String amount = '100']) {
  expect(
      c.state.support
          .transact('test:fund', BigInt.parse(amount), 'fixture', c.gameNow),
      isTrue);
}

void completeDaily(GameController c) {
  c.state.support.daily.taps = BigInt.from(50);
  c.state.support.daily.production = BigInt.from(1000);
  c.state.support.daily.purchases = BigInt.from(3);
  setRate(c.state, BigInt.from(10));
}

void main() {
  test('기본 추정 설정, 재화 분리와 레벨 코인 거래 ID 중복 방지', () async {
    final c = atLevel(1, FakeTime());
    expect(supportEvidence, 'estimated');
    c.state.lifetime = BigInt.from(10);
    final buns = c.state.buns;
    expect(await c.claimLevelUp(2), isTrue);
    expect(c.state.support.coins, BigInt.from(3));
    expect(c.state.support.ledger['level:2']!.delta, BigInt.from(3));
    expect(c.state.buns, buns);
    expect(c.state.stars, BigInt.zero); // Legacy field no longer spendable.
    expect(await c.claimLevelUp(2), isFalse);
    expect(c.state.support.ledger.length, 1);
    c.dispose();
  });

  test('실제 입력·생산·묶음 구매 수량·기본 초당 목표 집계와 실패한 구매 제외', () async {
    final c = atLevel(1, FakeTime());
    c.state.buns = BigInt.from(100000);
    for (var i = 0; i < 50; i++) {
      c.tap();
    }
    expect(c.state.support.daily.taps, BigInt.from(50));
    expect(c.state.support.daily.production, BigInt.from(50));
    expect(await c.buyUpgrade(upgrades.first, 10), isTrue);
    expect(c.state.support.daily.purchases, BigInt.from(10));
    final auto = upgrades.firstWhere((u) => u.id == 'auto_1');
    expect(await c.buyUpgrade(auto, 10), isTrue);
    expect(c.state.support.daily.peakAuto, BigInt.from(10));
    c.settleActive(95000);
    expect(c.state.support.daily.production, BigInt.from(1000));
    expect(dailyAllComplete(c.state), isTrue);
    expect(await c.buyUpgrade(upgrades.first, -1), isFalse);
    expect(c.state.support.daily.purchases, BigInt.from(20));
    c.dispose();
  });

  test('개별/전체 보상은 각기 한 번, 전체 보상 아이템도 중복 생성 불가', () async {
    final c = atLevel(1, FakeTime());
    final day = c.state.support.daily.day;
    expect(await c.claimDaily(day, 'taps'), isFalse);
    expect(await c.claimDaily(day, 'unknown'), isFalse);
    expect(await c.claimDaily(day, 'all'), isFalse);
    completeDaily(c);
    expect(await c.claimDaily(day, 'all'), isTrue);
    expect(await c.claimDaily(day, 'all'), isFalse);
    for (final d in dailyDefinitions) {
      expect(await c.claimDaily(day, d.id), isTrue);
      expect(await c.claimDaily(day, d.id), isFalse);
    }
    expect(c.state.support.coins, BigInt.from(15));
    expect(c.state.support.inventory,
        {'fairy': BigInt.from(2), 'butter': BigInt.from(2)});
    expect(c.state.support.ledger.length, 5);
    c.dispose();
  });

  test('한국 자정 직전/정각/이후·오래 열린 수령 버튼·시계 역행·여러 날 건너뜀', () async {
    final clock = FakeTime()..now = DateTime.utc(2026, 1, 1, 14, 59, 59);
    final c = atLevel(1, clock);
    final day = c.state.support.daily.day;
    completeDaily(c);
    expect(await c.claimDaily(day, 'taps'), isTrue);
    clock.advance(1000);
    c.tick();
    expect(c.state.support.daily.day, '2026-01-02');
    expect(c.state.support.daily.taps, BigInt.zero);
    expect(c.state.support.daily.production, BigInt.zero);
    expect(c.state.support.daily.claimed, isEmpty);
    expect(await c.claimDaily(day, 'production'), isFalse);
    final now = clock.now;
    clock.now = clock.now.subtract(const Duration(days: 1));
    c.tick();
    expect(c.state.support.daily.day, '2026-01-02');
    expect(await c.claimDaily(day, 'taps'), isFalse);
    clock.now = now.add(const Duration(days: 10));
    c.tick();
    expect(c.state.support.daily.day, '2026-01-12');
    expect(c.state.support.coins, BigInt.from(2));
    expect(c.state.support.ledger.length, 1);
    c.dispose();
  });

  test('자정을 가로지르는 자동 생산은 실제 해당 날짜에만 집계', () {
    final clock = FakeTime()..now = DateTime.utc(2026, 1, 1, 14, 59, 59);
    final c = atLevel(1, clock);
    setRate(c.state, BigInt.from(10));
    clock.advance(2000);
    c.tick();
    expect(c.state.buns, BigInt.from(20));
    expect(c.state.support.daily.production, BigInt.from(10));
    expect(c.state.support.daily.day, '2026-01-02');
    c.dispose();
  });

  test('아이템 수량 소비·채널 분리·사용 횟수·중복 활성화 방지·정확한 만료 경계', () async {
    final clock = FakeTime();
    final ctrl = atLevel(1, clock);
    ctrl.state.support.inventory['butter'] = BigInt.from(2);
    setRate(ctrl.state, BigInt.from(10));
    expect(await ctrl.useItem('butter'), isTrue);
    expect(ctrl.state.support.inventory['butter'], BigInt.one);
    expect(ctrl.currentTapRate, BigInt.from(2));
    expect(ctrl.currentAutoRate, BigInt.from(10));
    expect(ctrl.tap(), BigInt.from(2));
    expect(await ctrl.useItem('butter'), isFalse);
    expect(ctrl.state.support.inventory['butter'], BigInt.one);
    expect(ctrl.state.support.itemUses['butter'], BigInt.one);
    expect(await ctrl.useItem('fairy'), isTrue);
    expect(ctrl.currentAutoRate, BigInt.from(20));
    clock.advance(59999);
    ctrl.tick();
    expect(ctrl.currentTapRate, BigInt.from(2));
    clock.advance(1);
    ctrl.tick();
    expect(ctrl.currentTapRate, BigInt.one);
    expect(ctrl.state.support.effects['butter']!.remainingMs(ctrl.gameNow), 0);
    clock.advance(240000);
    ctrl.tick();
    expect(ctrl.currentAutoRate, BigInt.from(10));
    expect(ctrl.state.buns, BigInt.from(6002));
    expect(ctrl.state.support.itemUses['fairy'], BigInt.one);
    ctrl.dispose();
  });

  test('요정 배율은 일일 기본 초당 생산 목표를 대신 달성하지 않는다', () async {
    final c = atLevel(1, FakeTime());
    setRate(c.state, BigInt.from(5));
    expect(await c.useItem('fairy'), isTrue);
    expect(c.currentAutoRate, BigInt.from(10));
    expect(c.state.support.daily.peakAuto, BigInt.from(5));
    expect(await c.claimDaily(c.state.support.daily.day, 'auto'), isFalse);
    c.dispose();
  });

  test('부분 일일 진행·수령 기록은 재시작 복원, 다음 날에는 새 거래로 수령', () async {
    final clock = FakeTime(), disk = <String, String>{};
    final c = atLevel(1, clock, JsonRepository(disk));
    for (var i = 0; i < 50; i++) {
      c.tap();
    }
    final day = c.state.support.daily.day;
    expect(await c.claimDaily(day, 'taps'), isTrue);
    c.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.state.support.daily.taps, BigInt.from(50));
    expect(restart.state.support.daily.production, BigInt.from(50));
    expect(restart.state.support.daily.purchases, BigInt.zero);
    expect(restart.state.support.daily.claimed, {'taps'});
    expect(await restart.claimDaily(day, 'taps'), isFalse);
    clock.advance(const Duration(days: 1).inMilliseconds);
    restart.tick();
    for (var i = 0; i < 50; i++) {
      restart.tap();
    }
    final newDay = restart.state.support.daily.day;
    expect(newDay, isNot(day));
    expect(await restart.claimDaily(newDay, 'taps'), isTrue);
    expect(restart.state.support.coins, BigInt.from(4));
    expect(restart.state.support.ledger.keys.toSet(),
        {'daily:$day:taps', 'daily:$newDay:taps'});
    restart.dispose();
  });

  test('만료를 넘는 큰 tick과 1ms 분할 정산은 억·조 및 소수 배율에서도 일치', () {
    final clock = FakeTime(),
        a = atLevel(1, FakeTime()),
        b = atLevel(1, FakeTime());
    for (final c in [a, b]) {
      setRate(c.state, BigInt.parse('20000000000001'));
      c.state.support.effects['fairy'] = ActiveItem(
          'fairy',
          EffectChannel.automatic,
          BigInt.from(1501),
          clock.utcNow,
          clock.utcNow.add(const Duration(milliseconds: 777)));
    }
    for (var i = 0; i < 1001; i++) {
      a.settleActive(1);
    }
    b.settleActive(1001);
    expect(a.state.buns, b.state.buns);
    expect(a.state.support.autoFraction, b.state.support.autoFraction);
    final numerator = BigInt.parse('20000000000001') *
        BigInt.from(777 * 1501 * 2 + 224 * 1000 * 2);
    expect(a.state.buns, numerator ~/ BigInt.from(productionQuantum));
    a.dispose();
    b.dispose();
  });

  test('클릭 소수 배율의 재화 나머지도 손실 없이 저장한다', () {
    final c = atLevel(1, FakeTime());
    c.state.support.effects['butter'] = ActiveItem(
        'butter',
        EffectChannel.tap,
        BigInt.from(1500),
        c.gameNow,
        c.gameNow.add(const Duration(seconds: 60)));
    expect(c.tap(), BigInt.one);
    expect(c.state.support.tapFraction, BigInt.from(500));
    c.state = GameState.fromJson(jsonDecode(jsonEncode(c.state.toJson())));
    expect(c.tap(), BigInt.from(2));
    expect(c.state.buns, BigInt.from(3));
    expect(c.state.support.tapFraction, BigInt.zero);
    c.dispose();
  });

  test('활성 효과 재실행: 만료 전후를 나눠 오프라인 50% 정산하고 일일 생산에는 제외', () async {
    final clock = FakeTime(), disk = <String, String>{};
    final c = atLevel(1, clock, JsonRepository(disk));
    setRate(c.state, BigInt.from(10));
    await c.useItem('fairy');
    await c.useItem('butter');
    final saved = jsonDecode(disk['current']!)['support'] as Map;
    expect((saved['effects'] as Map)['fairy']['remainingMs'], 300000);
    c.dispose();
    clock.advance(600000);
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.lastOfflineReward, BigInt.from(4500));
    expect(restart.state.buns, BigInt.from(4500));
    expect(restart.state.support.daily.production, BigInt.zero);
    expect(restart.currentAutoRate, BigInt.from(10));
    expect(restart.currentTapRate, BigInt.one);
    expect(restart.state.support.inventory['fairy'], BigInt.zero);
    expect(restart.state.support.effects['fairy']!.remainingMs(restart.gameNow),
        0);
    restart.dispose();
  });

  test('효과 만료 후 시계를 되돌려도 효과 부활·추가 미접속 보상 없음', () async {
    final clock = FakeTime(), c = atLevel(1, FakeTime());
    final ctrl = GameController(c.repository, clock)..state = c.state;
    await ctrl.useItem('butter');
    clock.advance(60000);
    ctrl.tick();
    clock.now = clock.now.subtract(const Duration(minutes: 2));
    ctrl.tick();
    expect(ctrl.currentTapRate, BigInt.one);
    await ctrl.leaveActive();
    expect(await ctrl.resume(), BigInt.zero);
    expect(ctrl.currentTapRate, BigInt.one);
    c.dispose();
    ctrl.dispose();
  });

  test('코인 상점 거래 번호 중복·잔액 부족·꾸미기 영구 보유와 비용 분리', () async {
    final c = atLevel(6, FakeTime());
    fund(c);
    c.state.buns = BigInt.from(10000);
    expect(await c.buyCoinItem('fairy', 0), isTrue);
    expect(await c.buyCoinItem('fairy', 0), isFalse);
    expect(c.state.support.coins, BigInt.from(97));
    expect(c.state.support.inventory['fairy'], BigInt.from(2));
    expect(await c.buyCoinItem('invalid', 1), isFalse);
    expect(await c.buyOrEquip(skins.last), isTrue);
    expect(c.state.support.coins, BigInt.from(85));
    expect(await c.buyOrEquip(skins.last), isTrue);
    expect(c.state.support.coins, BigInt.from(85));
    expect(c.state.equippedSkin, 'cocoa');
    expect(c.state.buns, BigInt.from(10000));
    expect(c.state.support.ledger.keys.toSet(),
        {'test:fund', 'shop:0', 'skin:cocoa'});
    final poor = atLevel(1, FakeTime());
    expect(await poor.buyCoinItem('fairy', 0), isFalse);
    expect(poor.state.support.purchaseSequence, 0);
    poor.dispose();
    c.dispose();
  });

  // Stage 8: the final mock exchange became the Lv.10 achievement.
  test('Lv.10 업적 조건·1회 수령·칭호·재시작 후 중복 금지', () async {
    final clock = FakeTime(), disk = <String, String>{};
    final c = atLevel(9, clock, JsonRepository(disk));
    fund(c);
    expect(await c.claimAchievement('level-10'), isFalse);
    c.state.level = 10;
    c.state.missions = MissionState.forLevel(10, clock.utcNow);
    expect(await c.claimAchievement('level-10'), isTrue);
    expect(c.state.support.coins, BigInt.from(100));
    expect(c.state.achievements.titles, {'골목 명장'});
    expect(await c.claimAchievement('level-10'), isFalse);
    c.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(await restart.claimAchievement('level-10'), isFalse);
    expect(restart.state.support.ledger['achievement:level-10']!.reason,
        '업적 Lv.10 완주');
    restart.dispose();
  });

  test('지연된 저장 중 중복 지급 금지와 일일/아이템/상점/교환 실패 전체 롤백', () async {
    final clock = FakeTime(),
        repo = SlowRepository(),
        c = atLevel(10, FakeTime());
    final ctrl = GameController(repo, clock)..state = c.state;
    fund(ctrl);
    completeDaily(ctrl);
    ctrl.tick();
    for (final action in <Future<bool> Function()>[
      () => ctrl.claimDaily(ctrl.state.support.daily.day, 'all'),
      () => ctrl.useItem('fairy'),
      () => ctrl.buyCoinItem('butter', ctrl.state.support.purchaseSequence),
      () => ctrl.claimAchievement('level-5'),
    ]) {
      final before = ctrl.state.toJson();
      repo.pending = Completer<void>();
      repo.failNextSave = true;
      final running = action();
      expect(ctrl.busy, isTrue);
      expect(await action(), isFalse);
      repo.pending!.complete();
      expect(await running, isFalse);
      expect(ctrl.state.toJson(), before);
    }
    expect(await ctrl.claimAchievement('level-5'), isTrue);
    c.dispose();
    ctrl.dispose();
  });

  test('v3 기존 잔액·레벨 보상 보존 및 코인 1:1 이전은 재실행해도 한번', () async {
    final clock = FakeTime(), old = atLevel(6, FakeTime());
    old.state.stars = BigInt.from(10).pow(100);
    old.state.levelRewards[6] =
        LevelRewardRecord(level: 6, seasonId: 'legacy-v3', source: 'legacy');
    old.state.activeRemainder = BigInt.from(321);
    final json = old.state.toJson()
      ..['formatVersion'] = 3
      ..remove('support');
    final disk = {'current': jsonEncode(json)};
    final c = GameController(JsonRepository(disk), clock);
    await c.initialize();
    expect(c.state.support.coins, old.state.stars);
    expect(c.state.support.autoFraction, BigInt.from(642000));
    expect(c.state.levelRewards[6]!.source, 'legacy');
    expect(await c.claimLevelUp(6), isFalse);
    await c.save();
    final before = c.state.toJson();
    c.dispose();
    final again = GameController(JsonRepository(disk), clock);
    await again.initialize();
    expect(again.state.toJson(), before);
    expect(again.state.support.ledger.keys, ['migration:v4']);
    old.dispose();
    again.dispose();
  });

  test('손상된 잔액·중복 거래·나머지·아이템 남은 시간은 조용한 초기화 없이 거부', () {
    final c = atLevel(1, FakeTime());
    fund(c);
    Map<String, dynamic> json() => jsonDecode(jsonEncode(c.state.toJson()));
    final balance = json();
    balance['support']['coins'] = '999';
    expect(() => GameState.fromJson(balance), throwsFormatException);
    final duplicate = json();
    duplicate['support']['ledger'].add(duplicate['support']['ledger'].first);
    expect(() => GameState.fromJson(duplicate), throwsFormatException);
    final fraction = json();
    fraction['support']['autoFraction'] = '$productionQuantum';
    expect(() => GameState.fromJson(fraction), throwsFormatException);
    c.state.support.effects['fairy'] = ActiveItem(
        'fairy',
        EffectChannel.automatic,
        BigInt.from(2000),
        c.gameNow,
        c.gameNow.add(const Duration(seconds: 300)));
    final time = json();
    time['support']['effects']['fairy']['remainingMs'] = 123;
    expect(() => GameState.fromJson(time), throwsFormatException);
    c.dispose();
  });
}
