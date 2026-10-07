import 'dart:math' as math;
import 'dart:ui' as ui;
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
///
/// The home screen leaves out [stove] and [avatar]: it draws the griddle and
/// the vendor's cooking cut at their own pixel scale (see night_home.dart).
class NightStallPainter extends CustomPainter {
  final String background, decoration;

  /// Shows [background] by day or at night, or null for its own time (see
  /// PixelSprites.sceneBackground).
  final bool? night;

  /// Null leaves the stove out.
  final String? stove;

  /// The vendor behind the counter, or null for an empty stall.
  final AvatarLook? avatar;
  const NightStallPainter(
      {this.background = 'clear',
      this.night,
      this.stove = 'iron',
      this.decoration = 'none',
      this.avatar});

  static const sceneSize = Size(180, 400);

  /// Backgrounds that put snow on the counter.
  static const snowyBackgrounds = {'snow', 'snowday'};
  static const counterTop = 304.0;
  static const stoveAt = Offset(30, 268);
  // Right of the stove; rows below the counter top are hidden behind it.
  static const avatarAt = Offset(116, 250);
  /// Top-left of each copy of a decoration, in scene units; a true flag
  /// mirrors that copy (the lantern art has its post on the right, so the
  /// left-hand one is flipped to stand on the outside too).
  static const decorationAt = {
    'lantern': [(Offset(8, 78), true), (Offset(150, 78), false)],
    'windchime': [(Offset(10, 74), false), (Offset(156, 74), false)],
    'bunting': [(Offset(0, 100), false)],
    'starlights': [(Offset(0, 104), false)],
    'paperlanterns': [(Offset(0, 104), false)],
    // On the street at the right, behind the counter: the home screen's
    // cooking cut covers the counter's right end.
    'snowman': [(Offset(128, 66), false)],
  };

  /// Decoration art is stored at this many pixels per scene unit
  /// (tools/apply_extra_art.py DECO_SCALE), so it keeps its finer dots.
  static const decorationScale = 3.0;

  /// Concept-art backgrounds come at their own resolution (335x762, not the
  /// 180x400 scene grid); they are scaled smoothly so the raw art shows as
  /// drawn.
  static final _rawPaint = Paint()..filterQuality = FilterQuality.medium;

  /// The bungeoppang baked into the concept backgrounds (raw/backgrounds,
  /// 335x762): its body, in the cut's pixels.
  static const conceptFish = Rect.fromLTRB(62, 382, 287, 525);

  /// Where [background]'s baked-in bungeoppang shows on a [size] screen, or
  /// null when that background has none (scene-sized pixel art).
  static Rect? bakedFishOnScreen(Size size, String background) {
    final image = PixelSprites.cosmetic(CosmeticSlot.background, background);
    if (image == null ||
        (image.width == sceneSize.width && image.height == sceneSize.height)) {
      return null;
    }
    final w = image.width.toDouble(), h = image.height.toDouble();
    final s = math.max(sceneSize.width / w, sceneSize.height / h);
    final dx = (sceneSize.width - w * s) / 2, dy = sceneSize.height - h * s;
    final (k, origin) = fit(size);
    Offset map(Offset p) => origin + Offset(dx + p.dx * s, dy + p.dy * s) * k;
    // The concept cuts differ by a pixel or two in width; scale x with w.
    final f = w / 335;
    return Rect.fromPoints(map(Offset(conceptFish.left * f, conceptFish.top)),
        map(Offset(conceptFish.right * f, conceptFish.bottom)));
  }

