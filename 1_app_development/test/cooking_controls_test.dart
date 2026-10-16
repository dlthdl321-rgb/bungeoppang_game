import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_tilt_source.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/cooking_session_controls.dart';

void main() {
  testWidgets('누른 동안 단계가 바뀌면 이전 포인터 해제로 다음 반죽을 확정하지 않는다', (tester) async {
    final results = <int>[];
    Widget view(int token) => MaterialApp(home: Scaffold(body: BatterHoldButton(
        key: const ValueKey('batter'), stageToken: token, blocked: false,
        label: '반죽', onFinished: results.add)));
    await tester.pumpWidget(view(0));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(BatterHoldButton)));
    await tester.pumpWidget(view(1));
    await gesture.up();
    expect(results, isEmpty);
  });
  testWidgets('앱 비활성 중 들어온 손 떼기는 결과를 생성하지 않는다', (tester) async {
    final results = <int>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BatterHoldButton(
        stageToken: 0, blocked: false, label: '반죽', onFinished: results.add))));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(BatterHoldButton)));
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await gesture.up();
      expect(results, isEmpty);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
  test('지원하지 않는 환경은 센서 대신 터치 대체 상태를 반환한다', () async {
    final config = DevelopmentBalance.fromJson(jsonDecode(
        File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final samples = await CookingTiltSource(supported: false).samples(config).toList();
    expect(samples.length, 1);
    expect(samples.single.available, isFalse);
  });
}
