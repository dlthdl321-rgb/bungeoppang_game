import 'cooking_session.dart';
import 'development_balance.dart';
import 'development_rules.dart';

const provisionalDonenessLabels = ['덜 익음', '부드러움', '미디엄', '바삭함', '타버림'];

/// User-approved technique structure; all targets/tolerances remain provisional.
MasteryResult evaluateCookingResult(DevelopmentBalance config, CookingSession session,
    {required int difficulty}) {
  if (session.phase != CookingPhase.result) throw const FormatException('미완료 제작 판정 금지');
  final row = config.mastery(difficulty);
  final target = DevelopmentBalance.integer(row, 'batter_target_ms');
  final tolerance = DevelopmentBalance.integer(row, 'batter_tolerance_permille');
  bool within(int ms) => BigInt.from((ms - target).abs()) * BigInt.from(1000) <=
      BigInt.from(target) * BigInt.from(tolerance);
  final variant = provisionalDoneness(config, elapsedMs: session.donenessElapsedMs!, difficulty: difficulty);
  final pass = within(session.firstBatterMs!) && within(session.secondBatterMs!) &&
      (session.fillingDurationMs != null || session.wrongInputs <= DevelopmentBalance.integer(row, 'wrong_filling_inputs_allowed')) &&
      variant >= DevelopmentBalance.integer(row, 'success_doneness_min_index') &&
      variant <= DevelopmentBalance.integer(row, 'success_doneness_max_index');
  return MasteryResult(id: session.id, flavor: session.flavor, variant: variant,
      completed: true, practice: session.practice, techniquePassed: pass);
}
