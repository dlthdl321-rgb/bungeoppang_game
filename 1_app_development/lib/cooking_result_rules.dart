import 'dart:math' as math;

import 'feedback_config.dart';
import 'cooking_paint.dart';
import 'cooking_session.dart';
import 'development_balance.dart';
import 'development_rules.dart';

const provisionalDonenessLabels = ['덜 익음', '부드러움', '미디엄', '바삭함', '타버림'];

enum BatterVerdict { ok, short, overflow, spill }

/// The two batter strokes judged together (4차 피드백 IC6: the first and
/// second batter are one mass, so a thin first pour can be made up by the
/// second): the poured total (inside the fish plus spilled, [PaintAmount.poured])
/// over `batter_total_overflow_amount_permille` is too much — '흘림' when
/// the inside alone would have fit (IC4), '넘침' otherwise; less than
/// `batter_total_min_amount_permille` inside the fish, or neither stroke
/// covering `batter_min_coverage_permille` (the two layers together cover
/// at least the larger one), is too little. Too much wins over too little.
BatterVerdict batterTotalVerdict(DevelopmentBalance config, PaintAmount first, PaintAmount second) {
  final manual = config.section('manual_cooking');
  final cap = DevelopmentBalance.integer(manual, 'batter_total_overflow_amount_permille');
  if (first.poured + second.poured > cap) {
    return first.amount + second.amount > cap ? BatterVerdict.overflow : BatterVerdict.spill;
  }
  final short = first.amount + second.amount <
          DevelopmentBalance.integer(manual, 'batter_total_min_amount_permille') ||
      math.max(first.coverage, second.coverage) <
          DevelopmentBalance.integer(manual, 'batter_min_coverage_permille');
  return short ? BatterVerdict.short : BatterVerdict.ok;
}

/// Whether the batter poured so far ([before], the first stroke while the
/// second is being painted) and [paint] together are past the total line,
/// for the live caption and the drips.
bool batterOverflowed(DevelopmentBalance config, PaintAmount paint, {PaintAmount? before}) =>
    paint.poured + (before?.poured ?? 0) >
    DevelopmentBalance.integer(config.section('manual_cooking'), 'batter_total_overflow_amount_permille');

/// Whether one filling stroke is past the overflow line (shown only; the
/// filling is not judged).
bool paintOverflowed(DevelopmentBalance config, PaintAmount paint) =>
    paint.poured > DevelopmentBalance.integer(config.section('manual_cooking'), 'paint_overflow_amount_permille');

/// The judged batter of a finished [session], or null when a step came
/// from an older hold-time save (no area, G1).
BatterVerdict? sessionBatterVerdict(DevelopmentBalance config, CookingSession session) {
  final first = session.firstBatter, second = session.secondBatter;
  if (first == null || second == null) return null;
  return batterTotalVerdict(config, first, second);
}

/// Why a finished session's batter failed, for the result caption (G6):
/// '반죽 넘침', '반죽 흘림', '반죽 부족', or null when the two strokes
/// together were fine (or a step came from an older hold-time save, which
/// has no area to show).
String? batterFailureLabel(DevelopmentBalance config, CookingSession session) =>
    switch (sessionBatterVerdict(config, session)) {
      BatterVerdict.overflow => '반죽 넘침',
      BatterVerdict.spill => '반죽 흘림',
      BatterVerdict.short => '반죽 부족',
      _ => null,
    };

/// User-approved technique structure; all thresholds remain provisional.
/// The two batter strokes together must pass the area rule
/// ([batterTotalVerdict]) and the doneness must be in
/// `success_doneness_min_index`~`max_index`. The filling is not judged. A
/// batter step recorded by the old hold time (older saves, G1) fails.
MasteryResult evaluateCookingResult(DevelopmentBalance config, CookingSession session,
    {required int difficulty}) {
  if (session.phase != CookingPhase.result) throw const FormatException('미완료 제작 판정 금지');
  final row = config.mastery(difficulty);
  final variant = provisionalDoneness(config, elapsedMs: session.donenessElapsedMs!, difficulty: difficulty);
  final pass = sessionBatterVerdict(config, session) == BatterVerdict.ok &&
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

/// From the top: **perfect** = technique passed, the larger batter stroke
/// covers ≥ `cooking_grade.perfect_min_coverage_permille`, the two strokes'
/// amount together is ≤ `perfect_max_total_amount_permille` with at most
/// `perfect_max_spill_permille` spilled (4차 피드백 IC4·IC6), and the doneness is
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
  final first = session.firstBatter, second = session.secondBatter;
  final neat = first != null && second != null &&
      math.max(first.coverage, second.coverage) >= DevelopmentBalance.integer(grade, 'perfect_min_coverage_permille') &&
      first.amount + second.amount <= DevelopmentBalance.integer(grade, 'perfect_max_total_amount_permille') &&
      first.spill + second.spill <= DevelopmentBalance.integer(grade, 'perfect_max_spill_permille');
  return neat && variant == DevelopmentBalance.integer(grade, 'perfect_doneness_index')
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
        '반죽 흘림' => '반죽을 틀 밖으로 흘렸어요',
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

/// How many stars (of [cookingStarsMax]) a bake of [grade] shows
/// (26번 3차 피드백 H24, feedback_config.dart).
int cookingStars(CookingGrade grade) => switch (grade) {
      CookingGrade.perfect => cookingStarsPerfect,
      CookingGrade.good => cookingStarsGood,
      CookingGrade.near => cookingStarsNear,
      CookingGrade.fail => cookingStarsFail,
    };
