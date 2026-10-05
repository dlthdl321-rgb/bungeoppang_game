import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/missions.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'package:todays_bungeoppang/support_rules.dart';
import 'package:todays_bungeoppang/weekly_config.dart';
import 'package:todays_bungeoppang/progress_rules.dart';
import 'controller_test.dart' show FakeTime;
import 'stage8_progress_test.dart' show offlineActions;

class SlowRepository extends MemoryGameRepository {
  Completer<void>? pending;
  @override
  Future<void> save(GameState state) async {
    if (pending != null) await pending!.future;
    await super.save(state);
  }
}

// Explicit user actions replace the old automatic level awards. Mock social
// and item inputs only occur AFTER their own mission becomes active.
Future<void> claimReadyMissions(GameController c) async {
  while (activeLevelMission(c.state) != null) {
    final target = activeLevelMission(c.state)!;
    if (target.missions.any((m) => m.kind == MissionKind.goldenButterUses)) {
      await c.simulateButterUse(c.state.missions.token);
    }
    for (final p in missionProgress(c.state, target)) {
      if (p.definition.kind == MissionKind.newPlayerInvites) {
        while (BigInt.from(c.state.missions.qualifiedInvitePlayers.length) <
            p.definition.target) {
          expect(await c.createMockInvite(), isTrue);
        }
      }
    }
    if (!canClaimLevel(c.state)) break;
    expect(await c.claimLevelUp(target.level), isTrue);
  }
}

// Stage 8: these pacing tests target the invite-goal season (kept for the
// debug invite system); the offline season has its own simulation in
// stage8_progress_test.dart.
GameState legacySeasonState(DateTime now) => GameState.initial(now)
  ..missions =
      MissionState.forLevel(1, now, seasonId: legacyInviteMissionSeason);

