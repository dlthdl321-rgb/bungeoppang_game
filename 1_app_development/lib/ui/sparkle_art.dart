import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'pixel_sprites.dart';

/// The three sparkle looks of 26번 4단계 F11 ('UFO 같은' 옛 sparkle.png 대신).
/// - [star] (A, 기본): 25번 12번 three twinkle frames, no outline
///   (assets/images/fx/sparkle_1..3.png, 32x32), growing and fading;
/// - [glow] (B): a soft honey glow drawn in code, swelling and fading;
/// - [steam] (C): a light speck rising with a thin wisp of steam.
enum SparkleStyle { star, glow, steam }

/// One place for the sparkle switch (MASTER 10장 결과 연출·12장 효과).
class SparkleArt {
  SparkleArt._();

  /// The look every sparkle uses: the big floating bungeoppang, the result
  /// effects, the clear-sky weather and BakeTarget. A is the default until
  /// the user picks from build/f11_sparkle_options.png.
  static SparkleStyle style = SparkleStyle.star;

  /// One twinkle: frame 1 → 2 → 3 → rest, over [cycleMs].
  static const cycleMs = 1200;

  /// The still frame for reduced motion and tests (the largest frame).
  static const stillPhase = .32;

  static const frames = ['sparkle_1', 'sparkle_2', 'sparkle_3'];

  /// Honey (#FDBE38) and the warm white core.
  static const honey = Color(0xfffdbe38), core = Color(0xfffff8e6);

  /// Draws one sparkle centred at [center]. [side] is the size of the
  /// largest frame; [phase] runs 0..1 over one cycle (≥ .7 rests: nothing).
  static void paint(Canvas canvas, Offset center, double side, double phase,
      {SparkleStyle? look, double opacity = 1}) {
    final p = phase - phase.floorToDouble();
    if (p >= .7 || opacity <= 0) return;
    switch (look ?? style) {
      case SparkleStyle.star:
        final frame = p < .2 ? 0 : p < .45 ? 1 : 2;
        // Frames 1 and 3 fade in and out at the cycle's ends.
        final fade = p < .08 ? p / .08 : p > .6 ? (.7 - p) / .1 : 1.0;
        final image = PixelSprites.fx(frames[frame]);
        final rect = Rect.fromCenter(center: center, width: side, height: side);
        final alpha = (opacity * fade).clamp(0.0, 1.0);
        if (image == null) {
          _codeStar(canvas, center, side * (frame == 1 ? .5 : .25), alpha);
          return;
        }
        canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            rect,
            Paint()
              ..filterQuality = FilterQuality.none
              ..color = Color.fromRGBO(0, 0, 0, alpha));
      case SparkleStyle.glow:
        final swell = math.sin(p / .7 * math.pi);
        final r = side * (.18 + .3 * swell);
        canvas.drawCircle(
            center,
            r,
            Paint()
              ..shader = RadialGradient(colors: [
                core.withValues(alpha: opacity * swell),
                honey.withValues(alpha: opacity * swell * .55),
                honey.withValues(alpha: 0),
              ], stops: const [0, .35, 1])
                  .createShader(Rect.fromCircle(center: center, radius: r)));
      case SparkleStyle.steam:
        final t = p / .7, fade = math.sin(t * math.pi) * opacity;
        final at = center.translate(0, -side * .4 * t);
        final wisp = Path()..moveTo(at.dx, at.dy + side * .45);
        for (var i = 1; i <= 4; i++) {
          wisp.lineTo(at.dx + math.sin(t * 6 + i) * side * .08, at.dy + side * (.45 - i * .1));
        }
        canvas.drawPath(
            wisp,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1, side * .06)
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: fade * .45));
        canvas.drawCircle(at, side * (.06 + .05 * fade),
            Paint()..color = core.withValues(alpha: fade));
        canvas.drawCircle(at, side * (.14 + .08 * fade),
            Paint()..color = honey.withValues(alpha: fade * .3));
    }
  }

  /// A four-point light with no outline, for when the art did not load.
  static void _codeStar(Canvas canvas, Offset c, double r, double alpha) {
    final paint = Paint()..color = core.withValues(alpha: alpha);
    final ray = Paint()..color = honey.withValues(alpha: alpha * .8);
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * .18, c.dy - r * .18)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx + r * .18, c.dy + r * .18)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * .18, c.dy + r * .18)
          ..lineTo(c.dx - r, c.dy)
          ..lineTo(c.dx - r * .18, c.dy - r * .18)
          ..close(),
        ray);
    canvas.drawCircle(c, r * .22, paint);
  }
}

