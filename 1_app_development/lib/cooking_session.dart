import 'dart:convert';
import 'cooking_input.dart';
import 'cooking_paint.dart';
import 'development_balance.dart';

enum CookingPhase { firstBatter, filling, secondBatter, closing, flipping, cooking, result, canceled }

/// Explicit command state for the special bungeoppang mold. Flavor entry,
/// filling sequence and final technique policy are supplied by the caller,
/// never guessed.
///
/// The three piping steps record painted area (24번 5단계, DEC-031·032) as
/// permille pairs: `firstBatterCoverage/Amount`, `fillingCoverage/Amount`,
/// `secondBatterCoverage/Amount`, and the spilled paste `<step>Spill` when
/// there was any (4차 피드백 IC4, absent = 0). They are additive fields of schema 1 (G1):
/// the old hold-time fields `firstBatterMs`, `secondBatterMs` and
/// `fillingDurationMs` are still read from older saves, never written for a
/// new step. A step is done when either kind of record is present.
class CookingSession {
  final String id, flavor;
  final bool practice;
  final List<CookingDirection> fillingSequence;
  final CookingPhase phase;
  final int token, fillingIndex, wrongInputs;
  final int? donenessElapsedMs;

  /// Legacy hold times (older saves only).
  final int? firstBatterMs, secondBatterMs, fillingDurationMs;
  final PaintAmount? firstBatter, filling, secondBatter;
  const CookingSession._(this.id, this.flavor, this.practice, this.fillingSequence,
      this.phase, this.token, this.fillingIndex, this.wrongInputs,
      {this.donenessElapsedMs, this.firstBatterMs, this.secondBatterMs,
      this.fillingDurationMs, this.firstBatter, this.filling, this.secondBatter});

  factory CookingSession.start({required String id, required String flavor,
      required bool practice, required List<CookingDirection> fillingSequence}) {
    if (id.isEmpty || flavor.isEmpty || fillingSequence.isEmpty) {
      throw const FormatException('제작 진입 정보 오류');
    }
    return CookingSession._(id, flavor, practice, List.unmodifiable(fillingSequence),
        CookingPhase.firstBatter, 0, 0, 0);
  }
  bool get finished => phase == CookingPhase.result || phase == CookingPhase.canceled;
  bool get firstBatterDone => firstBatterMs != null || firstBatter != null;
  bool get secondBatterDone => secondBatterMs != null || secondBatter != null;
  bool get fillingSqueezed => fillingDurationMs != null || filling != null;

  CookingSession _copy({CookingPhase? phase, int? token, int? fillingIndex, int? wrongInputs,
      int? donenessElapsedMs, PaintAmount? firstBatter, PaintAmount? filling,
      PaintAmount? secondBatter}) =>
    CookingSession._(id, flavor, practice, fillingSequence, phase ?? this.phase,
      token ?? this.token, fillingIndex ?? this.fillingIndex, wrongInputs ?? this.wrongInputs,
      donenessElapsedMs: donenessElapsedMs ?? this.donenessElapsedMs,
      firstBatterMs: firstBatterMs, secondBatterMs: secondBatterMs,
      fillingDurationMs: fillingDurationMs,
      firstBatter: firstBatter ?? this.firstBatter, filling: filling ?? this.filling,
      secondBatter: secondBatter ?? this.secondBatter);
  CookingSession _next(CookingPhase phase, {int? fillingIndex, int? wrongInputs,
      int? donenessElapsedMs, PaintAmount? firstBatter, PaintAmount? secondBatter}) =>
    _copy(phase: phase, token: token + 1, fillingIndex: fillingIndex, wrongInputs: wrongInputs,
      donenessElapsedMs: donenessElapsedMs, firstBatter: firstBatter, secondBatter: secondBatter);

