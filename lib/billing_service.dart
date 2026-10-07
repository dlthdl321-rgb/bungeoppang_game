import 'dart:async';

// Google Play Billing as the app needs it: list the 황금 붕어빵 packs with
// their localized prices, start a purchase, and hear about finished ones.
// PlayBillingService (lib/play_billing_service.dart) wraps the
// in_app_purchase plugin; FakeBillingService is for tests.
//
// A purchase only becomes gold after the server has checked it
// (OnlineBackend.redeemPurchase); the server also consumes it.

class StoreProduct {
  final String id, title, price;
  const StoreProduct(this.id, this.title, this.price);
}

enum BillingPurchaseStatus { pending, purchased, canceled, error }

class BillingPurchase {
  final String productId, purchaseToken;
  final BillingPurchaseStatus status;
  const BillingPurchase(this.productId, this.purchaseToken, this.status);
}

abstract class BillingService {
  Future<bool> available();
  Future<List<StoreProduct>> products(Set<String> ids);

  /// Opens Google Play's purchase sheet; the result arrives on [purchases].
  Future<bool> buy(String productId);

  /// Finished, pending and canceled purchases, including ones left over
  /// from an earlier run (delivered again until the server accepts them).
  Stream<BillingPurchase> get purchases;

  /// Tells the plugin the app is done with [purchase] (after the server
  /// has recorded and consumed it).
  Future<void> complete(BillingPurchase purchase);
}

class NoBillingService implements BillingService {
  const NoBillingService();
  @override
  Future<bool> available() async => false;
  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];
  @override
  Future<bool> buy(String productId) async => false;
  @override
  Stream<BillingPurchase> get purchases => const Stream.empty();
  @override
  Future<void> complete(BillingPurchase purchase) async {}
}

class FakeBillingService implements BillingService {
  final Map<String, String> prices;
  FakeBillingService(this.prices);
  final _purchases = StreamController<BillingPurchase>.broadcast();
  final completed = <String>[];
  var _serial = 0;

  /// What the next [buy] does.
  BillingPurchaseStatus nextResult = BillingPurchaseStatus.purchased;

  @override
  Future<bool> available() async => true;
  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => [
        for (final id in ids)
          if (prices[id] case final price?) StoreProduct(id, id, price)
      ];
  @override
  Future<bool> buy(String productId) async {
    if (!prices.containsKey(productId)) return false;
    scheduleMicrotask(() => _purchases
        .add(BillingPurchase(productId, 'token-${_serial++}', nextResult)));
    return true;
  }

  @override
  Stream<BillingPurchase> get purchases => _purchases.stream;
  @override
  Future<void> complete(BillingPurchase purchase) async =>
      completed.add(purchase.purchaseToken);

  /// A purchase finished while the app was closed.
  void deliver(BillingPurchase purchase) => _purchases.add(purchase);
}