void main() {
  // Stage 11 retuned the curve to weeks: four hours of nonstop play now stops
  // around Lv.6. Early pacing is unchanged; the upper bound guards against the
  // old runaway. Full Lv.10 timing is the casual-player simulation below.
  test('2회/초 클릭과 효율 구매 4시간: 초반 페이스 유지, 폭주 없음', () async {
    final clock = FakeTime();
    final c = GameController(MemoryGameRepository(), clock)
      ..state = legacySeasonState(clock.utcNow);
    c.state.tutorialDone = true;
    final reached = <int, int>{1: 0};
    int? firstPurchase, firstAutomatic;
    // Deterministic policy: two clicks/second; buy the best affordable marginal
    // effect/price using cross multiplication, never floating-point ratios.
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
        firstPurchase ??= second;
        if (best.kind == UpgradeKind.auto) firstAutomatic ??= second;
      }
      await claimReadyMissions(c);
      for (var level = 2; level <= c.state.level; level++) {
        reached.putIfAbsent(level, () => second);
      }
      expect(c.state.buns.isNegative, isFalse);
    }
    expect(firstPurchase, lessThanOrEqualTo(15));
    expect(firstAutomatic, lessThanOrEqualTo(120));
    expect(reached[4], isNotNull);
    expect(reached[4]!, lessThanOrEqualTo(300));
    expect(c.state.level, inInclusiveRange(6, 9));
    expect(c.state.levelRewards.length, c.state.level - 1);
    expect(autoRate(c.state), lessThan(BigInt.parse('20000000000000')));
    expect(
        reached.keys, containsAll(List.generate(c.state.level, (i) => i + 1)));
    // This reports a test policy, not a promised human completion time.
    // ignore: avoid_print
    print(
        'simulation: first=$firstPurchase s, auto=$firstAutomatic s, levels=$reached, autoRate=${autoRate(c.state)}');
    c.dispose();
  });

  test('억·조 단위 분할 정산도 잔여분을 보존하고 레벨10 보상은 한번만 지급', () async {
    final clock = FakeTime();
    GameController build() {
      final c = GameController(MemoryGameRepository(), clock)
        ..state = legacySeasonState(clock.utcNow);
      // Enough top-tier ovens for the Lv.10 rate (20조/s) under balance v3.
      c.state.upgradeCounts['auto_16'] = 19;
      c.state.upgradeCounts['auto_1'] = 1;
      return c;
    }

    final a = build(), b = build();
    for (var i = 0; i < 1001; i++) {
      a.settleActive(1);
    }
    b.settleActive(1001);
    final top = upgrades.firstWhere((u) => u.id == 'auto_16');
    expect(autoRate(a.state), top.effect * BigInt.from(19) + BigInt.one);
    expect(autoRate(a.state), greaterThan(BigInt.parse('20000000000000')));
    expect(a.state.buns, b.state.buns);
    expect(a.state.activeRemainder, b.state.activeRemainder);
    a.settleActive(10000);
    expect(a.state.level, 1); // Production alone no longer claims levels.
    expect(a.state.support.coins, BigInt.zero);
    a.state.tutorialDone = true;
    await claimReadyMissions(a);
    expect(a.state.level, 10);
    final reward = a.state.support.coins;
    expect(
        reward, levels.skip(1).fold(BigInt.zero, (sum, l) => sum + l.reward));
    a.settleActive(1000000);
    a.tap();
    expect(a.state.level, 10);
    expect(a.state.support.coins, reward);
    expect(await a.claimLevelUp(10), isFalse);
    expect(a.state.levelRewards.length, 9);
    a.dispose();
    b.dispose();
  });

  test('최대 구매는 계산된 수량·차액을 정확히 반영한다', () async {
    final clock = FakeTime(), repo = MemoryGameRepository();
    final c = GameController(repo, clock);
    await c.initialize();
    final u = upgrades.first;
    c.state.buns = bundlePrice(u, 0, 25) + BigInt.from(7);
    final before = c.state.buns;
    expect(await c.buyMaximum(u), isTrue);
    expect(c.state.upgradeCounts[u.id], 25);
    expect(c.state.buns, BigInt.from(7));
    expect(before - c.state.buns, bundlePrice(u, 0, 25));
    expect(tapRate(c.state), BigInt.from(26));
    expect(await c.buyMaximum(u), isFalse);
    c.dispose();
  });

  test('같은 ID로 싼 가격을 주입하거나 잠긴 스킬을 구매할 수 없다', () async {
    final clock = FakeTime();
    final c = GameController(MemoryGameRepository(), clock);
    await c.initialize();
    c.state.buns = BigInt.from(10).pow(100);
    final fake = UpgradeDefinition(
        'tap_1', 'fake', UpgradeKind.tap, 1, 1000, 115, 100, 0);
    expect(await c.buyUpgrade(fake, 1), isFalse);
    expect(await c.buyUpgrade(upgrades.last, 1), isFalse);
    expect(await c.buyUpgrade(upgrades.first, -1), isFalse);
    expect(c.state.upgradeCounts.values.every((n) => n == 0), isTrue);
    c.dispose();
  });

  test('최대 구매 저장 실패 시 비용·생산·보상 모두 복구하고 경과시간은 옛 비율로 정산', () async {
    final clock = FakeTime(), repo = SlowRepository();
    final c = GameController(repo, clock);
    await c.initialize();
    c.state.upgradeCounts['auto_1'] = 1;
    c.state.buns = BigInt.from(10000);
    c.tick();
    final before = c.state.toJson();
    repo.pending = Completer<void>();
    repo.failNextSave = true;
    final buying = c.buyMaximum(upgrades.first);
    expect(c.busy, isTrue);
    clock.advance(1500);
    c.tick();
    expect(await c.buyMaximum(upgrades.first), isFalse);
    repo.pending!.complete();
    expect(await buying, isFalse);
    expect(c.state.toJson(), before);
    c.tick();
    expect(c.state.buns, BigInt.from(10001));
    expect(c.state.activeRemainder, BigInt.from(500));
    expect(tapRate(c.state), BigInt.one);
    c.dispose();
  });
  // Approved stage-11 target curve (Lv.10 in weeks 3-4). Days are counted
  // from install: day 1 is [0, 1).
  const targetDays = <int, (double, double)>{
    5: (0, 1),
    6: (1, 3),
    7: (3, 7),
    8: (7, 12),
    9: (12, 19),
    10: (20, 28),
  };
  for (final seed in [20261005, 1, 42]) {
    test('일반 사용자 시뮬레이션 seed $seed: 하루 2~3회 접속, 초당 2~4회 탭, 오프라인 보상 포함',
        () async {
      final report = await simulateCasualPlayer(seed: seed);
      // ignore: avoid_print
      print(report.table());
      expect(report.firstPurchaseSeconds, lessThanOrEqualTo(30));
      // Lv.2-4 inside the first session (sessions last at most 12 minutes).
      expect(report.reached[4]!.activeSeconds,
          lessThanOrEqualTo(simMaxSessionMinutes * 60));
      for (final e in targetDays.entries) {
        final days = report.reached[e.key]!.calendar.inMinutes / 1440;
        expect(days, inInclusiveRange(e.value.$1, e.value.$2),
            reason: 'Lv.${e.key}');
      }
      final reached = report.reached.values.toList();
      for (var i = 1; i < reached.length; i++) {
        expect(reached[i].calendar - reached[i - 1].calendar,
            lessThanOrEqualTo(stallCalendar));
        expect(
            reached[i].longestNoPurchase, lessThanOrEqualTo(stallNoPurchase));
      }
      expect(report.negativeBuns, isFalse);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

// ---- Casual player model: explicit, deterministic assumptions ----

const simDays = 35;
const simSessionHoursKst = [8, 13, 21];
const simMinSessionMinutes = 6, simMaxSessionMinutes = 12;
const simMinTapsPerSecond = 2, simMaxTapsPerSecond = 4;
const simDecisionEverySeconds = 5;
// A stall: one level taking over a week, or two minutes of play with nothing
// affordable to buy.
const stallCalendar = Duration(days: 7);
const stallNoPurchase = 120;

class LevelReach {
  final Duration calendar; // Since install.
  final int activeSeconds; // Played seconds since install.
  final int longestNoPurchase; // Longest active stretch without a purchase.
  const LevelReach(this.calendar, this.activeSeconds, this.longestNoPurchase);
}

class CasualReport {
  int? firstPurchaseSeconds;
  bool negativeBuns = false;
  final reached = <int, LevelReach>{};
  int sessions = 0, activeSeconds = 0;
  BigInt offlineTotal = BigInt.zero;
  BigInt? lifetimeAtTen; // Total production when Lv.10 was reached.

  static String when(Duration d) {
    final kst = d + const Duration(hours: 8); // Install at 08:00 KST.
    return '${kst.inDays + 1}일차 ${(kst.inHours % 24).toString().padLeft(2, '0')}'
        ':${(kst.inMinutes % 60).toString().padLeft(2, '0')}';
  }

  String table() {
    final b = StringBuffer()
      ..writeln('일반 사용자 시뮬레이션 ($simDays일 상한, 접속 $sessions회, '
          '총 플레이 ${activeSeconds ~/ 60}분, 첫 구매 $firstPurchaseSeconds초, '
          'Lv.10 누적 생산 $lifetimeAtTen)')
      ..writeln(
          '| 레벨 | 도달 시점(KST) | 누적 플레이 | 직전 이후 플레이 | 직전 이후 경과 | 최장 무구매 | 정체 |')
      ..writeln('|---|---|---|---|---|---|---|');
    LevelReach? prev;
    for (final e in reached.entries) {
      final r = e.value;
      final gapActive = prev == null ? 0 : r.activeSeconds - prev.activeSeconds;
      final gapCalendar =
          prev == null ? Duration.zero : r.calendar - prev.calendar;
      final stall =
          gapCalendar > stallCalendar || r.longestNoPurchase > stallNoPurchase;
      b.writeln(
          '| ${e.key} | ${when(r.calendar)} | ${r.activeSeconds ~/ 60}분 | '
          '${gapActive ~/ 60}분 | ${gapCalendar.inHours}시간 | '
          '${r.longestNoPurchase}초 | ${stall ? '정체' : ''} |');
      prev = r;
    }
    if (!reached.containsKey(10)) b.writeln('($simDays일 안에 Lv.10 미도달)');
    return b.toString();
  }
}

Future<void> claimDailyAndWeekly(GameController c) async {
  final daily = c.state.support.daily;
  for (final d in dailyDefinitions) {
    if (!daily.claimed.contains(d.id) && dailyComplete(c.state, d)) {
      await c.claimDaily(daily.day, d.id);
    }
  }
  if (!daily.allClaimed && dailyAllComplete(c.state)) {
    await c.claimDaily(daily.day, 'all');
  }
  for (final g in weeklyGoals) {
    if (!c.state.weekly.claimed.contains(g.id) &&
        weeklyGoalComplete(c.state, g)) {
      await c.claimWeekly(c.state.weekly.week, g.id);
    }
  }
}

/// Greedy: best affordable production per bun; tap skills are valued by the
/// session's tap rate. Returns how many units were bought.
Future<int> buyBest(GameController c, int tapsPerSecond) async {
  var bought = 0;
  for (var batch = 0; batch < 64; batch++) {
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
          u.effect * BigInt.from(u.kind == UpgradeKind.tap ? tapsPerSecond : 1);
      if (best == null || gain * bestCost > bestGain * cost) {
        best = u;
        bestGain = gain;
        bestCost = cost;
      }
    }
    if (best == null || !await c.buyUpgrade(best, 1)) break;
    bought++;
  }
  return bought;
}

Future<CasualReport> simulateCasualPlayer(
    {int days = simDays, int seed = 20261005}) async {
  final rng = math.Random(seed);
  final installed = DateTime.utc(2026, 10, 4, 23); // Monday 08:00 KST.
  final clock = FakeTime()..now = installed;
  final c = GameController(MemoryGameRepository(), clock);
  await c.initialize();
  c.state.tutorialDone = true; // The first-launch guide is read.
  final report = CasualReport();
  report.reached[1] = const LevelReach(Duration.zero, 0, 0);
  var noPurchase = 0, longestNoPurchase = 0;
  for (var day = 0; day < days && c.state.level < 10; day++) {
    final count = 2 + rng.nextInt(2);
    final hours = [...simSessionHoursKst]..shuffle(rng);
    final chosen = hours.take(count).toList()..sort();
    for (final hour in chosen) {
      if (c.state.level >= 10) break;
      final start = installed.add(Duration(days: day, hours: hour - 8));
      if (start.isAfter(clock.now)) {
        clock.now = start;
        report.offlineTotal += await c.resume();
      }
      report.sessions++;
      final minutes = simMinSessionMinutes +
          rng.nextInt(simMaxSessionMinutes - simMinSessionMinutes + 1);
      final taps = simMinTapsPerSecond +
          rng.nextInt(simMaxTapsPerSecond - simMinTapsPerSecond + 1);
      for (var second = 0; second < minutes * 60; second++) {
        clock.advance(1000);
        c.tick();
        for (var k = 0; k < taps; k++) {
          c.tap();
        }
        report.activeSeconds++;
        noPurchase++;
        if (second % simDecisionEverySeconds == 0) {
          if (await buyBest(c, taps) > 0) {
            report.firstPurchaseSeconds ??= report.activeSeconds;
            noPurchase = 0;
          }
          await claimDailyAndWeekly(c);
          final level = c.state.level;
          await offlineActions(c);
          if (noPurchase > longestNoPurchase) longestNoPurchase = noPurchase;
          for (var l = level + 1; l <= c.state.level; l++) {
            report.reached[l] = LevelReach(clock.now.difference(installed),
                report.activeSeconds, longestNoPurchase);
            if (l == 10) report.lifetimeAtTen = c.state.lifetime;
            longestNoPurchase = 0;
          }
        }
        if (c.state.buns.isNegative) report.negativeBuns = true;
      }
      await c.leaveActive();
    }
  }
  c.dispose();
  return report;
}
