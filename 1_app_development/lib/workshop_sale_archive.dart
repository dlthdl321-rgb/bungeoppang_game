import 'dart:convert';

import 'development_balance.dart';
import 'development_orders.dart';

/// 30번 저장 장부 요약 2-A (2026-11-24): finished sales to anonymous
/// guests move out of the save into two totals ([WorkshopState.archivedSales],
/// [WorkshopState.archivedSalesBuns]). Named neighbors' sales stay: their
/// relationship ledger and choice events read each sale (2-B).
///
/// A sale is settled when all hold:
/// * its guest is not a named neighbor ([named] is false),
/// * the server's review is final (`rewardReceipts['sale:<id>']` exists and
///   its `outcome` is not `pending`; the server keeps the result by sale ID,
///   so asking again never pays twice),
/// * none of its stock batches is still in the inventory ([liveBatches]),
/// * it was sold before the current business day ([businessIndex]).
class SaleArchivePick {
  final List<String> ids;
  final BigInt buns;
  const SaleArchivePick(this.ids, this.buns);
}

SaleArchivePick pickSettledAnonymousSales({
  required Map<String, String> sales,
  required Map<String, String> rewardReceipts,
  required Set<String> liveBatches,
  required int businessIndex,
  required bool Function(String customerId) named,
}) {
  final ids = <String>[];
  var buns = BigInt.zero;
  for (final entry in sales.entries) {
    final receipt = rewardReceipts['sale:${entry.key}'];
    if (receipt == null || (jsonDecode(receipt) as Map)['outcome'] == 'pending') continue;
    final evidence = validateStoredCustomerSale(entry.key, entry.value);
    if ((evidence['businessIndex'] as int) >= businessIndex) continue;
    if (named((evidence['order'] as Map)['customerId'] as String)) continue;
    if ((evidence['products'] as List).any((p) => liveBatches.contains((p as Map)['batch']))) continue;
    ids.add(entry.key);
    buns += saleBuns(evidence);
  }
  ids.sort();
  return SaleArchivePick(ids, buns);
}

/// What a finished sale paid in 붕어빵력: the ordinary price and the 특제
/// bonus on top of it (the same sum [WorkshopState.fromJson] checks).
BigInt saleBuns(Map<String, dynamic> evidence) =>
    DevelopmentBalance.decimal(evidence, 'ordinaryBuns') +
    (evidence.containsKey('premiumBuns') ? DevelopmentBalance.decimal(evidence, 'premiumBuns') : BigInt.zero);
