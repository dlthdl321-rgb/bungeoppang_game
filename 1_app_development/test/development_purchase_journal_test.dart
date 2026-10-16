import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/development_journal_repository.dart';

PurchaseJournal intent() => PurchaseJournal.start('account-a', 'transaction-a',
    CompositeQuote('draft', 'tap_1', 0, 1, BigInt.from(15), BigInt.one));
Map<String, dynamic> receipt(PurchaseJournal journal, String status) =>
    {...journal.toJson(), 'status': status,
      'receiptId': ['committed', 'canceled'].contains(status) ? 'receipt-$status' : '',
      'grantId': status == 'committed' ? 'grant-1' : ''};

void main() {
  test('확정 후 저장 실패를 같은 ID로 재시도하고 지급은1회다', () async {
    final repo = MemoryPurchaseJournalRepository();
    var journal = intent();
    await repo.save(journal, expectedSequence: null);
    for (final event in <PurchaseJournal Function(PurchaseJournal)>[
      (j) => j.recordReservation(receipt(j, 'reserved')),
      (j) => j.recordDebit(),
      (j) => j.recordServerResult(receipt(j, 'committed')),
    ]) {
      final next = event(journal);
      await repo.save(next, expectedSequence: journal.sequence);
      journal = next;
    }
    repo.failNextSave = true;
    final applied = journal.recordApplication();
    await expectLater(repo.save(applied, expectedSequence: journal.sequence), throwsException);
    final recovered = (await repo.load(journal.accountId, journal.transactionId))!;
    expect(recovered.applied, isFalse);
    await repo.save(recovered.recordApplication(), expectedSequence: recovered.sequence);
    final stored = (await repo.load(journal.accountId, journal.transactionId))!;
    expect(stored.settled, isTrue);
    expect(stored.serverReceiptId, 'receipt-committed');
    expect(stored.serverGrantId, 'grant-1');
    expect(() => stored.recordServerResult({...receipt(stored, 'committed'),
        'grantId': 'changed-grant'}), throwsFormatException);
    expect(stored.recordApplication(), same(stored));
  });

  test('최종 취소 근거와 차감 기록이 있어야1회 복원한다', () {
    var j = intent();
    expect(() => j.recordDebit(), throwsFormatException);
    expect(() => j.recordRestoration(), throwsFormatException);
    j = j.recordReservation(receipt(j, 'reserved')).recordDebit();
    expect(() => j.recordRestoration(), throwsFormatException);
    j = j.recordServerResult(receipt(j, 'canceled'));
    final restored = j.recordRestoration();
    expect(restored.recordRestoration(), same(restored));
    expect(restored.settled, isTrue);
    expect(() => restored.recordServerResult(receipt(restored, 'committed')), throwsFormatException);
  });

  test('차감 증거 없는 committed는 지급하지 않고 복구 대기한다', () {
    final j = intent();
    final result = j.recordServerResult(receipt(j, 'committed'));
    expect(result.settled, isFalse);
    expect(() => result.recordApplication(), throwsFormatException);
    expect(() => result.recordDebit(), throwsFormatException);
  });

  test('견적 변경·계정 바꿔치기·손상 플래그를 거부한다', () {
    final j = intent();
    for (final key in ['account', 'transaction', 'revision', 'skill', 'owned', 'quantity', 'buns', 'gold']) {
      expect(() => j.recordReservation({...receipt(j, 'reserved'), key: null}), throwsFormatException);
    }
    expect(() => PurchaseJournal.fromJson({...j.toJson(), 'debited': true}), throwsFormatException);
    expect(() => PurchaseJournal.fromJson({...j.toJson(), 'sequence': 1}), throwsFormatException);
    final roundtrip = PurchaseJournal.fromJson(jsonDecode(jsonEncode(j.toJson())) as Map<String, dynamic>);
    expect(roundtrip.toJson(), j.toJson());
  });

  test('경합 저장·상태 건너뛰기·견적 교체를 CAS가 거부한다', () async {
    final repo = MemoryPurchaseJournalRepository();
    final j = intent();
    await repo.save(j, expectedSequence: null);
    final reserved = j.recordReservation(receipt(j, 'reserved'));
    await repo.save(reserved, expectedSequence: 0);
    await expectLater(repo.save(j, expectedSequence: 0), throwsA(isA<JournalConflict>()));
    await expectLater(repo.save(reserved.recordDebit().recordServerResult(
        receipt(reserved, 'committed')), expectedSequence: 1), throwsA(isA<JournalConflict>()));
    final changed = PurchaseJournal.fromJson({...reserved.toJson(), 'buns': '16'});
    await expectLater(repo.save(changed, expectedSequence: 1), throwsA(isA<JournalConflict>()));
  });
  test('재시작 조회는 계정별 미정산 거래를 찾고 예약분을 가용액에서 뺀다', () async {
    final repo = MemoryPurchaseJournalRepository();
    final j = intent();
    await repo.save(j, expectedSequence: null);
    final other = PurchaseJournal.start('account-b', 'other-id', j.quote);
    await repo.save(other, expectedSequence: null);
    final pending = await repo.listForAccount('account-a');
    expect(pending.length, 1);
    expect(availableBunsAfterReservations(BigInt.from(20), 'account-a', pending), BigInt.from(5));
    expect(() => availableBunsAfterReservations(BigInt.from(14), 'account-a', pending), throwsFormatException);
    expect(() => availableBunsAfterReservations(BigInt.from(30), 'account-a', [j, j]), throwsFormatException);
    final canceled = j.recordServerResult(receipt(j, 'canceled'));
    await repo.save(canceled, expectedSequence: 0);
    expect(await repo.listForAccount('account-a'), isEmpty);
    expect((await repo.listForAccount('account-a', unsettledOnly: false)).length, 1);
  });

}
