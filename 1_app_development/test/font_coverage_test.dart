import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

/// Code points a TrueType/OpenType font maps (cmap formats 4 and 12).
Set<int> fontCodePoints(String path) {
  final data = ByteData.sublistView(File(path).readAsBytesSync());
  final tables = data.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < tables; i++) {
    final record = 12 + i * 16;
    if (String.fromCharCodes([for (var j = 0; j < 4; j++) data.getUint8(record + j)]) == 'cmap') {
      cmap = data.getUint32(record + 8);
    }
  }
  if (cmap < 0) throw FormatException('no cmap in $path');
  final points = <int>{};
  for (var i = 0; i < data.getUint16(cmap + 2); i++) {
    final platform = data.getUint16(cmap + 4 + i * 8), encoding = data.getUint16(cmap + 6 + i * 8);
    if (platform != 3 && platform != 0) continue;
    if (platform == 3 && encoding != 1 && encoding != 10) continue;
    final table = cmap + data.getUint32(cmap + 8 + i * 8);
    switch (data.getUint16(table)) {
      case 4:
        final segments = data.getUint16(table + 6) ~/ 2;
        final ends = table + 14, starts = ends + segments * 2 + 2;
        final deltas = starts + segments * 2, offsets = deltas + segments * 2;
        for (var s = 0; s < segments; s++) {
          final end = data.getUint16(ends + s * 2), start = data.getUint16(starts + s * 2);
          final delta = data.getUint16(deltas + s * 2), offset = data.getUint16(offsets + s * 2);
          for (var c = start; c <= end && c != 0xffff; c++) {
            final glyph = offset == 0
                ? (c + delta) & 0xffff
                : data.getUint16(offsets + s * 2 + offset + (c - start) * 2);
            if (glyph != 0) points.add(c);
          }
        }
      case 12:
        final groups = data.getUint32(table + 12);
        for (var g = 0; g < groups; g++) {
          final start = data.getUint32(table + 16 + g * 12), end = data.getUint32(table + 20 + g * 12);
          for (var c = start; c <= end; c++) {
            points.add(c);
          }
        }
    }
  }
  return points;
}

/// 5단계: 화면 글자는 Jua 또는 기호 대체 글꼴(BungeoSymbols)에 모두 있어야 한다.
/// 없는 글자는 기기에 따라 □로 보인다.
void main() {
  test('앱 문구의 모든 글자가 Jua 또는 BungeoSymbols에 있다', () {
    final jua = fontCodePoints('assets/fonts/Jua-Regular.ttf');
    final symbols = fontCodePoints('assets/fonts/BungeoSymbols-Regular.ttf');
    // Sanity: the parser read real tables.
    expect(jua.contains('가'.codeUnitAt(0)), isTrue);
    expect(symbols.contains(0x00b7), isTrue);
    final missing = <String, Set<String>>{};
    final files = [
      ...Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
      File('config/development_balance.json'),
    ];
    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//')) continue;
        for (final rune in line.runes) {
          if (rune < 0x80 || jua.contains(rune) || symbols.contains(rune)) continue;
          (missing[String.fromCharCode(rune)] ??= {}).add(file.path.replaceAll('\\', '/'));
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'tools/build_symbol_font.py의 RANGES에 넣거나 문구를 바꾸세요');
  });
}
