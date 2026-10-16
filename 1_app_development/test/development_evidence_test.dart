import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_evidence.dart';
import 'package:todays_bungeoppang/development_rules.dart';

PendingRewardEvidence sale(String account, {int quantity = 1}) =>
    PendingRewardEvidence(accountId: account, id: 'sale-1', kind: 'sale',
        policyRevision: 'draft-1', payload: {'quantity': quantity, 'order': 'order-1'});

void main() {
  test('오프라인 증거는 같은 ID로 재시도하고 다른 내용은 거부한다', () {
    final item = sale('a');
    final outbox = RewardEvidenceOutbox.empty().enqueue(item);
    expect(outbox.enqueue(sale('a')), same(outbox));
    expect(() => outbox.enqueue(sale('a', quantity: 2)), throwsFormatException);
    expect(outbox.forAccount('b'), isEmpty);
    expect(outbox.enqueue(sale('b')).forAccount('b').length, 1);
    final restored = RewardEvidenceOutbox.fromJson(
        jsonDecode(jsonEncode(outbox.toJson())) as Map<String, dynamic>);
    expect(restored.forAccount('a').single.fingerprint, item.fingerprint);
    final duplicate = outbox.toJson();
    (duplicate['records'] as List).add(item.toJson());
    expect(() => RewardEvidenceOutbox.fromJson(duplicate), throwsFormatException);
  });

  test('증거 입력과 반환 JSON 수정이 저장된 내용에 영향을 주지 않는다', () {
    final payload = <String, dynamic>{'products': [{'id': 'batch-1', 'count': 1}]};
    final item = PendingRewardEvidence(accountId: 'a', id: 's', kind: 'sale',
        policyRevision: 'r', payload: payload);
    final before = item.fingerprint;
    (payload['products'] as List).clear();
    (item.toJson()['payload'] as Map).clear();
    expect(item.fingerprint, before);
    expect(() => PendingRewardEvidence(accountId: 'a', id: 's', kind: 'sale',
        policyRevision: 'r', payload: {'rating': 1.5}), throwsFormatException);
  });

  test('동일 의미의 증거 키 순서는 중복 충돌을 만들지 않는다', () {
    final first = PendingRewardEvidence(accountId: 'a', id: 's', kind: 'sale',
        policyRevision: 'r', payload: {'a': 1, 'b': {'x': 2, 'y': 3}});
    final second = PendingRewardEvidence(accountId: 'a', id: 's', kind: 'sale',
        policyRevision: 'r', payload: {'b': {'y': 3, 'x': 2}, 'a': 1});
    expect(first.fingerprint, second.fingerprint);
  });

  test('영수증은 계정·거래·버전·회차·수량·두 가격이 모두 일치해야 한다', () {
    final quote = CompositeQuote('r', 'tap_1', 2, 1, BigInt.from(20), BigInt.one);
    final receipt = <String, dynamic>{'account': 'a', 'transaction': 't',
      'revision': 'r', 'skill': 'tap_1', 'owned': 2, 'quantity': 1,
      'buns': '20', 'gold': '1', 'status': 'committed'};
    bool matches(Map<String, dynamic> row) => compositeReceiptMatches(quote,
        expectedAccountId: 'a', expectedTransactionId: 't', receipt: row);
    expect(matches(receipt), isTrue);
    for (final field in receipt.keys) {
      expect(matches({...receipt, field: null}), isFalse, reason: field);
    }
    expect(matches({...receipt, 'owned': 2.0}), isFalse);
    expect(matches({...receipt, 'gold': '01'}), isFalse);
  });

  test('숙련 상태 왕복과 재시도는 중복 진행을 만들지 않는다', () {
    const result = MasteryResult(id: 'p', flavor: 'redbean', variant: 4,
        completed: true, practice: true, techniquePassed: false);
    final progress = FlavorMasteryProgress(flavor: 'redbean', difficulty: 0).record(result);
    final restored = FlavorMasteryProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>);
    expect(restored.record(result), same(restored));
    expect(restored.practices, 1);
    expect(restored.techniquePasses, 0);
    expect(() => FlavorMasteryProgress.fromJson({...progress.toJson(), 'practices': 2}),
        throwsFormatException);
    expect(() => FlavorMasteryProgress.fromJson({...progress.toJson(),
        'practiceDiscovered': [4, 4]}), throwsFormatException);
    expect(() => FlavorMasteryProgress.fromJson({...progress.toJson(), 'results': {}}),
        throwsFormatException);
  });
  test('미당첨 심사 결과도 왕복 보존하고 재추첨·계정 변경을 거부한다', () {
    final evidence = sale('a');
    final pending = RewardReviewRecord.pending(evidence);
    final result = <String, dynamic>{'account': 'a', 'evidence': evidence.id,
      'kind': evidence.kind, 'revision': evidence.policyRevision,
      'fingerprint': evidence.fingerprint, 'outcome': 'noWin'};
    final reviewed = pending.recordServerOutcome(result);
    expect(reviewed.recordServerOutcome(result), same(reviewed));
    expect(() => reviewed.recordServerOutcome({...result, 'outcome': 'eligible'}), throwsFormatException);
    expect(() => pending.recordServerOutcome({...result, 'account': 'b'}), throwsFormatException);
    final restored = RewardReviewRecord.fromJson(
        jsonDecode(jsonEncode(reviewed.toJson())) as Map<String, dynamic>);
    expect(restored.outcome, 'noWin');
    expect(() => restored.recordServerOutcome({...result, 'outcome': 'pending'}), throwsFormatException);
  });

}
