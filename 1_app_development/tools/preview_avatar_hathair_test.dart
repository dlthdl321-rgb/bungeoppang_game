// Hat x hair close-ups (26번 3차 AV3): the head of the v2 vendor, large, for
// every hat with every hair style and skin tone, beside the v1 vendor
// wearing the same hat (the size the hat should look), and every hair with
// the accessories worn on the head (glasses, ribbon, hairpin, scarf).
//   AVATAR_CHECK_TAG=x flutter test tools/preview_avatar_hathair_test.dart
// Writes build/avatar_check/<tag>/hathair/<character>_<hat|acc>.png.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

// The head on the 56x104 look (art 280x520 / 5): x 6..50, y 3..53.
const _crop = Rect.fromLTWH(6, 3, 44, 50);
const _zoom = 8.0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('모자 x 머리 확대', timeout: const Timeout(Duration(minutes: 10)), () async {
    final jua = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
    await (FontLoader('Jua')..addFont(Future.value(jua))).load();
    await PixelSprites.load();
    final tag = Platform.environment['AVATAR_CHECK_TAG'] ?? 'now';
    final dir = 'build/avatar_check/$tag/hathair';
    List<String> ids(CosmeticSlot slot) => [
          for (final d in cosmeticDefinitions)
            if (d.slot == slot) d.id
        ];
    final hairs = ids(CosmeticSlot.hair);
    final skins = ids(CosmeticSlot.skin);
    for (final c in ids(CosmeticSlot.character)) {
      for (final hat in ids(CosmeticSlot.hat)) {
        await _sheet('$dir/${c}_hat_$hat.png', '$c 모자 $hat — 위 줄 v1, 아래 v2 skin1~3', [
          for (final h in hairs)
            _Tile(c, {CosmeticSlot.hair: h, CosmeticSlot.hat: hat}, 'v1 $h',
                v1: true),
          for (final s in skins)
            for (final h in hairs)
              _Tile(
                  c,
                  {
                    CosmeticSlot.hair: h,
                    CosmeticSlot.hat: hat,
                    CosmeticSlot.skin: s
                  },
                  '$h $s'),
        ], cols: hairs.length);
      }
      for (final acc in ['ribbon', 'fishpin', 'glasses', 'scarf']) {
        await _sheet('$dir/${c}_acc_$acc.png', '$c 소품 $acc — 위 줄 v1', [
          for (final h in hairs)
            _Tile(c, {CosmeticSlot.hair: h, CosmeticSlot.accessory: acc},
                'v1 $h',
                v1: true),
          for (final s in skins)
            for (final h in hairs)
              _Tile(
                  c,
                  {
                    CosmeticSlot.hair: h,
                    CosmeticSlot.accessory: acc,
                    CosmeticSlot.skin: s
                  },
                  '$h $s'),
        ], cols: hairs.length);
      }
    }
  });
}

class _Tile {
  final String character, label;
  final Map<CosmeticSlot, String> worn;
  final bool v1;
  const _Tile(this.character, this.worn, this.label, {this.v1 = false});
}

Future<void> _sheet(String path, String title, List<_Tile> tiles,
    {required int cols}) async {
  final tileW = _crop.width * _zoom, tileH = _crop.height * _zoom + 26;
  final rows = (tiles.length / cols).ceil();
  final width = cols * tileW, height = 30 + rows * tileH;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFF3EEE6));
  _label(canvas, title, const Offset(0, 4), width, 18);
  for (var i = 0; i < tiles.length; i++) {
    final t = tiles[i];
    final at = Offset((i % cols) * tileW, 30 + (i ~/ cols) * tileH);
    canvas.drawRect(Rect.fromLTWH(at.dx + 2, at.dy + 2, tileW - 4, tileH - 4),
        Paint()..color = t.v1 ? const Color(0xFFD8D0E6) : const Color(0xFFB9C7B0));
    // ignore: invalid_use_of_visible_for_testing_member
    debugAvatarV2Override = !t.v1;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(at.dx, at.dy, tileW, tileH - 26));
    canvas.translate(at.dx, at.dy);
    canvas.scale(_zoom);
    canvas.translate(-_crop.left, -_crop.top);
    AvatarLook.of((s) => s == CosmeticSlot.character
        ? t.character
        : t.worn[s] ?? defaultAvatarItem(s, t.character)).paint(
        canvas, Offset.zero);
    canvas.restore();
    _label(canvas, t.label, Offset(at.dx, at.dy + tileH - 24), tileW, 15);
  }
  // ignore: invalid_use_of_visible_for_testing_member
  debugAvatarV2Override = null;
  final image =
      await recorder.endRecording().toImage(width.ceil(), height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File(path);
  await out.parent.create(recursive: true);
  await out.writeAsBytes(bytes!.buffer.asUint8List());
}

void _label(Canvas canvas, String text, Offset at, double width, double size) {
  final p = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontFamily: 'Jua', fontSize: size, color: const Color(0xFF2B1D16))),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1)
    ..layout(minWidth: width, maxWidth: width);
  p.paint(canvas, at);
}