  /// Draws [image] covering the scene, anchored to its bottom (the counter
  /// side), whatever its resolution. Scene-sized art keeps its crisp pixels.
  static void _drawBackground(Canvas canvas, ui.Image? image) {
    if (image == null) return;
    final w = image.width.toDouble(), h = image.height.toDouble();
    if (w == sceneSize.width && h == sceneSize.height) {
      PixelSprites.drawAt(canvas, image, Offset.zero);
      return;
    }
    final scale = math.max(sceneSize.width / w, sceneSize.height / h);
    final dw = w * scale, dh = h * scale;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w, h),
        Rect.fromLTWH(
            (sceneSize.width - dw) / 2, sceneSize.height - dh, dw, dh),
        _rawPaint);
  }

  /// Scale and top-left of the scene covering [size], anchored to the bottom.
  static (double, Offset) fit(Size size) {
    final scale =
        math.max(size.width / sceneSize.width, size.height / sceneSize.height);
    return (
      scale,
      Offset((size.width - sceneSize.width * scale) / 2,
          size.height - sceneSize.height * scale)
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xff2d2869));
    final (scale, origin) = fit(size);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final (image, darken) = PixelSprites.sceneBackground(background, night);
    _drawBackground(canvas, image);
    if (darken) {
      // No night picture yet: the day one under a deep blue night wash.
      canvas.drawRect(
          Offset.zero & sceneSize,
          Paint()
            ..color = const Color(0xff4a4f8f)
            ..blendMode = BlendMode.multiply);
    }
    avatar?.paint(canvas, avatarAt);
    PixelSprites.drawAt(
        canvas,
        PixelSprites.counter(snow: snowyBackgrounds.contains(background)),
        const Offset(0, counterTop));
    if (stove case final stove?) {
      PixelSprites.drawAt(
          canvas, PixelSprites.cosmetic(CosmeticSlot.stove, stove), stoveAt);
    }
    final deco = PixelSprites.cosmetic(CosmeticSlot.decoration, decoration);
    if (deco != null) {
      final size = Size(deco.width / decorationScale,
          deco.height / decorationScale);
      for (final (at, mirror)
          in decorationAt[decoration] ?? const <(Offset, bool)>[]) {
        final dst = at & size;
        if (!mirror) {
          PixelSprites.draw(canvas, deco, dst);
          continue;
        }
        canvas.save();
        canvas.translate(dst.left + dst.right, 0);
        canvas.scale(-1, 1);
        PixelSprites.draw(canvas, deco, dst);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant NightStallPainter oldDelegate) =>
      background != oldDelegate.background ||
      night != oldDelegate.night ||
      stove != oldDelegate.stove ||
      decoration != oldDelegate.decoration ||
      avatar != oldDelegate.avatar;
}

/// The stall's frame from the concept art: a striped awning across the top
/// of the screen and a wooden post with a hanging lamp at each side, down to
/// the counter of the [NightStallPainter] scene drawn under it.
class StallFramePainter extends CustomPainter {
  /// The equipped [CosmeticSlot.lamp]: the glass colour of both lamps.
  final String lamp;
  const StallFramePainter({this.lamp = 'amberlamp'});

  /// Awning pixels across the screen width.
  static const awningDots = 72;

  /// Post lamp width in scene pixels; higher-resolution lamp art keeps it.
  static const lampWidth = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final awning = PixelSprites.stallPart('awning');
    final post = PixelSprites.stallPart('post');
    final lamp = PixelSprites.cosmetic(CosmeticSlot.lamp, this.lamp) ??
        PixelSprites.stallPart('postlamp');
    final (scale, origin) = NightStallPainter.fit(size);
    final counterY = origin.dy + NightStallPainter.counterTop * scale;
    final dot = size.width / awningDots;
    final awningH = (awning?.height ?? 8) * dot;
    if (post != null) {
      final w = post.width * scale;
      for (final x in [0.0, size.width - w]) {
        PixelSprites.draw(
            canvas, post, Rect.fromLTRB(x, awningH * .5, x + w, counterY));
      }
    }
    if (lamp != null) {
      final lampDot = scale * 1.2;
      // Sized in scene pixels (9 wide), whatever the art's own resolution.
      final w = lampWidth * lampDot, h = w * lamp.height / lamp.width;
      final top = awningH + 6 * scale;
      for (final x in [
        post == null ? 0.0 : post.width * scale - w * .3,
        size.width - (post == null ? 0.0 : post.width * scale) - w * .7
      ]) {
        PixelSprites.draw(canvas, lamp, Rect.fromLTWH(x, top, w, h));
      }
    }
    PixelSprites.draw(canvas, awning, Rect.fromLTWH(0, 0, size.width, awningH));
  }

  @override
  bool shouldRepaint(covariant StallFramePainter oldDelegate) =>
      lamp != oldDelegate.lamp;
}

/// The baking griddle ([CosmeticSlot.stove]) at the bottom of the home
/// screen, scaled to the canvas width and anchored to its bottom edge.
class GriddlePainter extends CustomPainter {
  final String stove;
  const GriddlePainter(this.stove);

  @override
  void paint(Canvas canvas, Size size) {
    final image = PixelSprites.cosmetic(CosmeticSlot.stove, stove);
    if (image == null) return;
    final scale =
        math.min(size.width / image.width, size.height / image.height);
    final w = image.width * scale, h = image.height * scale;
    final dst = Rect.fromLTWH((size.width - w) / 2, size.height - h, w, h);
    // The concept griddle is bigger than its box: scale it down smoothly so
    // its fine detail does not shimmer.
    if (scale < 1) {
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dst,
          _rawPaint);
    } else {
      PixelSprites.draw(canvas, image, dst);
    }
  }

  static final _rawPaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  bool shouldRepaint(covariant GriddlePainter oldDelegate) =>
      stove != oldDelegate.stove;
}
