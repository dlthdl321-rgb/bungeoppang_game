import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart' hide levels;
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/missions.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;
import 'economy_persistence_test.dart' show JsonRepository;
import 'economy_simulation_test.dart' show SlowRepository;

void setRate(GameState state, BigInt rate) {
  var remaining = rate;
  for (final u
      in upgrades.where((u) => u.kind == UpgradeKind.auto).toList().reversed) {
    final amount = remaining ~/ u.effect;
    state.upgradeCounts[u.id] = amount.toInt();
    remaining -= u.effect * amount;
  }
  expect(remaining, BigInt.zero);
  expect(autoRate(state), rate);
  // Match a real skill purchase: both derived and persisted offline rates change.
  state.savedAutoRate = rate;
  if (rate > state.support.daily.peakAuto) state.support.daily.peakAuto = rate;
}

// Stage 8: the release season has no invite goals. These tests exercise the
// invite-goal season kept for the debug invite system, with the same
// expectations as before; the offline season is covered in
// stage8_progress_test.dart.
final levels = levelsForSeason(legacyInviteMissionSeason);

GameController atLevel(int level, FakeTime clock,
        [GameRepository? repository]) =>
    GameController(repository ?? MemoryGameRepository(), clock)
      ..state = (GameState.initial(clock.utcNow)
        ..level = level
        ..missions = MissionState.forLevel(level, clock.utcNow,
            seasonId: legacyInviteMissionSeason)
        ..tutorialDone = true);

MockInviteSuccess receipt(GameController c, String id,
        {DateTime? invitedAt,
        String? token,
        bool fresh = true,
        bool reached = true,
        DateTime? completedAt}) =>
    MockInviteSuccess(
        playerId: id,
        activationToken: token ?? c.state.missions.token,
        invitedAtUtc: invitedAt ?? c.clock.utcNow,
        completedAtUtc: completedAt ?? c.clock.utcNow,
        isNewPlayer: fresh,
        reachedLevelOne: reached);

