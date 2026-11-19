import 'dart:math' as math;

import 'feedback_config.dart';

/// One push of the special bungeoppang mold over its axle to flip it
/// (26번 3차 피드백 H21, replacing 24번 6단계's circle drawn round the
/// mold). Pure: the screen feeds the finger's screen y and reads
/// [degrees] / [done].
///
/// The mold hangs on an axle through its side rings; the finger pushes
/// its edge up (or down). Travel of one mold [height] turns it
/// [flipAxleDegreesPerHeight] degrees, with its sign (up > 0), so pulling
/// back takes the turn off and either way may finish. Under
/// [flipAxleStartPx] of travel nothing turns (a touch, not a push). Once
/// the turn reaches [doneDegrees] it is [done] and later moves change
/// nothing until [reset].
class FlipAxle {
  final double height, startY;
  final double doneDegrees;
  double _degrees = 0;
  bool _done = false;

  FlipAxle({required this.height, required this.startY, this.doneDegrees = flipAxleDoneDegrees}) {
    if (!height.isFinite || height <= 0 || !startY.isFinite || doneDegrees <= 0 || doneDegrees > 180) {
      throw const FormatException('뒤집기 축 설정 오류');
    }
  }

  /// Signed turn in degrees (pushed up > 0), at most a half turn.
  double get degrees => _degrees;
  bool get done => _done;

  /// 0..1 of the way to [doneDegrees], whichever way it turns.
  double get progress => math.min(1, _degrees.abs() / doneDegrees);

  /// The finger is now at screen [y].
  void moveTo(double y) {
    if (_done || !y.isFinite) return;
    final travel = startY - y;
    if (travel.abs() < flipAxleStartPx) {
      _degrees = 0;
      return;
    }
    _degrees = (travel / height * flipAxleDegreesPerHeight).clamp(-180.0, 180.0);
    if (_degrees.abs() >= doneDegrees) _done = true;
  }

  /// Back flat (the finger lifted early, or the push was dropped).
  void reset() {
    _degrees = 0;
    _done = false;
  }
}
