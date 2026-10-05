import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/missions.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'controller_test.dart' show FakeTime;

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

void main() {
  test('2회/초 클릭과 효율 구매 시뮬레이션: 초반 성장부터 초당 20조·레벨10까지', () async {
    final clock = FakeTime();
    final c = GameController(MemoryGameRepository(), clock)
      ..state = GameState.initial(clock.utcNow);
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
    expect(c.state.level, 10);
    expect(c.state.missions.seenInvitePlayers.length, 6);
    expect(c.state.levelRewards.length, 9);
    expect(autoRate(c.state),
        greaterThanOrEqualTo(BigInt.parse('20000000000000')));
    expect(reached.keys, containsAll(List.generate(10, (i) => i + 1)));
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
        ..state = GameState.initial(clock.utcNow);
      c.state.upgradeCounts['auto_14'] = 3;
      c.state.upgradeCounts['auto_1'] = 1;
      return c;
    }

    final a = build(), b = build();
    for (var i = 0; i < 1001; i++) {
      a.settleActive(1);
    }
    b.settleActive(1001);
    expect(autoRate(a.state), BigInt.parse('30000000000001'));
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
}