void main() {
  test('레벨 1~10 정의는 시즌·근거·추정 보상과 공개 후반 조건을 갖는다', () {
    expect(levels.map((l) => l.level), List.generate(10, (i) => i + 1));
    expect(levels.first.reward, BigInt.zero);
    final autoGoals = {
      5: '5000',
      6: '15000000',
      7: '500000000',
      8: '20000000000',
      9: '500000000000',
      10: '20000000000000'
    };
    for (final entry in autoGoals.entries) {
      expect(levels[entry.key - 1].autoPerSecond, BigInt.parse(entry.value));
    }
    for (final level in levels.skip(1)) {
      expect(level.rewardEvidence, 'estimated');
      expect(level.missions, isNotEmpty);
      expect(level.missions.map((m) => m.id).toSet().length,
          level.missions.length);
      for (final m in level.missions) {
        expect(m.target, greaterThan(BigInt.zero));
        expect(m.evidence, anyOf('estimated', 'public-review'));
        if (m.evidence == 'public-review') expect(m.source, isNotNull);
      }
      final invites =
          level.missions.where((m) => m.kind == MissionKind.newPlayerInvites);
      final expected = {5: 1, 7: 1, 9: 1, 10: 3}[level.level];
      expect(invites.length, expected == null ? 0 : 1);
      if (expected != null) {
        expect(invites.single.target, BigInt.from(expected));
      }
    }
    expect(levels[1].missions.first.evidence, 'estimated');
    expect(() => levelsForSeason('unknown-season'), throwsFormatException);
  });

  for (final target in [5, 6, 7, 8, 9, 10]) {
    test('Lv.$target 모든 조건 AND, 초당 생산 임계값 직전/정확 일치와 명시적 수령', () async {
      final clock = FakeTime(), c = atLevel(target - 1, FakeTime());
      final definition = activeLevelMission(c.state)!;
      final invite = definition.missions
          .where((m) => m.kind == MissionKind.newPlayerInvites);
      setRate(c.state, definition.autoPerSecond - BigInt.one);
      if (invite.isNotEmpty) {
        for (var i = 0; i < invite.single.target.toInt(); i++) {
          expect(await c.recordMockInvite(receipt(c, 'person-$i')), isTrue);
        }
      }
      expect(canClaimLevel(c.state), isFalse);
      expect(await c.claimLevelUp(target), isFalse);
      setRate(c.state, definition.autoPerSecond);
      c.tap();
      c.settleActive(1000);
      expect(c.state.level, target - 1);
      expect(c.state.support.coins, BigInt.zero);
      expect(canClaimLevel(c.state), isTrue);
      final before = c.state.buns;
      expect(await c.claimLevelUp(target), isTrue);
      expect(c.state.level, target);
      expect(c.state.buns, before);
      expect(c.state.support.coins, definition.reward);
      expect(c.state.levelRewards[target]!.amount, definition.reward);
      expect(c.state.levelRewards[target]!.claimedAtUtc, clock.utcNow);
      expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
      expect(await c.claimLevelUp(target), isFalse);
      expect(c.state.support.coins, definition.reward);
      c.dispose();
    });
  }

  test('초반 튜토리얼/누적 미션과 황금버터 모의 입력은 현재 단계에서만 인정', () async {
    final c = atLevel(1, FakeTime());
    c.state.tutorialDone = false;
    c.state.lifetime = BigInt.from(9);
    expect(canClaimLevel(c.state), isFalse);
    await c.finishTutorial();
    expect(canClaimLevel(c.state), isFalse);
    c.tap();
    expect(await c.claimLevelUp(2), isTrue);
    expect(await c.simulateButterUse(c.state.missions.token), isFalse);
    setRate(c.state, BigInt.one);
    final stale = c.state.missions.token;
    expect(await c.claimLevelUp(3), isTrue);
    expect(await c.simulateButterUse(stale), isFalse);
    expect(await c.simulateButterUse(c.state.missions.token), isTrue);
    expect(await c.simulateButterUse(c.state.missions.token), isFalse);
    expect(await c.claimLevelUp(4), isTrue);
    expect(c.state.missions.butterUses, BigInt.zero);
    expect(c.state.levelRewards.length, 3);
    c.dispose();
  });

  test('미리보기는 이미 높은 생산량/초대가 있어도 진행으로 계산하지 않는다', () async {
    final c = atLevel(4, FakeTime());
    setRate(c.state, BigInt.parse('20000000000000'));
    expect(canClaimLevel(c.state), isFalse);
    expect(await c.recordMockInvite(receipt(c, 'a')), isTrue);
    expect(canClaimLevel(c.state), isTrue);
    for (final future in levels.skip(5)) {
      expect(
          missionProgress(c.state, future).every((p) =>
              !p.active &&
              !p.complete &&
              p.current == BigInt.zero &&
              p.permille == 0),
          isTrue);
    }
    expect(await c.claimLevelUp(7), isFalse);
    expect(await c.claimLevelUp(5), isTrue);
    expect(await c.claimLevelUp(6), isTrue);
    expect(canClaimLevel(c.state), isFalse); // Another NEW invitation needed.
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(await c.recordMockInvite(receipt(c, 'a')), isFalse);
    expect(await c.recordMockInvite(receipt(c, 'b')), isTrue);
    expect(canClaimLevel(c.state), isTrue);
    c.dispose();
  });

  test('초대 이전 시각·다른 활성 토큰·기존 플레이어·중복·미완료·미래 결과 제외', () async {
    final clock = FakeTime(), c = atLevel(9, FakeTime());
    setRate(c.state, BigInt.parse('20000000000000'));
    expect(
        await c.recordMockInvite(receipt(c, 'early',
            invitedAt: clock.utcNow.subtract(const Duration(milliseconds: 1)))),
        isTrue);
    expect(await c.recordMockInvite(receipt(c, 'stale', token: 'old-token')),
        isTrue);
    expect(
        await c.recordMockInvite(receipt(c, 'existing', fresh: false)), isTrue);
    expect(await c.recordMockInvite(receipt(c, 'unfinished', reached: false)),
        isFalse);
    expect(
        await c.recordMockInvite(receipt(c, 'future',
            completedAt: clock.utcNow.add(const Duration(seconds: 1)))),
        isFalse);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    for (final id in ['early', 'stale', 'existing']) {
      expect(await c.recordMockInvite(receipt(c, id)), isFalse);
    }
    for (var i = 1; i <= 3; i++) {
      expect(await c.recordMockInvite(receipt(c, 'new-$i')), isTrue);
      expect(await c.recordMockInvite(receipt(c, 'new-$i')), isFalse);
      final invite = missionProgress(c.state, levels.last).last;
      expect(invite.permille, i * 1000 ~/ 3);
      expect(canClaimLevel(c.state), i == 3);
    }
    expect(await c.claimLevelUp(10), isTrue);
    expect(activeLevelMission(c.state), isNull);
    expect(canClaimLevel(c.state), isFalse);
    c.dispose();
  });

  test('초대 미션이 없을 때의 초대는 다음 단계에서 재사용 불가', () async {
    final c = atLevel(5, FakeTime());
    setRate(c.state, BigInt.parse('500000000'));
    expect(await c.recordMockInvite(receipt(c, 'before-activation')), isTrue);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(await c.claimLevelUp(6), isTrue);
    expect(await c.recordMockInvite(receipt(c, 'before-activation')), isFalse);
    expect(canClaimLevel(c.state), isFalse);
    c.dispose();
  });

  test('레벨업 중 중복 호출 차단, 저장 실패는 미션·초대·보상까지 원복', () async {
    final repo = SlowRepository(), c = atLevel(9, FakeTime());
    final controller = GameController(repo, c.clock)..state = c.state;
    setRate(controller.state, BigInt.parse('20000000000000'));
    for (var i = 0; i < 3; i++) {
      await controller.recordMockInvite(receipt(controller, '$i'));
    }
    final before = controller.state.toJson();
    repo.pending = Completer<void>();
    repo.failNextSave = true;
    final claim = controller.claimLevelUp(10);
    expect(controller.busy, isTrue);
    expect(await controller.claimLevelUp(10), isFalse);
    repo.pending!.complete();
    expect(await claim, isFalse);
    expect(controller.state.toJson(), before);
    expect(await controller.claimLevelUp(10), isTrue);
    expect(await controller.claimLevelUp(10), isFalse);
    expect(controller.state.support.coins, levels.last.reward);
    c.dispose();
    controller.dispose();
  });

  test('초대 저장 실패 후 같은 성공 재시도는 한 번만 집계한다', () async {
    final repo = MemoryGameRepository(), c = atLevel(4, FakeTime());
    final controller = GameController(repo, c.clock)..state = c.state;
    final event = receipt(controller, 'retry');
    final before = controller.state.toJson();
    repo.failNextSave = true;
    expect(await controller.recordMockInvite(event), isFalse);
    expect(controller.state.toJson(), before);
    expect(await controller.recordMockInvite(event), isTrue);
    expect(await controller.recordMockInvite(event), isFalse);
    expect(controller.state.missions.qualifiedInvitePlayers, {'retry'});
    c.dispose();
    controller.dispose();
  });

  test('부분 초대 진행/활성 시각/토큰/중복 기록과 수령 후 큰 재화를 재실행 복원', () async {
    final clock = FakeTime(), disk = <String, String>{};
    final c = atLevel(9, clock, JsonRepository(disk));
    c.state.support.transact(
        'test:fund', BigInt.from(10).pow(100), 'fixture', clock.utcNow);
    setRate(c.state, BigInt.parse('20000000000000'));
    await c.recordMockInvite(receipt(c, 'first'));
    final partial = c.state.toJson();
    c.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.state.toJson(), partial);
    expect(await restart.recordMockInvite(receipt(restart, 'first')), isFalse);
    expect(canClaimLevel(restart.state), isFalse);
    await restart.recordMockInvite(receipt(restart, 'second'));
    await restart.recordMockInvite(receipt(restart, 'third'));
    expect(await restart.claimLevelUp(10), isTrue);
    final claimed = restart.state.toJson();
    restart.dispose();
    final again = GameController(JsonRepository(disk), clock);
    await again.initialize();
    expect(again.state.toJson(), claimed);
    expect(await again.claimLevelUp(10), isFalse);
    expect(again.state.support.coins,
        BigInt.from(10).pow(100) + levels.last.reward);
    again.dispose();
  });

  test('v2 rewardedLevels는 추가 지급 없이 이전하며 활성 시각은 TimeService로 생성', () async {
    final clock = FakeTime()..advance(123456);
    final old = GameState.initial(DateTime.utc(2026))..level = 6;
    old.stars = BigInt.parse('12345678901234567890');
    final json = old.toJson()
      ..['formatVersion'] = 2
      ..['rewardedLevels'] = [2, 3, 4, 5, 6];
    json.remove('missions');
    json.remove('levelRewards');
    final disk = {'current': jsonEncode(json)};
    final c = GameController(JsonRepository(disk), clock);
    await c.initialize();
    expect(c.state.support.coins, old.stars);
    expect(c.state.level, 6);
    expect(c.state.levelRewards.keys.toSet(), {2, 3, 4, 5, 6});
    expect(
        c.state.levelRewards.values.every((r) =>
            r.source == 'legacy' && r.amount == null && r.claimedAtUtc == null),
        isTrue);
    expect(c.state.missions.activatedAtUtc, clock.utcNow);
    expect(c.state.missions.targetLevel, 7);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(
        jsonDecode(disk['current']!)['formatVersion'], GameState.formatVersion);
    expect(await c.claimLevelUp(6), isFalse);
    await c.recordMockInvite(
        receipt(c, 'old-invite', invitedAt: DateTime.utc(2026)));
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    c.dispose();
  });

  test('이미 지급된 구버전 보상 기록이 앞 단계에 있어도 재지급하지 않는다', () async {
    final c = atLevel(1, FakeTime());
    c.state.lifetime = BigInt.from(10);
    c.state.levelRewards[2] = const LevelRewardRecord(
        level: 2, seasonId: 'legacy-v2', source: 'legacy');
    expect(await c.claimLevelUp(2), isTrue);
    expect(c.state.level, 2);
    expect(c.state.support.coins, BigInt.zero);
    expect(c.state.levelRewards[2]!.source, 'legacy');
    c.dispose();
  });

  test('v3 필수 기록 누락·활성 단계 불일치·시즌 불명·보상 위조 구조 거부', () {
    final initial = GameState.initial(DateTime.utc(2026));
    expect(() => GameState.fromJson(initial.toJson()..remove('missions')),
        throwsFormatException);
    final wrongTarget = initial.toJson();
    (wrongTarget['missions'] as Map)['targetLevel'] = 10;
    expect(() => GameState.fromJson(wrongTarget), throwsFormatException);
    final wrongSeason = initial.toJson();
    (wrongSeason['missions'] as Map)['seasonId'] = 'unknown';
    expect(() => GameState.fromJson(wrongSeason), throwsFormatException);
    final wrongReward = initial.toJson();
    (wrongReward['levelRewards'] as Map)['2'] = {
      'level': 2,
      'seasonId': currentMissionSeason,
      'source': 'claim',
      'amount': '-1',
      'claimedAtUtc': DateTime.utc(2026).toIso8601String()
    };
    expect(() => GameState.fromJson(wrongReward), throwsFormatException);
  });
}
