import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/invite_reward_rules.dart';
import 'package:todays_bungeoppang/ranking_config.dart';
import 'package:todays_bungeoppang/online_texts.dart';
import 'package:todays_bungeoppang/billing_service.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/premium_config.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'fake_time.dart' show FakeTime;

FakeOnlineBackend fakeBackend(FakeTime t) => FakeOnlineBackend(products: {
      for (final p in goldProducts) p.id: p.gold
    }, prices: const {
    }, now: () => t.now);

Future<
        (
          GameController,
          FakeOnlineBackend,
          FakeBillingService,
          MemoryGameRepository
        )>
    start(FakeTime t,
        {FakeOnlineBackend? backend, MemoryGameRepository? repo}) async {
  final b = backend ?? fakeBackend(t);
  final billing = FakeBillingService({for (final p in goldProducts) p.id: '₩'});
  final r = repo ?? MemoryGameRepository();
  final c = GameController(r, t, online: b, billing: billing);
  await c.initialize();
  return (c, b, billing, r);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('충전: 결제가 끝나면 서버 확인 뒤 잔액이 늘고 결제가 마무리된다', () async {
    final t = FakeTime();
    final (c, b, billing, _) = await start(t);
    expect(await c.buyGoldPack('gold_60'), isNull);
    for (var i = 0; i < 5; i++) {
      await settle();
    }
    expect(b.gold, 60);
    expect(c.state.premium.gold, 60);
    expect(billing.completed, hasLength(1));
    expect(c.premiumNotice, contains('충전 완료'));
    c.dispose();
  });

  test('충전: 대기 중인 결제는 잔액을 바꾸지 않고, 오프라인이면 마무리하지 않는다', () async {
    final t = FakeTime();
    final (c, b, billing, _) = await start(t);
    await b.signIn();
    billing.deliver(const BillingPurchase(
        'gold_60', 'tok-pending', BillingPurchaseStatus.pending));
    await settle();
    expect(c.premiumNotice, contains('확인하는 중'));
    b.offline = true;
    billing.deliver(const BillingPurchase(
        'gold_60', 'tok-1', BillingPurchaseStatus.purchased));
    for (var i = 0; i < 5; i++) {
      await settle();
    }
    expect(c.state.premium.gold, 0);
    expect(billing.completed, isEmpty);
    c.dispose();
  });

  // DEC-154: with the new game wired (main.dart), visits go there and the
  // old clicker boost is untouched.
  test('새 게임이 연결되면 친구 방문은 새 게임으로 가고, 본 방문은 서버에 다시 묻지 않는다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    final seen = <String>{'visit_old'};
    final handed = <String>[];
    c.seenFriendVisits = () => seen;
    c.onFriendVisits = (visits) async { handed.addAll(visits.map((v) => v.id)); seen.addAll(visits.map((v) => v.id)); };
    await b.signIn();
    b.inbox.addAll([
      const ServerVisit(id: 'visit_old', name: '옛', invite: false),
      const ServerVisit(id: 'visit_a', name: '앨리스', invite: false),
    ]);
    await c.syncOnline();
    expect(handed, ['visit_a']);
    c.dispose();
  });

  // 29번 (2026-11-24): the goal is the NEW game's level (it was the old
  // clicker's Lv.2, which no longer rises).
  test('새 게임이 초대 목표 레벨이 되면 한 번만 알리고, 서버가 "아직"이면 30분 뒤 다시', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    var reached = false;
    c.inviteGoalReached = () => reached;
    await b.signIn();
    await c.syncOnline();
    expect(b.levelOneReports, 0, reason: '목표 전에는 알리지 않음');
    reached = true;
    b.inviteNotYet = true;
    await c.syncOnline();
    await c.syncOnline();
    expect(b.levelOneReports, 1, reason: '"아직"이면 바로 다시 묻지 않음');
    b.inviteNotYet = false;
    t.advance(inviteGoalRetryMs);
    await c.syncOnline();
    await c.syncOnline();
    expect(b.levelOneReports, 2);
    c.dispose();
  });

  test('새 게임 랭킹(DEC-153): 출시 스위치를 켜야 동기화 때 서버에 기록을 부탁하고, 점수는 보내지 않는다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn();
    await c.syncOnline();
    expect(b.workshopRankingSubmits, 0);
    debugRankingLaunchedOverride = true;
    addTearDown(() => debugRankingLaunchedOverride = null);
    t.advance(onlineSyncIntervalMs);
    await c.syncOnline();
    expect(b.workshopRankingSubmits, 1);
    c.dispose();
  });

  test('초대 보상 규칙은 공통 밸런스의 invite_rewards를 읽는다 (DEC-151)', () {
    final rules = InviteRewardRules.fromConfig(DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));
    expect([rules.inviterGold, rules.inviteeGold, rules.targetLevel, rules.dailyLimit, rules.lifetimeLimit], [5, 3, 5, 3, 20]);
    expect(rules.goalReached(4), isFalse);
    expect(rules.goalReached(5), isTrue);
  });

  test('친구 추가·방문·초대 아이디 입력은 실패 이유를 알려 준다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    expect(await c.addFriend('nope'), '아이디를 찾을 수 없어요');
    expect(await c.addFriend('bbaaaaaaaa'), isNull); // case-insensitive
    final friend = (await c.loadFriends())!.single;
    expect(await c.visitFriend(friend.playerId), isNull);
    expect(await c.visitFriend(friend.playerId), '오늘은 이미 방문했어요');
    expect((await c.loadFriends())!.single.visitedToday, isTrue);
    expect(await c.acceptInvite('BBAAAAAAAA'), isNull);
    expect(await c.acceptInvite('BBAAAAAAAA'), '초대 아이디는 한 번만 입력할 수 있어요');
    b.signInResult = SignInResult.canceled;
    b.signedIn = false;
    expect(await c.addFriend('BBAAAAAAAA'), '카카오 계정으로 로그인해 주세요');
    c.dispose();
  });

  test('온라인 설정이 없으면 모든 온라인 명령이 연결 불가로 끝난다', () async {
    final t = FakeTime();
    final c = GameController(MemoryGameRepository(), t);
    await c.initialize();
    expect(await c.addFriend('BBAAAAAAAA'), OnlineTexts.notSetUp);
    expect(await c.buyGoldPack('gold_60'), OnlineTexts.notSetUp);
    expect(await c.goldPacks(), isEmpty);
    await c.syncOnline(); // no-op, no throw
    c.dispose();
  });

  test('황금 붕어빵 기록은 저장 후 다시 불러와도 같고, 없던 세이브는 빈 지갑이다', () {
    final s = GameState.initial(DateTime.utc(2026));
    s.premium.gold = 42;
    final restored = GameState.fromJson(s.toJson());
    expect(restored.premium.gold, 42);
    // 32번 3단계: an older save's grant records are ignored, its gold kept.
    final older = s.toJson()
      ..['premium'] = {...s.premium.toJson(), 'synced': true, 'appliedGrants': ['spend_x'], 'skillUnlocks': ['tap_4']};
    expect(GameState.fromJson(older).premium.gold, 42);
    final old = s.toJson()..remove('premium');
    expect(GameState.fromJson(old).premium.gold, 0);
    final bad = s.toJson()..['premium'] = {...s.premium.toJson(), 'gold': -1};
    expect(() => GameState.fromJson(bad), throwsFormatException);
  });
}
