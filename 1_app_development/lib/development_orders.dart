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
/// Products already handed over for an unfinished order (DEC-017/023/007,
/// DEC-018/022). Quality and freshness are frozen on [soldOnBusinessIndex];
/// [ordinaryBuns] was paid at once and the sale count waits for completion.
class CustomerDelivery {
  final String batch, flavor;
  final int line, variant, quantity, madeOnBusinessIndex, soldOnBusinessIndex;
  final BigInt ordinaryBuns;
  CustomerDelivery({required this.batch, required this.flavor, required this.line, required this.variant,
      required this.quantity, required this.madeOnBusinessIndex, required this.soldOnBusinessIndex,
      required this.ordinaryBuns}) {
    if (batch.isEmpty || flavor.isEmpty || line < 0 || variant < 0 || variant >= 4 || quantity <= 0 ||
        madeOnBusinessIndex <= 0 || soldOnBusinessIndex < madeOnBusinessIndex || age >= 5 ||
        ordinaryBuns.isNegative) {
      throw const FormatException('부분 판매 기록 오류');
    }
  }
  int get age => soldOnBusinessIndex - madeOnBusinessIndex;
  Map<String, dynamic> toJson() => {'batch': batch, 'flavor': flavor, 'line': line, 'variant': variant,
    'quantity': quantity, 'madeOnBusinessIndex': madeOnBusinessIndex,
    'soldOnBusinessIndex': soldOnBusinessIndex, 'ordinaryBuns': ordinaryBuns.toString()};
  factory CustomerDelivery.fromJson(Map<String, dynamic> row) {
    if (row['batch'] is! String || row['flavor'] is! String) throw const FormatException('부분 판매 저장 오류');
    return CustomerDelivery(batch: row['batch'] as String, flavor: row['flavor'] as String,
      line: DevelopmentBalance.integer(row, 'line'), variant: DevelopmentBalance.integer(row, 'variant'),
      quantity: DevelopmentBalance.integer(row, 'quantity'),
      madeOnBusinessIndex: DevelopmentBalance.integer(row, 'madeOnBusinessIndex'),
      soldOnBusinessIndex: DevelopmentBalance.integer(row, 'soldOnBusinessIndex'),
      ordinaryBuns: DevelopmentBalance.decimal(row, 'ordinaryBuns'));
  }
}
class CustomerOrder {
  final String id, customerId;
  final List<CustomerOrderLine> lines;
  final List<CustomerDelivery> deliveries;
  final int remainingMs;
  CustomerOrder({required this.id, String? customerId, required List<CustomerOrderLine> lines, required this.remainingMs,
      List<CustomerDelivery> deliveries = const []})
      : customerId = customerId ?? id, lines = List.unmodifiable(lines), deliveries = List.unmodifiable(deliveries) {
    if (id.isEmpty || this.customerId.isEmpty || lines.isEmpty || remainingMs < 0) throw const FormatException('손님 대기 정보 오류');
    final seen = <String>{};
    for (final d in deliveries) {
      if (d.line >= lines.length || d.flavor != lines[d.line].flavor || !seen.add('${d.line}:${d.batch}') ||
          (lines[d.line].variant != null && d.variant != lines[d.line].variant) ||
          (d.variant == 0 && !lines[d.line].special)) {
        throw const FormatException('부분 판매와 주문 불일치');
      }
    }
    for (var i = 0; i < lines.length; i++) {
      if (remaining(i) < 0) throw const FormatException('주문보다 많은 부분 판매');
    }
  }
  int delivered(int line) => deliveries.where((d) => d.line == line).fold(0, (n, d) => n + d.quantity);
  int remaining(int line) => lines[line].quantity - delivered(line);
  int get remainingQuantity => List.generate(lines.length, remaining).fold(0, (a, b) => a + b);
  CustomerOrder _with({int? remainingMs, List<CustomerDelivery>? deliveries}) => CustomerOrder(id: id,
      customerId: customerId, lines: lines, remainingMs: remainingMs ?? this.remainingMs,
      deliveries: deliveries ?? this.deliveries);
  CustomerOrder advanceActive(int ms) {
    if (ms < 0) throw const FormatException('음수 손님 경과');
    return _with(remainingMs: ms >= remainingMs ? 0 : remainingMs - ms);
  }
  CustomerOrder withDeliveries(List<CustomerDelivery> more) => _with(deliveries: [...deliveries, ...more]);
  /// The order as the customer placed it, without deliveries: what sale
  /// evidence, visit records and the server see.
  CustomerOrder get placed => CustomerOrder(id: id, customerId: customerId, lines: lines, remainingMs: remainingMs);
  Map<String, dynamic> toJson() => {'id': id, 'customerId': customerId, 'remainingMs': remainingMs,
    'lines': lines.map((l) => l.toJson()).toList(),
    if (deliveries.isNotEmpty) 'deliveries': deliveries.map((d) => d.toJson()).toList()};
  factory CustomerOrder.fromJson(Map<String, dynamic> row) {
    if (row['id'] is! String || row['customerId'] is! String || row['lines'] is! List) throw const FormatException('손님 저장 형식 오류');
    final lines = <CustomerOrderLine>[];
    for (final value in row['lines'] as List) {
      if (value is! Map<String, dynamic> || value['flavor'] is! String || value['special'] is! bool ||
          (value['variant'] != null && value['variant'] is! int)) throw const FormatException('주문 행 저장 오류');
      lines.add(CustomerOrderLine(flavor: value['flavor'] as String,
          quantity: DevelopmentBalance.integer(value, 'quantity'), variant: value['variant'] as int?, special: value['special'] as bool));
    }
    final deliveries = row['deliveries'];
    if (deliveries != null && (deliveries is! List || deliveries.isEmpty)) throw const FormatException('부분 판매 목록 오류');
    return CustomerOrder(id: row['id'] as String, customerId: row['customerId'] as String, lines: lines,
        remainingMs: DevelopmentBalance.integer(row, 'remainingMs'), deliveries: [
          for (final d in (deliveries as List?) ?? const [])
            if (d is Map<String, dynamic>) CustomerDelivery.fromJson(d) else throw const FormatException('부분 판매 저장 오류')]);
  }
}

