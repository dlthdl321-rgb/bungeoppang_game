import 'dart:convert';
import 'development_balance.dart';
import 'development_rules.dart';

class ProductBatch {
  final String id, flavor;
  final int variant, quantity, madeOnBusinessIndex;
  ProductBatch({required this.id, required this.flavor, required this.variant,
      required this.quantity, required this.madeOnBusinessIndex}) {
    if (id.isEmpty || flavor.isEmpty || variant < 0 || variant >= 5 || quantity <= 0 || madeOnBusinessIndex < 0) {
      throw const FormatException('제품 묶음 오류');
    }
  }
  Map<String, dynamic> toJson() => {'id': id, 'flavor': flavor, 'variant': variant,
    'quantity': quantity, 'madeOnBusinessIndex': madeOnBusinessIndex};
  factory ProductBatch.fromJson(Map<String, dynamic> row) {
    if (row['id'] is! String || row['flavor'] is! String) throw const FormatException('제품 식별자 오류');
    return ProductBatch(id: row['id'] as String, flavor: row['flavor'] as String,
      variant: DevelopmentBalance.integer(row, 'variant'), quantity: DevelopmentBalance.integer(row, 'quantity'),
      madeOnBusinessIndex: DevelopmentBalance.integer(row, 'madeOnBusinessIndex'));
  }
}

/// Result disposition stays even when its batch is consumed/expired, preventing
/// the same result being reopened and turned into a new product or fresh batch.
class InventoryProgress {
  final Map<String, ProductBatch> batches;
  final Map<String, String> dispositions;
  final Map<String, ProductBatch> prepared;
  final Map<String, int> bindings;
  InventoryProgress._(Map<String, ProductBatch> batches, Map<String, String> dispositions,
      {Map<String, ProductBatch> prepared = const {}, Map<String, int> bindings = const {}})
      : batches = Map.unmodifiable(batches), dispositions = Map.unmodifiable(dispositions),
        prepared = Map.unmodifiable(prepared), bindings = Map.unmodifiable(bindings);
  factory InventoryProgress.empty() => InventoryProgress._({}, {});
  InventoryProgress recordResult(ProductBatch batch, {required bool keep}) {
    if (batch.madeOnBusinessIndex == 0) throw const FormatException('준비 제품 전용 경로 필요');
    final fingerprint = jsonEncode([keep, batch.toJson()]);
    final old = dispositions[batch.id];
    if (old != null) {
      if (old != fingerprint) throw const FormatException('제품 결과 ID 충돌');
      return this;
    }
    return InventoryProgress._({...batches, if (keep) batch.id: batch},
        {...dispositions, batch.id: fingerprint}, prepared: prepared, bindings: bindings);
  }
  /// madeOnBusinessIndex=0 is an unassigned preparation marker, not real age0
  /// inventory. It becomes sellable only after accepting an actual business day.
  InventoryProgress recordPreparedResult(ProductBatch batch, {required bool keep}) {
    if (batch.madeOnBusinessIndex != 0) throw const FormatException('준비 제품 귀속 오류');
    final fingerprint = jsonEncode([keep, batch.toJson()]);
    final old = dispositions[batch.id];
    if (old != null) {
      if (old != fingerprint) throw const FormatException('준비 결과 ID 충돌');
      return this;
    }
    return InventoryProgress._(batches, {...dispositions, batch.id: fingerprint},
        prepared: {...prepared, if (keep) batch.id: batch}, bindings: bindings);
  }
  InventoryProgress acceptPrepared(int businessIndex) {
    if (businessIndex <= 0) throw const FormatException('준비 제품 실제 영업일 필요');
    final next = {...batches}, accepted = {...bindings};
    for (final batch in prepared.values) {
      if (next.containsKey(batch.id) || accepted.containsKey(batch.id)) throw const FormatException('준비 제품 중복 귀속');
      next[batch.id] = ProductBatch(id: batch.id, flavor: batch.flavor, variant: batch.variant,
          quantity: batch.quantity, madeOnBusinessIndex: businessIndex);
      accepted[batch.id] = businessIndex;
    }
    return InventoryProgress._(next, dispositions, bindings: accepted);
  }
  InventoryProgress expire(DevelopmentBalance config, int businessIndex) {
    if (businessIndex < 0) throw const FormatException('영업일 순번 오류');
    return InventoryProgress._({for (final entry in batches.entries)
        if (!inventoryExpired(config, madeOnBusinessIndex: entry.value.madeOnBusinessIndex,
            currentBusinessIndex: businessIndex)) entry.key: entry.value}, dispositions, prepared: prepared, bindings: bindings);
  }

