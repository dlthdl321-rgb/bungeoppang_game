import 'dart:math' as math;
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

class CrumbPainter extends CustomPainter {
  static const _shades = [
    Color(0xffe9a54b),
    Color(0xffc77a2c),
    Color(0xfff6d28a)
  ];
  final CrumbPool pool;
  final int now;
  CrumbPainter(this.pool, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final c in pool.active) {
      final s = (now - c.born) / 1000;
      final fade = (1 - (now - c.born) / pool.lifeMs).clamp(0.0, 1.0);
      paint.color = _shades[c.shade].withValues(alpha: fade);
      canvas.drawCircle(
          Offset(c.x + c.vx * s, c.y + c.vy * s + 420 * s * s), c.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CrumbPainter old) => true;
}

/// Squash on impact, stretch on rebound; 0 at rest. [t] in 0..1.
double squashAmount(double t) =>
    t <= 0 || t >= 1 ? 0 : math.sin(t * math.pi * 2) * (1 - t);
