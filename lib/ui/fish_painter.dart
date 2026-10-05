import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// Pixel-art bungeoppang: [skin] (flavour) embossed with [pattern], with
/// [topping] on top, fitted into the canvas and centered. Every screen draws
/// the same sprites, so all looks match.
class FishPainter extends CustomPainter {
  final String skin, pattern, topping;
  const FishPainter(
      {this.skin = 'redbean', this.pattern = 'scales', this.topping = 'plain'});

  /// Filling colour of the sprite (FISH_SKINS in tools/draw_pixel_assets.py).
  Color get filling => switch (skin) {
        'cocoa' => const Color(0xff2a1a18),
        'custard' => const Color(0xfffff4e0),
        'sweetpotato' => const Color(0xffb28ad8),
        'matcha' => const Color(0xff2f5b48),
        'strawberry' => const Color(0xffd9573b),
        _ => const Color(0xff8c2f39),
      };

  /// Crust colours of the sprite, light to dark.
  List<Color> get crust => switch (skin) {
        'cocoa' => const [
            Color(0xffa8642f),
            Color(0xff6b3a1f),
            Color(0xff3a2420)
          ],
        'custard' => const [
            Color(0xffffe9a8),
            Color(0xfff8d27a),
            Color(0xffe0a040)
          ],
        'sweetpotato' => const [
            Color(0xffffc9a0),
            Color(0xffff9e4a),
            Color(0xffa8642f)
          ],
        'matcha' => const [
            Color(0xfffff4e0),
            Color(0xffb9e3a8),
            Color(0xff5e9e5a)
          ],
        'strawberry' => const [
            Color(0xfff4f7ff),
            Color(0xfff6b3c2),
            Color(0xffe07a98)
          ],
        _ => const [Color(0xfff8d27a), Color(0xffe0a040), Color(0xffa8642f)],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final image = PixelSprites.fish(skin, pattern);
    if (image == null) return;
    final scale =
        math.min(size.width / image.width, size.height / image.height);
    final dst = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: image.width * scale,
        height: image.height * scale);
    PixelSprites.draw(canvas, image, dst);
    // Topping overlays share the fish canvas size.
    PixelSprites.draw(
        canvas, PixelSprites.cosmetic(CosmeticSlot.topping, topping), dst);
  }

  @override
  bool shouldRepaint(covariant FishPainter oldDelegate) =>
      oldDelegate.skin != skin ||
      oldDelegate.pattern != pattern ||
      oldDelegate.topping != topping;
}
