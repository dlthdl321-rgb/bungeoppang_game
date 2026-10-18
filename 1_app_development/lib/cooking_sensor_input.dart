import 'cooking_input.dart';
import 'cooking_session.dart';

/// Sensor and touch share commands. New stages require a fresh neutral gesture.
class CookingSensorInput {
  final TiltDirectionGate gate;
  String? _sessionId;
  int? _token, _baseline;
  bool _neutralRequired = true;
  BatterHoldInput? _hold;
  CookingSensorInput(this.gate);
  bool get calibrated => gate.calibrated;
  bool get pouring => _hold?.active ?? false;
  bool get waitingNeutral => _neutralRequired;

  void interrupt() {
    _hold?.cancel();
    _hold = null;
    _sessionId = null;
    _token = null;
    _neutralRequired = true;
  }

  void reset() {
    _hold?.cancel();
    _hold = null;
    _sessionId = null;
    _token = null;
    _baseline = null;
    _neutralRequired = true;
    gate.reset();
  }

  CookingSession? sample(CookingSession session, int angle, int monotonicMs) {
    if (!gate.calibrated) {
      _baseline = angle;
      gate.calibrate(angle);
      _sessionId = session.id;
      _token = session.token;
      return null;
    }
    if (_sessionId != session.id || _token != session.token) {
      _hold?.cancel();
      _hold = null;
      _sessionId = session.id;
      _token = session.token;
      _neutralRequired = true;
    }
    final delta = ((angle - _baseline! + 180000) % 360000 - 180000).abs();
    if (_neutralRequired) {
      if (delta <= gate.deadZone) {
        _neutralRequired = false;
        gate.sample(angle);
      }
      return null;
    }
    if (session.phase == CookingPhase.firstBatter ||
        session.phase == CookingPhase.secondBatter) {
      final hold = _hold ??= BatterHoldInput(session.token);
      if (delta >= gate.activation && !hold.active) {
        hold.begin(token: session.token, pointer: -2, monotonicMs: monotonicMs);
      } else if (delta <= gate.deadZone && hold.active) {
        final duration = hold.finish(
            token: session.token, pointer: -2, monotonicMs: monotonicMs);
        if (duration != null) return session.pour(session.token, duration);
      }
      return null;
    }
    _hold?.cancel();
    _hold = null;
    if (session.phase != CookingPhase.filling) return null;
    final direction = gate.sample(angle);
    return direction == null ? null : session.fill(session.token, direction);
  }
}
