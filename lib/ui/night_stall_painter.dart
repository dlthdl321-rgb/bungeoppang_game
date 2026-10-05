import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'avatar_painter.dart';
import 'pixel_sprites.dart';

/// Pixel-art stall scene: background, vendor, counter, stove and decoration
/// layers.
///
/// Layers are placed in a 180x400 scene (one unit = one art pixel) that
/// covers the canvas and is anchored to the bottom, so the counter always
/// shows and only sky is cropped. Positions must match the previews of
/// tools/draw_pixel_assets.py.
class NightStallPainter extends CustomPainter {
  final String background, stove, decoration;

  /// The vendor behind the counter, or null for an empty stall.
  final AvatarLook? avatar;

  /// Tap animation of the vendor, 0..1.
  final double lift;
  const NightStallPainter(
      {this.background = 'night',
      this.stove = 'iron',
      this.decoration = 'none',
      this.avatar,
      this.lift = 0});

  static const sceneSize = Size(180, 400);
  static const counterTop = 304.0;
  static const stoveAt = Offset(30, 268);
  // Right of the stove; rows below the counter top are hidden behind it.
  static const avatarAt = Offset(118, 250);
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
    avatar?.paint(canvas, avatarAt, lift: lift);
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
      decoration != oldDelegate.decoration ||
      avatar != oldDelegate.avatar ||
      lift != oldDelegate.lift;
}

/// The stall with its vendor, who lifts the tongs once whenever [taps]
/// changes. Still when [reduceMotion] is set.
class StallScene extends StatefulWidget {
  final String Function(CosmeticSlot) equipped;
  final BigInt taps;
  final bool reduceMotion;
  const StallScene(
      {super.key,
      required this.equipped,
      required this.taps,
      this.reduceMotion = false});

  static const liftMs = 250;

  @override
  State<StallScene> createState() => _StallSceneState();
}

class _StallSceneState extends State<StallScene>
    with SingleTickerProviderStateMixin {
  late final _lift = AnimationController(
      vsync: this, duration: const Duration(milliseconds: StallScene.liftMs));

  @override
  void didUpdateWidget(StallScene old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion) {
      _lift.value = 0;
    } else if (widget.taps != old.taps) {
      _lift.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.equipped;
    return AnimatedBuilder(
        animation: _lift,
        builder: (context, _) => CustomPaint(
            key: const Key('stall-scene'),
            painter: NightStallPainter(
                background: e(CosmeticSlot.background),
                stove: e(CosmeticSlot.stove),
                decoration: e(CosmeticSlot.decoration),
                avatar: AvatarLook.of(e),
                lift: _lift.isAnimating
                    ? math.sin(math.pi * _lift.value)
                    : 0)));
  }
}
