import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// Pixel-art stall scene: background, counter, stove and decoration layers.
///
/// Layers are placed in a 180x400 scene (one unit = one art pixel) that
/// covers the canvas and is anchored to the bottom, so the counter always
/// shows and only sky is cropped. Positions must match the previews of
/// tools/draw_pixel_assets.py.
class NightStallPainter extends CustomPainter {
  final String background, stove, decoration;
  const NightStallPainter(
      {this.background = 'night',
      this.stove = 'iron',
      this.decoration = 'none'});

  static const sceneSize = Size(180, 400);
  static const counterTop = 304.0;
  static const stoveAt = Offset(30, 268);
  static const decorationAt = {
    'lantern': [Offset(8, 78), Offset(158, 78)],
    'windchime': [Offset(10, 74), Offset(156, 74)],
    'bunting': [Offset(0, 100)],
    'starlights': [Offset(0, 104)],
    'snowman': [Offset(148, 274)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff141830));
    final scale = math.max(
        size.width / sceneSize.width, size.height / sceneSize.height);
    canvas.save();
    canvas.translate((size.width - sceneSize.width * scale) / 2,
        size.height - sceneSize.height * scale);
    canvas.scale(scale);
    PixelSprites.drawAt(canvas,
        PixelSprites.cosmetic(CosmeticSlot.background, background), Offset.zero);
    PixelSprites.drawAt(canvas, PixelSprites.counter(snow: background == 'snow'),
        const Offset(0, counterTop));
    PixelSprites.drawAt(
        canvas, PixelSprites.cosmetic(CosmeticSlot.stove, stove), stoveAt);
    final deco = PixelSprites.cosmetic(CosmeticSlot.decoration, decoration);
    for (final at in decorationAt[decoration] ?? const <Offset>[]) {
      PixelSprites.drawAt(canvas, deco, at);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NightStallPainter oldDelegate) =>
      background != oldDelegate.background ||
      stove != oldDelegate.stove ||
      decoration != oldDelegate.decoration;
}
