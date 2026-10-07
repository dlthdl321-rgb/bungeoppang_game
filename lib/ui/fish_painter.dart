import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// Pixel-art bungeoppang (redbean; flavours were removed in stage 14)
/// embossed with [pattern], with
/// [topping] on top, fitted into the canvas and centered. Every screen draws
/// the same sprites, so all looks match.
class FishPainter extends CustomPainter {
  final String skin, pattern, topping;
  const FishPainter(
      {this.skin = 'redbean', this.pattern = 'scales', this.topping = 'plain'});

  static final _smooth = Paint()..filterQuality = FilterQuality.medium;

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
    if (scale < 1) {
      // The concept fish at its own resolution: scale it down smoothly.
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dst,
          _smooth);
    } else {
      PixelSprites.draw(canvas, image, dst);
    }
    // Topping overlays share the fish canvas shape (4:3).
    PixelSprites.draw(
        canvas, PixelSprites.cosmetic(CosmeticSlot.topping, topping), dst);
  }

  @override
  bool shouldRepaint(covariant FishPainter oldDelegate) =>
      oldDelegate.skin != skin ||
      oldDelegate.pattern != pattern ||
      oldDelegate.topping != topping;
}
