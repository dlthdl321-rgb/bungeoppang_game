import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_gestures.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/ui/cooking_filling_controls.dart';

void main() {
  const rules = FillingGestureRules(
      minDistance: 32,
      maxDurationMs: 800,
      dominancePermille: 2000,
      rotationDegrees: 360,
      minRadius: 20);
  test(
      'swipes accept distance/time/dominance boundaries, reject diagonals and clock reversal',
      () {
    const swipe = FillingSwipe(100, 100, 100, rules: rules);
    expect(swipe.finish(132, 116, 900), CookingDirection.right);
    expect(swipe.finish(68, 84, 900), CookingDirection.left);
    expect(swipe.finish(131, 100, 900), isNull);
    expect(swipe.finish(132, 117, 900), isNull);
    expect(swipe.finish(132, 100, 901), isNull);
    expect(swipe.finish(132, 100, 99), isNull);
  });
  test('spoon wraps angles, incomplete/reversed arcs cannot become a full turn',
      () {
    for (final sign in [-1, 1]) {
      final rotation = FillingRotation(rules);
      for (var i = 0; i <= 32; i++) {
        rotation.sample(60 * math.cos(sign * i * math.pi / 16),
            60 * math.sin(sign * i * math.pi / 16));
        if (i < 32) expect(rotation.finish(), isNull);
      }
      expect(rotation.finish(),
          sign < 0 ? CookingDirection.left : CookingDirection.right);
    }
    final center = FillingRotation(rules)
      ..sample(60, 0)
      ..sample(0, 0)
      ..sample(-60, 0);
    expect(center.radians, 0);
  });
  testWidgets(
      'one full spoon release emits once; interrupted/stale stage emits nothing',
      (tester) async {
    final results = <CookingDirection>[];
    Widget view(int token) => MaterialApp(
        home: Scaffold(
            body: Center(
                child: CookingFillingControls(
                    key: const ValueKey('tool'),
                    stageToken: token,
                    rules: rules,
                    blocked: false,
                    expected: CookingDirection.right,
                    onDirection: results.add))));
    await tester.pumpWidget(view(0));
    final target = find.byKey(const ValueKey('filling-gesture'));
    final center = tester.getCenter(target);
    final gesture = await tester.startGesture(center + const Offset(60, 0));
    for (var i = 1; i <= 32; i++) {
      await gesture.moveTo(center +
          Offset(60 * math.cos(i * math.pi / 16),
              60 * math.sin(i * math.pi / 16)));
    }
    expect(results, isEmpty);
    await gesture.up();
    expect(results, [CookingDirection.right]);
    final stale = await tester.startGesture(center + const Offset(60, 0));
    await tester.pumpWidget(view(1));
    await stale.up();
    expect(results.length, 1);
  });
  testWidgets(
      'chopstick swipe and accessible buttons use identical direction commands',
      (tester) async {
    final results = <CookingDirection>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: CookingFillingControls(
                    stageToken: 0,
                    rules: rules,
                    blocked: false,
                    expected: CookingDirection.left,
                    onDirection: results.add)))));
    await tester.tap(find.text('젓가락'));
    await tester.pump();
    final center =
        tester.getCenter(find.byKey(const ValueKey('filling-gesture')));
    final stroke = await tester.startGesture(center);
    await stroke.moveTo(center - const Offset(50, 0));
    await stroke.up();
    await tester.tap(find.text('오른쪽으로 속 넣기'));
    expect(results, [CookingDirection.left, CookingDirection.right]);
  });
}
