// Avatar check sheets (26번 3차 피드백 H10): every avatar item the shop or
// the wardrobe can list, worn by the default vendor, for both characters and
// every skin tone, plus the combinations that touch each other (hair x hat,
// hair x accessory/tool, top x apron, bottom x shoes), drawn large by the
// game's own painter so each tile can be checked by eye.
//   flutter test tools/preview_avatar_check_test.dart
//   AVATAR_CHECK_TAG=before flutter test tools/preview_avatar_check_test.dart
// Writes build/avatar_check/<tag>/<sheet>.png. A tile on red is an item the
// shop and wardrobe do not list (PixelSprites.avatarArtReady false).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('아바타 점검 시트', timeout: const Timeout(Duration(minutes: 10)), () async {
    final jua = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
    await (FontLoader('Jua')..addFont(Future.value(jua))).load();
    await PixelSprites.load();
    final tag = Platform.environment['AVATAR_CHECK_TAG'] ?? 'now';
    final dir = 'build/avatar_check/$tag';
    List<String> ids(CosmeticSlot slot) => [
          for (final d in cosmeticDefinitions)
            if (d.slot == slot) d.id
        ];
    String name(String id) =>
        cosmeticDefinitions.firstWhere((d) => d.id == id).name;
    for (final c in ids(CosmeticSlot.character)) {
      // Close-up of the default vendor, every skin tone.
      await _sheet('$dir/${c}_0_default.png', '$c 기본 차림 (확대)', [
        for (final s in ids(CosmeticSlot.skin))
          _Tile(c, {CosmeticSlot.skin: s}, s),
      ], cols: 3, tileW: 300);
      for (final s in ids(CosmeticSlot.skin)) {
        final items = [
          for (final d in cosmeticDefinitions)
            if (d.slot.category == CosmeticCategory.avatar &&
                d.slot != CosmeticSlot.character &&
                d.slot != CosmeticSlot.skin)
              d
        ];
        await _sheet('$dir/${c}_1_items_$s.png',
            '$c / $s — 아이템 하나씩 (빨강 = 상점·꾸미기에 안 나옴)', [
          for (final d in items)
            _Tile(c, {CosmeticSlot.skin: s, d.slot: d.id},
                '${cosmeticSlotLabel(d.slot)} ${d.name}'),
        ]);
      }
      Future<void> matrix(String file, String title, CosmeticSlot rows,
          CosmeticSlot cols) {
        // The longer list runs down, so a row fits on one screen.
        if (ids(rows).length < ids(cols).length) {
          (rows, cols) = (cols, rows);
        }
        final r = ids(rows), k = ids(cols);
        return _sheet('$dir/$file', title, [
          for (final a in r)
            for (final b in k)
              _Tile(c, {rows: a, cols: b}, '${name(a)}+${name(b)}'),
        ], cols: k.length);
      }

      await matrix('${c}_2_hair_hat.png', '$c 머리 × 모자', CosmeticSlot.hair,
          CosmeticSlot.hat);
      await matrix('${c}_3_hair_acc.png', '$c 머리 × 소품', CosmeticSlot.hair,
          CosmeticSlot.accessory);
      await matrix('${c}_4_hair_tool.png', '$c 머리 × 도구', CosmeticSlot.hair,
          CosmeticSlot.tool);
      await matrix('${c}_5_hair_apron.png', '$c 머리 × 앞치마',
          CosmeticSlot.hair, CosmeticSlot.outfit);
      await matrix('${c}_6_top_apron.png', '$c 상의 × 앞치마', CosmeticSlot.top,
          CosmeticSlot.outfit);
      await matrix('${c}_7_bottom_shoes.png', '$c 하의 × 신발',
          CosmeticSlot.bottom, CosmeticSlot.shoes);
      await matrix('${c}_8_bottom_apron.png', '$c 하의 × 앞치마',
          CosmeticSlot.bottom, CosmeticSlot.outfit);
    }
  });
}

class _Tile {
  final String character, label;
  final Map<CosmeticSlot, String> worn;
  const _Tile(this.character, this.worn, this.label);

  bool get listed => worn.entries.every((e) =>
      PixelSprites.avatarArtReady(character, e.key, e.value));
}

void _label(Canvas canvas, String text, Offset at, double width,
    {Color color = const Color(0xFF2B1D16), double size = 13}) {
  final p = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Jua', fontSize: size, color: color)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2)
    ..layout(minWidth: width, maxWidth: width);
  p.paint(canvas, at);
}

Future<void> _sheet(String path, String title, List<_Tile> tiles,
    {int cols = 8, double tileW = 200}) async {
  final tileH = tileW * 104 / 56 + 34;
  final rows = (tiles.length / cols).ceil();
  final width = cols * tileW, height = 32 + rows * tileH;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF3EEE6));
  _label(canvas, title, const Offset(0, 6), width, size: 18);
  for (var i = 0; i < tiles.length; i++) {
    final t = tiles[i];
    final at = Offset((i % cols) * tileW, 32 + (i ~/ cols) * tileH);
    canvas.drawRect(
        Rect.fromLTWH(at.dx + 2, at.dy + 2, tileW - 4, tileH - 4),
        Paint()
          ..color =
              t.listed ? const Color(0xFFB9C7B0) : const Color(0xFFD9A49C));
    canvas.save();
    canvas.translate(at.dx + 4, at.dy + 4);
    AvatarPainter(AvatarLook.of((s) => s == CosmeticSlot.character
            ? t.character
            : t.worn[s] ?? defaultCosmetics[s]!))
        .paint(canvas, Size(tileW - 8, tileH - 40));
    canvas.restore();
    _label(canvas, t.label, Offset(at.dx + 2, at.dy + tileH - 34), tileW - 4,
        size: tileW < 200 ? 12 : 15);
  }
  final image =
      await recorder.endRecording().toImage(width.ceil(), height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File(path);
  await out.parent.create(recursive: true);
  await out.writeAsBytes(bytes!.buffer.asUint8List());
}
