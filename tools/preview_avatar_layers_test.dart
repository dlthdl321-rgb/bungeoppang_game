// Checking sheet for the vendor's layers (stage 17), drawn by the game's own
// painters at the sizes the game uses:
//   rows 1-6  the cooking cut, frames 1..6: rest, mouth small, mouth wide,
//             eyes half, eyes closed, and the debug outlines
//   row 7     the front vendor (girl, boy) in the same states, then mirrored
// flutter test tools/preview_avatar_layers_test.dart
// Writes build/preview/avatar_layers.png (2x).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/cook_cut.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('사장님 레이어 미리보기', () async {
    await PixelSprites.load();
    const faces = <Map<String, String>?>[
      {},
      {'mouth': 'small'},
      {'mouth': 'wide'},
      {'eyes': 'half'},
      {'eyes': 'closed'},
      null, // debug outlines
    ];
    const cut = Size(125, 105); // the home window on a 390-wide phone
    const pad = 6.0, zoom = 2.0;
    const frontW = 64.0;
    final width = [
      faces.length * (cut.width + pad) + pad,
      2 * (faces.length + 1) * (frontW + pad / 2) + pad,
    ].reduce((a, b) => a > b ? a : b);
    final height = 6 * (cut.height + pad) + 140 + pad;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(zoom);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF2E2420));
    final look = AvatarLook.of((s) => defaultCosmetics[s]!);
    for (var frame = 0; frame < 6; frame++) {
      for (var i = 0; i < faces.length; i++) {
        AvatarRigDebug.show.value = faces[i] == null;
        canvas.save();
        canvas.translate(pad + i * (cut.width + pad),
            pad + frame * (cut.height + pad));
        canvas.clipRect(Offset.zero & cut);
        CookCutPainter(look: look, face: faces[i] ?? const {}, frame: frame)
            .paint(canvas, cut);
        canvas.restore();
      }
    }
    final y = pad + 6 * (cut.height + pad);
    var x = pad;
    for (final character in ['girl', 'boy']) {
      final front = AvatarLook.of((s) => s == CosmeticSlot.character
          ? character
          : s == CosmeticSlot.hat
              ? 'beanie'
              : defaultCosmetics[s]!);
      for (final (face, flip) in [
        ...faces.map((f) => (f, false)),
        (const {'mouth': 'wide'}, true),
      ]) {
        AvatarRigDebug.show.value = face == null;
        canvas.save();
        canvas.translate(x, y);
        AvatarPainter(front, face: face ?? const {}, flip: flip)
            .paint(canvas, const Size(frontW, 130));
        canvas.restore();
        x += frontW + pad / 2;
      }
    }
    AvatarRigDebug.show.value = false;
    final image = await recorder
        .endRecording()
        .toImage((width * zoom).ceil(), (height * zoom).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/preview/avatar_layers.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(bytes!.buffer.asUint8List());
  });
}
