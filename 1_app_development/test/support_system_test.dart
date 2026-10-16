import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/game_events.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'package:todays_bungeoppang/support_state.dart';
import 'package:todays_bungeoppang/support_rules.dart';
import 'controller_test.dart' show FakeTime, catchPlacedGoldenChance;
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

  test('개별/전체 보상은 각기 한 번, 전체 보상 코인도 중복 지급 불가', () async {
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
    expect(c.state.support.coins, BigInt.from(20)); // 2+3+2+3 and 10.
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

  test('부스트는 클릭·자동 생산 모두에 적용되고 정확한 만료 경계에서 끝난다', () async {
    final clock = FakeTime();
    final ctrl = atLevel(1, clock);
    setRate(ctrl.state, BigInt.from(10));
    expect(await catchPlacedGoldenChance(ctrl), isTrue);
    expect(ctrl.state.support.boostUses, BigInt.one);
    expect(ctrl.activeBoost!.kind, BoostKind.golden);
    expect(ctrl.currentTapRate, BigInt.from(3));
    expect(ctrl.currentAutoRate, BigInt.from(30));
    expect(ctrl.tap(), BigInt.from(3));
    clock.advance(59999);
    ctrl.tick();
    expect(ctrl.currentTapRate, BigInt.from(3));
    clock.advance(1);
    ctrl.tick();
    expect(ctrl.currentTapRate, BigInt.one);
    expect(ctrl.currentAutoRate, BigInt.from(10));
    expect(ctrl.activeBoost, isNull);
    expect(ctrl.state.support.effects['golden']!.remainingMs(ctrl.gameNow), 0);
    clock.advance(240000);
    ctrl.tick();
    expect(ctrl.state.buns, BigInt.from(3 + 60 * 30 + 240 * 10));
    expect(ctrl.state.support.boostUses, BigInt.one);
    ctrl.dispose();
  });
  test('부스트 배율은 일일 기본 초당 생산 목표를 대신 달성하지 않는다', () async {
    final c = atLevel(1, FakeTime());
    setRate(c.state, BigInt.from(5));
    expect(await catchPlacedGoldenChance(c), isTrue);
    expect(c.currentAutoRate, BigInt.from(15));
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
      c.state.support.effects['golden'] = ActiveBoost(
          BoostKind.golden,
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
    c.state.support.effects['golden'] = ActiveBoost(
        BoostKind.golden,
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
    expect(
        await c.applyGuestVisits(const [
          GuestVisit(id: 'visit-1', name: '단골', kind: BoostKind.visit)
        ]),
        isTrue);
    final saved = jsonDecode(disk['current']!)['support'] as Map;
    expect((saved['effects'] as Map)['visit']['remainingMs'], 300000);
    c.dispose();
    clock.advance(600000);
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    // 300 s at 30/s, then 300 s at 10/s, both at the 50% offline rate.
    expect(restart.lastOfflineReward, BigInt.from(6000));
    expect(restart.state.buns, BigInt.from(6000));
    expect(restart.state.support.daily.production, BigInt.zero);
    expect(restart.currentAutoRate, BigInt.from(10));
    expect(restart.currentTapRate, BigInt.one);
    expect(restart.state.support.effects['visit']!.remainingMs(restart.gameNow),
        0);
    restart.dispose();
  });
  test('효과 만료 후 시계를 되돌려도 효과 부활·추가 미접속 보상 없음', () async {
    final clock = FakeTime(), c = atLevel(1, FakeTime());
    final ctrl = GameController(c.repository, clock)..state = c.state;
    expect(await catchPlacedGoldenChance(ctrl), isTrue);
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

  test('꾸미기 코인 구매: 잔액 부족·잠금·영구 보유와 붕어빵 비용 분리', () async {
    final c = atLevel(6, FakeTime());
    fund(c, '10');
    c.state.buns = BigInt.from(10000);
    expect(await c.buyOrEquipCosmetic('invalid'), isFalse);
    expect(await c.buyOrEquipCosmetic('heartscale'), isTrue);
    expect(c.state.support.coins, BigInt.from(5));
    expect(await c.buyOrEquipCosmetic('scales'), isTrue);
    expect(await c.buyOrEquipCosmetic('heartscale'), isTrue);
    expect(c.state.support.coins, BigInt.from(5)); // Owned for good.
    expect(c.state.equippedCosmetic(CosmeticSlot.pattern), 'heartscale');
    expect(await c.buyOrEquipCosmetic('chefhat'), isFalse); // 10 coins.
    expect(c.state.support.coins, BigInt.from(5));
    expect(c.state.buns, BigInt.from(10000));
    expect(c.state.support.ledger.keys.toSet(),
        {'test:fund', 'cosmetic:heartscale'});
    final poor = atLevel(1, FakeTime());
    fund(poor, '10');
    expect(await poor.buyOrEquipCosmetic('beanie'), isFalse); // Lv.2 item.
    expect(poor.state.support.coins, BigInt.from(10));
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

  test('지연된 저장 중 중복 지급 금지와 일일/부스트/꾸미기/업적 실패 전체 롤백', () async {
    final clock = FakeTime(),
        repo = SlowRepository(),
        c = atLevel(10, FakeTime());
    final ctrl = GameController(repo, clock)..state = c.state;
    fund(ctrl);
    completeDaily(ctrl);
    ctrl.tick();
    for (final action in <Future<bool> Function()>[
      () => ctrl.claimDaily(ctrl.state.support.daily.day, 'all'),
      () => catchPlacedGoldenChance(ctrl),
      () => ctrl.buyOrEquipCosmetic('heartscale'),
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

  test('손상된 잔액·중복 거래·나머지·부스트 남은 시간은 조용한 초기화 없이 거부', () {
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
    c.state.support.startBoost(boostOf(BoostKind.visit), c.gameNow);
    final time = json();
    time['support']['effects']['visit']['remainingMs'] = 123;
    expect(() => GameState.fromJson(time), throwsFormatException);
    final key = json();
    key['support']['effects'] = {
      'invite': key['support']['effects']['visit']
    };
    expect(() => GameState.fromJson(key), throwsFormatException);
    final kind = json();
    kind['support']['effects']['visit']['id'] = 'fairy';
    expect(() => GameState.fromJson(kind), throwsFormatException);
    final visits = json();
    visits['support']['appliedVisits'] = ['a', 'a'];
    expect(() => GameState.fromJson(visits), throwsFormatException);
    c.dispose();
  });

  group('부스트 (stage 14)', () {
    final t0 = DateTime.utc(2026, 10, 5, 3);
    Duration sec(int s) => Duration(seconds: s);

    test('같은 부스트는 남은 시간에 더해지고, 여러 개면 가장 강한 배율만 적용', () {
      final s = SupportState.initial(t0);
      expect(s.multiplier(t0), BigInt.from(effectScale));
      s.startBoost(boostOf(BoostKind.golden), t0); // ×3, 60 s.
      expect(s.multiplier(t0), BigInt.from(3000));
      expect(s.multiplier(t0.subtract(const Duration(milliseconds: 1))),
          BigInt.from(effectScale));
      s.startBoost(boostOf(BoostKind.golden), t0.add(sec(30)));
      final golden = s.effects['golden']!;
      expect(golden.startedAtUtc, t0);
      expect(golden.endsAtUtc, t0.add(sec(120))); // Extended, not restarted.
      expect(golden.multiplierPermille, BigInt.from(3000));
      s.startBoost(boostOf(BoostKind.invite), t0.add(sec(30))); // ×5, 600 s.
      expect(s.effects.keys.toSet(), {'golden', 'invite'});
      expect(s.multiplier(t0.add(sec(100))), BigInt.from(5000)); // Not ×15.
      expect(s.multiplier(t0.add(sec(629))), BigInt.from(5000));
      expect(s.multiplier(t0.add(sec(630))), BigInt.from(effectScale));
      // An expired boost starts afresh instead of extending the old one.
      s.startBoost(boostOf(BoostKind.golden), t0.add(sec(700)));
      expect(s.effects['golden']!.startedAtUtc, t0.add(sec(700)));
      expect(s.effects['golden']!.endsAtUtc, t0.add(sec(760)));
      expect(s.multiplier(t0.add(sec(759))), BigInt.from(3000));
      expect(s.boostUses, BigInt.from(4));
      final restored =
          SupportState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(restored.toJson(), s.toJson());
    });

    test('방문 ID는 한 번만 기록되고 오래된 기록부터 잊는다', () {
      final s = SupportState.initial(t0);
      expect(s.markVisit('a'), isTrue);
      expect(s.markVisit('a'), isFalse);
      for (var i = 0; i < SupportState.appliedVisitLimit; i++) {
        expect(s.markVisit('v$i'), isTrue);
      }
      expect(s.appliedVisits.length, SupportState.appliedVisitLimit);
      expect(s.appliedVisits.contains('a'), isFalse);
      expect(s.appliedVisits.contains('v0'), isTrue);
    });

    test('support-v1 저장: 아이템과 효과는 버리고 사용 횟수는 부스트 사용으로 이전', () {
      final c = atLevel(1, FakeTime());
      fund(c, '7');
      final json = jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>;
      final now = c.gameNow;
      (json['support'] as Map<String, dynamic>)
        ..['configVersion'] = legacySupportConfigVersion
        ..remove('boostUses')
        ..remove('appliedVisits')
        ..['inventory'] = {'fairy': '2', 'butter': '1'}
        ..['itemUses'] = {'fairy': '3', 'butter': '4'}
        ..['effects'] = {
          'butter': {
            'id': 'butter',
            'channel': 'tap',
            'multiplierPermille': '2000',
            'startedAtUtc': now.toIso8601String(),
            'endsAtUtc': now.add(const Duration(minutes: 1)).toIso8601String(),
            'remainingMs': 60000
          }
        };
      final restored = GameState.fromJson(json);
      final s = restored.support;
      expect(s.boostUses, BigInt.from(7));
      expect(s.effects, isEmpty);
      expect(s.multiplier(now), BigInt.from(effectScale));
      expect(s.appliedVisits, isEmpty);
      expect(s.coins, BigInt.from(7));
      expect(s.ledger.keys, ['test:fund']);
      final saved = s.toJson();
      expect(saved['configVersion'], supportConfigVersion);
      expect(saved.containsKey('inventory'), isFalse);
      expect(saved.containsKey('itemUses'), isFalse);
      // Migrates once: the v2 result reloads unchanged.
      final again = GameState.fromJson(jsonDecode(jsonEncode(restored.toJson())));
      expect(again.toJson(), restored.toJson());
      // A v1 save still has to be well formed.
      final noUses = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      (noUses['support'] as Map).remove('itemUses');
      expect(() => GameState.fromJson(noUses), throwsFormatException);
      final negative = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      (negative['support'] as Map)['itemUses'] = {'fairy': '-1'};
      expect(() => GameState.fromJson(negative), throwsFormatException);
      final unknown = jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>;
      (unknown['support'] as Map)['configVersion'] = 'support-v0';
      expect(() => GameState.fromJson(unknown), throwsFormatException);
      c.dispose();
    });

    test('황금 찬스: 3~7분 뒤 등장, 8초 뒤 사라짐, 다른 칸·지난 찬스는 거부', () async {
      final clock = FakeTime()..now = t0;
      // Delay picks are seconds past the 3 minute minimum; then the cavity.
      final random = ScriptedRandom([0, 4, 240, 2, 0, 5, 0]);
      final c = GameController(MemoryGameRepository(), clock,
          goldenRandom: random)
        ..state = (GameState.initial(t0)..tutorialDone = true);
      c.tick(); // Schedules the first chance 180 s from now.
      expect(c.goldenChance, isNull);
      expect(await c.catchGoldenChance(0), isFalse);
      clock.advance(179999);
      c.tick();
      expect(c.goldenChance, isNull);
      clock.advance(1);
      c.tick();
      expect(c.goldenChance!.slot, 4);
      expect(c.goldenChance!.expiresAtMs, 188000);
      expect(await c.catchGoldenChance(3), isFalse); // Wrong cavity.
      expect(c.goldenChance, isNotNull);
      clock.advance(7999);
      c.tick();
      expect(c.goldenChance, isNotNull);
      clock.advance(1);
      c.tick();
      expect(c.goldenChance, isNull); // Gone; next one 420 s later.
      expect(await c.catchGoldenChance(4), isFalse);
      clock.advance(419999);
      c.tick();
      expect(c.goldenChance, isNull);
      clock.advance(1);
      c.tick();
      expect(c.goldenChance!.slot, 2);
      clock.advance(8000); // Expired, before any tick noticed.
      expect(await c.catchGoldenChance(2), isFalse);
      expect(c.state.support.boostUses, BigInt.zero);
      c.tick(); // Next one 180 s later.
      clock.advance(180000);
      c.tick();
      expect(c.goldenChance!.slot, 5);
      clock.advance(7999);
      final events = <GameEvent>[];
      c.events.listen(events.add);
      expect(await c.catchGoldenChance(5), isTrue);
      expect(c.goldenChance, isNull);
      expect(await c.catchGoldenChance(5), isFalse); // Caught only once.
      expect(c.state.support.boostUses, BigInt.one);
      expect(c.activeBoost!.kind, BoostKind.golden);
      expect(c.activeBoost!.remainingMs(c.gameNow), 60000);
      // No golden goal at Lv.1: the boost runs, no mission counts it.
      expect(c.state.missions.goldenCatches, BigInt.zero);
      expect(random.picks, isEmpty);
      await pumpEventQueue();
      expect(events.single.kind, GameEventKind.boostStarted);
      c.dispose();
    });

    test('손님 방문은 방문 ID마다 한 번만 부스트를 주고 저장 실패는 되돌린다', () async {
      final repo = MemoryGameRepository();
      final c = atLevel(1, FakeTime(), repo);
      const invite =
          GuestVisit(id: 'invite:p1', name: '민지', kind: BoostKind.invite);
      const visit = GuestVisit(
          id: 'visit:p2:2026-01-01', name: '준호', kind: BoostKind.visit);
      expect(await c.applyGuestVisits(const [invite, visit]), isTrue);
      expect(c.state.support.boostUses, BigInt.two);
      expect(c.state.support.appliedVisits, {invite.id, visit.id});
      expect(c.guestArrivals, [invite, visit]);
      expect(c.activeBoost!.kind, BoostKind.invite);
      final ends = c.state.support.effects['invite']!.endsAtUtc;
      // Delivered again (or with a duplicate in the batch): nothing changes.
      expect(await c.applyGuestVisits(const [invite, visit, visit]), isFalse);
      expect(c.state.support.boostUses, BigInt.two);
      expect(c.state.support.effects['invite']!.endsAtUtc, ends);
      expect(c.guestArrivals, [invite, visit]);
      // Only invite and visit kinds come from visits.
      expect(
          await c.applyGuestVisits(const [
            GuestVisit(id: 'x', name: '?', kind: BoostKind.bought),
            GuestVisit(id: 'y', name: '?', kind: BoostKind.golden),
          ]),
          isFalse);
      expect(c.state.support.appliedVisits, {invite.id, visit.id});
      c.guestShown(invite);
      expect(c.guestArrivals, [visit]);
      // Saved: a restart still knows the visit.
      expect((await repo.load())!.support.appliedVisits, {invite.id, visit.id});
      const late = GuestVisit(
          id: 'visit:p3:2026-01-01', name: '서연', kind: BoostKind.visit);
      repo.failNextSave = true;
      expect(await c.applyGuestVisits(const [late]), isFalse);
      expect(c.state.support.appliedVisits.contains(late.id), isFalse);
      expect(c.guestArrivals, [visit]);
      expect(await c.applyGuestVisits(const [late]), isTrue);
      expect(c.state.support.boostUses, BigInt.from(3));
      expect(c.guestArrivals, [visit, late]);
      c.dispose();
    });
  });
}

/// Returns scripted picks in order, so golden chance timing is exact.
class ScriptedRandom implements math.Random {
  final List<int> picks;
  ScriptedRandom(this.picks);
  @override
  int nextInt(int max) {
    final v = picks.removeAt(0);
    expect(v, lessThan(max));
    return v;
  }

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}
