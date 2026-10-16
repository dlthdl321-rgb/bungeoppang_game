import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/composite_purchase_coordinator.dart';
import 'package:todays_bungeoppang/development_journal_repository.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/development_rules.dart';

class Backend extends CompositePurchaseBackend {
  int reservations = 0, queries = 0, commits = 0;
  PurchaseJournal? intent;
  String status = 'reserved';
  Map<String, dynamic> response() => {...intent!.toJson(), 'status': status,
    'receiptId': ['committed', 'canceled'].contains(status) ? 'server-receipt' : '',
    'grantId': status == 'committed' ? 'server-grant' : ''};
  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal value) async {
    reservations++; intent = value; return response();
  }
  @override
  Future<Map<String, dynamic>> query(String accountId, String transactionId) async {
    queries++; return response();
  }
  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal debitEvidence) async {
    commits++; status = 'committed'; return response();
  }
  @override
  Future<Map<String, dynamic>> cancel(String accountId, String transactionId) async {
    status = 'canceled'; return response();
  }
}

void main() {
  PurchaseJournal intent() => PurchaseJournal.start('a', 'transaction-1',
      CompositeQuote('revision', 'tap_1', 0, 1, BigInt.from(15), BigInt.one));
  test('온라인·의도 내구 저장 전에는 서버 예약을 보내지 않는다', () async {
    final repo = MemoryPurchaseJournalRepository(), backend = Backend();
    final coordinator = CompositePurchaseCoordinator(repo, backend);
    await expectLater(coordinator.prepare(intent(), online: false), throwsStateError);
    repo.failNextSave = true;
    await expectLater(coordinator.prepare(intent(), online: true), throwsException);
    expect(backend.reservations, 0);
    expect(await repo.load('a', 'transaction-1'), isNull);
  });
  test('재시도는 같은 거래 조회이며 차감 근거 전 서버 소비는 없다', () async {
    final repo = MemoryPurchaseJournalRepository(), backend = Backend();
    final coordinator = CompositePurchaseCoordinator(repo, backend);
    var journal = await coordinator.prepare(intent(), online: true);
    journal = await coordinator.prepare(intent(), online: true);
    expect(backend.reservations, 1);
    expect(backend.queries, 1);
    await expectLater(coordinator.confirmDebit('a', 'transaction-1'), throwsFormatException);
    final debit = journal.recordDebit();
    await repo.save(debit, expectedSequence: journal.sequence);
    final committed = await coordinator.confirmDebit('a', 'transaction-1');
    expect(committed.serverStatus, 'committed');
    expect(committed.applied, isFalse);
    expect(backend.commits, 1);
  });
  test('결과 불명은 취소/복원으로 바꾸지 않는다', () async {
    final repo = MemoryPurchaseJournalRepository(), backend = Backend();
    final coordinator = CompositePurchaseCoordinator(repo, backend);
    final reserved = await coordinator.prepare(intent(), online: true);
    backend.status = 'unknown';
    final pending = await coordinator.refresh('a', 'transaction-1');
    expect(pending.toJson(), reserved.toJson());
    expect(pending.restored, isFalse);
  });
}