  /// Supply all quantities consumed by ONE validated sale. Save with its sale
  /// id/payment/evidence. Reservation and sale eligibility are separate checks.
  InventoryProgress consume(Map<String, int> amounts) {
    if (amounts.isEmpty) throw const FormatException('빈 재고 소비');
    final next = {...batches};
    for (final entry in amounts.entries) {
      final old = next[entry.key];
      if (old == null || entry.value <= 0 || entry.value > old.quantity) {
        throw const FormatException('재고 수량 부족');
      }
      final remaining = old.quantity - entry.value;
      if (remaining == 0) { next.remove(entry.key); }
      else { next[entry.key] = ProductBatch(id: old.id, flavor: old.flavor, variant: old.variant,
          quantity: remaining, madeOnBusinessIndex: old.madeOnBusinessIndex); }
    }
    return InventoryProgress._(next, dispositions, prepared: prepared, bindings: bindings);
  }
  Map<String, dynamic> toJson() => {'schema': 1,
    'batches': {for (final e in batches.entries) e.key: e.value.toJson()},
    'dispositions': Map<String, String>.from(dispositions),
    'prepared': {for (final e in prepared.entries) e.key: e.value.toJson()},
    'bindings': Map<String, int>.from(bindings)};
  factory InventoryProgress.fromJson(Map<String, dynamic> row) {
    if (row['schema'] is! int || row['schema'] != 1 || row['batches'] is! Map<String, dynamic> ||
        row['dispositions'] is! Map<String, dynamic> || row['prepared'] is! Map<String, dynamic> ||
        row['bindings'] is! Map<String, dynamic>) throw const FormatException('재고 저장 형식 오류');
    final dispositions = <String, String>{};
    final originals = <String, ProductBatch>{};
    for (final e in (row['dispositions'] as Map<String, dynamic>).entries) {
      if (e.value is! String) throw const FormatException('제품 처리 기록 오류');
      final value = jsonDecode(e.value as String);
      if (value is! List || value.length != 2 || value[0] is! bool || value[1] is! Map<String, dynamic>) {
        throw const FormatException('제품 처리 내용 오류');
      }
      final batch = ProductBatch.fromJson(value[1] as Map<String, dynamic>);
      if (batch.id != e.key) throw const FormatException('제품 처리 키 불일치');
      dispositions[e.key] = e.value as String;
      if (value[0] == true) originals[e.key] = batch;
    }
    final bindings = <String, int>{};
    for (final e in (row['bindings'] as Map<String, dynamic>).entries) {
      final value = e.value, original = originals[e.key];
      if (value is! int || value <= 0 || original == null || original.madeOnBusinessIndex != 0) {
        throw const FormatException('준비 제품 귀속 기록 오류');
      }
      bindings[e.key] = value;
    }
    final prepared = <String, ProductBatch>{};
    for (final e in (row['prepared'] as Map<String, dynamic>).entries) {
      if (e.value is! Map<String, dynamic> || bindings.containsKey(e.key)) throw const FormatException('준비 제품 상태 충돌');
      final batch = ProductBatch.fromJson(e.value as Map<String, dynamic>), original = originals[e.key];
      if (original == null || batch.id != e.key || batch.madeOnBusinessIndex != 0 ||
          jsonEncode(batch.toJson()) != jsonEncode(original.toJson())) throw const FormatException('준비 제품 원장 불일치');
      prepared[e.key] = batch;
    }
    final batches = <String, ProductBatch>{};
    for (final e in (row['batches'] as Map<String, dynamic>).entries) {
      if (e.value is! Map<String, dynamic>) throw const FormatException('재고 묶음 형식 오류');
      final batch = ProductBatch.fromJson(e.value as Map<String, dynamic>), original = originals[e.key];
      if (batch.id != e.key || original == null || batch.flavor != original.flavor ||
          batch.variant != original.variant || batch.madeOnBusinessIndex != (bindings[e.key] ?? original.madeOnBusinessIndex) ||
          prepared.containsKey(e.key) || (original.madeOnBusinessIndex == 0 && !bindings.containsKey(e.key)) ||
          batch.quantity > original.quantity) throw const FormatException('재고/제품 원장 불일치');
      batches[e.key] = batch;
    }
    for (final original in originals.values) {
      if (original.madeOnBusinessIndex == 0 && !prepared.containsKey(original.id) &&
          !bindings.containsKey(original.id)) throw const FormatException('준비 제품 귀속 누락');
    }
    return InventoryProgress._(batches, dispositions, prepared: prepared, bindings: bindings);
  }
}
