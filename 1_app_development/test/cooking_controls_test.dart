import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';

/// 짤주머니 색칠 조작(24번 5단계) 위젯: 손 떼면 확정, 취소·차단·두 번째 손가락.
void main() {
  final config = DevelopmentBalance.fromJson(jsonDecode(
      File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final results = <PaintAmount>[];
  setUp(results.clear);

  Widget view({int token = 0, bool blocked = false, bool filling = false,
          bool vibration = false}) =>
      MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, height: 200,
          child: MoldPaintControl(key: const ValueKey('paint'), stageToken: token,
              blocked: blocked, filling: filling, flavor: 'redbean', config: config,
              vibration: vibration,
              onFinished: (paint, _) => results.add(paint))))));
  Offset centre(WidgetTester tester) => tester.getCenter(find.byType(MoldPaintControl));
  String caption(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('piping-amount'))).data!;

  testWidgets('문지르면 칠한 양이 보이고 손을 떼면 그 양으로 확정한다', (tester) async {
    await tester.pumpWidget(view());
    expect(caption(tester), '틀 위를 문질러 반죽을 부어 주세요');
    final gesture = await tester.startGesture(centre(tester) - const Offset(60, 0));
    await tester.pump();
    for (var x = -60.0; x <= 60; x += 10) {
      await gesture.moveTo(centre(tester) + Offset(x, 0));
      await tester.pump();
    }
    expect(caption(tester), matches(RegExp(r'^반죽 덮음 \d+% · 양 \d+% · 손을 떼면 마무리$')));
    expect(results, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(results.length, 1);
    expect(results.single.coverage, greaterThan(0));
    expect(results.single.amount, greaterThanOrEqualTo(results.single.coverage));
    expect(caption(tester), '틀 위를 문질러 반죽을 부어 주세요');
  });
  testWidgets('속은 양만 보이고 넘치면 넘쳤어요', (tester) async {
    await tester.pumpWidget(view(filling: true));
    expect(caption(tester), '틀 위를 문질러 속을 짜 주세요');
    final gesture = await tester.startGesture(centre(tester));
    await tester.pump();
    expect(caption(tester), matches(RegExp(r'^속 양 \d+% · 손을 떼면 마무리$')));
    for (var i = 0; i < 40; i++) {
      await gesture.moveTo(centre(tester) + Offset(i.isEven ? -110 : 110, (i % 7 - 3) * 18));
    }
    await tester.pump();
    expect(caption(tester), endsWith(' · 넘쳤어요'));
    await gesture.up();
    expect(results.single.amount, greaterThan(1300));
  });
  testWidgets('틀 밖만 문지르면(칠 0) 확정하지 않는다 (G3)', (tester) async {
    await tester.pumpWidget(view());
    final topLeft = tester.getTopLeft(find.byType(MoldPaintControl));
    final gesture = await tester.startGesture(topLeft + const Offset(2, 2));
    await gesture.moveTo(topLeft + const Offset(40, 2));
    await gesture.up();
    await tester.pump();
    expect(results, isEmpty);
  });
  testWidgets('틀 밖으로 나가도 취소하지 않고, 밖은 양에 넣지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await tester.startGesture(centre(tester));
    await gesture.moveTo(centre(tester) + const Offset(0, 400));
    await gesture.moveTo(const Offset(1, 1));
    await gesture.up();
    await tester.pump();
    expect(results.length, 1);
    expect(results.single.coverage, lessThan(300));
  });
  testWidgets('칠하는 중 단계가 바뀌면 이전 손 떼기로 확정하지 않는다', (tester) async {
    await tester.pumpWidget(view(token: 0));
    final gesture = await tester.startGesture(centre(tester));
    await gesture.moveTo(centre(tester) + const Offset(30, 0));
    await tester.pumpWidget(view(token: 1));
    await gesture.moveTo(centre(tester) + const Offset(60, 0));
    await gesture.up();
    expect(results, isEmpty);
  });
  testWidgets('앱이 비활성이 되면 칠을 버린다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await tester.startGesture(centre(tester));
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await gesture.up();
      expect(results, isEmpty);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });
  testWidgets('일시정지로 차단된 칠은 늦게 놓아도 확정하지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await tester.startGesture(centre(tester));
    await tester.pumpWidget(view(blocked: true));
    await tester.pumpWidget(view());
    await gesture.up();
    expect(results, isEmpty);
    // A blocked mold does not start a stroke at all.
    await tester.pumpWidget(view(blocked: true));
    final late = await tester.startGesture(centre(tester));
    await late.up();
    expect(results, isEmpty);
  });
  testWidgets('포인터 취소는 확정하지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await tester.startGesture(centre(tester));
    await gesture.moveTo(centre(tester) + const Offset(20, 0));
    await gesture.cancel();
    expect(results, isEmpty);
  });
  testWidgets('두 번째 손가락은 칠하지도 확정하지도 않는다', (tester) async {
    await tester.pumpWidget(view());
    final first = await tester.startGesture(centre(tester), pointer: 1);
    await tester.pump();
    final state = tester.state<MoldPaintControlState>(find.byType(MoldPaintControl));
    final before = state.stroke!.amount;
    final second = await tester.startGesture(centre(tester) + const Offset(-100, 0), pointer: 2);
    await second.moveTo(centre(tester) + const Offset(100, 0));
    await second.up();
    expect(results, isEmpty);
    expect(state.stroke!.amount, before);
    await first.up();
    expect(results, [before]);
  });
  testWidgets('화면 읽기 두 번 활성화는 고르게 칠하기(100%/100%)로 확정한다 (G4)', (tester) async {
    final semantics = tester.ensureSemantics();
    Uint8List? cells;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 300, height: 200,
        child: MoldPaintControl(stageToken: 0, blocked: false, filling: false,
            flavor: 'redbean', config: config, onFinished: (paint, c) {
              results.add(paint);
              cells = c;
            })))));
    tester.semantics.tap(find.semantics.byLabel('짤주머니로 반죽 붓기'));
    await tester.pump();
    expect(results, [PaintAmount.even]);
    expect(cells!.where((c) => c > 0).length, FishCavityMask.standard.count);
    semantics.dispose();
  });
  testWidgets('진동 설정이 켜져 있으면 확정할 때 진동한다', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(view(vibration: true));
    final gesture = await tester.startGesture(centre(tester));
    await gesture.up();
    expect(calls, ['HapticFeedbackType.selectionClick']);
    calls.clear();
    await tester.pumpWidget(view(token: 1));
    final quiet = await tester.startGesture(centre(tester));
    await quiet.up();
    expect(results.length, 2);
    expect(calls, isEmpty);
  });
}
