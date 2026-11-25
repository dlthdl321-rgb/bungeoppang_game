import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/local_test_purchases.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_local_rewards.dart';
import 'package:todays_bungeoppang/workshop_missions.dart';
import 'step02_controller_test.dart' show MemoryRepository;

/// 5차 피드백 12·13 (2026-11-25): gold is rarer — each daily mission pays
/// 붕어빵력, all four together gold 2, each weekly one gold 1 — and a test
/// build without a server shows the gold it was given.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  group('보상표 (13)', () {
    test('일일 미션 하나하나는 황금 0(붕어빵력), 모두 끝내기 2, 주간은 모두 1', () {
      for (final goal in ['taps', 'production', 'purchases', 'auto']) {
        expect(missionGold(config, 'daily', goal), 0, reason: goal);
      }
      expect(missionGold(config, 'daily', 'all'), 2);
      for (final goal in ['taps', 'days', 'purchases', 'dailyAll']) {
        expect(missionGold(config, 'weekly', goal), 1, reason: goal);
      }
    });

    test('붕어빵력 보상은 초당 수입 R의 300초분, 최소 100', () {
      expect(missionBuns(config, tapRate: BigInt.one, autoRate: BigInt.zero), BigInt.from(600),
          reason: 'R = 탭 1 × 초당 2 = 2, 300초분');
      expect(missionBuns(config, tapRate: BigInt.zero, autoRate: BigInt.zero), BigInt.from(100));
    });
  });

  group('컨트롤러', () {
    late WorkshopController c;
    var gold = 0;
    LocalTestPurchaseGateway? gateway;
    Future<void> start({bool testBuild = false}) async {
      gold = 0;
      gateway = testBuild ? LocalTestPurchaseGateway(gold: () => gold, setGold: (g) async { gold = g; return true; }) : null;
      c = WorkshopController(config, MemoryRepository(), purchaseGateway: gateway,
          now: () => DateTime.utc(2026, 11, 25, 3), monotonicMs: () => 0);
      await c.initialize();
      await c.command(() => c.state.tutorial = 'done');
    }
    Future<void> finishDaily() => c.command(() {
      c.state.missions = c.state.missions.observe(c.now(), taps: 50, production: BigInt.from(1000), purchases: 3,
          autoPeak: BigInt.from(10));
    });
    tearDown(() => c.dispose());

    test('일일 미션은 붕어빵력을 바로 주고 황금 심사로 가지 않는다. 모두 끝내기는 황금 신청', () async {
      await start();
      await finishDaily();
      final before = c.state.buns, reward = c.missionReward('daily', 'taps');
      expect(reward.gold, 0);
      expect(await c.claimMission('daily', 'taps'), isTrue, reason: c.notice);
      expect(c.state.buns, before + reward.buns);
      expect(c.state.pendingGold.keys.where((k) => k.startsWith('mission:')), isEmpty);
      for (final goal in ['production', 'purchases', 'auto']) { expect(await c.claimMission('daily', goal), isTrue); }
      expect(await c.claimMission('daily', 'all'), isTrue, reason: c.notice);
      final pending = c.state.pendingGold.keys.where((k) => k.startsWith('mission:')).toList();
      expect(pending, hasLength(1));
      expect(claimGold(c.state.pendingGold[pending.single]!), 2);
      // The save keeps the 붕어빵력 claims without gold and reloads.
      final back = WorkshopState.fromJson(jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>, config);
      expect(back.missions.claims, hasLength(5));
    });

    test('붕어빵력 미션에 황금 신청이 붙은 저장은 거부', () async {
      await start();
      await finishDaily();
      expect(await c.claimMission('daily', 'taps'), isTrue);
      final key = c.state.missions.claimKey('daily', 'taps');
      final json = jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>;
      (json['pendingGold'] as Map<String, dynamic>)['mission:$key'] = c.state.missions.claims[key];
      expect(() => WorkshopState.fromJson(json, config), throwsFormatException);
    });

    test('(12) 시험용 빌드: 받은 황금이 시험용 황금에 바로 더해지고 심사 대기가 남지 않는다, 한 번만', () async {
      await start(testBuild: true);
      await finishDaily();
      for (final goal in ['taps', 'production', 'purchases', 'auto', 'all']) {
        expect(await c.claimMission('daily', goal), isTrue, reason: c.notice);
      }
      await pumpEventQueue();
      expect(gold, 2, reason: '모두 끝내기 황금 2');
      expect(c.pendingRewardCount, 0);
      expect(c.state.rewardAccount, localTestAccount);
      await c.command(() {});
      await pumpEventQueue();
      expect(gold, 2, reason: '두 번 주지 않음');
      final back = WorkshopState.fromJson(jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>, config);
      expect(back.rewardReceipts, isNotEmpty);
    });

    test('(12) 시험용 빌드의 출석 7일째는 붕어빵력 대신 황금', () async {
      await start(testBuild: true);
      expect(c.stampGivesGold(c.attendanceCycle), isTrue);
      c.dispose();
      await start();
      expect(c.stampGivesGold(c.attendanceCycle), isFalse, reason: '서버도 시험용 지갑도 없으면 붕어빵력');
    });
  });

  test('(12) 정산 규칙: 황금 신청은 eligible, 판매는 noWin, 이미 받은 것은 건너뜀', () {
    final pending = {
      'mission:daily:2026-11-25:all': jsonEncode({'scope': 'daily', 'goal': 'all', 'gold': 2}),
      'level:3': jsonEncode({'level': 3, 'gold': 5, 'revision': 'r'}),
      'sale:s1': jsonEncode({'fingerprint': 'f', 'evidence': {}}),
    };
    final first = settleLocalTestRewards(pendingGold: pending, rewardReceipts: const {}, account: localTestAccount, progress: 'run');
    expect(first.gold, 7);
    expect((jsonDecode(first.receipts['sale:s1']!) as Map)['outcome'], 'noWin');
    final again = settleLocalTestRewards(pendingGold: pending, rewardReceipts: first.receipts, account: localTestAccount, progress: 'run');
    expect(again.isEmpty, isTrue);
  });
}
