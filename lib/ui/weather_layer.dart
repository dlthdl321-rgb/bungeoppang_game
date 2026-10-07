import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';

/// What falls or twinkles over each background (stage 14, B5). Drawn in
/// code over the fixed background: swapping background frames would make
/// the buildings wobble (concept art guide).
enum Weather { sparkle, rain, snow, leaves, petals, stars, fireflies }

Weather? weatherFor(String background) => switch (background) {
      'clear' => Weather.sparkle,
      'rain' => Weather.rain,
      'snow' || 'snowday' => Weather.snow,
      'autumn' => Weather.leaves,
      'cherry' => Weather.petals,
      'night' || 'seaside' => Weather.stars,
      'dusk' || 'forest' => Weather.fireflies,
      _ => null,
    };

/// Weather particles over the [NightStallPainter] scene, on its pixel grid.
/// Hidden when [reduceMotion] is set.
class WeatherLayer extends StatefulWidget {
  final String background;
  final bool reduceMotion;
  const WeatherLayer(
      {super.key, required this.background, this.reduceMotion = false});

  /// Off in tests (test/flutter_test_config.dart): a never-ending animation
  /// keeps pumpAndSettle from settling. The layer then draws one still frame.
  static bool animate = true;

  /// Frames per second; pixel art does not need more.
  static const fps = 20;

  @override
  State<WeatherLayer> createState() => _WeatherLayerState();
}

class _WeatherLayerState extends State<WeatherLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) {
    final t = elapsed.inMilliseconds / 1000;
    if (t - _t >= 1 / WeatherLayer.fps) setState(() => _t = t);
  });
  double _t = 0;

  bool get _running =>
      WeatherLayer.animate &&
      !widget.reduceMotion &&
      weatherFor(widget.background) != null;

  @override
  void initState() {
    super.initState();
    if (_running) _ticker.start();
  }

  @override
  void didUpdateWidget(WeatherLayer old) {
    super.didUpdateWidget(old);
    if (_running && !_ticker.isActive) {
      _ticker.start();
    } else if (!_running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = weatherFor(widget.background);
    if (widget.reduceMotion || weather == null) return const SizedBox.expand();
    return CustomPaint(
        key: const Key('weather'),
        size: Size.infinite,
        painter: WeatherPainter(weather, _t));
  }
}

/// [weather] at [t] seconds. Every particle is a function of time from a
/// fixed seed, so nothing is allocated per frame.
class WeatherPainter extends CustomPainter {
  final Weather weather;
  final double t;
  const WeatherPainter(this.weather, this.t);

  /// Particles stay above the counter, in scene pixels.
  static const _width = 180.0, _height = NightStallPainter.counterTop;

  static final _paint = Paint()..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final (scale, origin) = NightStallPainter.fit(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    final random = math.Random(weather.index + 1);
    double next() => random.nextDouble();
    void dot(double x, double y, double w, double h, Color color) =>
        canvas.drawRect(
            Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), w, h),
            _paint..color = color);
    double wrap(double v, double max) => v % max;

    switch (weather) {
      case Weather.rain:
        for (var i = 0; i < 60; i++) {
          final x0 = next() * _width, y0 = next() * _height;
          final speed = 200 + next() * 60;
          final y = wrap(y0 + speed * t, _height);
          final x = wrap(x0 - y * .25, _width);
          dot(x, y, 1, 3, const Color(0xb3a8c8e8));
        }
      case Weather.snow:
        for (var i = 0; i < 45; i++) {
          final x0 = next() * _width, y0 = next() * _height;
          final speed = 12 + next() * 12, phase = next() * 6.3;
          final big = next() < .3;
          final y = wrap(y0 + speed * t, _height);
          final x = wrap(x0 + 4 * math.sin(t * 1.3 + phase), _width);
          dot(x, y, big ? 2 : 1, big ? 2 : 1, const Color(0xf0ffffff));
        }
      case Weather.leaves:
      case Weather.petals:
        final leaves = weather == Weather.leaves;
        final colors = leaves
            ? const [Color(0xffe3812b), Color(0xffc4502a), Color(0xfff0b040)]
            : const [Color(0xfff6c7d8), Color(0xffe89ab4)];
        for (var i = 0; i < (leaves ? 14 : 18); i++) {
          final x0 = next() * _width, y0 = next() * _height;
          final speed = 14 + next() * 12, phase = next() * 6.3;
          final color = colors[random.nextInt(colors.length)];
          final y = wrap(y0 + speed * t, _height);
          final x = wrap(x0 + 9 * t + 6 * math.sin(t * 1.1 + phase), _width);
          // Turning over: flat for part of each sway.
          final flat = math.sin(t * 2.2 + phase) > .4;
          dot(x, y, 2, leaves && !flat ? 2 : 1, color);
        }
      case Weather.stars:
        for (var i = 0; i < 20; i++) {
          final x = next() * _width, y = next() * 120;
          final phase = next() * 6.3, rate = .8 + next() * 1.5;
          final glow = .5 + .5 * math.sin(t * rate + phase);
          dot(x, y, 1, 1, Color.fromRGBO(255, 244, 214, .25 + .75 * glow));
        }
      case Weather.fireflies:
        for (var i = 0; i < 12; i++) {
          final x0 = 10 + next() * 160, y0 = 60 + next() * 200;
          final phase = next() * 6.3, rate = .6 + next() * .8;
          final x = x0 + 6 * math.sin(t * rate + phase);
          final y = y0 + 4 * math.cos(t * rate * 1.3 + phase);
          final on = math.sin(t * 2 + phase * 3) > -.2;
          if (on) dot(x, y, 1, 1, const Color(0xffe8f27a));
        }
      case Weather.sparkle:
        final sprite = PixelSprites.fx('sparkle');
        for (var i = 0; i < 6; i++) {
          final x = 8 + next() * 164, y = 10 + next() * 140;
          final phase = next() * 6.3;
          final glow = math.sin(t * .9 + phase);
          if (glow < .3) continue;
          if (sprite != null) {
            // Small at half glow, the full 7x7 sparkle at its peak.
            final d = glow > .7 ? 7.0 : 3.0;
            canvas.saveLayer(
                null, Paint()..color = Color.fromRGBO(0, 0, 0, glow));
            PixelSprites.draw(
                canvas,
                sprite,
                Rect.fromCenter(
                    center: Offset(x.floorToDouble(), y.floorToDouble()),
                    width: d,
                    height: d));
            canvas.restore();
            continue;
          }
          final color = Color.fromRGBO(254, 241, 214, glow);
          dot(x, y, 1, 1, color);
          if (glow > .7) {
            dot(x - 1, y, 1, 1, color);
            dot(x + 1, y, 1, 1, color);
            dot(x, y - 1, 1, 1, color);
            dot(x, y + 1, 1, 1, color);
          }
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WeatherPainter old) =>
      old.t != t || old.weather != weather;
}
