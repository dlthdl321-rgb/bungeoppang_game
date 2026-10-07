import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// What the vendor wears: one id per avatar slot.
class AvatarLook {
  final String character, skin, hair, top, bottom, shoes, outfit, hat;
  final String accessory, tool;

  const AvatarLook(
      {this.character = 'girl',
      this.skin = 'skin1',
      this.hair = 'long',
      this.top = 'tee',
      this.bottom = 'shorts',
      this.shoes = 'flats',
      this.outfit = 'apron',
      this.hat = 'nohat',
      this.accessory = 'noacc',
      this.tool = 'tongs'});
  factory AvatarLook.of(String Function(CosmeticSlot) equipped) => AvatarLook(
      character: equipped(CosmeticSlot.character),
      skin: equipped(CosmeticSlot.skin),
      hair: equipped(CosmeticSlot.hair),
      top: equipped(CosmeticSlot.top),
      bottom: equipped(CosmeticSlot.bottom),
      shoes: equipped(CosmeticSlot.shoes),
      outfit: equipped(CosmeticSlot.outfit),
      hat: equipped(CosmeticSlot.hat),
      accessory: equipped(CosmeticSlot.accessory),
      tool: equipped(CosmeticSlot.tool));

  /// Size of the vendor in scene units. Every layer image is a 280x520
  /// canvas (tools/concept_avatar.py) drawn into this box.
  static const size = Size(56, 104);

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Draws the vendor with its top-left at [at], in scene units.
  /// [lift] (0..1) hops the vendor and raises the tool for a tap.
  ///
  /// Layer order: base figure (body, face, default hair and clothes), then
  /// bottom, shoes, top, apron/outfit, hat, accessory and tool. Items
  /// without art (and the defaults the base already wears) are left out.
  void paint(Canvas canvas, Offset at, {double lift = 0}) {
    final body = at.translate(0, -(lift * 2).roundToDouble());
    final lifted = body.translate(0, -(lift * 3).roundToDouble());
    void layer(ui.Image? image, Offset offset) {
      if (image == null) return;
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          offset & size,
          _paint);
    }

    layer(PixelSprites.avatarBase(character), body);
    for (final (slot, id) in [
      (CosmeticSlot.bottom, bottom),
      (CosmeticSlot.shoes, shoes),
      (CosmeticSlot.top, top),
      (CosmeticSlot.outfit, outfit),
      (CosmeticSlot.hat, hat),
      (CosmeticSlot.accessory, accessory),
    ]) {
      layer(PixelSprites.avatarPart(character, slot, id), body);
    }
    layer(PixelSprites.avatarPart(character, CosmeticSlot.tool, tool), lifted);
  }

  List<String> get _ids =>
      [character, skin, hair, top, bottom, shoes, outfit, hat, accessory, tool];

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      Iterable.generate(_ids.length).every((i) => other._ids[i] == _ids[i]);

  @override
  int get hashCode => Object.hashAll(_ids);
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
