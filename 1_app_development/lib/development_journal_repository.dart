import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'development_purchase_journal.dart';

class JournalConflict implements Exception {
  const JournalConflict();
  @override
  String toString() => '구매 복구 기록이 변경되어 다시 읽어야 합니다.';
}

String _key(String account, String transaction) => jsonEncode([account, transaction]);

void _successor(PurchaseJournal? before, int? expectedSequence, PurchaseJournal next) {
  if (before?.sequence != expectedSequence) throw const JournalConflict();
  final encoded = jsonEncode(next.toJson());
  if (before == null) {
    final initial = PurchaseJournal.start(next.accountId, next.transactionId, next.quote);
    if (encoded != jsonEncode(initial.toJson())) throw const JournalConflict();
    return;
  }
  if (encoded == jsonEncode(before.toJson())) return;
  // Only one supported state transition, same identity and immutable quote.
  final receipt = {...before.toJson(), 'status': 'reserved'};
  final resultReceipt = {...receipt, 'receiptId': next.serverReceiptId,
      'grantId': next.serverGrantId};
  final transitions = <PurchaseJournal Function()>[
    () => before.recordReservation(receipt),
    () => before.recordDebit(),
    () => before.recordServerResult({...resultReceipt, 'status': 'committed'}),
    () => before.recordServerResult({...resultReceipt, 'status': 'canceled'}),
    () => before.recordApplication(),
    () => before.recordRestoration(),
  ];
  for (final transition in transitions) {
    try {
      if (encoded == jsonEncode(transition().toJson())) return;
    } on FormatException {
      // Ineligible transition; try the next explicit event.
    }
  }
  throw const JournalConflict();
}

abstract class PurchaseJournalRepository {
  Future<PurchaseJournal?> load(String account, String transaction);
  Future<List<PurchaseJournal>> listForAccount(String account, {bool unsettledOnly = true});
  Future<void> save(PurchaseJournal next, {required int? expectedSequence});
}

class MemoryPurchaseJournalRepository implements PurchaseJournalRepository {
  final _rows = <String, String>{};
  bool failNextSave = false;
  @override
  Future<PurchaseJournal?> load(String account, String transaction) async {
    final raw = _rows[_key(account, transaction)];
    return raw == null ? null : PurchaseJournal.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }
  @override
  Future<List<PurchaseJournal>> listForAccount(String account, {bool unsettledOnly = true}) async {
    final records = _rows.entries.where((entry) =>
        (jsonDecode(entry.key) as List).first == account).map((entry) =>
          PurchaseJournal.fromJson(jsonDecode(entry.value) as Map<String, dynamic>))
        .where((j) => !unsettledOnly || !j.settled).toList()
      ..sort((a, b) => a.transactionId.compareTo(b.transactionId));
    return List<PurchaseJournal>.unmodifiable(records);
  }
  @override
  Future<void> save(PurchaseJournal next, {required int? expectedSequence}) async {
    if (failNextSave) {
      failNextSave = false;
      throw Exception('의도된 거래 저장 실패');
    }
    final key = _key(next.accountId, next.transactionId), raw = _rows[_key(next.accountId, next.transactionId)];
    final before = raw == null ? null : PurchaseJournal.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    _successor(before, expectedSequence, next);
    _rows[key] = jsonEncode(next.toJson());
  }
}

/// Explicit opt-in table, separate from current/backup snapshot replacement.
/// NOT opened by app startup. Same database is not protection against app data
/// deletion or reinstall. A journal-only save never constitutes a wallet debit.
class SqlitePurchaseJournalRepository implements PurchaseJournalRepository {
  final Database database;
  SqlitePurchaseJournalRepository(this.database);

  Future<void> initialize() => database.execute('CREATE TABLE IF NOT EXISTS '
      'development_purchase_journal_v1 ('
      'account TEXT NOT NULL, transaction_id TEXT NOT NULL, '
      'body TEXT NOT NULL, PRIMARY KEY(account, transaction_id))');

  Future<PurchaseJournal?> _load(DatabaseExecutor executor,
      String account, String transaction) async {
    final rows = await executor.query('development_purchase_journal_v1',
        where: 'account = ? AND transaction_id = ?', whereArgs: [account, transaction]);
    if (rows.isEmpty) return null;
    final result = PurchaseJournal.fromJson(
        jsonDecode(rows.single['body'] as String) as Map<String, dynamic>);
    if (result.accountId != account || result.transactionId != transaction) {
      throw const FormatException('거래 저장 키 불일치');
    }
    return result;
  }

  @override
  Future<PurchaseJournal?> load(String account, String transaction) =>
      _load(database, account, transaction);

  @override
  Future<List<PurchaseJournal>> listForAccount(String account, {bool unsettledOnly = true}) async {
    final rows = await database.query('development_purchase_journal_v1',
        where: 'account = ?', whereArgs: [account], orderBy: 'transaction_id');
    final result = <PurchaseJournal>[];
    for (final row in rows) {
      final journal = PurchaseJournal.fromJson(
          jsonDecode(row['body'] as String) as Map<String, dynamic>);
      if (journal.accountId != account || journal.transactionId != row['transaction_id']) {
        throw const FormatException('거래 저장 키 불일치');
      }
      if (!unsettledOnly || !journal.settled) result.add(journal);
    }
    return List<PurchaseJournal>.unmodifiable(result);
  }

  /// Integrator must write the matching snapshot cost/item changes through
  /// THIS same transaction, or roll back both. No nested database calls.
  Future<void> writeInTransaction(Transaction tx, PurchaseJournal next,
      {required int? expectedSequence}) async {
    final before = await _load(tx, next.accountId, next.transactionId);
    _successor(before, expectedSequence, next);
    await tx.insert('development_purchase_journal_v1', {
      'account': next.accountId, 'transaction_id': next.transactionId,
      'body': jsonEncode(next.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> save(PurchaseJournal next, {required int? expectedSequence}) =>
      database.transaction((tx) => writeInTransaction(tx, next,
          expectedSequence: expectedSequence));
}
