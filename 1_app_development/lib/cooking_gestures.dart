import 'dart:math' as math;
import 'cooking_input.dart';
import 'development_balance.dart';

class FillingGestureRules {
  final int minDistance,
      maxDurationMs,
      dominancePermille,
      rotationDegrees,
      minRadius;
  const FillingGestureRules(
      {required this.minDistance,
      required this.maxDurationMs,
      required this.dominancePermille,
      required this.rotationDegrees,
      required this.minRadius});
  factory FillingGestureRules.fromBalance(DevelopmentBalance config) {
    final row = config.section('manual_cooking');
    int read(String key) => DevelopmentBalance.integer(row, key);
    for (final key in [
      'filling_swipe_min_distance_px',
      'filling_swipe_max_duration_ms',
      'filling_swipe_dominance_permille',
      'filling_rotation_degrees',
      'filling_rotation_min_radius_px'
    ]) {
      if (read(key) <= 0) throw const FormatException('속 넣기 제스처 설정 오류');
    }
    if (read('filling_swipe_dominance_permille') < 1000)
      throw const FormatException('스와이프 주축 비율 오류');
    return FillingGestureRules(
        minDistance: read('filling_swipe_min_distance_px'),
        maxDurationMs: read('filling_swipe_max_duration_ms'),
        dominancePermille: read('filling_swipe_dominance_permille'),
        rotationDegrees: read('filling_rotation_degrees'),
        minRadius: read('filling_rotation_min_radius_px'));
  }
}

/// Geometry only: gestures never own or mutate a cooking session.
class FillingSwipe {
  final double x, y;
  final int startedMs;
  final FillingGestureRules rules;
  const FillingSwipe(this.x, this.y, this.startedMs, {required this.rules});
  CookingDirection? finish(double endX, double endY, int endedMs) {
    final dx = endX - x, dy = endY - y;
    final duration = endedMs - startedMs;
    if (duration < 0 ||
        duration > rules.maxDurationMs ||
        dx.abs() < rules.minDistance ||
        dx.abs() * 1000 < dy.abs() * rules.dominancePermille) return null;
    return dx < 0 ? CookingDirection.left : CookingDirection.right;
  }
}

class FillingRotation {
  final FillingGestureRules rules;
  FillingRotation(this.rules);
  double get targetRadians => rules.rotationDegrees * math.pi / 180;
  double? _lastAngle;
  double radians = 0;
  void sample(double x, double y) {
    // Crossing the bowl center cannot create a half turn for free.
    if (x * x + y * y < rules.minRadius * rules.minRadius) {
      _lastAngle = null;
      return;
    }
    final angle = math.atan2(y, x), previous = _lastAngle;
    _lastAngle = angle;
    if (previous == null) return;
    var delta = angle - previous;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    radians += delta;
  }

  double get progress => (radians.abs() / targetRadians).clamp(0, 1);
  CookingDirection? finish() => radians.abs() + 0.000001 < targetRadians
      ? null
      : radians < 0
          ? CookingDirection.left
          : CookingDirection.right;
}
