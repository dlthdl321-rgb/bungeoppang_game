import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'owner_profile.dart';

/// Where the first-run answers live (26번 2-1단계). One JSON row in its own
/// database file, so the game saves keep their formats.
abstract class OwnerProfileRepository {
  /// Null on a new install. A damaged row also reads as null: the first-run
  /// questions are simply asked again (the game progress is elsewhere).
  Future<OwnerProfile?> load();
  Future<void> save(OwnerProfile profile);
  /// Forgets everything (account deletion).
  Future<void> clear();
}

class MemoryOwnerProfileRepository implements OwnerProfileRepository {
  Map<String, dynamic>? stored;
  int saves = 0;
  MemoryOwnerProfileRepository([OwnerProfile? initial])
      : stored = initial == null ? null : _copy(initial);
  static Map<String, dynamic> _copy(OwnerProfile p) =>
      jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  @override
  Future<OwnerProfile?> load() async {
    final row = stored;
    if (row == null) return null;
    try {
      return OwnerProfile.fromJson(row);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(OwnerProfile profile) async {
    saves++;
    stored = _copy(profile);
  }

  @override
  Future<void> clear() async => stored = null;
}

class SqliteOwnerProfileRepository implements OwnerProfileRepository {
  Database? _db;
  static Future<String> defaultPath() async =>
      path.join(await getDatabasesPath(), 'todays_bungeoppang_owner.db');

  Future<Database> get _database async => _db ??= await openDatabase(await defaultPath(),
      version: 1,
      onCreate: (d, _) => d.execute('CREATE TABLE owner(id INTEGER PRIMARY KEY, body TEXT NOT NULL)'));

  Future<void> close() async {
    final d = _db;
    _db = null;
    await d?.close();
  }

  @override
  Future<OwnerProfile?> load() async {
    final rows = await (await _database).query('owner', where: 'id = 1');
    if (rows.isEmpty) return null;
    try {
      return OwnerProfile.fromJson(jsonDecode(rows.first['body'] as String) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(OwnerProfile profile) async => (await _database).insert(
      'owner', {'id': 1, 'body': jsonEncode(profile.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> clear() async => (await _database).delete('owner');
}
