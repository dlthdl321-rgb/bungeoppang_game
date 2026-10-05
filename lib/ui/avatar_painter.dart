import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// What the vendor wears: one id per avatar slot.
class AvatarLook {
  final String skin, hair, outfit, hat, tool;
  const AvatarLook(
      {this.skin = 'skin1',
      this.hair = 'short',
      this.outfit = 'apron',
      this.hat = 'nohat',
      this.tool = 'tongs'});
  factory AvatarLook.of(String Function(CosmeticSlot) equipped) => AvatarLook(
      skin: equipped(CosmeticSlot.skin),
      hair: equipped(CosmeticSlot.hair),
      outfit: equipped(CosmeticSlot.outfit),
      hat: equipped(CosmeticSlot.hat),
      tool: equipped(CosmeticSlot.tool));

  /// Size of every layer image, in art pixels (tools/draw_pixel_assets.py).
  static const size = Size(44, 60);

  /// Draws the layers with their top-left at [at], in art-pixel units.
  /// [lift] (0..1) hops the vendor and raises the tongs for a tap.
  void paint(Canvas canvas, Offset at, {double lift = 0}) {
    final body = at.translate(0, -(lift * 2).roundToDouble());
    final tongs = body.translate(0, -(lift * 3).roundToDouble());
    for (final (image, offset) in [
      (PixelSprites.cosmetic(CosmeticSlot.skin, skin), body),
      (PixelSprites.cosmetic(CosmeticSlot.outfit, outfit), body),
      (PixelSprites.cosmetic(CosmeticSlot.hair, hair), body),
      (PixelSprites.cosmetic(CosmeticSlot.hat, hat), body),
      (PixelSprites.cosmetic(CosmeticSlot.tool, tool), tongs),
      (PixelSprites.hands(skin), body),
    ]) {
      PixelSprites.drawAt(canvas, image, offset);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      other.skin == skin &&
      other.hair == hair &&
      other.outfit == outfit &&
      other.hat == hat &&
      other.tool == tool;

  @override
  int get hashCode => Object.hash(skin, hair, outfit, hat, tool);
}

/// The vendor alone, fitted into the canvas (wardrobe preview).
class AvatarPainter extends CustomPainter {
  final AvatarLook look;
  const AvatarPainter(this.look);

  @override
  void paint(Canvas canvas, Size size) {
    const art = AvatarLook.size;
    final scale = math.min(size.width / art.width, size.height / art.height);
    canvas.save();
    canvas.translate((size.width - art.width * scale) / 2,
        (size.height - art.height * scale) / 2);
    canvas.scale(scale);
    look.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => old.look != look;
}
