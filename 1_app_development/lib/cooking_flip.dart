import 'dart:math' as math;

import 'development_balance.dart';

/// Circles drawn round the special bungeoppang mold to flip it (24번 6단계
/// DEC-034, back again by 4차 피드백 IC5: '위로 밀기 대신 원 그리기', and
/// the mold turns with the circle). Pure: the screen feeds finger points
/// relative to the mold's centre and reads [degrees] / [progress] / [done].
///
/// The angle swept around the centre adds up with its sign (clockwise on
/// screen is positive), so turning back takes degrees off and either
/// direction may finish. Points closer to the centre than [deadRadius] are
/// ignored and also break the chain: the next point outside starts from
/// itself, so circling at the centre or cutting straight across it adds
/// nothing. Once [targetDegrees] is reached the circle is [done] and later
/// points change nothing until [reset].
class FlipCircle {
  final double deadRadius;
  final int targetDegrees;
  double _degrees = 0;
  double? _last;
  bool _done = false;

  FlipCircle({required this.deadRadius, required this.targetDegrees}) {
    if (!deadRadius.isFinite || deadRadius < 0 || targetDegrees <= 0) {
      throw const FormatException('뒤집기 원 설정 오류');
    }
  }

  /// [moldWidth] is the mold's width in the same units as the points
  /// (manual_cooking `flip_dead_zone_permille`, `flip_turn_degrees`).
  factory FlipCircle.forMold(DevelopmentBalance config, double moldWidth) {
    final manual = config.section('manual_cooking');
    return FlipCircle(
        deadRadius: moldWidth * DevelopmentBalance.integer(manual, 'flip_dead_zone_permille') / 1000,
        targetDegrees: DevelopmentBalance.integer(manual, 'flip_turn_degrees'));
  }

  /// Signed swept angle in degrees (clockwise on screen > 0).
  double get degrees => _degrees;
  bool get done => _done;

  /// 0..1 of the way to [targetDegrees], whichever way it turns.
  double get progress => math.min(1, _degrees.abs() / targetDegrees);

  /// The mold's turn over its axle for this circle: [progress] of a half
  /// turn, with the circle's direction.
  double get moldDegrees => (_degrees < 0 ? -180 : 180) * progress;

  /// The finger moved to ([dx], [dy]) from the mold's centre.
  void moveTo(double dx, double dy) {
    if (_done || !dx.isFinite || !dy.isFinite) return;
    if (dx * dx + dy * dy <= deadRadius * deadRadius) {
      _last = null;
      return;
    }
    final angle = math.atan2(dy, dx);
    final last = _last;
    _last = angle;
    if (last == null) return;
    var delta = angle - last;
    // The short way round: one move never sweeps more than half a turn.
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta <= -math.pi) {
      delta += 2 * math.pi;
    }
    _degrees += delta * 180 / math.pi;
    if (_degrees.abs() >= targetDegrees) _done = true;
  }

  /// Back to 0 degrees (the finger lifted early, or the stroke was dropped).
  void reset() {
    _degrees = 0;
    _last = null;
    _done = false;
  }
}
