import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/achievement_config.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/invite_models.dart';
import 'package:todays_bungeoppang/menu_rules.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/missions.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/progress_rules.dart';
import 'package:todays_bungeoppang/progress_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'package:todays_bungeoppang/support_state.dart';
import 'controller_test.dart' show FakeTime;
import 'level_missions_test.dart' show setRate;
import 'widget_test.dart' show CountingRepository;

final now = DateTime.utc(2026, 10, 5, 3); // Monday 12:00 KST.

Map<String, dynamic> plainJson(GameState s) =>
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

GameState progressed() {
  final s = GameState.initial(now)
    ..buns = BigInt.parse('123456789012345678901234567890')
    ..lifetime = BigInt.parse('999999999999999999999')
    ..stars = BigInt.from(42)
    ..level = 3
    ..tutorialDone = true;
  s.missions = MissionState.forLevel(3, now);
  s.upgradeCounts['tap_1'] = 7;
  s.support.transact('test:fund', BigInt.from(42), 'test', now);
  s.support.inventory['butter'] = BigInt.from(3);
  s.ownedSkins.add('custard');
  s.equippedSkin = 'custard';
  s.wardrobe.owned.add('dusk');
  s.wardrobe.equipped[CosmeticSlot.background] = 'dusk';
  return s;
}

/// Rebuilds the JSON shape an older app version wrote for [s].
Map<String, dynamic> asVersion(GameState s, int version) {
  final json = plainJson(s)..['formatVersion'] = version;
  for (final key in ['records', 'weekly', 'achievements']) {
    json.remove(key);
  }
  final missions = json['missions'] as Map
    ..['seasonId'] = legacyInviteMissionSeason
    ..remove('waivedGoals');
  if (version == 6) json['events'] = <String, Object?>{};
  if (version <= 5) json.remove('wardrobe');
  if (version <= 4) json.remove('invites');
  if (version <= 3) json.remove('support');
  if (version <= 2) {
    json
      ..remove('missions')
      ..remove('levelRewards')
      ..['rewardedLevels'] = [for (var l = 2; l <= s.level; l++) l];
  }
  expect(missions, isNotEmpty);
  return json;
}

Future<void> useAnyItem(GameController c) async {
  for (final item in itemDefinitions) {
    final s = c.state.support;
    if (s.effects[item.id]?.activeAt(c.gameNow) == true) continue;
    if (s.inventory[item.id] == BigInt.zero) {
      if (s.coins < BigInt.parse(item.coinPrice)) continue;
      expect(await c.buyCoinItem(item.id, s.purchaseSequence), isTrue);
    }
    expect(await c.useItem(item.id), isTrue);
  }
}

/// Explicit player actions for the offline season, only for active goals.
Future<void> offlineActions(GameController c) async {
  for (final d in achievementDefinitions) {
    if (!c.state.achievements.claimed.contains(d.id) &&
        achievementMet(c.state, d)) {
      expect(await c.claimAchievement(d.id), isTrue);
    }
  }
  final target = activeLevelMission(c.state);
  if (target == null) return;
  for (final p in missionProgress(c.state, target)) {
    if (p.complete) continue;
    switch (p.definition.kind) {
      case MissionKind.goldenButterUses:
        await c.simulateButterUse(c.state.missions.token);
      case MissionKind.cosmeticsOwned:
        final options = cosmeticDefinitions
            .where((d) =>
                !c.state.ownsCosmetic(d) &&
                cosmeticUnlocked(c.state, d) &&
                d.cost <= c.state.support.coins)
            .toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
        if (options.isNotEmpty) {
          expect(await c.buyOrEquipCosmetic(options.first.id), isTrue);
        }
      case MissionKind.itemUses || MissionKind.achievements:
        await useAnyItem(c);
      default:
        break;
    }
  }
  if (canClaimLevel(c.state)) {
    expect(await c.claimLevelUp(target.level), isTrue);
  }
}

