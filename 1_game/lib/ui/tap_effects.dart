import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class Crumb {
  bool active = false;
  double x = 0, y = 0, vx = 0, vy = 0, size = 0;
  int born = 0, shade = 0;
}

/// Fixed-size crumb pool: every particle is allocated up front and reused,
/// so taps never allocate and never exceed [capacity].
class CrumbPool {
  final int capacity, lifeMs;
  final List<Crumb> _items;
  final math.Random _random;
  int _next = 0;
  CrumbPool(this.capacity, this.lifeMs, {int seed = 7})
      : _items = List.generate(capacity, (_) => Crumb()),
        _random = math.Random(seed);

  int get activeCount => _items.where((c) => c.active).length;
  Iterable<Crumb> get active => _items.where((c) => c.active);

  void spawn(Offset at, int now, int count) {
    for (var i = 0; i < count; i++) {
      // Round-robin reuse: when full, the oldest crumb is recycled.
      final c = _items[_next];
      _next = (_next + 1) % capacity;
      final angle = -math.pi / 2 + (_random.nextDouble() - .5) * math.pi * 1.2;
      final speed = 90 + _random.nextDouble() * 110;
      c
        ..active = true
        ..x = at.dx
        ..y = at.dy
        ..vx = math.cos(angle) * speed
        ..vy = math.sin(angle) * speed
        ..size = 2.5 + _random.nextDouble() * 3
        ..shade = _random.nextInt(3)
        ..born = now;
    }
  }

  void update(int now) {
    for (final c in _items) {
      if (c.active && now - c.born >= lifeMs) c.active = false;
    }
  }

  void clear() {
    for (final c in _items) {
      c.active = false;
    }
  }
}

/// Draws each crumb as a small bungeoppang ([fish], the equipped flavour)
/// that pops up from the tap, turning and fading; plain squares if the
/// sprite is missing.
class CrumbPainter extends CustomPainter {
  // Concept crust colours, light to dark.
  static const _shades = [
    Color(0xfff4c180),
    Color(0xffe39e57),
    Color(0xffc47942)
  ];
  static const _pixel = 3.0;
  final CrumbPool pool;
  final int now;
  final ui.Image? fish;
  CrumbPainter(this.pool, this.now, {this.fish});

  static final _sprite = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final c in pool.active) {
      final s = (now - c.born) / 1000;
      final fade = (1 - (now - c.born) / pool.lifeMs).clamp(0.0, 1.0);
      // Rises fast, slows down near the top.
      final x = c.x + c.vx * s, y = c.y + c.vy * s * 1.4 + 260 * s * s;
      final image = fish;
      if (image == null) {
        paint.color = _shades[c.shade].withValues(alpha: fade);
        final side = c.size < 4 ? _pixel * 2 : _pixel * 3;
        canvas.drawRect(Rect.fromLTWH(_snap(x), _snap(y), side, side), paint);
        continue;
      }
      final w = 10 + c.size * 3, h = w * image.height / image.width;
      _sprite.color = Color.fromRGBO(255, 255, 255, fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.vx * s * .012);
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          _sprite);
      canvas.restore();
    }
  }

  static double _snap(double v) => (v / _pixel).roundToDouble() * _pixel;

  @override
  bool shouldRepaint(covariant CrumbPainter old) => true;
}

/// Scale of the tapped bungeoppang [t] (0..1) into the pop:
/// 1.0 -> 0.94 -> 1.06 -> 1.0, and 1 at rest.
double tapPopScale(double t) {
  if (t <= 0 || t >= 1) return 1;
  if (t < .3) return 1 - .06 * (t / .3);
  if (t < .7) return .94 + .12 * ((t - .3) / .4);
  return 1.06 - .06 * ((t - .7) / .3);
}
