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

/// How a finished bake is shown (26번 4단계): presentation only. The
/// technique pass, mastery, stock and sale price stay those of
/// [evaluateCookingResult] (DEC-031~034·040).
enum CookingGrade { perfect, good, near, fail }

/// From the top: **perfect** = technique passed, both batter strokes cover
/// ≥ `cooking_grade.perfect_min_coverage_permille` with an amount ≤
/// `perfect_max_amount_permille`, and the doneness is
/// `perfect_doneness_index` (미디엄); **good** = technique passed; **near**
/// = technique failed but the doneness is still in the success range (short
/// or spilled batter, an older hold-time save); **fail** = the doneness is
/// outside it (덜 익음·타버림).
CookingGrade cookingGrade(DevelopmentBalance config, CookingSession session,
    {required int difficulty}) {
  final result = evaluateCookingResult(config, session, difficulty: difficulty);
  final row = config.mastery(difficulty);
  final variant = result.variant;
  if (variant < DevelopmentBalance.integer(row, 'success_doneness_min_index') ||
      variant > DevelopmentBalance.integer(row, 'success_doneness_max_index')) {
    return CookingGrade.fail;
  }
  if (!result.techniquePassed) return CookingGrade.near;
  final grade = config.section('cooking_grade');
  bool neat(PaintAmount? paint) => paint != null &&
      paint.coverage >= DevelopmentBalance.integer(grade, 'perfect_min_coverage_permille') &&
      paint.amount <= DevelopmentBalance.integer(grade, 'perfect_max_amount_permille');
  return neat(session.firstBatter) && neat(session.secondBatter) &&
          variant == DevelopmentBalance.integer(grade, 'perfect_doneness_index')
      ? CookingGrade.perfect : CookingGrade.good;
}

/// The big word of [grade] on the result screen.
String cookingGradeTitle(CookingGrade grade) => switch (grade) {
      CookingGrade.perfect => '완벽해요!',
      CookingGrade.good => '잘 구웠어요!',
      CookingGrade.near => '아깝다!',
      CookingGrade.fail => '다음엔 더 잘할 수 있어요',
    };

/// The short praise or reason under the title.
String cookingGradeLine(DevelopmentBalance config, CookingSession session, CookingGrade grade,
    {required int variant}) {
  switch (grade) {
    case CookingGrade.perfect:
      return '겉은 바삭, 속은 촉촉!';
    case CookingGrade.good:
      return switch (variant) {
        1 => '부드럽게 잘 익었어요',
        3 => '바삭하게 잘 익었어요',
        _ => '알맞게 잘 익었어요',
      };
    case CookingGrade.near:
      return switch (batterFailureLabel(config, session)) {
        '반죽 넘침' => '반죽이 넘쳤어요',
        '반죽 부족' => '반죽이 조금 모자랐어요',
        _ => '조금만 더 하면 돼요',
      };
    case CookingGrade.fail:
      return variant == 0 ? '덜 익었어요' : '타버렸어요';
  }
}

/// The common dialogue event of an order customer's reaction to [grade]
/// (config/customer_content.json `common_dialogues`).
String cookingGradeEvent(CookingGrade grade) => switch (grade) {
      CookingGrade.perfect => 'result_perfect',
      CookingGrade.good => 'result_good',
      CookingGrade.near => 'result_near',
      CookingGrade.fail => 'result_fail',
    };
