import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/billing_service.dart';
import 'package:todays_bungeoppang/invite_models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/server_invite_repository.dart';

FakeOnlineBackend backend() => FakeOnlineBackend(products: {
      'gold_60': 60
    }, prices: {
      PremiumKind.cosmetic: {'beanie': 15},
      PremiumKind.skill: {'tap_4': 40},
      PremiumKind.boost: {'bought': 20},
    }, now: () => DateTime.utc(2026, 10, 6));

Matcher failsWith(OnlineFailure f) =>
    throwsA(isA<OnlineException>().having((e) => e.failure, 'failure', f));

void main() {
  test('설정이 없는 빌드는 모든 온라인 기능이 사용 불가로 끝난다', () async {
    const off = NoOnlineBackend();
    expect(off.configured, isFalse);
    expect(await off.signIn(), SignInResult.failed);
    expect(off.syncWallet(), failsWith(OnlineFailure.unavailable));
    expect(const ServerInvitationRepository(off).register(),
        failsWith(OnlineFailure.unavailable));
    expect(await const NoBillingService().available(), isFalse);
  });

  test('로그인 전에는 지갑을 쓸 수 없고, 구매 토큰은 한 번만 충전된다', () async {
    final b = backend();
    expect(b.syncWallet(), failsWith(OnlineFailure.signedOut));
    expect(await b.signIn(), SignInResult.success);
    expect(await b.redeemPurchase('gold_60', 'tok'), 60);
    expect(await b.redeemPurchase('gold_60', 'tok'), 60);
    expect(b.redeemPurchase('gold_9', 'x'), failsWith(OnlineFailure.rejected));
  });

  test('같은 요청은 두 번 차감되지 않고, 영구 해금은 다시 살 수 없다', () async {
    final b = backend();
    await b.signIn();
    expect(b.spend('req-00001', PremiumKind.skill, 'tap_4'),
        failsWith(OnlineFailure.insufficient));
    await b.redeemPurchase('gold_60', 'tok');
    final (gold, grant) =
        await b.spend('req-00002', PremiumKind.skill, 'tap_4');
    expect(gold, 20);
    expect(grant.consumable, isFalse);
    expect((await b.spend('req-00002', PremiumKind.skill, 'tap_4')).$1, 20);
    expect(b.spend('req-00003', PremiumKind.skill, 'tap_4'),
        failsWith(OnlineFailure.alreadyOwned));
    final (_, item) = await b.spend('req-00004', PremiumKind.boost, 'bought');
    expect(item.consumable, isTrue);
    expect((await b.syncWallet()).grants.length, 2);
  });

  test('서버 초대 저장소는 필요하면 로그인하고 서버 출처로 표시한다', () async {
    final b = backend();
    final repo = ServerInvitationRepository(b);
    expect(repo.origin, InviteOrigin.server);
    final profile = await repo.register();
    expect(b.signedIn, isTrue);
    expect(profile.origin, InviteOrigin.server);
    final ticket = await repo.createTicket(
        profile, 'mission-1', DateTime.utc(2026, 10, 6));
    expect(ticket.missionToken, 'mission-1');
    expect(ticket.url, startsWith('https://'));
    b.inviteEvents.add(InviteEvent(
        eventId: 'e1',
        ticketId: ticket.id,
        visitId: 'v1',
        playerId: 'p1',
        kind: InviteEventKind.clicked,
        atUtc: DateTime.utc(2026, 10, 6),
        origin: InviteOrigin.server));
    expect(await repo.fetchEvents(profile, {}), hasLength(1));
    expect(await repo.fetchEvents(profile, {'e1'}), isEmpty);
  });

  test('로그인을 취소하면 초대는 로그인 필요로 끝난다', () async {
    final b = backend()..signInResult = SignInResult.canceled;
    expect(ServerInvitationRepository(b).register(),
        failsWith(OnlineFailure.signedOut));
  });

  test('결제는 구매 결과를 스트림으로 알린다', () async {
    final billing = FakeBillingService({'gold_60': '₩1,200'});
    expect(
        (await billing.products({'gold_60', 'gold_1'})).single.price, '₩1,200');
    final next = billing.purchases.first;
    expect(await billing.buy('gold_60'), isTrue);
    final p = await next;
    expect(p.status, BillingPurchaseStatus.purchased);
    await billing.complete(p);
    expect(billing.completed, [p.purchaseToken]);
  });
}
