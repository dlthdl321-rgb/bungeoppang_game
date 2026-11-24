part of 'game_controller.dart';

/// 황금 붕어빵: buying packs with Google Play ([GameController.billing]).
/// The server owns the balance; [GameState.premium] mirrors it. The new game
/// spends gold through its own purchase gateway (WorkshopOnline).
extension PremiumCommands on GameController {
  /// New Workshop only mirrors confirmed server gold, without applying legacy
  /// prototype item grants to the fresh game's progress.
  Future<String?> refreshWorkshopWallet() async {
    if (!online.signedIn) return '로그인 후 확인할 수 있어요.';
    try {
      final source=online;
      final transport=source is WorkshopTransport ? source as WorkshopTransport : null;
      final account=transport?.authenticatedAccount;
      final wallet=await source.syncWallet();
      if (!source.signedIn || (transport != null && transport.authenticatedAccount!=account)) return '계정이 변경됐어요. 잔액을 다시 확인해 주세요.';
      await _setGold(wallet.gold); return null;
    }
    on OnlineException { return '황금붕어빵력 잔액 확인을 다시 시도해 주세요.'; }
  }

  /// The packs with Google Play's localized prices; empty when billing is
  /// unavailable.
  Future<List<StoreProduct>> goldPacks() async {
    try {
      return await billing.products({for (final p in goldProducts) p.id});
    } catch (_) {
      return const [];
    }
  }

  /// Opens Google Play's purchase sheet; the gold arrives through
  /// [_onPurchase] once the server has checked the purchase.
  Future<String?> buyGoldPack(String productId) async {
    if (await _requireSignIn() case final error?) return error;
    return await billing.buy(productId) ? null : '결제를 시작할 수 없어요';
  }

  Future<void> _onPurchase(BillingPurchase p) async {
    switch (p.status) {
      case BillingPurchaseStatus.pending:
        _setPremiumNotice('결제를 확인하는 중이에요');
        return;
      case BillingPurchaseStatus.canceled || BillingPurchaseStatus.error:
        return;
      case BillingPurchaseStatus.purchased:
        break;
    }
    try {
      // Signed out: the plugin delivers the purchase again after login.
      if (!online.signedIn) return;
      final gold = await online.redeemPurchase(p.productId, p.purchaseToken);
      await billing.complete(p);
      await _setGold(gold);
      // 사용 통계: the product only, never the price (26번 5단계).
      usage.record(UsageEvent.payDone, {'product_id': p.productId});
      _setPremiumNotice('$goldName 충전 완료');
    } on OnlineException catch (e) {
      if (e.failure == OnlineFailure.rejected) {
        // Not a valid purchase for this account: stop redelivering it.
        await billing.complete(p);
        _setPremiumNotice('결제를 확인하지 못했어요');
      }
      // Offline: the plugin delivers the purchase again on the next start.
    }
  }

  /// Brings the balance up to date. Old server grants (the old clicker's
  /// cosmetics, early skills and boosts) are no longer applied (32번).
  Future<void> _syncWallet() async {
    final wallet = await online.syncWallet();
    await _setGold(wallet.gold);
  }

  /// A build without the online settings only (4차 피드백 IC10 후속): its
  /// test gold lives on this device, for LocalTestPurchaseGateway and the
  /// charge tab's free test gold. An online build's gold is the server's, so
  /// this refuses there. True once [gold] is stored.
  Future<bool> setLocalTestGold(int gold) async {
    if (online.configured || gold < 0) return false;
    await _setGold(gold);
    return state.premium.gold == gold;
  }

  Future<void> _setGold(int gold) async {
    if (busy || _away || _disposed || state.premium.gold == gold) return;
    final before = state.copy();
    state.premium.gold = gold;
    await _commit(before);
  }

  void _setPremiumNotice(String message) {
    premiumNotice = message;
    _notifyChanged();
  }
}
