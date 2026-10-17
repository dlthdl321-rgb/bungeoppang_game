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

/// Deterministic oldest-first allocation shared by stored and freshly produced
/// stock. It only selects; prepareCustomerSale rechecks the complete transaction.
List<Map<String, int>> selectCustomerInventory(CustomerOrder order,
    InventoryProgress inventory, {required int businessIndex}) {
  if (businessIndex <= 0 || order.remainingMs <= 0) {
    throw const FormatException('판매 시간/주문 상태 오류');
  }
  final remaining = {for (final b in inventory.batches.values) b.id: b.quantity};
  final selected = <Map<String, int>>[];
  for (final line in order.lines) {
    var needed = line.quantity;
    final eligible = inventory.batches.values.where((b) {
      final age = businessIndex - b.madeOnBusinessIndex;
      return b.flavor == line.flavor && age >= 0 && age < 5 &&
          (line.variant == null ? b.variant >= 1 && b.variant <= 3 :
           b.variant == line.variant && (b.variant != 0 || line.special));
    }).toList()..sort((a, b) {
      final age = a.madeOnBusinessIndex.compareTo(b.madeOnBusinessIndex);
      return age != 0 ? age : a.id.compareTo(b.id);
    });
    final selection = <String, int>{};
    for (final batch in eligible) {
      if (needed == 0) break;
      final available = remaining[batch.id]!;
      final amount = needed < available ? needed : available;
      if (amount > 0) {
        selection[batch.id] = amount;
        needed -= amount;
        remaining[batch.id] = available - amount;
      }
    }
    if (needed != 0) throw const FormatException('주문 전량의 재고가 필요해요.');
    selected.add(selection);
  }
  return selected;
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

/// Structural replay validation of a stored sale, without repricing historical
/// receipts against today's provisional balance. This is corruption detection,
/// NOT proof a server may accept to mint gold.
Map<String, dynamic> validateStoredCustomerSale(String id, String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! Map<String, dynamic> || decoded['evidence'] is! Map<String, dynamic> ||
      decoded['fingerprint'] is! String) throw const FormatException('판매 기록 형식 오류');
  final evidence = decoded['evidence'] as Map<String, dynamic>;
  if (evidence['order'] is! Map<String, dynamic> || evidence['products'] is! List ||
      evidence['revision'] is! String || (evidence['revision'] as String).isEmpty) throw const FormatException('판매 증거 누락');
  final order = CustomerOrder.fromJson(evidence['order'] as Map<String, dynamic>);
  final index = DevelopmentBalance.integer(evidence, 'businessIndex');
  final stars = DevelopmentBalance.integer(evidence, 'stars');
  final score = DevelopmentBalance.integer(evidence, 'scorePermille');
  DevelopmentBalance.decimal(evidence, 'ordinaryBuns');
  if (order.id != id || order.remainingMs == 0 || index == 0 || stars < 1 || stars > 5 || score > 1000) {
    throw const FormatException('판매 결과 식별/범위 오류');
  }
  final selected = [for (final _ in order.lines) <String, int>{}];
  final batchFacts = <String, String>{};
  for (final value in evidence['products'] as List) {
    if (value is! Map<String, dynamic> || value['batch'] is! String || (value['batch'] as String).isEmpty ||
        value['flavor'] is! String) throw const FormatException('판매 제품 증거 오류');
    final lineIndex = DevelopmentBalance.integer(value, 'line');
    final quantity = DevelopmentBalance.integer(value, 'quantity');
    final variant = DevelopmentBalance.integer(value, 'variant');
    final made = DevelopmentBalance.integer(value, 'madeOnBusinessIndex');
    final age = DevelopmentBalance.integer(value, 'age');
    if (lineIndex >= order.lines.length || quantity == 0 || made == 0 || index - made != age || age >= 5 || variant >= 4) {
      throw const FormatException('판매 제품 수량/신선도 오류');
    }
    final line = order.lines[lineIndex], batch = value['batch'] as String;
    if (value['flavor'] != line.flavor || (line.variant != null && variant != line.variant) ||
        (variant == 0 && !(line.special && line.variant == 0)) || selected[lineIndex].containsKey(batch)) {
      throw const FormatException('판매 제품과 주문 불일치');
    }
    final facts = jsonEncode([value['flavor'], variant, made]);
    if (batchFacts.containsKey(batch) && batchFacts[batch] != facts) throw const FormatException('동일 제품 증거 충돌');
    batchFacts[batch] = facts;
    selected[lineIndex][batch] = quantity;
  }
  for (var i = 0; i < selected.length; i++) {
    if (selected[i].values.fold<BigInt>(BigInt.zero, (sum, n) => sum + BigInt.from(n)) != BigInt.from(order.lines[i].quantity)) {
      throw const FormatException('판매 전량 증거 불일치');
    }
  }
  final fingerprint = jsonEncode([order.id, order.customerId, order.lines.map((l) => l.toJson()).toList(),
    selected.map((row) { final keys = row.keys.toList()..sort(); return {for (final k in keys) k: row[k]}; }).toList()]);
  if (fingerprint != decoded['fingerprint']) throw const FormatException('판매 요청 지문 불일치');
  return evidence;
}
