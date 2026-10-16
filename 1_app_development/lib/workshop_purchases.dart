import 'development_balance.dart';
import 'development_purchase_journal.dart';
import 'development_rules.dart';

/// Embedded in the SAME durable snapshot as buns. No separate journal-only
/// transaction may debit/refund this wallet. Network responses must originate
/// from the authenticated gateway; JSON matching is not authentication.
class WorkshopPurchases {
  final String? account;
  final Map<String, PurchaseJournal> journals;
  final Map<String, int> owned;
  WorkshopPurchases._(this.account, Map<String, PurchaseJournal> journals, Map<String, int> owned)
      : journals = Map.unmodifiable(journals), owned = Map.unmodifiable(owned);
  factory WorkshopPurchases.empty() => WorkshopPurchases._(null, {}, {});
  BigInt available(BigInt buns) => account == null ? buns :
      availableBunsAfterReservations(buns, account!, journals.values);
  WorkshopPurchases prepare(DevelopmentBalance config, PurchaseJournal intent,
      {required BigInt buns, required BigInt lifetime}) {
    if ((account != null && account != intent.accountId) || intent.sequence != 0 ||
        journals.values.any((j) => !j.settled)) throw const FormatException('미정산 구매 또는 계정 확인이 필요해요.');
    final old = journals[intent.transactionId];
    if (old != null) throw const FormatException('기존 거래는 같은 ID로 복구해 주세요.');
    final expected = quoteCompositeSkill(config, intent.quote.skillId,
      owned: owned[intent.quote.skillId] ?? 0, quantity: intent.quote.quantity);
    final q = intent.quote;
    if (q.revision != expected.revision || q.owned != expected.owned || q.buns != expected.buns || q.gold != expected.gold ||
        lifetime < DevelopmentBalance.decimal(config.skill(q.skillId), 'unlock_total') || buns < q.buns) {
      throw const FormatException('구매 조건 또는 견적이 변경됐어요.');
    }
    return WorkshopPurchases._(intent.accountId, {...journals, intent.transactionId: intent}, owned);
  }
  PurchaseJournal journal(String id) => journals[id] ?? (throw const FormatException('구매 기록이 없어요.'));
  WorkshopPurchases _replace(PurchaseJournal next, [Map<String, int>? skills]) =>
      WorkshopPurchases._(account, {...journals, next.transactionId: next}, skills ?? owned);
  WorkshopPurchases response(String id, Map<String, dynamic> response) {
    final old = journal(id);
    if (response['account'] != account || response['transaction'] != id) throw const FormatException('다른 계정/거래의 응답');
    if (response['status'] == 'unknown') return this;
    final next = response['status'] == 'reserved' ? old.recordReservation(response) : old.recordServerResult(response);
    return _replace(next);
  }
  WorkshopPurchaseChange debit(String id, BigInt buns) {
    final old = journal(id);
    if (old.debited) return WorkshopPurchaseChange(this, buns);
    final next = old.recordDebit();
    if (available(buns).isNegative || buns < old.quote.buns) throw const FormatException('차감할 재화 확인이 필요해요.');
    return WorkshopPurchaseChange(_replace(next), buns - old.quote.buns);
  }
  WorkshopPurchaseChange settle(String id, BigInt buns) {
    final old = journal(id);
    if (old.settled) return WorkshopPurchaseChange(this, buns);
    if (old.serverStatus == 'canceled') {
      if (!old.debited) return WorkshopPurchaseChange(this, buns);
      return WorkshopPurchaseChange(_replace(old.recordRestoration()), buns + old.quote.buns);
    }
    final next = old.recordApplication(); // Requires committed AND durable debit.
    final count = owned[old.quote.skillId] ?? 0;
    if (count != old.quote.owned || journals.values.any((j) => j.transactionId != id &&
        j.applied && j.serverGrantId == old.serverGrantId)) throw const FormatException('상품/지급 기록 재대조 필요');
    return WorkshopPurchaseChange(_replace(next, {...owned, old.quote.skillId: count + old.quote.quantity}), buns);
  }
  BigInt rate(DevelopmentBalance config, String kind) {
    if (kind != 'tap' && kind != 'auto') throw const FormatException('생산 종류 오류');
    var result = kind == 'tap' ? BigInt.one : BigInt.zero;
    for (final e in owned.entries) {
      if (e.key.startsWith('${kind}_')) result += DevelopmentBalance.decimal(config.skill(e.key), 'effect') * BigInt.from(e.value);
    }
    return result;
  }
  Map<String, dynamic> toJson() => {'schema': 1, 'account': account,
    'journals': {for (final e in journals.entries) e.key: e.value.toJson()}, 'owned': Map<String, int>.from(owned)};
  factory WorkshopPurchases.fromJson(Map<String, dynamic> row, DevelopmentBalance config) {
    if (row['schema'] != 1 || row['schema'] is! int ||
        (row['account'] != null && (row['account'] is! String || (row['account'] as String).isEmpty)) ||
        row['journals'] is! Map<String, dynamic> || row['owned'] is! Map<String, dynamic>) throw const FormatException('구매 집계 형식 오류');
    final journals = <String, PurchaseJournal>{}, owned = <String, int>{}, expected = <String, int>{};
    final grants = <String>{};
    var unsettled = 0;
    for (final e in (row['journals'] as Map<String, dynamic>).entries) {
      if (e.value is! Map<String, dynamic>) throw const FormatException('구매 원장 형식 오류');
      final j = PurchaseJournal.fromJson(e.value as Map<String, dynamic>);
      config.skill(j.quote.skillId);
      if (j.transactionId != e.key || j.accountId != row['account']) throw const FormatException('구매 원장 소유 불일치');
      if (!j.settled) unsettled++;
      journals[e.key] = j;
    }
    // Reconstruct every owned count from immutable applied ranges. Current
    // balance revisions never reprice a previously issued receipt.
    final applied = journals.values.where((j) => j.applied).toList()..sort((a,b) => a.quote.owned.compareTo(b.quote.owned));
    for (final j in applied) {
      final count = expected[j.quote.skillId] ?? 0;
      if (j.quote.owned != count || !grants.add(j.serverGrantId)) throw const FormatException('상품 회차/지급 중복');
      expected[j.quote.skillId] = count + j.quote.quantity;
    }
    for (final e in (row['owned'] as Map<String, dynamic>).entries) {
      config.skill(e.key);
      final count = DevelopmentBalance.integer(row['owned'] as Map<String, dynamic>, e.key);
      if (count <= 0 || count != expected.remove(e.key)) throw const FormatException('상품 보유 근거 오류');
      owned[e.key] = count;
    }
    if (expected.isNotEmpty || unsettled > 1 || (journals.isNotEmpty && row['account'] == null)) throw const FormatException('구매 집계 불일치');
    for (final j in journals.values.where((j) => !j.settled)) {
      if (j.quote.owned != (owned[j.quote.skillId] ?? 0)) throw const FormatException('미정산 구매 회차 불일치');
    }
    return WorkshopPurchases._(row['account'] as String?, journals, owned);
  }
}
class WorkshopPurchaseChange {
  final WorkshopPurchases purchases;
  final BigInt buns;
  WorkshopPurchaseChange(this.purchases, this.buns);
}

/// Implement only with authenticated transport AND server active-progress /
/// epoch checks and verified local-debit evidence. An online flag alone is not
/// authority. No implementation is enabled at startup until these exist.
abstract class WorkshopPurchaseGateway implements CompositePurchaseBackend {
  String get authenticatedAccount;
  Future<void> requireActiveProgress(String progressId);
}
