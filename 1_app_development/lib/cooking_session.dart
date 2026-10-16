import 'cooking_input.dart';
import 'development_balance.dart';

enum CookingPhase { firstBatter, filling, secondBatter, closing, flipping, cooking, result, canceled }

/// Explicit command state shared by sensor and touch UI. Flavor entry, filling
/// sequence and final technique policy are supplied by the caller, never guessed.
class CookingSession {
  final String id, flavor;
  final bool practice;
  final List<CookingDirection> fillingSequence;
  final CookingPhase phase;
  final int token, fillingIndex, wrongInputs;
  final int? firstBatterMs, secondBatterMs, donenessElapsedMs;
  CookingSession._(this.id, this.flavor, this.practice, this.fillingSequence,
      this.phase, this.token, this.fillingIndex, this.wrongInputs,
      this.firstBatterMs, this.secondBatterMs, this.donenessElapsedMs);

  factory CookingSession.start({required String id, required String flavor,
      required bool practice, required List<CookingDirection> fillingSequence}) {
    if (id.isEmpty || flavor.isEmpty || fillingSequence.isEmpty) {
      throw const FormatException('제작 진입 정보 오류');
    }
    return CookingSession._(id, flavor, practice, List.unmodifiable(fillingSequence),
        CookingPhase.firstBatter, 0, 0, 0, null, null, null);
  }
  bool get finished => phase == CookingPhase.result || phase == CookingPhase.canceled;
  CookingSession _next(CookingPhase phase, {int? fillingIndex, int? wrongInputs,
      int? firstBatterMs, int? secondBatterMs, int? donenessElapsedMs}) =>
    CookingSession._(id, flavor, practice, fillingSequence, phase, token + 1,
      fillingIndex ?? this.fillingIndex, wrongInputs ?? this.wrongInputs,
      firstBatterMs ?? this.firstBatterMs, secondBatterMs ?? this.secondBatterMs,
      donenessElapsedMs ?? this.donenessElapsedMs);

  /// A stale release/direction event is ignored, rather than forwarded.
  CookingSession pour(int eventToken, int durationMs) {
    if (eventToken != token || finished) return this;
    if (durationMs < 0) throw const FormatException('음수 반죽 시간');
    if (phase == CookingPhase.firstBatter) return _next(CookingPhase.filling, firstBatterMs: durationMs);
    if (phase == CookingPhase.secondBatter) return _next(CookingPhase.closing, secondBatterMs: durationMs);
    return this;
  }
  CookingSession fill(int eventToken, CookingDirection direction) {
    if (eventToken != token || phase != CookingPhase.filling) return this;
    if (direction != fillingSequence[fillingIndex]) {
      return _next(phase, wrongInputs: wrongInputs + 1);
    }
    final index = fillingIndex + 1;
    return _next(index == fillingSequence.length ? CookingPhase.secondBatter : phase,
        fillingIndex: index);
  }
  CookingSession close(int eventToken) => eventToken == token && phase == CookingPhase.closing
      ? _next(CookingPhase.flipping) : this;
  CookingSession flip(int eventToken) => eventToken == token && phase == CookingPhase.flipping
      ? _next(CookingPhase.cooking) : this;
  CookingSession takeOut(int eventToken, int elapsedMs) {
    if (eventToken != token || phase != CookingPhase.cooking) return this;
    if (elapsedMs < 0) throw const FormatException('음수 굽기 시간');
    return _next(CookingPhase.result, donenessElapsedMs: elapsedMs);
  }
  CookingSession cancel() => finished ? this : _next(CookingPhase.canceled);
  Map<String, dynamic> toJson() => {'schema': 1, 'id': id, 'flavor': flavor,
    'practice': practice, 'fillingSequence': fillingSequence.map((d) => d.name).toList(),
    'phase': phase.name, 'token': token, 'fillingIndex': fillingIndex, 'wrongInputs': wrongInputs,
    'firstBatterMs': firstBatterMs, 'secondBatterMs': secondBatterMs, 'donenessElapsedMs': donenessElapsedMs};
  factory CookingSession.fromJson(Map<String, dynamic> row) {
    final directions = row['fillingSequence'];
    if (row['schema'] is! int || row['schema'] != 1 || row['id'] is! String ||
        row['flavor'] is! String || row['practice'] is! bool || directions is! List ||
        directions.isEmpty || directions.any((d) => !['left', 'right'].contains(d)) ||
        !CookingPhase.values.any((p) => p.name == row['phase'])) {
      throw const FormatException('제작 저장 형식 오류');
    }
    final initial = CookingSession.start(id: row['id'] as String, flavor: row['flavor'] as String,
      practice: row['practice'] as bool, fillingSequence: directions.map((d) =>
          d == 'left' ? CookingDirection.left : CookingDirection.right).toList());
    int? amount(String key) => row[key] == null ? null : DevelopmentBalance.integer(row, key);
    final phase = CookingPhase.values.firstWhere((p) => p.name == row['phase']);
    final token = DevelopmentBalance.integer(row, 'token');
    final index = DevelopmentBalance.integer(row, 'fillingIndex');
    final wrong = DevelopmentBalance.integer(row, 'wrongInputs');
    final first = amount('firstBatterMs'), second = amount('secondBatterMs'), elapsed = amount('donenessElapsedMs');
    final count = initial.fillingSequence.length;
    if (index > count || (first == null && (index != 0 || wrong != 0 || second != null)) ||
        (second != null && index != count)) throw const FormatException('제작 진행 불일치');
    if (phase == CookingPhase.canceled) {
      if (elapsed != null || token < 1 || token > count + wrong + 5) throw const FormatException('취소 상태 오류');
    } else {
      final stage = phase.index;
      final expected = stage == 0 ? 0 : stage == 1 ? 1 + index + wrong : count + wrong + stage - 1;
      if ((stage == 0 && (first != null || index != 0 || wrong != 0)) ||
          (stage > 0 && first == null) || (stage == 1 && index >= count) ||
          (stage >= 2 && index != count) ||
          ((stage >= 3) != (second != null)) || ((phase == CookingPhase.result) != (elapsed != null)) ||
          token != expected) throw const FormatException('제작 단계/순번 불일치');
    }
    return CookingSession._(initial.id, initial.flavor, initial.practice, initial.fillingSequence,
        phase, token, index, wrong, first, second, elapsed);
  }

}
