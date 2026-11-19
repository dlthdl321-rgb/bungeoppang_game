import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_flip.dart';
import 'package:todays_bungeoppang/feedback_config.dart';

/// 걸이 축 뒤집기(26번 3차 피드백 H21, 예전 24번 6단계 원 그리기)의 밀기 각도 계산.
void main() {
  FlipAxle axle() => FlipAxle(height: 180, startY: 500);

  test('설정값: 틀 높이만큼 밀면 180도, 120도에서 넘어감', () {
    expect(flipAxleDegreesPerHeight, 180);
    expect(flipAxleDoneDegrees, 120);
    expect(axle().doneDegrees, flipAxleDoneDegrees);
  });
  test('위로 밀면 +, 아래로 당기면 -, 되돌리면 줄어든다', () {
    final a = axle();
    a.moveTo(455);
    expect(a.degrees, closeTo(45, 1e-9));
    expect(a.progress, closeTo(45 / 120, 1e-9));
    a.moveTo(480);
    expect(a.degrees, closeTo(20, 1e-9));
    a.moveTo(545);
    expect(a.degrees, closeTo(-45, 1e-9));
    expect(a.done, isFalse);
  });
  test('120도에 닿으면 끝나고 그 뒤 움직임은 무시', () {
    final a = axle();
    a.moveTo(380);
    expect(a.done, isTrue);
    expect(a.progress, 1);
    a.moveTo(500);
    expect(a.degrees, closeTo(120, 1e-9));
    a.reset();
    expect(a.degrees, 0);
    expect(a.done, isFalse);
  });
  test('조금 움직인 것은 0도', () {
    final a = axle();
    a.moveTo(500 - flipAxleStartPx + .5);
    expect(a.degrees, 0);
  });
  test('잘못된 설정은 거부', () {
    expect(() => FlipAxle(height: 0, startY: 0), throwsFormatException);
    expect(() => FlipAxle(height: 10, startY: 0, doneDegrees: 200), throwsFormatException);
  });
}
