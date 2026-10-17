import 'development_balance.dart';

enum CookingDirection { left, right }

/// Device-independent input gate. Native adapters convert angles to integer
/// millidegrees; no hardware, permission, telemetry or gameplay side effects.
class TiltDirectionGate {
  final int activation, deadZone;
  int? _baseline;
  bool _armed = true;
  TiltDirectionGate({required this.activation, required this.deadZone}) {
    if (activation <= 0 || deadZone < 0 || deadZone >= activation) {
      throw const FormatException('기울기 입력 구간 오류');
    }
  }
  factory TiltDirectionGate.fromBalance(DevelopmentBalance config) {
    final row = config.section('manual_cooking');
    return TiltDirectionGate(
      activation: DevelopmentBalance.integer(row, 'tilt_activation_degrees') * 1000,
      deadZone: DevelopmentBalance.integer(row, 'tilt_dead_zone_degrees') * 1000);
  }
  bool get calibrated => _baseline != null;
  void calibrate(int angleMillidegrees) {
    _baseline = angleMillidegrees;
    _armed = true;
  }
  void reset() { _baseline = null; _armed = true; }
  CookingDirection? sample(int angleMillidegrees) {
    final baseline = _baseline;
    if (baseline == null) return null;
    final delta = (angleMillidegrees - baseline + 180000) % 360000 - 180000;
    if (delta.abs() <= deadZone) _armed = true;
    if (!_armed || delta.abs() < activation) return null;
    _armed = false;
    return delta < 0 ? CookingDirection.left : CookingDirection.right;
  }
}

/// One stage token + one pointer. Pointer cancel, navigation, source switch or
/// app pause discards the unfinished hold and cannot confirm the next stage.
class BatterHoldInput {
  final int stageToken;
  int? _pointer, _startedAt, _lastAt;
  BatterHoldInput(this.stageToken);
  bool get active => _pointer != null;
  bool ownsPointer(int pointer) => _pointer == pointer;
  void begin({required int token, required int pointer, required int monotonicMs}) {
    if (token != stageToken || active || monotonicMs < 0) {
      throw const FormatException('반죽 입력 시작 오류');
    }
    _pointer = pointer; _startedAt = monotonicMs; _lastAt = monotonicMs;
  }
  int? elapsed({required int token, required int pointer, required int monotonicMs}) {
    if (token != stageToken || pointer != _pointer) return null;
    if (_lastAt == null || monotonicMs < _lastAt!) {
      cancel();
      throw const FormatException('입력 시계 역행');
    }
    _lastAt = monotonicMs;
    return monotonicMs - _startedAt!;
  }
  int? finish({required int token, required int pointer, required int monotonicMs}) {
    final result = elapsed(token: token, pointer: pointer, monotonicMs: monotonicMs);
    if (result != null) cancel();
    return result;
  }
  void cancel() { _pointer = null; _startedAt = null; _lastAt = null; }
}
