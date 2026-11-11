import 'dart:io';

/// Moves a damaged SQLite database, with its `-wal`/`-shm`/`-journal` files,
/// aside under a dated name instead of deleting it. The database must be
/// closed first. Returns the new path, or null when there was no file.
Future<String?> setAsideDatabaseFile(String path, DateTime now) async {
  if (!await File(path).exists()) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final base = path.endsWith('.db') ? path.substring(0, path.length - 3) : path;
  var target = '$base.damaged-$stamp.db';
  for (var n = 2; await File(target).exists(); n++) {
    target = '$base.damaged-$stamp-$n.db';
  }
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.rename('$target$suffix');
  }
  return target;
}
