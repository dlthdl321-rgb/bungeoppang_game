part of 'game_controller.dart';

/// 황금 붕어빵: buying packs with Google Play ([GameController.billing]),
/// spending through the server ([GameController.online]) and restoring what
/// was bought. The server owns the balance; [GameState.premium] mirrors it.
extension PremiumCommands on GameController {
  /// Gold price of [itemId] for [kind], or null if it is not for sale.
  int? goldPrice(PremiumKind kind, String itemId) => switch (kind) {
        PremiumKind.cosmetic => cosmetics
            .where((d) => d.id == itemId)
            .map(cosmeticGoldPrice)
            .firstOrNull,
        PremiumKind.skill =>
          upgrades.where((u) => u.id == itemId).map(skillUnlockGoldPrice).firstOrNull,
        PremiumKind.boost =>
          itemId == BoostKind.bought.name ? boughtBoostGold : null,
      };

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
    if (!online.configured) return '온라인 기능을 준비 중이에요';
    if (!online.signedIn && !await online.signIn()) {
      return 'Google Play 게임즈에 로그인해 주세요';
    }
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
      if (!online.signedIn && !await online.signIn()) return;
      final gold = await online.redeemPurchase(p.productId, p.purchaseToken);
      await billing.complete(p);
      await _setGold(gold);
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

  /// Spends gold on a cosmetic (owned for good, its lock skipped), an early
  /// skill unlock or a 10-minute boost. Null on success.
  Future<String?> spendGold(PremiumKind kind, String itemId) async {
    final price = goldPrice(kind, itemId);
    if (price == null) return '살 수 없는 항목이에요';
    if (!online.configured) return '온라인 기능을 준비 중이에요';
    if (state.premium.gold < price) return '$goldName이 부족해요';
    try {
      if (!online.signedIn && !await online.signIn()) {
        return 'Google Play 게임즈에 로그인해 주세요';
      }
      final requestId = List.generate(
          20, (_) => _requestAlphabet[_requestRandom.nextInt(36)]).join();
      final (gold, grant) = await online.spend(requestId, kind, itemId);
      if (busy || _away || _disposed) return null; // applied on next sync
      tick();
      final before = state.copy();
      _applyGrant(grant);
      state.premium.gold = gold;
      return await _commitWith(
              before, GameEvent(GameEventKind.purchase, _grantName(grant)))
          ? null
          : '저장하지 못했어요';
    } on OnlineException catch (e) {
      return switch (e.failure) {
        OnlineFailure.insufficient => '$goldName이 부족해요',
        OnlineFailure.alreadyOwned => '이미 가지고 있어요',
        _ => '연결이 불안정해요. 잠시 후 다시 해 주세요',
      };
    }
  }

  /// Brings the balance up to date and applies grants this save has not
  /// seen (a purchase made on another device, or a reinstall).
  Future<void> _syncWallet() async {
    final wallet = await online.syncWallet();
    if (busy || _away || _disposed) return;
    tick();
    final before = state.copy(), premium = state.premium;
    // A fresh save restores permanent unlocks but does not hand out boosts
    // that were already used.
    final fresh = !premium.synced;
    var changed = premium.gold != wallet.gold || fresh;
    for (final g in wallet.grants) {
      if (premium.appliedGrants.contains(g.id)) continue;
      if (fresh && g.consumable) {
        premium.appliedGrants.add(g.id);
      } else {
        _applyGrant(g);
      }
      changed = true;
    }
    premium
      ..gold = wallet.gold
      ..synced = true;
    if (changed) await _commit(before);
  }

  void _applyGrant(WalletGrant g) {
    final premium = state.premium;
    if (!premium.appliedGrants.add(g.id)) return;
    switch (g.kind) {
      case PremiumKind.cosmetic:
        final matches = cosmetics.where((d) => d.id == g.itemId);
        if (matches.isNotEmpty && !state.ownsCosmetic(matches.first)) {
          state.wardrobe.owned.add(g.itemId);
        }
      case PremiumKind.skill:
        if (upgrades.any((u) => u.id == g.itemId)) {
          premium.skillUnlocks.add(g.itemId);
        }
      case PremiumKind.boost:
        state.support.startBoost(boostOf(BoostKind.bought), gameNow);
    }
  }

  String _grantName(WalletGrant g) => switch (g.kind) {
        PremiumKind.cosmetic =>
          cosmetics.where((d) => d.id == g.itemId).firstOrNull?.name ??
              g.itemId,
        PremiumKind.skill =>
          '${upgrades.where((u) => u.id == g.itemId).firstOrNull?.name ?? g.itemId} 먼저 해금',
        PremiumKind.boost => boostOf(BoostKind.bought).name,
      };

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

const _requestAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
final _requestRandom = math.Random.secure();
