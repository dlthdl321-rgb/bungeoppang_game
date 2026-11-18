// ignore_for_file: invalid_use_of_visible_for_testing_member
// 26번 4-7단계 checking pictures (not a test of behaviour):
//   flutter test tools/preview_avatar_v2_test.dart
// Writes to build/avatar_v2/:
//   render_<girl|boy>.png  the default vendor as the game draws it, one
//                          canvas pixel per rig pixel (280x520), for
//                          `python tools/avatar_v2.py faceaudit` (G3);
//   skin_tones.png         skin1~3, girl and boy, at preview size (G4);
//   switch_<girl|boy>.png  the same looks drawn v1 | v2 side by side (v2
//                          only when every v2 picture is there).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/avatar_v2_atlas.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

AvatarLook _look(String character, Map<CosmeticSlot, String> worn) =>
    AvatarLook.of((s) => s == CosmeticSlot.character
        ? character
        : worn[s] ?? defaultCosmetics[s]!);

Future<void> _save(String name, Size size, void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder
      .endRecording()
      .toImage(size.width.ceil(), size.height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File('build/avatar_v2/$name');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('4-7단계 확인 그림', () async {
    final jua = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
    await (FontLoader('Jua')..addFont(Future.value(jua))).load();
    await PixelSprites.load();
    for (final c in ['girl', 'boy']) {
      await _save('render_$c.png', const Size(280, 520), (canvas) {
        AvatarPainter(_look(c, {})).paint(canvas, const Size(280, 520));
      });
    }
    const tile = Size(112, 208);
    await _save('skin_tones.png', Size(tile.width * 6, tile.height), (canvas) {
      canvas.drawRect(Offset.zero & Size(tile.width * 6, tile.height),
          Paint()..color = const Color(0xFF6E8F64));
      var i = 0;
      for (final c in ['girl', 'boy']) {
        for (final s in ['skin1', 'skin2', 'skin3']) {
          canvas.save();
          canvas.translate(i++ * tile.width, 0);
          AvatarPainter(_look(c, {CosmeticSlot.skin: s})).paint(canvas, tile);
          canvas.restore();
        }
      }
    });
    final looks = <Map<CosmeticSlot, String>>[
      {},
      {CosmeticSlot.hair: 'short', CosmeticSlot.hat: 'beanie'},
      {CosmeticSlot.hair: 'ponytail', CosmeticSlot.bottom: 'skirt'},
      {CosmeticSlot.top: 'chefcoat', CosmeticSlot.outfit: 'noapron'},
      {CosmeticSlot.hair: 'curly', CosmeticSlot.hat: 'ballcap'},
    ];
    for (final c in ['girl', 'boy']) {
      final w = tile.width * looks.length;
      await _save('switch_$c.png', Size(w, tile.height * 2), (canvas) {
        canvas.drawRect(Offset.zero & Size(w, tile.height * 2),
            Paint()..color = const Color(0xFF6E8F64));
        for (final (row, v2) in [(0, false), (1, true)]) {
          if (v2 && !avatarV2Ready) continue;
          debugAvatarV2Override = v2;
          for (var i = 0; i < looks.length; i++) {
            canvas.save();
            canvas.translate(i * tile.width, row * tile.height);
            AvatarPainter(_look(c, looks[i])).paint(canvas, tile);
            canvas.restore();
          }
        }
        debugAvatarV2Override = null;
      });
    }
  });
}
