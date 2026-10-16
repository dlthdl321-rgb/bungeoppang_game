import 'development_balance.dart';
import 'development_evidence.dart';
import 'development_rules.dart';

/// Detached journal. Methods describe evidence recorded by atomic integration;
/// they do NOT debit, refund, grant, authenticate or modify GameState.
class PurchaseJournal {
  final String accountId, transactionId;
  final CompositeQuote quote;
  final int sequence;
  final bool reserved, debited, applied, restored;
  final String serverStatus, serverReceiptId, serverGrantId;
  PurchaseJournal._(this.accountId, this.transactionId, this.quote, this.sequence,
      this.reserved, this.debited, this.applied, this.restored, this.serverStatus,
      this.serverReceiptId, this.serverGrantId);

  factory PurchaseJournal.start(String accountId, String transactionId, CompositeQuote quote) {
    if (accountId.isEmpty || transactionId.isEmpty || quote.revision.isEmpty ||
        quote.skillId.isEmpty || quote.quantity <= 0 || quote.owned < 0 ||
        quote.buns <= BigInt.zero || quote.gold <= BigInt.zero) {
      throw const FormatException('구매 의도 오류');
    }
    return PurchaseJournal._(accountId, transactionId, quote, 0,
        false, false, false, false, 'unknown', '', '');
  }

  PurchaseJournal _next({bool? reserved, bool? debited, bool? applied,
      bool? restored, String? serverStatus, String? serverReceiptId, String? serverGrantId}) => PurchaseJournal._(
          accountId, transactionId, quote, sequence + 1,
          reserved ?? this.reserved, debited ?? this.debited,
          applied ?? this.applied, restored ?? this.restored,
          serverStatus ?? this.serverStatus, serverReceiptId ?? this.serverReceiptId,
          serverGrantId ?? this.serverGrantId);

  /// Invoke only after authenticated reservation response matching this quote.
  PurchaseJournal recordReservation(Map<String, dynamic> receipt) {
    _match(receipt, 'reserved');
    if (serverStatus == 'committed' || serverStatus == 'canceled') {
      throw const FormatException('종료 거래 예약 역행');
    }
    return reserved ? this : _next(reserved: true, serverStatus: 'reserved');
  }

  /// Must be saved atomically WITH the actual local cost debit.
  PurchaseJournal recordDebit() {
    if (debited) return this;
    if (!reserved || serverStatus != 'reserved') {
      throw const FormatException('예약 없는 로컬 차감');
    }
    return _next(debited: true);
  }

  /// Caller must obtain this via authenticated backend transport. Matching is
  /// not cryptographic verification. Unknown transport outcome calls no method.
  PurchaseJournal recordServerResult(Map<String, dynamic> receipt) {
    final status = receipt['status'];
    if (status != 'committed' && status != 'canceled') {
      throw const FormatException('최종 서버 결과 오류');
    }
    _match(receipt, status as String);
    final receiptId = receipt['receiptId'], grantId = receipt['grantId'];
    if (receiptId is! String || receiptId.isEmpty || grantId is! String ||
        (status == 'committed' && grantId.isEmpty) ||
        (status == 'canceled' && grantId.isNotEmpty)) {
      throw const FormatException('최종 영수증/지급 식별자 오류');
    }
    if (serverStatus == status) {
      if (serverReceiptId != receiptId || serverGrantId != grantId) {
        throw const FormatException('같은 거래 영수증/지급 식별자 충돌');
      }
      return this;
    }
    if (serverStatus == 'committed' || serverStatus == 'canceled') {
      throw const FormatException('최종 서버 결과 충돌');
    }
    // A committed result without local debit evidence is retained for manual
    // reconciliation, rather than being interpreted as a free grant.
    return _next(serverStatus: status, serverReceiptId: receiptId, serverGrantId: grantId);
  }

  void _match(Map<String, dynamic> receipt, String status) {
    if (receipt['status'] != status || !compositeReceiptMatches(quote,
        expectedAccountId: accountId, expectedTransactionId: transactionId,
        receipt: {...receipt, 'status': 'committed'})) {
      throw const FormatException('구매 영수증 불일치');
    }
  }

  /// Must be saved atomically WITH actual item/skill application.
  PurchaseJournal recordApplication() {
    if (applied) return this;
    if (serverStatus != 'committed' || !debited || restored) {
      throw const FormatException('지급 근거 부족');
    }
    return _next(applied: true);
  }