/// Deterministic oldest-first allocation shared by stored and freshly produced
/// stock, for what each line still needs. It only selects; the sale command
/// rechecks the transaction. With [partial] a shortfall is allowed, but at
/// least one product must match.
List<Map<String, int>> selectCustomerInventory(CustomerOrder order,
    InventoryProgress inventory, {required int businessIndex, bool partial = false}) {
  if (businessIndex <= 0 || order.remainingMs <= 0) {
    throw const FormatException('판매 시간/주문 상태 오류');
  }
  final remaining = {for (final b in inventory.batches.values) b.id: b.quantity};
  final used = {for (final d in order.deliveries) '${d.line}:${d.batch}'};
  final selected = <Map<String, int>>[];
  for (var i = 0; i < order.lines.length; i++) {
    final line = order.lines[i];
    var needed = order.remaining(i);
    final eligible = inventory.batches.values.where((b) {
      final age = businessIndex - b.madeOnBusinessIndex;
      return b.flavor == line.flavor && age >= 0 && age < 5 && !used.contains('$i:${b.id}') &&
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
    if (needed != 0 && !partial) throw const FormatException('주문 전량의 재고가 필요해요.');
    selected.add(selection);
  }
  if (selected.every((s) => s.isEmpty)) throw const FormatException('주문에 맞는 재고가 없어요.');
  return selected;
}

class SaleCommit {
  final InventoryProgress inventory;
  final SaleQualityQuote quote;
  final Map<String, dynamic> evidence;
  /// Ordinary buns for the products handed over in this command only.
  final BigInt paidNow;
  SaleCommit(this.inventory, this.quote, this.evidence, {BigInt? paidNow})
      : paidNow = paidNow ?? quote.provisionalOrdinaryBuns;
}

/// Hands [selectedByLine] over now: checks it against what each line still
/// needs and freezes each product's quality and freshness on [businessIndex].
List<CustomerDelivery> _handOver(DevelopmentBalance config, CustomerOrder order,
    InventoryProgress inventory, List<Map<String, int>> selectedByLine,
    int businessIndex, Map<String, int> flavorDifficulties) {
  if (order.remainingMs <= 0 || selectedByLine.length != order.lines.length || businessIndex <= 0) {
    throw const FormatException('판매 시간/주문 상태 오류');
  }
  final used = {for (final d in order.deliveries) '${d.line}:${d.batch}'};
  final amounts = <String, int>{}, handed = <CustomerDelivery>[];
  for (var i = 0; i < order.lines.length; i++) {
    final line = order.lines[i];
    var count = 0;
    for (final entry in selectedByLine[i].entries) {
      final batch = inventory.batches[entry.key], difficulty = flavorDifficulties[line.flavor];
      if (batch == null || difficulty == null || batch.flavor != line.flavor || entry.value <= 0 ||
          used.contains('$i:${entry.key}')) {
        throw const FormatException('손님 요구와 재고 불일치');
      }
      amounts[entry.key] = (amounts[entry.key] ?? 0) + entry.value;
      if (amounts[entry.key]! > batch.quantity) throw const FormatException('손님 요구와 재고 불일치');
      count += entry.value;
      final age = businessIndex - batch.madeOnBusinessIndex;
      final quote = evaluateSaleQuality(config, [SaleQualityPortion(variant: batch.variant, quantity: entry.value,
          age: age, difficulty: difficulty, requestedVariant: line.variant, specialOrder: line.special)]);
      handed.add(CustomerDelivery(batch: batch.id, flavor: batch.flavor, line: i, variant: batch.variant,
          quantity: entry.value, madeOnBusinessIndex: batch.madeOnBusinessIndex,
          soldOnBusinessIndex: businessIndex, ordinaryBuns: quote.provisionalOrdinaryBuns));
    }
    if (count > order.remaining(i)) throw const FormatException('주문보다 많은 제품이에요.');
  }
  if (handed.isEmpty) throw const FormatException('주문에 맞는 재고가 없어요.');
  return handed;
}

/// A full-order candidate: earlier partial deliveries plus [selectedByLine]
/// must cover every line. Caller saves inventory consumption, sale ID, ordinary
/// buns + lifetime, and pending gold evidence in ONE durable command.
SaleCommit prepareCustomerSale(DevelopmentBalance config, CustomerOrder order,
    InventoryProgress inventory, {required List<Map<String, int>> selectedByLine,
      required int businessIndex, required Map<String, int> flavorDifficulties}) {
  final handed = _handOver(config, order, inventory, selectedByLine, businessIndex, flavorDifficulties);
  final all = [...order.deliveries, ...handed];
  for (var i = 0; i < order.lines.length; i++) {
    if (all.where((d) => d.line == i).fold(0, (n, d) => n + d.quantity) != order.lines[i].quantity) {
      throw const FormatException('손님 주문 전량을 준비해 주세요.');
    }
  }
  // Count-weighted over the values frozen when each product was handed over.
  final quality = evaluateSaleQuality(config, [for (final d in all) SaleQualityPortion(variant: d.variant,
      quantity: d.quantity, age: d.age, difficulty: flavorDifficulties[d.flavor]!,
      requestedVariant: order.lines[d.line].variant, specialOrder: order.lines[d.line].special)]);
  return SaleCommit(inventory.consume({for (final d in handed) d.batch: d.quantity}), quality, {
    'order': order.placed.toJson(), 'businessIndex': businessIndex,
    'products': [for (final d in all) {'batch': d.batch, 'flavor': d.flavor, 'variant': d.variant,
      'quantity': d.quantity, 'madeOnBusinessIndex': d.madeOnBusinessIndex, 'age': d.age, 'line': d.line,
      if (d.soldOnBusinessIndex != businessIndex) 'soldOnBusinessIndex': d.soldOnBusinessIndex}],
    'revision': config.revision, 'stars': quality.stars, 'scorePermille': quality.scorePermille,
    'ordinaryBuns': quality.provisionalOrdinaryBuns.toString(),
  }, paidNow: handed.fold<BigInt>(BigInt.zero, (n, d) => n + d.ordinaryBuns));
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
    // Same shape as validateStoredCustomerSale rebuilds from all products.
    final combined = [for (var i = 0; i < order.lines.length; i++) {
      for (final d in order.deliveries.where((d) => d.line == i)) d.batch: d.quantity,
      if (i < selectedByLine.length) ...selectedByLine[i]}];
    final fingerprint = jsonEncode([order.id, order.customerId, order.lines.map((l) => l.toJson()).toList(),
      combined.map((row) { final keys = row.keys.toList()..sort(); return {for (final k in keys) k: row[k]}; }).toList()]);
    final old = sales[order.id];
    if (old != null) {
      final saved = jsonDecode(old) as Map<String, dynamic>;
      if (saved['fingerprint'] != fingerprint) throw const FormatException('같은 판매 ID의 다른 요청');
      return this;
    }
    final result = prepareCustomerSale(config, order, inventory, selectedByLine: selectedByLine,
        businessIndex: businessIndex, flavorDifficulties: flavorDifficulties);
    final amount = result.paidNow;
    return CustomerSalesProgress(inventory: result.inventory, ordinaryBuns: ordinaryBuns + amount,
      lifetimeSalesBuns: lifetimeSalesBuns + amount,
      sales: {...sales, order.id: jsonEncode({'fingerprint': fingerprint, 'evidence': result.evidence})});
  }
  /// A partial sale: pays ordinary buns for [selectedByLine] now and returns
  /// the order with those deliveries. No sale ID, count or gold evidence yet.
  (CustomerSalesProgress, CustomerOrder) deliver(DevelopmentBalance config, CustomerOrder order, {
      required List<Map<String, int>> selectedByLine, required int businessIndex,
      required Map<String, int> flavorDifficulties}) {
    if (sales.containsKey(order.id)) throw const FormatException('이미 끝난 주문이에요.');
    final handed = _handOver(config, order, inventory, selectedByLine, businessIndex, flavorDifficulties);
    final next = order.withDeliveries(handed);
    if (next.remainingQuantity == 0) throw const FormatException('주문을 다 채우는 판매는 완료로 처리해 주세요.');
    final amount = handed.fold<BigInt>(BigInt.zero, (n, d) => n + d.ordinaryBuns);
    return (CustomerSalesProgress(inventory: inventory.consume({for (final d in handed) d.batch: d.quantity}),
      ordinaryBuns: ordinaryBuns + amount, lifetimeSalesBuns: lifetimeSalesBuns + amount, sales: sales), next);
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
    // A partial delivery keeps the day it was handed over.
    final sold = value.containsKey('soldOnBusinessIndex') ? DevelopmentBalance.integer(value, 'soldOnBusinessIndex') : index;
    if (lineIndex >= order.lines.length || quantity == 0 || made == 0 || sold >= index && value.containsKey('soldOnBusinessIndex') ||
        sold - made != age || age >= 5 || variant >= 4) {
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
