part of 'workshop_controller.dart';

abstract class WorkshopRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> next, int expectedSequence);
}
String _workshopGuard(Map<String,dynamic> row) => jsonEncode((row['schema'] as int)>=3 ? {
  'purchases':row['purchases'],'rewardAccount':row['rewardAccount'],
  'rewardReceipts':row['rewardReceipts'],'adAttempts':row['adAttempts'],
  'missionClaims':(row['missions'] as Map<String,dynamic>)['claims'],
  if(row['schema']==4) 'relationships':row['relationships'],
  if(row['schema']==4) 'customerScene':row['customerScene']} : row['purchases']);
/// Optional port: freeze a complete production transaction before applying it.
abstract interface class WorkshopProductionJournal {
  Future<void> stageProduction(Map<String, dynamic> next, int expectedSequence);
}
class SqliteWorkshopRepository implements WorkshopRepository, WorkshopProductionJournal {
  Database? _database;
  SqliteWorkshopRepository();
  /// Inject an already opened database for storage integration tests.
  SqliteWorkshopRepository.withDatabase(Database database) : _database = database;

  Future<Database> get database async {
    final db = _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'todays_bungeoppang_workshop.db'), version: 4,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
      await db.execute('CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    },
    onUpgrade: (db, old, next) async {
      if (old < 2) await db.execute('CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    });
    await db.execute('CREATE TABLE IF NOT EXISTS production_journal(id INTEGER PRIMARY KEY, expected_sequence INTEGER NOT NULL, base_body TEXT NOT NULL, body TEXT NOT NULL)');
    return db;
  }
  @override
  Future<Map<String, dynamic>?> load() => loadValidated((_) {});

  /// Repair only the latest fully witnessed checkpoint. Historical `backup`
  /// can precede a debit, sale or receipt and must never be replayed.
  Future<Map<String, dynamic>?> loadValidated(
      void Function(Map<String, dynamic>) validate) async {
    final checkpoint = await (await database).transaction((tx) async {
      final rows = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      final guards = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [1]);
      final witnesses = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [2]);
      Map<String, dynamic> decode(Map<String, Object?> record) {
        final body = jsonDecode(record['body'] as String) as Map<String, dynamic>;
        if (body['sequence'] != record['sequence'] ||
            ([2,3,4].contains(body['schema']) &&
                (guards.isEmpty || guards.single['body'] != _workshopGuard(body))) ||
            (body['schema'] == 1 && guards.isNotEmpty) ||
            (witnesses.isNotEmpty && witnesses.single['body'] != record['body'])) {
          throw const FormatException('저장 보호 기록 재대조가 필요해요.');
        }
        validate(body);
        return body;
      }
      if (rows.isNotEmpty) {
        try { return decode(rows.single); }
        on FormatException { /* Try only a matching latest checkpoint. */ }
        on TypeError { /* A malformed JSON shape is damaged too. */ }
      } else if (guards.isEmpty && witnesses.isEmpty) {
        final existing = await tx.query('snapshots', limit: 1);
        if (existing.isEmpty) return null;
        throw const FormatException('현재 저장이 누락됐어요. 초기화하지 않아요.');
      }
      if (witnesses.isEmpty) throw const FormatException('최신 복구 근거가 없어요. 저장을 보존해 주세요.');
      final recovery = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['recovery']);
      if (recovery.isEmpty) throw const FormatException('최신 복구 기록이 없어요.');
      if (rows.isNotEmpty && rows.single['sequence'] is int &&
          recovery.single['sequence'] is int &&
          (rows.single['sequence'] as int) > (recovery.single['sequence'] as int)) {
        throw const FormatException('현재 저장보다 오래된 복구 사본은 적용하지 않아요.');
      }
      final recovered = decode(recovery.single);
      await tx.insert('snapshots', {...recovery.single, 'slot': 'current'},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return recovered;
    });
    final attempts = await (await database).query('production_journal', where: 'id = ?', whereArgs: [1]);
    if (attempts.isEmpty) return checkpoint;
    final attempt = attempts.single;
    final candidate = jsonDecode(attempt['body'] as String) as Map<String, dynamic>;
    validate(candidate);
    if (checkpoint != null && jsonEncode(checkpoint) == attempt['body']) {
      await (await database).delete('production_journal', where: 'id = ? AND body = ?', whereArgs: [1, attempt['body']]);
      return checkpoint;
    }
    if (checkpoint == null || checkpoint['sequence'] != attempt['expected_sequence'] ||
        jsonEncode(checkpoint) != attempt['base_body'] ||
        candidate['sequence'] != (attempt['expected_sequence'] as int) + 1) {
      throw const FormatException('제작 저널의 기준 저장이 일치하지 않아요.');
    }
    await save(candidate, attempt['expected_sequence'] as int);
    return candidate;
  }
  @override
  Future<void> stageProduction(Map<String, dynamic> next, int expectedSequence) async {
    await (await database).transaction((tx) async {
      final rows = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      if (rows.length != 1 || rows.single['sequence'] != expectedSequence || next['sequence'] != expectedSequence + 1) {
        throw const FormatException('제작 확정 순번 충돌');
      }
      final body = jsonEncode(next);
      final pending = await tx.query('production_journal', where: 'id = ?', whereArgs: [1]);
      if (pending.isNotEmpty && pending.single['body'] != body) {
        throw const FormatException('먼저 이전 제작 결과를 복구해 주세요.');
      }
      await tx.insert('production_journal', {'id': 1, 'expected_sequence': expectedSequence,
        'base_body': rows.single['body'], 'body': body}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    await (await database).transaction((tx) async {
      final current = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      final guards = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [1]);
      if (current.isEmpty && guards.isNotEmpty) {
        throw const FormatException('구매 보호 기록만 남은 상태');
      }
      if (current.isNotEmpty) {
        final body = jsonDecode(current.single['body'] as String) as Map<String, dynamic>;
        if (body['sequence'] != current.single['sequence'] ||
            ([2,3,4].contains(body['schema']) && (guards.isEmpty || guards.single['body'] != _workshopGuard(body))) ||
            (body['schema'] == 1 && guards.isNotEmpty)) throw const FormatException('구매 보호 기록 충돌');
      }
      final oldSequence = current.isEmpty ? 0 : current.single['sequence'];
      if (oldSequence != expectedSequence || next['sequence'] != expectedSequence + 1) {
        throw const FormatException('진행 저장 순번 충돌');
      }
      final witnesses = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [2]);
      if (witnesses.isNotEmpty && (current.isEmpty || witnesses.single['body'] != current.single['body'])) {
        throw const FormatException('최신 저장 증거 충돌');
      }
      if (next['schema'] != 4 || next['purchases'] is! Map<String, dynamic>) throw const FormatException('구매 보호 저장 형식 오류');
      final encoded = jsonEncode(next);
      final pending = await tx.query('production_journal', where: 'id = ?', whereArgs: [1]);
      if (pending.isNotEmpty && (pending.single['body'] != encoded ||
          pending.single['expected_sequence'] != expectedSequence ||
          current.isEmpty || pending.single['base_body'] != current.single['body'])) {
        throw const FormatException('먼저 고정된 제작 결과를 복구해 주세요.');
      }
      await tx.insert('purchase_guard', {'id': 2, 'body': encoded}, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('snapshots', {'slot': 'recovery', 'sequence': next['sequence'], 'body': encoded}, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('purchase_guard', {'id': 1, 'body': _workshopGuard(next)}, conflictAlgorithm: ConflictAlgorithm.replace);
      if (current.isNotEmpty) await tx.insert('snapshots', {...current.single, 'slot': 'backup'}, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('snapshots', {'slot': 'current', 'sequence': next['sequence'], 'body': encoded},
          conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.delete('production_journal', where: 'id = ? AND body = ?', whereArgs: [1, encoded]);
    });
  }
}