/// Sparkles at fixed places (fractions of the box) that twinkle one after
/// another, each at its own beat. Still (each at [SparkleArt.stillPhase])
/// with [reduceMotion] or when [animate] is off (tests: an endless
/// animation keeps pumpAndSettle from settling).
class TwinklingSparkles extends StatefulWidget {
  /// (x, y, size): centre as a fraction of the box, size as a fraction of
  /// the box's shortest side.
  final List<(double, double, double)> points;
  final bool reduceMotion;
  const TwinklingSparkles({super.key, required this.points, this.reduceMotion = false});

  /// Off in tests (test/flutter_test_config.dart), like WeatherLayer.animate.
  static bool animate = true;

  @override
  State<TwinklingSparkles> createState() => _TwinklingSparklesState();
}

class _TwinklingSparklesState extends State<TwinklingSparkles>
    with SingleTickerProviderStateMixin {
  // 20 frames a second is enough for a pixel twinkle (WeatherLayer.fps).
  late final Ticker _ticker = createTicker((elapsed) {
    final ms = elapsed.inMilliseconds;
    if (ms - _ms.value >= 50) _ms.value = ms;
  });
  final _ms = ValueNotifier<int>(0);

  bool get _running => TwinklingSparkles.animate && !widget.reduceMotion;

  @override
  void initState() {
    super.initState();
    if (_running) _ticker.start();
  }

  @override
  void didUpdateWidget(TwinklingSparkles old) {
    super.didUpdateWidget(old);
    if (_running && !_ticker.isActive) {
      _ticker.start();
    } else if (!_running && _ticker.isActive) {
      _ticker.stop();
      _ms.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: CustomPaint(
          key: const Key('twinkling-sparkles'),
          painter: _TwinklePainter(widget.points, _ms, still: !_running)));
}

class _TwinklePainter extends CustomPainter {
  final List<(double, double, double)> points;
  final ValueNotifier<int> ms;
  final bool still;
  _TwinklePainter(this.points, this.ms, {required this.still}) : super(repaint: ms);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final (x, y, s) = points[i];
      // Each point starts at its own beat, so they never all flash at once.
      final phase = still
          ? SparkleArt.stillPhase
          : ms.value / SparkleArt.cycleMs + i * .37;
      SparkleArt.paint(canvas, Offset(x * size.width, y * size.height),
          size.shortestSide * s, phase);
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter old) =>
      old.still != still || old.points != points;
}

/// Fixed four-point pixel sparkles around the bungeoppang (concept art).
class SparklePainter extends CustomPainter {
  const SparklePainter();

  /// Centre (fraction of the box) and size in sparkle pixels.
  static const _sparkles = [
    (.12, .22, 3),
    (.86, .18, 2),
    (.2, .78, 2),
    (.9, .7, 3),
    (.08, .52, 1),
    (.78, .9, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // The no-outline twinkle of 26번 4단계 F11 (ui/sparkle_art.dart), still.
    if (PixelSprites.fx(SparkleArt.frames[1]) != null ||
        SparkleArt.style != SparkleStyle.star) {
      for (final (fx, fy, n) in _sparkles) {
        // The 32x32 art is mostly glow: a little larger than the old 7x7.
        final side = 10 * (1.0 + n) * (size.width / 360);
        SparkleArt.paint(canvas, Offset(size.width * fx, size.height * fy), side,
            SparkleArt.stillPhase);
      }
      return;
    }
    final px = math.max(2.0, (size.width / 120).roundToDouble());
    final core = Paint()..color = const Color(0xfffff3c4);
    final ray = Paint()..color = const Color(0xccfed794);
    for (final (fx, fy, n) in _sparkles) {
      final c = Offset((size.width * fx / px).roundToDouble() * px,
          (size.height * fy / px).roundToDouble() * px);
      canvas.drawRect(Rect.fromCenter(center: c, width: px, height: px), core);
      for (var i = 1; i <= n; i++) {
        for (final d in const [
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(0, -1)
        ]) {
          canvas.drawRect(
              Rect.fromCenter(
                  center: c + d * px * i.toDouble(), width: px, height: px),
              ray);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) => false;
}