  /// Must be saved atomically WITH the one-time local refund.
  PurchaseJournal recordRestoration() {
    if (restored) return this;
    if (serverStatus != 'canceled' || !debited || applied) {
      throw const FormatException('복원 근거 부족');
    }
    return _next(restored: true);
  }

  bool get settled => (serverStatus == 'committed' && applied) ||
      (serverStatus == 'canceled' && (!debited || restored));
  BigInt get reservedBuns => settled || debited ? BigInt.zero : quote.buns;

  Map<String, dynamic> toJson() => {
    'schema': 1, 'account': accountId, 'transaction': transactionId,
    'revision': quote.revision, 'skill': quote.skillId, 'owned': quote.owned,
    'quantity': quote.quantity, 'buns': quote.buns.toString(),
    'gold': quote.gold.toString(), 'sequence': sequence,
    'reserved': reserved, 'debited': debited, 'applied': applied,
    'restored': restored, 'serverStatus': serverStatus,
    'receiptId': serverReceiptId, 'grantId': serverGrantId,
  };

  factory PurchaseJournal.fromJson(Map<String, dynamic> row) {
    String text(String key) {
      final value = row[key];
      if (value is! String || value.isEmpty) throw FormatException('거래 필드 오류: $key');
      return value;
    }
    bool flag(String key) {
      final value = row[key];
      if (value is! bool) throw FormatException('거래 표식 오류: $key');
      return value;
    }
    if (row['schema'] is! int || row['schema'] != 1) {
      throw const FormatException('거래 저장 버전 오류');
    }
    final start = PurchaseJournal.start(text('account'), text('transaction'),
        CompositeQuote(text('revision'), text('skill'),
          DevelopmentBalance.integer(row, 'owned'),
          DevelopmentBalance.integer(row, 'quantity'),
          DevelopmentBalance.decimal(row, 'buns'),
          DevelopmentBalance.decimal(row, 'gold')));
    final reserved = flag('reserved'), debited = flag('debited');
    final applied = flag('applied'), restored = flag('restored');
    final status = text('serverStatus');
    final receiptId = row['receiptId'], grantId = row['grantId'];
    final terminal = ['committed', 'canceled'].contains(status);
    if (receiptId is! String || grantId is! String ||
        (terminal != receiptId.isNotEmpty) ||
        ((status == 'committed') != grantId.isNotEmpty)) {
      throw const FormatException('저장된 영수증/지급 식별자 불일치');
    }
    final sequence = DevelopmentBalance.integer(row, 'sequence');
    if (!['unknown', 'reserved', 'committed', 'canceled'].contains(status) ||
        (debited && !reserved) || (applied && (!debited || status != 'committed')) ||
        (restored && (!debited || status != 'canceled')) ||
        (reserved && status == 'unknown') || (status == 'reserved' && !reserved)) {
      throw const FormatException('거래 상태 불일치');
    }
    // Each recorded event increments exactly once. This rejects rolled-back
    // counters/flags; it does not prove local evidence survives reinstall.
    final expected = (reserved ? 1 : 0) + (debited ? 1 : 0) +
        (applied ? 1 : 0) + (restored ? 1 : 0) +
        (['committed', 'canceled'].contains(status) ? 1 : 0);
    if (sequence != expected) throw const FormatException('거래 순번 불일치');
    return PurchaseJournal._(start.accountId, start.transactionId, start.quote,
        sequence, reserved, debited, applied, restored, status, receiptId, grantId);
  }
}

/// Backend boundary only. No Firebase adapter/endpoint is enabled by this file.
abstract class CompositePurchaseBackend {
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent);
  Future<Map<String, dynamic>> query(String accountId, String transactionId);
  Future<Map<String, dynamic>> commit(PurchaseJournal debitEvidence);
  Future<Map<String, dynamic>> cancel(String accountId, String transactionId);
}

/// Only call with the ledger belonging to the SAME local wallet/snapshot.
/// Account filtering alone cannot establish device/progress ownership.
BigInt availableBunsAfterReservations(BigInt balance, String account,
    Iterable<PurchaseJournal> journals) {
  if (balance.isNegative || account.isEmpty) throw const FormatException('가용 재화 입력 오류');
  final ids = <String>{};
  var held = BigInt.zero;
  for (final journal in journals) {
    if (journal.accountId != account || !ids.add(journal.transactionId)) {
      throw const FormatException('예약 원장 계정/중복 오류');
    }
    held += journal.reservedBuns;
  }
  if (held > balance) throw const FormatException('예약 잔액 재대조 필요');
  return balance - held;
}