final offlineAutoTargets = {
  5: BigInt.from(5000),
  6: BigInt.from(60000000),
  7: BigInt.parse('16000000000'),
  8: BigInt.parse('500000000000'),
  9: BigInt.parse('4000000000000'),
  10: BigInt.parse('15000000000000'),
};

void main() {
  test('오프라인 시즌은 초대 조건 없이 Lv.5·7·9·10 대체 조건을 갖는다', () {
    expect(levels, same(offlineLevels));
    final legacy = levelsForSeason(legacyInviteMissionSeason);
    expect(
        levels
            .expand((l) => l.missions)
            .where((m) => m.kind == MissionKind.newPlayerInvites),
        isEmpty);
    final replaced = {
      5: (MissionKind.cosmeticsOwned, '1'),
      7: (MissionKind.itemUses, '5'),
      9: (MissionKind.skillLevel, '1'),
      10: (MissionKind.achievements, '12'),
    };
    for (var i = 0; i < levels.length; i++) {
      // Stage 11 raised the mid/late offline targets to pace Lv.10 at
      // weeks 3-4; the legacy (debug) season keeps its values.
      expect(levels[i].autoPerSecond,
          offlineAutoTargets[levels[i].level] ?? legacy[i].autoPerSecond);
      expect(levels[i].reward, legacy[i].reward);
      final extra = replaced[levels[i].level];
      final kinds = levels[i].missions.map((m) => m.kind).toList();
      if (extra == null) {
        expect(kinds, legacy[i].missions.map((m) => m.kind).toList());
      } else {
        final m = levels[i].missions.firstWhere((m) => m.kind == extra.$1);
        expect(m.targetValue, extra.$2);
      }
    }
    expect(levels[8].missions.last.skillId, 'auto_11');
    expect(upgrades.any((u) => u.id == 'auto_11'), isTrue);
  });

  group('v1~v6 저장은 v7로 진행도를 잃지 않고 이전된다', () {
    for (var version = 1; version <= 6; version++) {
      test('v$version', () async {
        final original = progressed();
        final GameState restored;
        if (version == 1) {
          final raw =
              jsonDecode(File('test/fixtures/v1_save.json').readAsStringSync())
                  as Map<String, dynamic>;
          restored = GameState.fromJson(raw);
          expect(restored.buns.toString(), raw['buns']);
          expect(restored.lifetime.toString(), raw['lifetime']);
          expect(restored.support.coins.toString(), raw['stars']);
          expect(restored.level, raw['level']);
          expect(restored.equippedSkin, raw['equippedSkin']);
          expect(restored.ownedSkins, (raw['ownedSkins'] as List).toSet());
        } else {
          restored = GameState.fromJson(asVersion(original, version));
          expect(restored.buns, original.buns);
          expect(restored.lifetime, original.lifetime);
          expect(restored.level, original.level);
          expect(restored.upgradeCounts, original.upgradeCounts);
          expect(restored.ownedSkins, original.ownedSkins);
          expect(restored.equippedSkin, original.equippedSkin);
          expect(restored.support.coins, BigInt.from(42));
          if (version >= 4) {
            expect(restored.support.inventory, original.support.inventory);
            expect(restored.support.ledger.keys,
                containsAll(original.support.ledger.keys));
          }
          if (version >= 6) {
            expect(restored.wardrobe.toJson(), original.wardrobe.toJson());
          }
        }
        expect(restored.missions.seasonId, currentMissionSeason);
        expect(restored.achievements.claimed, isEmpty);
        expect(restored.records.playDays, greaterThanOrEqualTo(1));
        // Migration runs once: the v7 result reloads unchanged.
        final again = GameState.fromJson(plainJson(restored));
        expect(plainJson(again), plainJson(restored));
        // And a controller can keep playing and saving it.
        final repo = MemoryGameRepository()..current = restored;
        final c = GameController(repo, FakeTime()..now = now);
        await c.initialize();
        expect(c.state.buns, greaterThanOrEqualTo(restored.buns));
        final before = c.state.buns;
        c.tap();
        await c.save();
        expect(c.state.buns, greaterThan(before));
        expect((await repo.load())!.buns, c.state.buns);
        c.dispose();
      });
    }
  });

  group('초대 조건 인정', () {
    GameState legacyAt(int level, int invites) {
      final s = GameState.initial(now)
        ..level = level
        ..tutorialDone = true;
      s.missions = MissionState.forLevel(level, now,
          seasonId: legacyInviteMissionSeason);
      for (var i = 0; i < invites; i++) {
        s.missions.seenInvitePlayers.add('p$i');
        s.missions.qualifiedInvitePlayers.add('p$i');
      }
      return s;
    }

    test('이미 채운 초대 조건은 대체 조건 완료로 인정', () {
      final restored = GameState.fromJson(asVersion(legacyAt(4, 1), 6));
      expect(restored.missions.waivedGoals, {'cosmetics'});
      expect(cosmeticsOwnedCount(restored), 0);
      setRate(restored, BigInt.from(5000));
      expect(canClaimLevel(restored), isTrue);
    });
    test('덜 채운 초대 조건은 새 조건으로 진행', () {
      final restored = GameState.fromJson(asVersion(legacyAt(9, 2), 6));
      expect(restored.missions.waivedGoals, isEmpty);
      setRate(restored, BigInt.parse('20000000000000'));
      expect(canClaimLevel(restored), isFalse);
    });
    test('레벨업하면 인정 기록은 다음 단계로 넘어가지 않는다', () async {
      final repo = MemoryGameRepository()
        ..current = GameState.fromJson(asVersion(legacyAt(4, 1), 6));
      final c = GameController(repo, FakeTime()..now = now);
      await c.initialize();
      setRate(c.state, BigInt.from(5000));
      expect(await c.claimLevelUp(5), isTrue);
      expect(c.state.missions.waivedGoals, isEmpty);
      c.dispose();
    });
    test('대체 조건 기록이 현재 단계에 없는 ID면 손상으로 거부', () {
      final json = plainJson(GameState.initial(now));
      (json['missions'] as Map)['waivedGoals'] = ['cosmetics'];
      expect(() => GameState.fromJson(json), throwsFormatException);
    });
  });

  test('기존 완주 기록은 Lv.10 업적·칭호로 이전되고 환불은 없다', () async {
    final s = GameState.initial(now)
      ..level = 10
      ..tutorialDone = true;
    s.missions = MissionState.forLevel(10, now);
    s.support
      ..transact('level:test', BigInt.from(15), 'fixture', now)
      ..transact(legacyFinalExchangeId, -BigInt.from(10), '완주', now);
    final restored = GameState.fromJson(asVersion(s, 6));
    expect(restored.achievements.claimed, {legacyFinisherAchievement});
    expect(restored.achievements.titles, {'골목 명장'});
    expect(restored.support.coins, BigInt.from(5));
    expect(restored.support.ledger['achievement:level-10']!.delta, BigInt.zero);
    final repo = MemoryGameRepository()..current = restored;
    final c = GameController(repo, FakeTime()..now = now);
    await c.initialize();
    expect(await c.claimAchievement('level-10'), isFalse);
    expect(await c.equipTitle('골목 명장'), isTrue);
    expect(c.state.support.coins, BigInt.from(5));
    c.dispose();
  });

  test('플레이 일수는 일일 보상 원장 날짜로 복원하고 값을 지어내지 않는다', () {
    final s = GameState.initial(now);
    for (final id in [
      'daily:2026-10-01:taps',
      'daily:2026-10-02:taps',
      'daily:2026-10-02:all'
    ]) {
      s.support.transact(id, BigInt.one, 'fixture', now);
    }
    final restored = GameState.fromJson(asVersion(s, 6));
    expect(restored.records.playDays, 3); // 10-01, 10-02, today (10-05).
    expect(restored.records.bestCombo, 0);
    expect(restored.records.pastBestDayProduction, BigInt.zero);
    expect(dailyAllClearCount(restored), 1);
  });

  group('콤보·내 기록', () {
    late FakeTime clock;
    late GameController c;
    setUp(() async {
      clock = FakeTime()..now = now;
      c = GameController(MemoryGameRepository(), clock);
      await c.initialize();
    });
    tearDown(() => c.dispose());

    test('1초 이내 직접 탭만 콤보, 길게 누르기는 제외', () {
      for (var i = 0; i < 5; i++) {
        c.tap();
        clock.advance(comboWindowMilliseconds);
      }
      expect(c.currentCombo, 5);
      clock.advance(1);
      expect(c.currentCombo, 0);
      c.tap();
      expect(c.currentCombo, 1);
      for (var i = 0; i < 10; i++) {
        clock.advance(250);
        c.tap(direct: false);
      }
      expect(c.currentCombo, 0);
      expect(c.state.records.todayBestCombo, 5);
      expect(c.state.records.lifetimeTaps, BigInt.from(16));
      expect(c.state.weekly.taps, BigInt.from(16));
    });

    test('자정에 오늘 기록을 지난 최고로 넘기고 신기록 일수를 센다', () {
      for (var i = 0; i < 3; i++) {
        c.tap();
      }
      expect(c.state.records.playDays, 1);
      clock.now = nextDailyReset(c.gameNow);
      c.tick();
      expect(c.state.records.pastBestDayProduction, BigInt.from(3));
      expect(c.state.records.pastBestCombo, 3);
      expect(c.state.records.todayBestCombo, 0);
      expect(c.state.records.newRecordDays, 0);
      expect(c.state.records.playDays, 2);
      for (var i = 0; i < 5; i++) {
        c.tap();
      }
      clock.now = nextDailyReset(c.gameNow);
      c.tick();
      expect(c.state.records.pastBestDayProduction, BigInt.from(5));
      expect(c.state.records.newRecordDays, 1);
      expect(
          achievementMet(c.state,
              achievementDefinitions.firstWhere((d) => d.id == 'record-1')),
          isTrue);
    });

    test('최고 초당 생산은 아이템 효과를 빼고 기록한다', () async {
      c.state.buns = BigInt.from(1000);
      expect(
          await c.buyUpgrade(upgrades.firstWhere((u) => u.id == 'auto_1'), 1),
          isTrue);
      expect(c.state.records.bestAutoRate, autoRate(c.state));
      expect(await c.useItem('fairy'), isTrue);
      clock.advance(1000);
      c.tick();
      expect(c.state.records.bestAutoRate, autoRate(c.state));
    });

    test('기록은 시계를 되돌려도 지난 날을 다시 세지 않는다', () {
      clock.now = nextDailyReset(c.gameNow);
      c.tick();
      expect(c.state.records.playDays, 2);
      clock.now = now;
      c.tick();
      expect(c.state.records.playDays, 2);
    });
  });

  group('주간 도전', () {
    late FakeTime clock;
    late MemoryGameRepository repo;
    late GameController c;
    setUp(() async {
      clock = FakeTime()..now = now;
      repo = MemoryGameRepository();
      c = GameController(repo, clock);
      await c.initialize();
    });
    tearDown(() => c.dispose());

    test('월요일 00:00 KST 경계와 자동 다음 주 시작', () async {
      final week = c.state.weekly.week;
      expect(week, '2026-10-05');
      c.state.weekly.taps = BigInt.from(1000);
      expect(await c.claimWeekly(week, 'taps'), isTrue);
      expect(await c.claimWeekly(week, 'taps'), isFalse);
      expect(c.state.support.coins, BigInt.from(3));
      expect(await c.claimWeekly(week, 'purchases'), isFalse);
      clock.now = weekEndUtc(week).subtract(const Duration(milliseconds: 1));
      c.tick();
      expect(c.state.weekly.week, week);
      clock.now = weekEndUtc(week);
      c.tick();
      expect(c.state.weekly.week, '2026-10-12');
      expect(c.state.weekly.taps, BigInt.zero);
      expect(c.state.weekly.claimed, isEmpty);
      expect(await c.claimWeekly(week, 'taps'), isFalse);
      clock.now = now;
      c.tick();
      expect(c.state.weekly.week, '2026-10-12');
    });

    test('접속일·구매·일일 전체 완료가 주간 진행에 반영되고 재시작 후 보존', () async {
      c.state.buns = BigInt.from(100000);
      expect(await c.buyUpgrade(upgrades.first, 2), isTrue);
      expect(c.state.weekly.purchases, BigInt.from(2));
      clock.now = nextDailyReset(c.gameNow);
      c.tick();
      expect(c.state.weekly.playDays, 2);
      c.state.support.daily
        ..taps = BigInt.from(50)
        ..production = BigInt.from(1000)
        ..purchases = BigInt.from(3);
      setRate(c.state, BigInt.from(10));
      expect(await c.claimDaily(c.state.support.daily.day, 'all'), isTrue);
      expect(c.state.weekly.dailyAllClears, BigInt.one);
      await c.save();
      final restarted = GameController(repo, clock);
      await restarted.initialize();
      expect(restarted.state.weekly.toJson(), c.state.weekly.toJson());
      restarted.dispose();
    });

    test('네 목표를 모두 받으면 주간 완주 업적이 열린다', () async {
      final w = c.state.weekly
        ..taps = BigInt.from(1000)
        ..playDays = 3
        ..purchases = BigInt.from(20)
        ..dailyAllClears = BigInt.from(3);
      for (final id in ['taps', 'days', 'purchases', 'dailyAll']) {
        expect(await c.claimWeekly(w.week, id), isTrue);
      }
      expect(weeklyCompletionCount(c.state), 1);
      expect(await c.claimAchievement('weekly-1'), isTrue);
    });

    test('원장 없는 주간 수령 기록은 거부', () {
      final json = plainJson(c.state);
      (json['weekly'] as Map)['claimed'] = ['taps'];
      expect(() => GameState.fromJson(json), throwsFormatException);
    });
  });

  group('업적·칭호', () {
    late FakeTime clock;
    late MemoryGameRepository repo;
    late GameController c;
    setUp(() async {
      clock = FakeTime()..now = now;
      repo = MemoryGameRepository();
      c = GameController(repo, clock);
      await c.initialize();
    });
    tearDown(() => c.dispose());

    test('업적은 20개 내외, ID 중복 없음, 보상은 코인 또는 칭호', () {
      // 20 in stage 8, two stage-11 prestige and two stage-12 wardrobe ones.
      expect(achievementDefinitions.length, 24);
      expect(achievementDefinitions.map((d) => d.id).toSet().length, 24);
      for (final d in achievementDefinitions) {
        expect(d.coins != '0' || d.titleReward != null, isTrue, reason: d.id);
      }
    });

    test('조건 달성 후 1회 수령, 저장 실패 롤백', () async {
      expect(await c.claimAchievement('bake-1'), isFalse);
      c.tap();
      repo.failNextSave = true;
      expect(await c.claimAchievement('bake-1'), isFalse);
      expect(c.state.support.coins, BigInt.zero);
      expect(c.state.achievements.claimed, isEmpty);
      expect(await c.claimAchievement('bake-1'), isTrue);
      expect(await c.claimAchievement('bake-1'), isFalse);
      expect(c.state.support.coins, BigInt.one);
      expect(await c.claimAchievement('unknown'), isFalse);
    });

    test('칭호는 얻은 것만 장착하고 재시작 후 유지', () async {
      expect(await c.equipTitle('번개손'), isFalse);
      c.state.records.todayBestCombo = 50;
      expect(await c.claimAchievement('combo-50'), isTrue);
      expect(await c.equipTitle('번개손'), isTrue);
      final restarted = GameController(repo, clock);
      await restarted.initialize();
      expect(restarted.state.achievements.equippedTitle, '번개손');
      expect(await restarted.equipTitle(null), isTrue);
      expect(restarted.state.achievements.equippedTitle, isNull);
      restarted.dispose();
    });

    test('원장 없는 업적·보유하지 않은 칭호는 손상으로 거부', () {
      final claimed = plainJson(c.state);
      (claimed['achievements'] as Map)['claimed'] = ['bake-1'];
      expect(() => GameState.fromJson(claimed), throwsFormatException);
      final title = plainJson(c.state);
      (title['achievements'] as Map)['equippedTitle'] = '골목 명장';
      expect(() => GameState.fromJson(title), throwsFormatException);
    });
  });

  test('탭은 DB에 저장하지 않는다(10초 주기 저장만)', () async {
    final repo = CountingRepository();
    final clock = FakeTime()..now = now;
    final c = GameController(repo, clock);
    await c.initialize();
    final saves = repo.saves;
    for (var i = 0; i < 200; i++) {
      c.tap();
    }
    expect(repo.saves, saves);
    expect(c.state.records.lifetimeTaps, BigInt.from(200));
    c.dispose();
  });

  test('배포 빌드 설정에서는 초대 시뮬레이터를 쓸 수 없다', () async {
    final c = GameController(MemoryGameRepository(), FakeTime()..now = now,
        developerTools: false);
    await c.initialize();
    expect(c.canSimulateInvites, isFalse);
    expect(
        await c.simulateInvitation(InviteEventKind.clicked, 'friend'), isFalse);
    expect(c.state.invites.profile, isNull);
    c.dispose();
  });

  test('오프라인 시즌 시뮬레이션: 2회/초 클릭과 효율 구매 4시간, 중반 도달·폭주 없음', () async {
    final clock = FakeTime()..now = now;
    final c = GameController(MemoryGameRepository(), clock)
      ..state = GameState.initial(clock.utcNow);
    c.state.tutorialDone = true;
    final reached = <int, int>{1: 0};
    for (var second = 1; second <= 14400 && c.state.level < 10; second++) {
      clock.advance(1000);
      c.tick();
      c.tap();
      c.tap();
      for (var batch = 0; batch < 128; batch++) {
        UpgradeDefinition? best;
        var bestGain = BigInt.zero, bestCost = BigInt.one;
        for (final u in upgrades) {
          final owned = c.state.upgradeCounts[u.id]!;
          if (owned == maxUpgradeCount || c.state.lifetime < u.unlockTotal) {
            continue;
          }
          final cost = priceAt(u, owned);
          if (cost > c.state.buns) continue;
          final gain =
              u.effect * BigInt.from(u.kind == UpgradeKind.tap ? 2 : 1);
          if (best == null || gain * bestCost > bestGain * cost) {
            best = u;
            bestGain = gain;
            bestCost = cost;
          }
        }
        if (best == null) break;
        expect(await c.buyUpgrade(best, 1), isTrue);
      }
      await offlineActions(c);
      reached.putIfAbsent(c.state.level, () => second);
    }
    // Stage 11: Lv.10 takes weeks now (casual simulation); four hours of
    // nonstop play reaches the mid levels without running away.
    expect(c.state.level, inInclusiveRange(6, 9));
    expect(c.state.missions.seenInvitePlayers, isEmpty);
    expect(c.state.levelRewards.length, c.state.level - 1);
    // Reports a test policy, not a promised human completion time.
    // ignore: avoid_print
    print('offline simulation: levels=$reached, '
        'achievements=${achievementsMetCount(c.state)}, '
        'coins=${c.state.support.coins}');
    c.dispose();
  });
}