  /// One brush stroke of batter. A stale event is ignored; an empty stroke
  /// (nothing painted in the fish, G3) is never a step.
  CookingSession pour(int eventToken, PaintAmount paint) {
    if (eventToken != token || finished) return this;
    if (!paint.valid) throw const FormatException('반죽 칠 양 오류');
    if (phase == CookingPhase.firstBatter) return _next(CookingPhase.filling, firstBatter: paint);
    if (phase == CookingPhase.secondBatter) return _next(CookingPhase.closing, secondBatter: paint);
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
  /// Piping-bag stroke of filling. Retains the old sequence/token encoding for
  /// saved sessions, but consumes the remaining legacy filling steps as one
  /// atomic action.
  CookingSession squeezeFilling(int eventToken, PaintAmount paint) {
    if(eventToken != token || phase != CookingPhase.filling) return this;
    if(!paint.valid) throw const FormatException('속 칠 양 오류');
    var next = this;
    while(next.phase == CookingPhase.filling) {
      next = next.fill(next.token, next.fillingSequence[next.fillingIndex]);
    }
    return next._copy(filling: paint);
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
    if(fillingDurationMs != null) 'fillingDurationMs': fillingDurationMs,
    if(firstBatter != null) ...{'firstBatterCoverage': firstBatter!.coverage, 'firstBatterAmount': firstBatter!.amount,
      if (firstBatter!.spill > 0) 'firstBatterSpill': firstBatter!.spill},
    if(filling != null) ...{'fillingCoverage': filling!.coverage, 'fillingAmount': filling!.amount,
      if (filling!.spill > 0) 'fillingSpill': filling!.spill},
    if(secondBatter != null) ...{'secondBatterCoverage': secondBatter!.coverage, 'secondBatterAmount': secondBatter!.amount,
      if (secondBatter!.spill > 0) 'secondBatterSpill': secondBatter!.spill},
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
    PaintAmount? paint(String stage) {
      final coverage = amount('${stage}Coverage'), total = amount('${stage}Amount');
      final spill = amount('${stage}Spill');
      if (coverage == null && total == null && spill == null) return null;
      final value = PaintAmount(coverage ?? 0, total ?? 0, spill ?? 0);
      if (coverage == null || total == null || !value.valid) throw const FormatException('칠 양 기록 오류');
      return value;
    }
    final fillingMs = amount('fillingDurationMs');
    final fillingPaint = paint('filling');
    final phase = CookingPhase.values.firstWhere((p) => p.name == row['phase']);
    final token = DevelopmentBalance.integer(row, 'token');
    final index = DevelopmentBalance.integer(row, 'fillingIndex');
    final wrong = DevelopmentBalance.integer(row, 'wrongInputs');
    final firstMs = amount('firstBatterMs'), secondMs = amount('secondBatterMs'), elapsed = amount('donenessElapsedMs');
    final firstPaint = paint('firstBatter'), secondPaint = paint('secondBatter');
    if ((firstMs != null && firstPaint != null) || (secondMs != null && secondPaint != null) ||
        (fillingMs != null && fillingPaint != null) ||
        (firstMs != null && firstMs < 0) || (secondMs != null && secondMs < 0)) {
      throw const FormatException('반죽 기록 중복');
    }
    final first = firstMs != null || firstPaint != null, second = secondMs != null || secondPaint != null;
    final count = initial.fillingSequence.length;
    if((fillingMs != null || fillingPaint != null) && ((fillingMs ?? 0) < 0 || index != count ||
      ![CookingPhase.secondBatter,CookingPhase.closing,CookingPhase.flipping,CookingPhase.cooking,CookingPhase.result,CookingPhase.canceled].contains(phase))) {
      throw const FormatException('속 넣기 양 기록 불일치');
    }
    if (index > count || (!first && (index != 0 || wrong != 0 || second)) ||
        (second && index != count)) throw const FormatException('제작 진행 불일치');
    if (phase == CookingPhase.canceled) {
      if (elapsed != null || token < 1 || token > count + wrong + 5) throw const FormatException('취소 상태 오류');
    } else {
      final stage = phase.index;
      final expected = stage == 0 ? 0 : stage == 1 ? 1 + index + wrong : count + wrong + stage - 1;
      if ((stage == 0 && (first || index != 0 || wrong != 0)) ||
          (stage > 0 && !first) || (stage == 1 && index >= count) ||
          (stage >= 2 && index != count) ||
          ((stage >= 3) != second) || ((phase == CookingPhase.result) != (elapsed != null)) ||
          token != expected) throw const FormatException('제작 단계/순번 불일치');
    }
    return CookingSession._(initial.id, initial.flavor, initial.practice, initial.fillingSequence,
        phase, token, index, wrong, donenessElapsedMs: elapsed, firstBatterMs: firstMs,
        secondBatterMs: secondMs, fillingDurationMs: fillingMs, firstBatter: firstPaint,
        filling: fillingPaint, secondBatter: secondPaint);
  }

}

/// Only accept one event derivable from the current immutable session. Matching
/// IDs/tokens alone must not replace flavor, practice context or prior inputs.
bool isCookingSuccessor(CookingSession previous, CookingSession next) {
  if (next.id != previous.id || next.token <= previous.token) return false;
  final encoded = jsonEncode(next.toJson());
  const none = PaintAmount(0, 0);
  final candidates = <CookingSession Function()>[
    () => previous.pour(previous.token, next.firstBatter ?? none),
    () => previous.pour(previous.token, next.secondBatter ?? none),
    () => previous.squeezeFilling(previous.token, next.filling ?? none),
    () => previous.fill(previous.token, CookingDirection.left),
    () => previous.fill(previous.token, CookingDirection.right),
    () => previous.close(previous.token),
    () => previous.flip(previous.token),
    () => previous.takeOut(previous.token, next.donenessElapsedMs ?? 0),
    () => previous.cancel(),
  ];
  for (final candidate in candidates) {
    try {
      if (jsonEncode(candidate().toJson()) == encoded) return true;
    } on FormatException { /* An ineligible event is not a successor. */ }
  }
  return false;
}
