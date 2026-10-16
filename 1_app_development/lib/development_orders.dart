import 'dart:convert';
import 'development_balance.dart';
import 'development_inventory.dart';
import 'development_sale_quality.dart';

class CustomerOrderLine {
  final String flavor;
  final int quantity;
  final int? variant;
  final bool special;
  CustomerOrderLine({required this.flavor, required this.quantity, this.variant, this.special = false}) {
    if (flavor.isEmpty || quantity <= 0 || (variant != null && (variant! < 0 || variant! >= 4)) ||
        (variant == 0 && !special)) throw const FormatException('손님 주문 오류');
  }
  Map<String, dynamic> toJson() => {'flavor': flavor, 'quantity': quantity, 'variant': variant, 'special': special};
}
class CustomerOrder {
  final String id, customerId;
  final List<CustomerOrderLine> lines;
  final int remainingMs;
  CustomerOrder({required this.id, String? customerId, required List<CustomerOrderLine> lines, required this.remainingMs})
      : customerId = customerId ?? id, lines = List.unmodifiable(lines) {
    if (id.isEmpty || this.customerId.isEmpty || lines.isEmpty || remainingMs < 0) throw const FormatException('손님 대기 정보 오류');
  }
  CustomerOrder advanceActive(int ms) {
    if (ms < 0) throw const FormatException('음수 손님 경과');
    return CustomerOrder(id: id, customerId: customerId, lines: lines, remainingMs: ms >= remainingMs ? 0 : remainingMs - ms);
  }
  Map<String, dynamic> toJson() => {'id': id, 'customerId': customerId, 'remainingMs': remainingMs,
    'lines': lines.map((l) => l.toJson()).toList()};
  factory CustomerOrder.fromJson(Map<String, dynamic> row) {
    if (row['id'] is! String || row['customerId'] is! String || row['lines'] is! List) throw const FormatException('손님 저장 형식 오류');
    final lines = <CustomerOrderLine>[];
    for (final value in row['lines'] as List) {
      if (value is! Map<String, dynamic> || value['flavor'] is! String || value['special'] is! bool ||
          (value['variant'] != null && value['variant'] is! int)) throw const FormatException('주문 행 저장 오류');
      lines.add(CustomerOrderLine(flavor: value['flavor'] as String,
          quantity: DevelopmentBalance.integer(value, 'quantity'), variant: value['variant'] as int?, special: value['special'] as bool));
    }
    return CustomerOrder(id: row['id'] as String, customerId: row['customerId'] as String, lines: lines,
        remainingMs: DevelopmentBalance.integer(row, 'remainingMs'));
  }
}

class SaleCommit {
  final InventoryProgress inventory;
  final SaleQualityQuote quote;
  final Map<String, dynamic> evidence;
  SaleCommit(this.inventory, this.quote, this.evidence);
}

/// A full-order candidate. Caller saves inventory consumption, sale ID, ordinary
/// buns + lifetime, and pending gold evidence in ONE durable command.
SaleCommit prepareCustomerSale(DevelopmentBalance config, CustomerOrder order,
    InventoryProgress inventory, {required List<Map<String, int>> selectedByLine,
      required int businessIndex, required Map<String, int> flavorDifficulties}) {
  if (order.remainingMs <= 0 || selectedByLine.length != order.lines.length || businessIndex <= 0) {
    throw const FormatException('판매 시간/주문 상태 오류');
  }
  final amounts = <String, int>{}, portions = <SaleQualityPortion>[];
  final evidence = <Map<String, dynamic>>[];
  for (var i = 0; i < order.lines.length; i++) {
    final line = order.lines[i], selected = selectedByLine[i];
    var count = BigInt.zero;
    for (final entry in selected.entries) {
      final batch = inventory.batches[entry.key], difficulty = flavorDifficulties[line.flavor];
      if (batch == null || difficulty == null || batch.flavor != line.flavor || entry.value <= 0) {
        throw const FormatException('손님 요구와 재고 불일치');
      }
      final age = businessIndex - batch.madeOnBusinessIndex;
      amounts[entry.key] = (amounts[entry.key] ?? 0) + entry.value;
      count += BigInt.from(entry.value);
      portions.add(SaleQualityPortion(variant: batch.variant, quantity: entry.value,
          age: age, difficulty: difficulty, requestedVariant: line.variant, specialOrder: line.special));
      evidence.add({'batch': batch.id, 'flavor': batch.flavor, 'variant': batch.variant,
        'quantity': entry.value, 'madeOnBusinessIndex': batch.madeOnBusinessIndex, 'age': age, 'line': i});
    }
    if (count != BigInt.from(line.quantity)) throw const FormatException('손님 주문 전량을 준비해 주세요.');
  }
  final quality = evaluateSaleQuality(config, portions);
  return SaleCommit(inventory.consume(amounts), quality, {
    'order': order.toJson(), 'products': evidence, 'businessIndex': businessIndex,
    'revision': config.revision, 'stars': quality.stars, 'scorePermille': quality.scorePermille,
    'ordinaryBuns': quality.provisionalOrdinaryBuns.toString(),
  });
}

/// Full successful sale ledger. Immutable retries return the same candidate;
/// cancellation/time expiry creates no sale, payment or rare-gold opportunity.
class CustomerSalesProgress {
  final InventoryProgress inventory;
  final BigInt ordinaryBuns, lifetimeSalesBuns;
  final Map<String, String> sales;
  CustomerSalesProgress({required this.inventory, required this.ordinaryBuns,
      required this.lifetimeSalesBuns, Map<String, String> sales = const {}}) : sales = Map.unmodifiable(sales) {
    if (ordinaryBuns.isNegative || lifetimeSalesBuns.isNegative) throw const FormatException('판매 재화 오류');
  }
  CustomerSalesProgress sell(DevelopmentBalance config, CustomerOrder order, {
      required List<Map<String, int>> selectedByLine, required int businessIndex,
      required Map<String, int> flavorDifficulties}) {
    final fingerprint = jsonEncode([order.id, order.customerId, order.lines.map((l) => l.toJson()).toList(),
      selectedByLine.map((row) { final keys = row.keys.toList()..sort(); return {for (final k in keys) k: row[k]}; }).toList()]);
    final old = sales[order.id];
    if (old != null) {
      final saved = jsonDecode(old) as Map<String, dynamic>;
      if (saved['fingerprint'] != fingerprint) throw const FormatException('같은 판매 ID의 다른 요청');
      return this;
    }
    final result = prepareCustomerSale(config, order, inventory, selectedByLine: selectedByLine,
        businessIndex: businessIndex, flavorDifficulties: flavorDifficulties);
    final amount = result.quote.provisionalOrdinaryBuns;
    return CustomerSalesProgress(inventory: result.inventory, ordinaryBuns: ordinaryBuns + amount,
      lifetimeSalesBuns: lifetimeSalesBuns + amount,
      sales: {...sales, order.id: jsonEncode({'fingerprint': fingerprint, 'evidence': result.evidence})});
  }
}
