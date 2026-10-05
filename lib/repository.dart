import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

abstract class GameRepository {
  Future<GameState?> load();
  Future<void> save(GameState state);
  Future<GameState?> recover();
  Future<void> clear();
}

class MemoryGameRepository implements GameRepository {
  GameState? current, backup;
  bool failNextSave = false;
  @override
  Future<GameState?> load() async => current?.copy();
  @override
  Future<GameState?> recover() async => backup?.copy();
  @override
  Future<void> save(GameState state) async {
    if (failNextSave) {
      failNextSave = false;
      throw Exception('의도된 저장 실패');
    }
    if (current != null &&
        state.snapshotSequence <= current!.snapshotSequence) {
      return;
    }
    backup = current?.copy();
    current = state.copy();
  }

  @override
  Future<void> clear() async {
    current = null;
    backup = null;
  }
}

class SqliteGameRepository implements GameRepository {
  Database? _db;
  Future<Database> get db async => _db ??= await openDatabase(
      join(await getDatabasesPath(), 'todays_bungeoppang.db'),
      version: 1,
      onCreate: (d, _) => d.execute(
          'CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)'));
  GameState _decode(String body) =>
      GameState.fromJson(jsonDecode(body) as Map<String, dynamic>);
  @override
  Future<GameState?> load() async {
    final rows = await (await db)
        .query('snapshots', where: 'slot = ?', whereArgs: ['current']);
    return rows.isEmpty ? null : _decode(rows.first['body'] as String);
  }

  @override
  Future<GameState?> recover() async {
    final rows = await (await db)
        .query('snapshots', where: 'slot = ?', whereArgs: ['backup']);
    return rows.isEmpty ? null : _decode(rows.first['body'] as String);
  }

  @override
  Future<void> save(GameState state) async {
    final d = await db;
    await d.transaction((tx) async {
      final old = await tx
          .query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      if (old.isNotEmpty &&
          (old.first['sequence'] as int) >= state.snapshotSequence) {
        return;
      }
      if (old.isNotEmpty) {
        await tx.insert(
            'snapshots',
            {
              'slot': 'backup',
              'sequence': old.first['sequence'],
              'body': old.first['body']
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await tx.insert(
          'snapshots',
          {
            'slot': 'current',
            'sequence': state.snapshotSequence,
            'body': jsonEncode(state.toJson())
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<void> clear() async => (await db).delete('snapshots');
}
