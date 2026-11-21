import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_flip.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/prep_minigames.dart';

/// 재료 타이쿤 D — 재료 준비 미니게임 3종 규칙 (`lib/prep_minigames.dart`,
/// 설정 `prep_minigames`): 반죽 젓기·불 조절·휘젓기의 성공·실패.
Map<String, dynamic> _raw() =>
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final config = DevelopmentBalance.fromJson(_raw());
  final c = PrepGameConfig.of(config);
  const width = 300.0;

  /// Stirs [degrees] clockwise on a circle of radius 100 (outside the dead zone).
  void stir(StirGame g, double degrees, {double from = 0}) {
    for (var a = from; a <= from + degrees; a += 10) {
      final r = a * math.pi / 180;
      g.move(math.sin(r) * 100, -math.cos(r) * 100);
    }
  }

  group('설정', () {
    test('숫자는 설정 파일 그대로, 6~10초, 준비물마다 미니게임이 있음', () {
      expect(identical(PrepGameConfig.of(config), c), isTrue);
      expect(c.create('stir', width).durationMs, 8000);
      expect(c.create('heat', width).durationMs, 10000);
      expect(c.create('whisk', width).durationMs, 6000);
      expect(c.stir['green_min_permille'], 700);
      expect(c.stir['green_max_permille'], 900);
      expect(c.heat['success_time_permille'], 700);
      final pantry = PantryConfig.of(config);
      for (final k in pantry.prepared.values) {
        expect(c.create(k.minigame, width).id, k.minigame);
      }
      expect(() => c.create('fry', width), throwsFormatException);
    });

    test('잘못된 설정은 거절', () {
      for (final (game, key, value) in const [
        ('stir', 'duration_ms', 5000),
        ('heat', 'duration_ms', 12000),
        ('stir', 'green_min_permille', 950),
        ('stir', 'full_degrees', 100),
        ('heat', 'start_permille', 100),
        ('heat', 'success_time_permille', 0),
        ('whisk', 'fill_per_stroke_permille', 0),
        ('whisk', 'stroke_min_permille', 1000),
      ]) {
        final raw = _raw();
        ((raw['prep_minigames'] as Map<String, dynamic>)[game] as Map<String, dynamic>)[key] = value;
        expect(() => PrepGameConfig.parse(raw['prep_minigames'] as Map<String, dynamic>), throwsFormatException,
            reason: '$game.$key');
      }
    });
  });

  group('반죽 젓기', () {
    test('원을 그리면 매끈함이 오르고 초록 칸에서 손을 떼면 성공', () {
      final g = c.create('stir', width) as StirGame;
      stir(g, 360);
      expect(g.bar, closeTo(.25, .01));
      expect(g.inGreen, isFalse);
      g.release(); // 초록 칸 아래: 끝나지 않고 이어서 젓는다
      expect(g.playing, isTrue);
      stir(g, 800, from: 360);
      expect(g.inGreen, isTrue);
      expect(g.caption, '지금 손을 떼요!');
      g.release();
      expect(g.phase, PrepPhase.success);
      expect(g.failText, isNull);
    });

    test('너무 저으면 바로 조금 묽어요', () {
      final g = c.create('stir', width) as StirGame;
      stir(g, 1400);
      expect(g.phase, PrepPhase.fail);
      expect(g.failText, StirGame.overText);
    });

    test('시간이 다 되면 덜 저었어요 (초록 칸이면 성공)', () {
      final g = c.create('stir', width) as StirGame;
      stir(g, 200);
      g.advance(8000);
      expect(g.phase, PrepPhase.fail);
      expect(g.failText, StirGame.underText);
      final h = c.create('stir', width) as StirGame;
      stir(h, 1150);
      h.advance(9000);
      expect(h.phase, PrepPhase.success);
    });

    test('가운데를 휘젓거나 거꾸로 돌면 늘지 않음, 손을 뗐다 다시 대도 그대로', () {
      final g = c.create('stir', width) as StirGame;
      for (var i = 0; i < 50; i++) {
        g.move(math.sin(i.toDouble()) * 10, math.cos(i.toDouble()) * 10);
      }
      expect(g.bar, 0);
      stir(g, 360);
      final after = g.bar;
      g.release();
      g.move(-100, 0); // 반대편에서 다시 시작: 건너뛴 각도는 세지 않음
      expect(g.bar, after);
    });

    test('FlipCircle.lift는 각도를 남기고 다음 점부터 셈', () {
      final f = FlipCircle(deadRadius: 10, targetDegrees: 720);
      f.moveTo(0, -100);
      f.moveTo(100, 0);
      expect(f.degrees, closeTo(90, .01));
      f.lift();
      f.moveTo(0, 100);
      expect(f.degrees, closeTo(90, .01));
      f.moveTo(-100, 0);
      expect(f.degrees, closeTo(180, .01));
    });
  });

  group('불 조절', () {
    test('누르지 않으면 바늘이 내려가고, 누르면 올라감', () {
      final g = c.create('heat', width) as HeatGame;
      final start = g.level;
      g.advance(1000);
      expect(g.level, closeTo(start - .22, .001));
      g.hold(true);
      g.advance(1000);
      expect(g.level, closeTo(start - .22 + .38, .001));
    });

    test('초록 칸에 70% 넘게 있으면 성공', () {
      final g = c.create('heat', width) as HeatGame;
      // Hold a little, let go a little: stays round the middle of green.
      for (var t = 0; t < 10000; t += 100) {
        g.hold(g.level < .57);
        g.advance(100);
      }
      expect(g.phase, PrepPhase.success);
      expect(g.greenShare, greaterThanOrEqualTo(.7));
    });

    test('계속 누르거나 그냥 두면 실패', () {
      final g = c.create('heat', width) as HeatGame;
      g.hold(true);
      g.advance(10000);
      expect(g.phase, PrepPhase.fail);
      expect(g.failText, HeatGame.failWords);
      final h = c.create('heat', width) as HeatGame;
      h.advance(10000);
      expect(h.phase, PrepPhase.fail);
      expect(h.level, 0);
    });

    test('끝난 뒤에는 바뀌지 않음', () {
      final g = c.create('heat', width) as HeatGame;
      g.advance(20000);
      expect(g.elapsedMs, 10000);
      g.hold(true);
      expect(g.holding, isFalse);
    });
  });

  group('휘젓기', () {
    test('좌우로 충분히 문지르면 거품이 차서 성공', () {
      final g = c.create('whisk', width) as WhiskGame;
      var x = 100.0;
      for (var i = 0; i < 20 && g.playing; i++) {
        final to = i.isEven ? 200.0 : 100.0;
        for (var k = 0; k <= 10; k++) {
          g.move(x + (to - x) * k / 10);
        }
        x = to;
        g.advance(100);
      }
      expect(g.phase, PrepPhase.success);
      expect(g.strokes, greaterThanOrEqualTo(15));
    });

    test('짧게 문지르면 세지 않고, 시간이 다 되면 거품이 덜 올랐어요', () {
      final g = c.create('whisk', width) as WhiskGame;
      for (var i = 0; i < 40; i++) {
        g.move(i.isEven ? 100 : 110); // 10 < 300 × 12%
      }
      expect(g.strokes, 0);
      g.advance(6000);
      expect(g.phase, PrepPhase.fail);
      expect(g.failText, WhiskGame.failWords);
    });

    test('거품은 시간이 지나면 조금씩 꺼짐', () {
      final g = c.create('whisk', width) as WhiskGame;
      for (final x in const <double>[100, 200, 100, 200]) {
        g.move(x);
      }
      final foam = g.foam;
      expect(foam, greaterThan(0));
      g.advance(1000);
      expect(g.foam, closeTo(foam - .05, .001));
    });
  });
}
