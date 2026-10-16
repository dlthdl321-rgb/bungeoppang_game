import 'dart:convert';
import 'development_journal_repository.dart';
import 'development_purchase_journal.dart';

/// Network orchestration only. Local cost/item/refund commands are deliberately
/// performed by the atomic snapshot integration, never by this coordinator.
class CompositePurchaseCoordinator {
  final PurchaseJournalRepository repository;
  final CompositePurchaseBackend backend;
  CompositePurchaseCoordinator(this.repository, this.backend);

  Future<PurchaseJournal> prepare(PurchaseJournal intent, {required bool online}) async {
    if (!online) throw StateError('복합 구매는 연결 후 이용할 수 있어요.');
    if (intent.sequence != 0) throw const FormatException('신규 구매 의도가 아님');
    var saved = await repository.load(intent.accountId, intent.transactionId);
    if (saved == null) {
      await repository.save(intent, expectedSequence: null);
      saved = intent;
    } else {
      final original = PurchaseJournal.start(saved.accountId, saved.transactionId, saved.quote);
      if (jsonEncode(original.toJson()) != jsonEncode(intent.toJson())) {
        throw const JournalConflict();
      }
      // An existing transaction is recovered by query, not a new reservation.
      return refresh(saved.accountId, saved.transactionId);
    }
    return _record(saved, await backend.reserve(saved));
  }

  Future<PurchaseJournal> refresh(String account, String transaction) async {
    final saved = await _load(account, transaction);
    return _record(saved, await backend.query(account, transaction));
  }

  /// Only after the actual local debit AND journal were atomically persisted.
  Future<PurchaseJournal> confirmDebit(String account, String transaction) async {
    final saved = await _load(account, transaction);
    if (!saved.debited || saved.serverStatus != 'reserved') {
      throw const FormatException('서버 확정을 요청할 차감 근거 없음');
    }
    return _record(saved, await backend.commit(saved));
  }

  Future<PurchaseJournal> requestCancellation(String account, String transaction) async {
    final saved = await _load(account, transaction);
    if (saved.serverStatus == 'committed' || saved.serverStatus == 'canceled') {
      return saved;
    }
    return _record(saved, await backend.cancel(account, transaction));
  }

  Future<PurchaseJournal> _load(String account, String transaction) async {
    final saved = await repository.load(account, transaction);
    if (saved == null) throw const FormatException('복구할 구매 기록 없음');
    return saved;
  }

  Future<PurchaseJournal> _record(PurchaseJournal saved, Map<String, dynamic> response) async {
    if (response['account'] != saved.accountId || response['transaction'] != saved.transactionId) {
      throw const FormatException('다른 계정/거래의 구매 응답');
    }
    final status = response['status'];
    if (status == 'unknown') return saved; // Not cancellation, no refund.
    final next = status == 'reserved' ? saved.recordReservation(response)
        : saved.recordServerResult(response);
    if (!identical(saved, next)) {
      await repository.save(next, expectedSequence: saved.sequence);
    }
    return next;
  }
}
