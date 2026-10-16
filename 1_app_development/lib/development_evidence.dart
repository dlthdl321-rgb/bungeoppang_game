import 'dart:convert';
import 'development_rules.dart';

String _text(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('증거 식별자 누락: $key');
  }
  return value;
}

Object? _canonical(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  if (value == null || value is String || value is bool || value is int) return value;
  throw const FormatException('증거는 정수 기반 JSON이어야 함');
}

/// Immutable local evidence, NOT proof accepted by the server. No wallet or
/// reward operation is exposed. Storage protection/transport remain integration.
class PendingRewardEvidence {
  final String accountId, id, kind, policyRevision;
  final String _payload;
  PendingRewardEvidence._(this.accountId, this.id, this.kind,
      this.policyRevision, this._payload);

  factory PendingRewardEvidence({required String accountId, required String id,
      required String kind, required String policyRevision,
      required Map<String, dynamic> payload}) {
    final row = {'account': accountId, 'id': id, 'kind': kind,
      'revision': policyRevision, 'payload': payload};
    return PendingRewardEvidence.fromJson(row);
  }

  factory PendingRewardEvidence.fromJson(Map<String, dynamic> row) {
    final kind = _text(row, 'kind');
    if (!['sale', 'rewardedAd'].contains(kind) ||
        row['payload'] is! Map<String, dynamic>) {
      throw const FormatException('보상 증거 종류 오류');
    }
    return PendingRewardEvidence._(_text(row, 'account'), _text(row, 'id'),
        kind, _text(row, 'revision'), jsonEncode(_canonical(row['payload'])));
  }

  Map<String, dynamic> toJson() => {'account': accountId, 'id': id,
    'kind': kind, 'revision': policyRevision, 'payload': jsonDecode(_payload)};
  String get fingerprint => jsonEncode([accountId, id, kind, policyRevision, _payload]);
}

/// Detached outbox proposal. Account selection cannot move evidence to another
/// account. Retrying returns the same ID/payload; removal requires a separately
/// persisted server outcome and is intentionally not provided here.
class RewardEvidenceOutbox {
  final Map<String, PendingRewardEvidence> _records;
  RewardEvidenceOutbox._(this._records);
  factory RewardEvidenceOutbox.empty() => RewardEvidenceOutbox._({});
  String _key(PendingRewardEvidence item) =>
      jsonEncode([item.accountId, item.kind, item.id]);

  RewardEvidenceOutbox enqueue(PendingRewardEvidence item) {
    final key = _key(item), old = _records[_key(item)];
    if (old != null) {
      if (old.fingerprint != item.fingerprint) {
        throw const FormatException('보상 증거 ID 재사용 충돌');
      }
      return this;
    }
    return RewardEvidenceOutbox._({..._records, key: item});
  }

  List<PendingRewardEvidence> forAccount(String accountId) =>
      List<PendingRewardEvidence>.unmodifiable(
          _records.values.where((item) => item.accountId == accountId));

  Map<String, dynamic> toJson() => {'schema': 1,
    'records': [for (final item in _records.values) item.toJson()]};

  factory RewardEvidenceOutbox.fromJson(Map<String, dynamic> row) {
    if (row['schema'] is! int || row['schema'] != 1 || row['records'] is! List) {
      throw const FormatException('보상 대기 저장 형식 오류');
    }
    var result = RewardEvidenceOutbox.empty();
    for (final value in row['records'] as List) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('보상 대기 항목 오류');
      }
      final item = PendingRewardEvidence.fromJson(value);
      // A stored duplicate is corruption, even when a retry would be harmless.
      if (result._records.containsKey(result._key(item))) {
        throw const FormatException('보상 대기 저장 중복');
      }
      result = result.enqueue(item);
    }
    return result;
  }
}

/// All fields must be compared with a receipt obtained via authenticated
/// backend transport. Matching alone is NOT signature verification or a grant.
bool compositeReceiptMatches(CompositeQuote quote, {
    required String expectedAccountId, required String expectedTransactionId,
    required Map<String, dynamic> receipt}) {
  if (expectedAccountId.isEmpty || expectedTransactionId.isEmpty ||
      quote.quantity <= 0 || quote.owned < 0 || quote.revision.isEmpty ||
      quote.skillId.isEmpty || quote.buns <= BigInt.zero ||
      quote.gold <= BigInt.zero) return false;
  return receipt['account'] == expectedAccountId &&
      receipt['transaction'] == expectedTransactionId &&
      receipt['revision'] == quote.revision && receipt['skill'] == quote.skillId &&
      receipt['owned'] is int && receipt['owned'] == quote.owned &&
      receipt['quantity'] is int && receipt['quantity'] == quote.quantity &&
      receipt['buns'] == quote.buns.toString() &&
      receipt['gold'] == quote.gold.toString() && receipt['status'] == 'committed';
}

/// A server REVIEW outcome, not a wallet grant. `unverifiable` is final rejection;
/// evidence still being investigated must remain `pending`.
class RewardReviewRecord {
  final PendingRewardEvidence evidence;
  final String outcome;
  RewardReviewRecord._(this.evidence, this.outcome);
  factory RewardReviewRecord.pending(PendingRewardEvidence evidence) =>
      RewardReviewRecord._(evidence, 'pending');

  RewardReviewRecord recordServerOutcome(Map<String, dynamic> result) {
    final next = result['outcome'];
    if (!['pending', 'unverifiable', 'noWin', 'eligible'].contains(next) ||
        (evidence.kind == 'rewardedAd' && next == 'noWin') ||
        result['account'] != evidence.accountId || result['evidence'] != evidence.id ||
        result['kind'] != evidence.kind || result['revision'] != evidence.policyRevision ||
        result['fingerprint'] != evidence.fingerprint) {
      throw const FormatException('보상 심사 결과 불일치');
    }
    if (outcome != 'pending' && outcome != next) {
      throw const FormatException('최종 보상 심사 결과 충돌');
    }
    return outcome == next ? this : RewardReviewRecord._(evidence, next as String);
  }

  Map<String, dynamic> toJson() => {'schema': 1,
    'evidence': evidence.toJson(), 'outcome': outcome};
  factory RewardReviewRecord.fromJson(Map<String, dynamic> row) {
    if (row['schema'] is! int || row['schema'] != 1 ||
        row['evidence'] is! Map<String, dynamic>) {
      throw const FormatException('보상 심사 저장 형식 오류');
    }
    final evidence = PendingRewardEvidence.fromJson(row['evidence'] as Map<String, dynamic>);
    return RewardReviewRecord.pending(evidence).recordServerOutcome({
      'account': evidence.accountId, 'evidence': evidence.id, 'kind': evidence.kind,
      'revision': evidence.policyRevision, 'fingerprint': evidence.fingerprint,
      'outcome': row['outcome'],
    });
  }
}

/// Authenticated adapter remains a separate integration. SDK callbacks and
/// local review records cannot be converted into wallet grants through this API.
abstract class RewardReviewBackend {
  Future<RewardReviewRecord> submit(PendingRewardEvidence evidence);
  Future<RewardReviewRecord> query(PendingRewardEvidence evidence);
}
