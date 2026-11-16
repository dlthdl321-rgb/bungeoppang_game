import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_flip.dart';
import 'package:todays_bungeoppang/development_balance.dart';

/// 원 그려 뒤집기(24번 6단계, DEC-034)의 각도 누적 계산.
void main() {
  final json = File('config/development_balance.json').readAsStringSync();
  final config = DevelopmentBalance.fromJson(jsonDecode(json) as Map<String, dynamic>);

  /// Moves along a circle of [radius] from [from] to [to] degrees in 10° steps.
  void arc(FlipCircle c, double from, double to, {double radius = 100}) {
    final step = to >= from ? 10.0 : -10.0;
    for (var a = from; step > 0 ? a <= to : a >= to; a += step) {
      c.moveTo(radius * math.cos(a * math.pi / 180), radius * math.sin(a * math.pi / 180));
    }
  }

  FlipCircle circle() => FlipCircle(deadRadius: 30, targetDegrees: 320);

  test('설정값: 320도, 틀 그림 폭의 15% 안쪽 무시', () {
    final c = FlipCircle.forMold(config, 1200);
    expect(c.targetDegrees, 320);
    expect(c.deadRadius, closeTo(180, 1e-9));
    final manual = config.section('manual_cooking');
    expect(DevelopmentBalance.integer(manual, 'flip_turn_degrees'), 320);
    expect(DevelopmentBalance.integer(manual, 'flip_dead_zone_permille'), 150);
  });
  test('한 바퀴(시계 방향) 그리면 뒤집힌다', () {
    final c = circle();
    arc(c, 0, 330);
    expect(c.done, isTrue);
    expect(c.degrees, closeTo(320, 10));
    expect(c.progress, 1);
  });
  test('반시계 방향 한 바퀴도 뒤집힌다', () {
    final c = circle();
    arc(c, 0, -330);
    expect(c.done, isTrue);
    expect(c.degrees, lessThan(-319));
  });
  test('반 바퀴는 부족하다', () {
    final c = circle();
    arc(c, 0, 180);
    expect(c.done, isFalse);
    expect(c.degrees, closeTo(180, 1e-6));
    expect(c.progress, closeTo(180 / 320, 1e-6));
    // 310도까지 가도 아직 아니다.
    arc(c, 190, 310);
    expect(c.done, isFalse);
  });
  test('중심 가까이에서 맴돌면 각도가 쌓이지 않는다', () {
    final c = circle();
    for (var turn = 0; turn < 5; turn++) {
      arc(c, 0, 350, radius: 20);
    }
    expect(c.degrees, 0);
    expect(c.done, isFalse);
  });
  test('중심을 가로질러 지나가도 반 바퀴로 세지 않는다', () {
    final c = circle();
    c.moveTo(100, 0);
    c.moveTo(10, 0);
    c.moveTo(-100, 0);
    expect(c.degrees, 0);
    // 중심 밖에서 다시 이어 그리면 그 점부터 센다.
    arc(c, 180, 270);
    expect(c.degrees, closeTo(90, 1e-6));
  });
  test('거꾸로 돌면 각도가 줄고, 반대 방향으로 다 그려도 뒤집힌다', () {
    final c = circle();
    arc(c, 0, 180);
    arc(c, 180, 0);
    expect(c.degrees.abs(), lessThan(1e-6));
    arc(c, 0, -200);
    expect(c.degrees, closeTo(-200, 1e-6));
    expect(c.done, isFalse);
    arc(c, -200, -330);
    expect(c.done, isTrue);
  });
  test('한 번에 크게 건너뛴 점은 짧은 쪽으로 센다', () {
    // 90도씩 네 번(빠르게 그린 원): -180도를 넘어가는 곳도 이어서 센다.
    final c = circle();
    for (final (x, y) in [(100.0, 0.0), (0.0, 100.0), (-100.0, 0.0), (0.0, -100.0), (100.0, 0.0)]) {
      c.moveTo(x, y);
    }
    expect(c.degrees, closeTo(360, 1e-6));
    expect(c.done, isTrue);
    // 반 바퀴 가까이 건너뛰면 가까운 쪽(여기서는 반시계)으로 본다.
    final jump = circle();
    jump.moveTo(100, 0);
    jump.moveTo(-100, -1);
    expect(jump.degrees, closeTo(-179.43, .01));
  });
  test('취소(reset)하면 0도로 돌아가고 처음부터 다시 그린다', () {
    final c = circle();
    arc(c, 0, 200);
    c.reset();
    expect(c.degrees, 0);
    expect(c.progress, 0);
    expect(c.done, isFalse);
    arc(c, 90, 200);
    expect(c.degrees, closeTo(110, 1e-6));
  });
  test('다 그린 뒤의 움직임은 바꾸지 않는다', () {
    final c = circle();
    arc(c, 0, 330);
    final at = c.degrees;
    arc(c, 330, 0);
    expect(c.degrees, at);
    expect(c.done, isTrue);
  });
  test('잘못된 설정은 거부한다', () {
    expect(() => FlipCircle(deadRadius: -1, targetDegrees: 320), throwsFormatException);
    expect(() => FlipCircle(deadRadius: 1, targetDegrees: 0), throwsFormatException);
    for (final bad in [
      {'flip_turn_degrees': 0},
      {'flip_turn_degrees': 721},
      {'flip_dead_zone_permille': 500},
      {'flip_ms': 0},
    ]) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      (data['manual_cooking'] as Map<String, dynamic>).addAll(bad);
      expect(() => DevelopmentBalance.fromJson(data), throwsFormatException, reason: '$bad');
    }
  });
}
