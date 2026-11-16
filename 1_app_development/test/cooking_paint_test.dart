import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';

/// 24번 5단계: 짤주머니 색칠의 면적 계산(DEC-031·032)과 판정·저장(G1).
void main() {
  final config = DevelopmentBalance.fromJson(jsonDecode(
      File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final mask = FishCavityMask.standard;
  MoldPaint brush() => MoldPaint(mask, brushWidthPermille: 140);

  /// A horizontal zigzag over the whole fish rect, rows [spacing] × brush
  /// diameter apart.
  MoldPaint zigzag(double spacing) {
    final paint = brush();
    final d = paint.radius * 2;
    var row = 0;
    for (var y = paint.radius * .8; y < mask.height; y += d * spacing, row++) {
      final xs = [paint.radius * .5, mask.width - paint.radius * .5];
      paint.moveTo(xs[row % 2], y);
      paint.moveTo(xs[1 - row % 2], y);
    }
    return paint;
  }

  group('마스크', () {
    test('붕어빵 모양 격자는 그림에서 만든 1081칸이고 붓 지름은 붕어빵 폭의 14%', () {
      expect(mask.cols, 49);
      expect(mask.rows, 34);
      expect(mask.count, 1081);
      expect(mask.cell, 16);
      expect(brush().radius * 2, closeTo(769 * .14, 1e-9));
    });
    test('생성 도구 --check가 그림과 생성 파일이 같다고 확인한다', () {
      final result = Process.runSync('python', ['tools/fish_cavity_mask.py', '--check'],
          environment: {'PYTHONIOENCODING': 'utf-8'});
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    }, skip: Process.runSync('python', ['-c', 'import numpy, PIL']).exitCode != 0
        ? 'numpy/Pillow 없음' : false);
  });

  group('면적 계산', () {
    test('빈 틀은 0%', () {
      final paint = brush();
      expect(paint.painted, isFalse);
      expect(paint.amount, const PaintAmount(0, 0));
    });
    test('꽉 칠하면 덮은 면적 100%', () {
      final paint = zigzag(1);
      expect(paint.amount.coverage, 1000);
      expect(paint.amount.amount, inInclusiveRange(1000, 1020));
    });
    test('틀 밖(붕어빵 모양 밖)은 세지 않는다', () {
      final paint = brush();
      paint.moveTo(-200, -200);
      paint.moveTo(-200, 800);
      paint.moveTo(1000, 800);
      expect(paint.painted, isFalse);
      expect(paint.amount, const PaintAmount(0, 0));
      // The fish's top-left corner is outside the fish shape too.
      final corner = brush()..moveTo(0, 0);
      expect(corner.painted, isFalse);
    });
    test('머물러 문질러도 한 겹, 떠났다 돌아오면 두 겹', () {
      final paint = brush();
      final centre = (mask.width / 2, mask.height / 2);
      for (var i = 0; i < 20; i++) {
        paint.moveTo(centre.$1 + (i.isEven ? 3 : -3), centre.$2);
      }
      final once = paint.amount;
      expect(once.coverage, greaterThan(0));
      expect(once.amount, once.coverage);
      paint.moveTo(centre.$1 + 300, centre.$2);
      final away = paint.amount;
      paint.moveTo(centre.$1, centre.$2);
      final back = paint.amount;
      expect(back.coverage, away.coverage);
      expect(back.amount, greaterThan(away.amount));
    });
    test('떠남 여유(반지름 + 1칸) 안의 떨림은 덧칠이 아니다 (G7)', () {
      final paint = brush();
      final x = mask.width / 2, y = mask.height / 2;
      paint.moveTo(x, y);
      final first = paint.amount;
      for (var i = 0; i < 30; i++) {
        paint.moveTo(x + (i.isEven ? mask.cell * .9 : 0), y);
      }
      final shaken = paint.amount;
      expect(shaken.amount - shaken.coverage, lessThanOrEqualTo(first.coverage ~/ 10));
    });
    test('빠르게 휘둘러도 사이를 반 칸 간격으로 칠해 빈틈이 없다', () {
      final fast = brush()..moveTo(100, 260)..moveTo(700, 260);
      final slow = brush();
      for (var x = 100.0; x <= 700; x += 4) {
        slow.moveTo(x, 260);
      }
      expect(fast.amount, slow.amount);
    });
    test('덧칠이 많으면 130%를 넘어 넘침', () {
      final over = zigzag(.5);
      expect(over.amount.coverage, 1000);
      expect(over.amount.amount, greaterThan(1300));
      expect(batterVerdict(config, over.amount), BatterVerdict.overflow);
      expect(paintOverflowed(config, over.amount), isTrue);
    });
    test('깔끔한 지그재그는 90% 이상·130% 이하로 성공할 수 있다', () {
      expect(batterVerdict(config, zigzag(1).amount), BatterVerdict.ok);
      expect(batterVerdict(config, zigzag(.9).amount), BatterVerdict.ok);
    });
    test('겹은 칸마다 9겹까지만 센다', () {
      final paint = brush();
      for (var i = 0; i < 30; i++) {
        paint.moveTo(mask.width / 2, mask.height / 2);
        paint.moveTo(mask.width / 2 + 400, mask.height / 2);
      }
      expect(paint.layers.reduce((a, b) => a > b ? a : b), MoldPaint.maxLayers);
      expect(paint.amount.valid, isTrue);
    });
  });

  group('판정', () {
    test('반죽 경계: 덮은 면적 90% 이상, 양 130% 이하', () {
      expect(batterVerdict(config, const PaintAmount(900, 1300)), BatterVerdict.ok);
      expect(batterVerdict(config, const PaintAmount(899, 899)), BatterVerdict.short);
      expect(batterVerdict(config, const PaintAmount(1000, 1301)), BatterVerdict.overflow);
      expect(batterVerdict(config, const PaintAmount(500, 1400)), BatterVerdict.overflow);
    });
    CookingSession finished(PaintAmount first, PaintAmount second, {int bakeMs = 15000}) {
      var s = CookingSession.start(id: 'judge', flavor: 'redbean', practice: true,
          fillingSequence: [CookingDirection.left, CookingDirection.right]);
      s = s.pour(s.token, first);
      s = s.squeezeFilling(s.token, const PaintAmount(300, 2500));
      s = s.pour(s.token, second);
      s = s.close(s.token);
      s = s.flip(s.token);
      return s.takeOut(s.token, bakeMs);
    }
    test('반죽 두 번과 익힘이 모두 맞아야 성공, 속은 판정하지 않는다', () {
      final ok = finished(const PaintAmount(950, 1100), const PaintAmount(900, 1300));
      expect(evaluateCookingResult(config, ok, difficulty: 0).techniquePassed, isTrue);
      expect(batterFailureLabel(config, ok), isNull);
      final short = finished(const PaintAmount(880, 900), PaintAmount.even);
      expect(evaluateCookingResult(config, short, difficulty: 0).techniquePassed, isFalse);
      expect(batterFailureLabel(config, short), '반죽 부족');
      final over = finished(PaintAmount.even, const PaintAmount(1000, 1400));
      expect(evaluateCookingResult(config, over, difficulty: 0).techniquePassed, isFalse);
      expect(batterFailureLabel(config, over), '반죽 넘침');
      final raw = finished(PaintAmount.even, PaintAmount.even, bakeMs: 0);
      expect(evaluateCookingResult(config, raw, difficulty: 0).techniquePassed, isFalse);
    });
  });

  group('저장(G1: 필드 추가, schema 유지)', () {
    CookingSession start() => CookingSession.start(id: 'save', flavor: 'redbean',
        practice: true, fillingSequence: [CookingDirection.left, CookingDirection.right]);
    test('칠한 양은 permille 쌍으로 저장되고 그대로 읽힌다', () {
      var s = start().pour(0, const PaintAmount(930, 1120));
      s = s.squeezeFilling(s.token, const PaintAmount(720, 830));
      final json = s.toJson();
      expect(json['schema'], 1);
      expect(json['firstBatterCoverage'], 930);
      expect(json['firstBatterAmount'], 1120);
      expect(json['fillingCoverage'], 720);
      expect(json['fillingAmount'], 830);
      expect(json.containsKey('secondBatterCoverage'), isFalse);
      expect(json['firstBatterMs'], isNull);
      final back = CookingSession.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(back.toJson(), json);
      expect(back.firstBatter, const PaintAmount(930, 1120));
    });
    test('빈 붓질·잘못된 양은 단계가 되지 않는다 (G3)', () {
      expect(() => start().pour(0, const PaintAmount(0, 0)), throwsFormatException);
      expect(() => start().pour(0, const PaintAmount(900, 800)), throwsFormatException);
      expect(() => start().pour(0, const PaintAmount(1001, 1001)), throwsFormatException);
      final poured = start().pour(0, PaintAmount.even).toJson();
      expect(() => CookingSession.fromJson({...poured, 'firstBatterAmount': null}), throwsFormatException);
      expect(() => CookingSession.fromJson({...poured, 'firstBatterMs': 2500}), throwsFormatException);
      expect(() => CookingSession.fromJson({...start().toJson(), 'firstBatterCoverage': 900, 'firstBatterAmount': 900}),
          throwsFormatException);
      expect(() => CookingSession.fromJson({...poured, 'fillingCoverage': 900, 'fillingAmount': 900}),
          throwsFormatException);
    });
    test('예전 길게 누르기 저장(ms)은 그대로 이어서 하고, 그 반죽은 손기술 실패', () {
      final old = {...start().toJson(), 'phase': 'filling', 'token': 1, 'firstBatterMs': 2500};
      var s = CookingSession.fromJson(old);
      expect(s.firstBatterDone, isTrue);
      expect(s.firstBatter, isNull);
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, PaintAmount.even);
      expect(s.toJson()['firstBatterMs'], 2500);
      s = s.close(s.token);
      s = s.flip(s.token);
      s = s.takeOut(s.token, 15000);
      expect(CookingSession.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).toJson(), s.toJson());
      final result = evaluateCookingResult(config, s, difficulty: 0);
      expect(result.completed, isTrue);
      expect(result.techniquePassed, isFalse);
      expect(batterFailureLabel(config, s), isNull);
    });
    test('예전 속 기록(fillingDurationMs)도 읽힌다', () {
      final old = {...start().toJson(), 'phase': 'secondBatter', 'token': 3, 'fillingIndex': 2,
          'firstBatterMs': 2500, 'fillingDurationMs': 1450};
      final s = CookingSession.fromJson(old);
      expect(s.fillingSqueezed, isTrue);
      expect(s.toJson()['fillingDurationMs'], 1450);
    });
  });
}
