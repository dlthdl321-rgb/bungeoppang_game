import 'dart:convert';

import 'development_balance.dart';
import 'workshop_online.dart' show validateWorkshopRewardReceipt, workshopRewardFingerprint;

/// 5차 피드백 12 (2026-11-25): in a test build without the online settings
/// (`LocalTestPurchaseGateway`, debug/profile only) no server ever answers a
/// reward claim, so mission, attendance, collection and level gold stayed
/// '심사 대기' and the gold shown never changed. This settles them on the
/// device, once each, with receipts of the same shape the server gives
/// ([validateWorkshopRewardReceipt]) under the test account:
///
/// * a gold claim (`mission:`·`attendance:`·`collection:`·`level:`) is
///   `eligible` for the gold it asks — added to the device's test gold;
/// * a sale (`sale:`) is `noWin`: the server's draw is not imitated, so a
///   test build gets no sale gold (the sale can then be archived, 30번).
///
/// Release builds never come here: they have no `LocalTestPurchaseGateway`.
class LocalRewardSettlement {
  /// New receipts by `pendingGold` key (JSON strings, like the server's).
  final Map<String, String> receipts;
  /// The gold the new receipts pay.
  final int gold;
  const LocalRewardSettlement(this.receipts, this.gold);
  bool get isEmpty => receipts.isEmpty;
}

LocalRewardSettlement settleLocalTestRewards({
  required Map<String, String> pendingGold,
  required Map<String, String> rewardReceipts,
  required String account,
  required String progress,
}) {
  final receipts = <String, String>{};
  var gold = 0;
  for (final entry in pendingGold.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final old = rewardReceipts[entry.key];
    if (old != null && (jsonDecode(old) as Map)['outcome'] != 'pending') continue;
    final sale = entry.key.startsWith('sale:');
    final claim = sale ? entry.key.substring(5) : '$progress:${entry.key}';
    final kind = sale ? 'sale' : 'mission';
    final payload = jsonDecode(entry.value) as Map<String, dynamic>;
    final amount = sale ? 0 : DevelopmentBalance.integer(payload, 'gold');
    final receipt = validateWorkshopRewardReceipt({
      'account': account, 'progress': progress, 'claim': claim, 'kind': kind,
      'fingerprint': workshopRewardFingerprint(account, progress, claim, kind, payload),
      'outcome': sale ? 'noWin' : 'eligible', 'gold': amount, 'receiptId': 'local-test:$claim',
    }, account: account, progress: progress, claim: claim, kind: kind, payload: payload);
    receipts[entry.key] = jsonEncode(receipt);
    gold += amount;
  }
  return LocalRewardSettlement(receipts, gold);
}
