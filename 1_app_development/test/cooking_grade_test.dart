import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';

/// 26번 4단계(4차 g15에 '보통' 추가): 결과 등급(완벽·잘 구움·보통·아깝다·실패)은 보여 주기 전용이고
/// 판정(DEC-031~034·040)은 그대로다.
void main() {
  Map<String, dynamic> raw() => jsonDecode(File('config/development_balance.json').readAsStringSync())
      as Map<String, dynamic>;
  final config = DevelopmentBalance.fromJson(raw());

  CookingSession finished(PaintAmount first, PaintAmount second,
      {int bakeMs = 15000, bool practice = true}) {
    var s = CookingSession.start(id: 'grade', flavor: 'redbean', practice: practice,
        fillingSequence: [CookingDirection.left, CookingDirection.right]);
    s = s.pour(s.token, first);
    s = s.squeezeFilling(s.token, const PaintAmount(300, 2500));
    s = s.pour(s.token, second);
    s = s.close(s.token);
    s = s.flip(s.token);
    return s.takeOut(s.token, bakeMs);
  }

  CookingGrade grade(CookingSession s) => cookingGrade(config, s, difficulty: 0);

  test('설정값(4차 IC4·IC6): 넓은 쪽 덮음 950‰ 이상, 1·2차 합 양 2300‰ 이하, 흘림 50‰ 이하, 익힘 미디엄(2)', () {
    final g = config.section('cooking_grade');
    expect(DevelopmentBalance.integer(g, 'perfect_min_coverage_permille'), 950);
    expect(DevelopmentBalance.integer(g, 'perfect_max_total_amount_permille'), 2300);
    expect(DevelopmentBalance.integer(g, 'perfect_max_spill_permille'), 50);
    expect(DevelopmentBalance.integer(g, 'perfect_doneness_index'), 2);
  });

  test('완벽 경계: 넓은 쪽 덮음 949/950, 합 양 2300/2301, 흘림 50/51', () {
    const ok = PaintAmount(950, 1150);
    expect(grade(finished(ok, ok)), CookingGrade.perfect);
    expect(grade(finished(const PaintAmount(949, 1000), const PaintAmount(949, 1300))), CookingGrade.good);
    expect(grade(finished(const PaintAmount(949, 1000), const PaintAmount(950, 1300))), CookingGrade.perfect);
    expect(grade(finished(ok, const PaintAmount(1000, 1151))), CookingGrade.good);
    expect(grade(finished(const PaintAmount(1000, 1151), ok)), CookingGrade.good);
    expect(grade(finished(const PaintAmount(950, 1150, 25), const PaintAmount(950, 1150, 25))), CookingGrade.perfect);
    expect(grade(finished(const PaintAmount(950, 1150, 25), const PaintAmount(950, 1150, 26))), CookingGrade.good);
  });

  test('보통(4차 g15): 기법은 통과했지만 반죽이 잘 구움 기준(덮음 925‰·합 1900~2450‰·흘림 150‰) 밖', () {
    final g = config.section('cooking_grade');
    expect(DevelopmentBalance.integer(g, 'good_min_coverage_permille'), 925);
    expect(DevelopmentBalance.integer(g, 'good_min_total_amount_permille'), 1900);
    expect(DevelopmentBalance.integer(g, 'good_max_total_amount_permille'), 2450);
    expect(DevelopmentBalance.integer(g, 'good_max_spill_permille'), 150);
    // 덮음 924/925
    expect(grade(finished(const PaintAmount(924, 1000), const PaintAmount(924, 1000))), CookingGrade.fair);
    expect(grade(finished(const PaintAmount(925, 1000), const PaintAmount(924, 1000))), CookingGrade.good);
    // 합 1899/1900, 2450/2451
    expect(grade(finished(const PaintAmount(950, 950), const PaintAmount(900, 949))), CookingGrade.fair);
    expect(grade(finished(const PaintAmount(950, 950), const PaintAmount(950, 950))), CookingGrade.perfect);
    expect(grade(finished(const PaintAmount(1000, 1225), const PaintAmount(1000, 1225))), CookingGrade.good);
    expect(grade(finished(const PaintAmount(1000, 1225), const PaintAmount(1000, 1226))), CookingGrade.fair);
    // 흘림 150/151
    expect(grade(finished(const PaintAmount(950, 1000, 75), const PaintAmount(950, 1000, 75))), CookingGrade.good);
    expect(grade(finished(const PaintAmount(950, 1000, 75), const PaintAmount(950, 1000, 76))), CookingGrade.fair);
    // 이유 글
    String line(PaintAmount a, PaintAmount b) {
      final s = finished(a, b);
      return cookingGradeLine(config, s, grade(s), variant: 2);
    }
    expect(line(const PaintAmount(924, 1000), const PaintAmount(924, 1000)), '반죽이 군데군데 비었어요');
    expect(line(const PaintAmount(950, 950), const PaintAmount(900, 920)), '반죽이 살짝 적었어요');
    expect(line(const PaintAmount(1000, 1250), const PaintAmount(1000, 1250)), '반죽이 조금 많았어요');
    expect(line(const PaintAmount(950, 1000, 100), const PaintAmount(950, 1000, 100)), '반죽이 틀 밖으로 조금 흘렀어요');
    // 보통도 판정 통과(판매·숙련·재고는 잘 구움과 같음).
    expect(evaluateCookingResult(config, finished(const PaintAmount(924, 1000), const PaintAmount(924, 1000)),
        difficulty: 0).techniquePassed, isTrue);
  });

  test('익힘 0~4: 미디엄만 완벽, 1·3은 성공, 0·4는 실패', () {
    const even = PaintAmount.even;
    // Boundaries 600·900·1100·1400‰ of 15000 ms.
    final byBake = {5000: CookingGrade.fail, 12000: CookingGrade.good, 15000: CookingGrade.perfect,
        18000: CookingGrade.good, 25000: CookingGrade.fail};
    byBake.forEach((ms, expected) {
      final s = finished(even, even, bakeMs: ms);
      expect(grade(s), expected, reason: '$ms ms');
    });
    expect(cookingGradeLine(config, finished(even, even, bakeMs: 5000), CookingGrade.fail, variant: 0), '덜 익었어요');
    expect(cookingGradeLine(config, finished(even, even, bakeMs: 25000), CookingGrade.fail, variant: 4), '타버렸어요');
  });

  test('반죽 부족·넘침은 익힘이 맞으면 아쉬움, 타면 실패', () {
    final short = finished(const PaintAmount(880, 900), const PaintAmount(880, 880));
    expect(grade(short), CookingGrade.near);
    expect(cookingGradeLine(config, short, CookingGrade.near, variant: 2), '반죽이 조금 모자랐어요');
    final over = finished(const PaintAmount(1000, 1300), const PaintAmount(1000, 1400));
    expect(grade(over), CookingGrade.near);
    expect(cookingGradeLine(config, over, CookingGrade.near, variant: 2), '반죽이 넘쳤어요');
    expect(grade(finished(const PaintAmount(880, 900), const PaintAmount(880, 880), bakeMs: 25000)), CookingGrade.fail);
  });

  test('예전 길게 누르기 저장은 아쉬움', () {
    final start = CookingSession.start(id: 'old', flavor: 'redbean', practice: true,
        fillingSequence: [CookingDirection.left, CookingDirection.right]);
    var s = CookingSession.fromJson({...start.toJson(), 'phase': 'filling', 'token': 1, 'firstBatterMs': 2500});
    s = s.squeezeFilling(s.token, PaintAmount.even);
    s = s.pour(s.token, PaintAmount.even);
    s = s.close(s.token);
    s = s.flip(s.token);
    s = s.takeOut(s.token, 15000);
    expect(grade(s), CookingGrade.near);
    expect(cookingGradeLine(config, s, CookingGrade.near, variant: 2), '조금만 더 하면 돼요');
  });

  test('연습과 주문 제작은 같은 등급, 판정 결과는 그대로', () {
    const ok = PaintAmount(960, 1100);
    final practice = finished(ok, ok), order = finished(ok, ok, practice: false);
    expect(grade(practice), grade(order));
    for (final s in [
      practice,
      finished(const PaintAmount(949, 1000), ok),
      finished(const PaintAmount(880, 900), const PaintAmount(880, 880)),
      finished(ok, ok, bakeMs: 25000),
    ]) {
      final r = evaluateCookingResult(config, s, difficulty: 0);
      // Perfect and good are exactly the technique passes.
      expect(r.techniquePassed, {CookingGrade.perfect, CookingGrade.good, CookingGrade.fair}.contains(grade(s)));
    }
  });

  test('등급 글·손님 반응 이벤트', () {
    expect(CookingGrade.values.map(cookingGradeTitle),
        ['완벽해요!', '잘 구웠어요!', '보통이에요', '아깝다!', '다음엔 더 잘할 수 있어요']);
    expect(CookingGrade.values.map(cookingGradeEvent),
        ['result_perfect', 'result_good', 'result_fair', 'result_near', 'result_fail']);
    // 4차 피드백 g15 (사용자 결정 2026-11-21): 완벽 5 · 잘 구움 4 · 보통 3 · 아깝다 2 · 실패 0.
    expect(CookingGrade.values.map(cookingStars), [5, 4, 3, 2, 0]);
  });

  test('설정 검사: 완벽 기준은 성공 기준 안쪽', () {
    for (final (key, value) in [
      ('perfect_min_coverage_permille', 899),
      ('perfect_min_coverage_permille', 1001),
      ('perfect_max_total_amount_permille', 1799),
      ('perfect_max_total_amount_permille', 2601),
      ('perfect_max_spill_permille', -1),
      ('perfect_max_spill_permille', 301),
      ('perfect_doneness_index', 0),
      ('perfect_doneness_index', 4),
      ('good_min_coverage_permille', 899),
      ('good_min_coverage_permille', 951),
      ('good_min_total_amount_permille', 1799),
      ('good_min_total_amount_permille', 2301),
      ('good_max_total_amount_permille', 2299),
      ('good_max_total_amount_permille', 2601),
      ('good_max_spill_permille', 49),
      ('good_max_spill_permille', 701),
    ]) {
      final data = raw();
      (data['cooking_grade'] as Map<String, dynamic>)[key] = value;
      expect(() => DevelopmentBalance.fromJson(data), throwsFormatException, reason: '$key=$value');
    }
  });
}
