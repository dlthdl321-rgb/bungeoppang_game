import 'cooking_paint.dart';
import 'cooking_session.dart';
import 'development_balance.dart';
import 'development_rules.dart';

const provisionalDonenessLabels = ['덜 익음', '부드러움', '미디엄', '바삭함', '타버림'];

enum BatterVerdict { ok, short, overflow }

/// One batter stroke against the manual_cooking area rule (DEC-031):
/// coverage ≥ `batter_min_coverage_permille` and amount ≤
/// `paint_overflow_amount_permille`. Overflow wins over short.
BatterVerdict batterVerdict(DevelopmentBalance config, PaintAmount paint) {
  final manual = config.section('manual_cooking');
  if (paint.amount > DevelopmentBalance.integer(manual, 'paint_overflow_amount_permille')) {
    return BatterVerdict.overflow;
  }
  return paint.coverage >= DevelopmentBalance.integer(manual, 'batter_min_coverage_permille')
      ? BatterVerdict.ok : BatterVerdict.short;
}

/// Whether [paint] is past the overflow line (also shown for the filling,
/// which is not judged).
bool paintOverflowed(DevelopmentBalance config, PaintAmount paint) =>
    paint.amount > DevelopmentBalance.integer(config.section('manual_cooking'), 'paint_overflow_amount_permille');

/// Why a finished session's batter failed, for the result caption (G6):
/// '반죽 넘침', '반죽 부족', or null when both strokes were fine (or a step
/// came from an older hold-time save, which has no area to show).
String? batterFailureLabel(DevelopmentBalance config, CookingSession session) {
  final verdicts = [session.firstBatter, session.secondBatter]
      .whereType<PaintAmount>().map((p) => batterVerdict(config, p));
  if (verdicts.contains(BatterVerdict.overflow)) return '반죽 넘침';
  if (verdicts.contains(BatterVerdict.short)) return '반죽 부족';
  return null;
}

/// User-approved technique structure; all thresholds remain provisional.
/// Both batter strokes must pass the area rule and the doneness must be in
/// `success_doneness_min_index`~`max_index`. The filling is not judged. A
/// batter step recorded by the old hold time (older saves, G1) fails.
MasteryResult evaluateCookingResult(DevelopmentBalance config, CookingSession session,
    {required int difficulty}) {
  if (session.phase != CookingPhase.result) throw const FormatException('미완료 제작 판정 금지');
  final row = config.mastery(difficulty);
  bool within(PaintAmount? paint) => paint != null && batterVerdict(config, paint) == BatterVerdict.ok;
  final variant = provisionalDoneness(config, elapsedMs: session.donenessElapsedMs!, difficulty: difficulty);
  final pass = within(session.firstBatter) && within(session.secondBatter) &&
      (session.fillingSqueezed || session.wrongInputs <= DevelopmentBalance.integer(row, 'wrong_filling_inputs_allowed')) &&
      variant >= DevelopmentBalance.integer(row, 'success_doneness_min_index') &&
      variant <= DevelopmentBalance.integer(row, 'success_doneness_max_index');
  return MasteryResult(id: session.id, flavor: session.flavor, variant: variant,
      completed: true, practice: session.practice, techniquePassed: pass);
}
