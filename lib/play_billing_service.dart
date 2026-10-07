import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'billing_service.dart';

/// Google Play Billing through the in_app_purchase plugin. Packs are
/// consumable, but the server consumes them after checking (autoConsume
/// off), so a purchase is never used up before its gold is recorded.
class PlayBillingService implements BillingService {
  final InAppPurchase _iap;
  PlayBillingService([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;

  final _details = <String, ProductDetails>{};
  final _pending = <String, PurchaseDetails>{};

  @override
  Future<bool> available() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async {
    if (!await available()) return const [];
    final response = await _iap.queryProductDetails(ids);
    for (final p in response.productDetails) {
      _details[p.id] = p;
    }
    return [
      for (final p in response.productDetails)
        StoreProduct(p.id, p.title, p.price)
    ];
  }

  @override
  Future<bool> buy(String productId) async {
    final product = _details[productId];
    if (product == null) return false;
    return _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
        autoConsume: false);
  }

  @override
  Stream<BillingPurchase> get purchases => _iap.purchaseStream
      .expand((list) => list)
      .map((p) {
        final token = p.verificationData.serverVerificationData;
        _pending[token] = p;
        return BillingPurchase(
            p.productID,
            token,
            switch (p.status) {
              PurchaseStatus.pending => BillingPurchaseStatus.pending,
              PurchaseStatus.purchased ||
              PurchaseStatus.restored =>
                BillingPurchaseStatus.purchased,
              PurchaseStatus.canceled => BillingPurchaseStatus.canceled,
              PurchaseStatus.error => BillingPurchaseStatus.error,
            });
      });

  @override
  Future<void> complete(BillingPurchase purchase) async {
    final details = _pending.remove(purchase.purchaseToken);
    if (details != null && details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }
}
