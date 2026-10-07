import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/billing_service.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/premium_config.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'controller_test.dart' show FakeTime;
import 'stage12_customization_test.dart' show setLevel;

FakeOnlineBackend fakeBackend(FakeTime t) => FakeOnlineBackend(products: {
      for (final p in goldProducts) p.id: p.gold
    }, prices: {
      PremiumKind.cosmetic: {
        for (final d in cosmeticDefinitions)
          if (cosmeticGoldPrice(d) case final price?) d.id: price
      },
      PremiumKind.skill: {
        for (final u in upgrades)
          if (skillUnlockGoldPrice(u) case final price?) u.id: price
      },
      PremiumKind.boost: {BoostKind.bought.name: boughtBoostGold},
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

  test('황금 붕어빵으로 잠긴 꾸미기를 사면 레벨과 상관없이 보유한다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn();
    b.gold = 500;
    c.state.premium.gold = 500;
    final locked = cosmeticDefinitions.firstWhere(
        (d) => d.unlockLevel > c.state.level && cosmeticGoldPrice(d) != null);
    expect(await c.spendGold(PremiumKind.cosmetic, locked.id), isNull);
    expect(c.state.ownsCosmetic(locked), isTrue);
    expect(c.state.premium.gold, 500 - cosmeticGoldPrice(locked)!);
    expect(await c.spendGold(PremiumKind.cosmetic, locked.id), '이미 가지고 있어요');
    c.dispose();
  });

  test('스킬 먼저 해금: 누적 생산 전에도 붕어빵으로 살 수 있다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn();
    final skill = upgrades.firstWhere((u) => u.unlockTotal > BigInt.zero);
    expect(quoteUpgrade(c.state, skill, PurchaseMode.one).unlocked, isFalse);
    expect(await c.spendGold(PremiumKind.skill, skill.id), contains('부족'));
    b.gold = 500;
    c.state.premium.gold = 500;
    expect(await c.spendGold(PremiumKind.skill, skill.id), isNull);
    expect(quoteUpgrade(c.state, skill, PurchaseMode.one).unlocked, isTrue);
    c.state.buns = skill.baseCost;
    expect(await c.buyUpgrade(skill, 1), isTrue);
    c.dispose();
  });

  test('황금 부스트를 사면 10분 동안 3배가 된다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn();
    b.gold = 100;
    c.state.premium.gold = 100;
    final before = c.currentTapRate;
    expect(await c.spendGold(PremiumKind.boost, BoostKind.bought.name), isNull);
    expect(c.currentTapRate, before * BigInt.from(3));
    expect(c.activeBoost?.kind, BoostKind.bought);
    c.dispose();
  });

  test('다시 설치하면 꾸미기·스킬 해금은 돌아오고 이미 쓴 부스트는 돌아오지 않는다', () async {
    final t = FakeTime();
    final backend = fakeBackend(t);
    final (c, b, _, _) = await start(t, backend: backend);
    await b.signIn();
    b.gold = 500;
    c.state.premium.gold = 500;
    final skill = upgrades.firstWhere((u) => u.unlockTotal > BigInt.zero);
    final beanie = cosmeticDefinitions.firstWhere((d) => d.id == 'beanie');
    await c.spendGold(PremiumKind.skill, skill.id);
    await c.spendGold(PremiumKind.cosmetic, beanie.id);
    await c.spendGold(PremiumKind.boost, BoostKind.bought.name);
    c.dispose();

    // Fresh save, same account.
    final (fresh, _, _, _) = await start(FakeTime(), backend: backend);
    await fresh.syncOnline();
    expect(fresh.state.premium.skillUnlocks, {skill.id});
    expect(fresh.state.ownsCosmetic(beanie), isTrue);
    expect(fresh.activeBoost, isNull);
    expect(fresh.state.premium.gold, backend.gold);
    // A purchase made later on another device is applied once.
    await backend.spend(
        'other-device-1', PremiumKind.boost, BoostKind.bought.name);
    await fresh.syncOnline();
    expect(fresh.activeBoost?.kind, BoostKind.bought);
    fresh.dispose();
  });

  test('친구 방문과 초대 손님은 한 번씩만 부스트가 되고 손님 줄에 선다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn(); // background sync never opens the Kakao login
    b.inbox.addAll([
      const ServerVisit(id: 'visit_a', name: '앨리스', invite: false),
      const ServerVisit(
          id: 'invite_b', name: '밥', invite: true, look: {'hat': 'beanie'}),
    ]);
    await c.syncOnline();
    expect(c.guestArrivals.map((g) => g.name), ['앨리스', '밥']);
    expect(c.activeBoost?.kind, BoostKind.invite); // strongest wins
    expect(c.state.support.appliedVisits, {'visit_a', 'invite_b'});
    c.guestShown(c.guestArrivals.first);
    await c.syncOnline();
    expect(c.guestArrivals.map((g) => g.name), ['밥']);
    expect(b.name, '테스터');
    expect(b.look['hat'], c.state.equippedCosmetic(CosmeticSlot.hat));
    c.dispose();
  });

  test('Lv.2가 되면 초대 Lv.1 달성을 한 번만 알린다', () async {
    final t = FakeTime();
    final (c, b, _, _) = await start(t);
    await b.signIn();
    await c.syncOnline();
    expect(b.levelOneReports, 0);
    setLevel(c.state, 2, t.now);
    await c.syncOnline();
    await c.syncOnline();
    expect(b.levelOneReports, 1);
    c.dispose();
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

  test('온라인 설정이 없으면 모든 온라인 명령이 준비 중으로 끝난다', () async {
    final t = FakeTime();
    final c = GameController(MemoryGameRepository(), t);
    await c.initialize();
    expect(await c.addFriend('BBAAAAAAAA'), '온라인 기능을 준비 중이에요');
    expect(await c.spendGold(PremiumKind.boost, BoostKind.bought.name),
        '온라인 기능을 준비 중이에요');
    expect(await c.buyGoldPack('gold_60'), '온라인 기능을 준비 중이에요');
    expect(await c.goldPacks(), isEmpty);
    await c.syncOnline(); // no-op, no throw
    c.dispose();
  });

  test('황금 붕어빵 기록은 저장 후 다시 불러와도 같고, 없던 세이브는 빈 지갑이다', () {
    final s = GameState.initial(DateTime.utc(2026));
    s.premium
      ..gold = 42
      ..synced = true
      ..appliedGrants.add('spend_x')
      ..skillUnlocks.add('tap_4');
    final restored = GameState.fromJson(s.toJson());
    expect(restored.premium.gold, 42);
    expect(restored.premium.skillUnlocks, {'tap_4'});
    expect(restored.premium.appliedGrants, {'spend_x'});
    final old = s.toJson()..remove('premium');
    expect(GameState.fromJson(old).premium.gold, 0);
    final bad = s.toJson()
      ..['premium'] = {
        ...s.premium.toJson(),
        'skillUnlocks': ['tap_999']
      };
    expect(() => GameState.fromJson(bad), throwsFormatException);
  });
}
