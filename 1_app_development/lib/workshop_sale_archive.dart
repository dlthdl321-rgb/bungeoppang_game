import 'dart:convert';

import 'development_balance.dart';
import 'development_inventory.dart';
import 'development_orders.dart';

/// 30번 저장 장부 요약 (2026-11-24): finished sales move out of the save.
///
/// * 2-A (schema 14): sales to anonymous guests become two totals
///   ([WorkshopState.archivedSales], [WorkshopState.archivedSalesBuns]).
/// * 2-B (schema 15): a named neighbor's sale goes too, but its ID stays in
///   [WorkshopState.archivedNamedSales]. Its relationship record
///   (`actions['sale:<id>']`, its award and its visit) stays, and the visit's
///   `context.lines` is the order as placed (loading checks they are equal),
///   so the choice events read the archived sale from there.
///
/// A sale is settled when all hold:
/// * [keep] is false for it (the controller keeps a named sale whose visit
///   has no order lines to read it back from),
/// * the server's review is final (`rewardReceipts['sale:<id>']` exists and
///   its `outcome` is not `pending`; the server keeps the result by sale ID,
///   so asking again never pays twice),
/// * none of its stock batches is still in the inventory ([liveBatches]),
/// * it was sold before the current business day ([businessIndex]).
class SaleArchivePick {
  final List<String> ids;
  /// The part of [ids] sold to named neighbors.
  final List<String> namedIds;
  final BigInt buns;
  const SaleArchivePick(this.ids, this.buns, [this.namedIds = const []]);
}

SaleArchivePick pickSettledSales({
  required Map<String, String> sales,
  required Map<String, String> rewardReceipts,
  required Set<String> liveBatches,
  required int businessIndex,
  required bool Function(String customerId) named,
  required bool Function(String saleId, Map<String, dynamic> evidence) keep,
}) {
  final ids = <String>[], namedIds = <String>[];
  var buns = BigInt.zero;
  for (final entry in sales.entries) {
    final receipt = rewardReceipts['sale:${entry.key}'];
    if (receipt == null || (jsonDecode(receipt) as Map)['outcome'] == 'pending') continue;
    final evidence = validateStoredCustomerSale(entry.key, entry.value);
    if ((evidence['businessIndex'] as int) >= businessIndex) continue;
    if (keep(entry.key, evidence)) continue;
    if ((evidence['products'] as List).any((p) => liveBatches.contains((p as Map)['batch']))) continue;
    ids.add(entry.key);
    if (named((evidence['order'] as Map)['customerId'] as String)) namedIds.add(entry.key);
    buns += saleBuns(evidence);
  }
  ids.sort();
  namedIds.sort();
  return SaleArchivePick(ids, buns, namedIds);
}

/// What a finished sale paid in 붕어빵력: the ordinary price and the 특제
/// bonus on top of it (the same sum [WorkshopState.fromJson] checks).
BigInt saleBuns(Map<String, dynamic> evidence) =>
    DevelopmentBalance.decimal(evidence, 'ordinaryBuns') +
    (evidence.containsKey('premiumBuns') ? DevelopmentBalance.decimal(evidence, 'premiumBuns') : BigInt.zero);

/// 30번 2-B: the production results still needed in the save. A result's
/// fingerprint (`inventory.dispositions`) backs its live stock, an unplaced
/// prepared product, a sale still in the ledger (the load check finds each
/// sold product's origin) or a waiting guest's partial delivery, and the
/// result on screen ([sessionId], which `storeResult` looks up). Other
/// results are spent: their IDs never come back (a cooking session ID is
/// random, a griddle cell's cycle only grows), so their fingerprints go.
InventoryProgress keepNeededResults(InventoryProgress inventory, {
  required Iterable<String> salesEvidence,
  required Iterable<CustomerOrder> waiting,
  String? sessionId,
}) {
  final needed = <String>{...inventory.batches.keys, ...inventory.prepared.keys, if (sessionId != null) sessionId};
  for (final raw in salesEvidence) {
    final evidence = (jsonDecode(raw) as Map<String, dynamic>)['evidence'] as Map<String, dynamic>;
    for (final product in evidence['products'] as List) { needed.add((product as Map)['batch'] as String); }
  }
  for (final delivery in waiting.expand((c) => c.deliveries)) { needed.add(delivery.batch); }
  return inventory.retain(needed);
}
