import 'dart:convert';
import 'dart:math' as math;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

abstract class GameRepository {
  Future<GameState?> load();
  Future<void> save(GameState state);
  Future<GameState?> recover();

  /// Makes the backup snapshot current, numbered above the (possibly
  /// damaged) current row so later saves are not discarded as stale.
  /// Returns false without a backup; throws [FormatException] if it is damaged.
  Future<bool> restoreBackup();
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
  Future<bool> restoreBackup() async {
    final b = backup;
    if (b == null) return false;
    if (failNextSave) {
      failNextSave = false;
      throw Exception('의도된 저장 실패');
    }
    current = b.copy()
      ..snapshotSequence =
          math.max(b.snapshotSequence, current?.snapshotSequence ?? 0) + 1;
    return true;
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
  Future<bool> restoreBackup() async => (await db).transaction((tx) async {
        final rows = {
          for (final r in await tx.query('snapshots')) r['slot']: r
        };
        final backup = rows['backup'];
        if (backup == null) return false;
        final restored = _decode(backup['body'] as String);
        restored.snapshotSequence = math.max(backup['sequence'] as int,
                rows['current']?['sequence'] as int? ?? 0) +
            1;
        await tx.insert(
            'snapshots',
            {
              'slot': 'current',
              'sequence': restored.snapshotSequence,
              'body': jsonEncode(restored.toJson())
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      });

  @override
  Future<void> clear() async => (await db).delete('snapshots');
}
