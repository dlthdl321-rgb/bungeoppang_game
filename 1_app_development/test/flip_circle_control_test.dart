import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';

/// 걸이 축 뒤집기 조작(26번 3차 피드백 H21, 예전 24번 6단계 원 그리기) 위젯: 밀어 올려
/// flipAxleDoneDegrees(120도)를 넘으면 flip_ms 동안 마저 넘어간 뒤 명령, 손 떼면 원위치,
/// 취소·차단·두 번째 손가락·화면 읽기·모션 줄이기·진동.
void main() {
  final config = DevelopmentBalance.fromJson(jsonDecode(
      File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final flipMs = DevelopmentBalance.integer(config.section('manual_cooking'), 'flip_ms');
  var flips = 0;
  var answer = true;
  setUp(() {
    flips = 0;
    answer = true;
  });

  Widget view({int token = 0, bool blocked = false, bool reduceMotion = false,
          bool vibration = false}) =>
      MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, height: 200,
          child: FlipCircleControl(key: const ValueKey('flip'), stageToken: token,
              blocked: blocked, config: config, reduceMotion: reduceMotion,
              vibration: vibration,
              mold: const ColoredBox(color: Colors.brown),
              onFlip: () async {
                flips++;
                return answer;
              })))));
  Offset centre(WidgetTester tester) => tester.getCenter(find.byType(FlipCircleControl));
  String caption(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('flip-caption'))).data!;
  FlipCircleControlState state(WidgetTester tester) =>
      tester.state<FlipCircleControlState>(find.byType(FlipCircleControl));
  double turn(WidgetTester tester) => state(tester).turn;

  /// The mold's height on screen in the 300x200 test box (WorkshopMoldArt.fit).
  const moldHeight = 532 * (200 / 532);

  /// Pushes the mold [degrees] over its axle (up > 0) in small steps and
  /// returns the gesture still down.
  Future<TestGesture> push(WidgetTester tester, double degrees, {int pointer = 1}) async {
    final start = centre(tester) + const Offset(0, 40);
    final gesture = await tester.startGesture(start, pointer: pointer);
    await tester.pump();
    final distance = degrees / 180 * moldHeight;
    final steps = (distance.abs() / 8).ceil();
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(start - Offset(0, distance * i / steps));
      await tester.pump();
    }
    return gesture;
  }

  testWidgets('탭만으로는 뒤집히지 않는다', (tester) async {
    await tester.pumpWidget(view());
    expect(caption(tester), '틀을 위로 밀어 올려 뒤집어요');
    await tester.tap(find.byType(FlipCircleControl));
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    expect(state(tester).flipping, isFalse);
  });
  testWidgets('밀어 올리면 틀이 축을 따라 돌고, 120도를 넘으면 flip_ms 동안 넘어간 뒤 한 번 뒤집는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await push(tester, 60);
    expect(caption(tester), matches(RegExp(r'^뒤집기 (49|50)% · 손을 떼면 처음부터$')));
    expect(turn(tester), closeTo(60, 2));
    expect(find.byKey(const Key('flip-turn')), findsOneWidget);
    await gesture.moveBy(Offset(0, -moldHeight * 70 / 180));
    await tester.pump();
    expect(state(tester).flipping, isTrue);
    expect(caption(tester), '뒤집는 중…');
    await tester.pump(Duration(milliseconds: flipMs - 50));
    expect(flips, 0, reason: '연출(flip_ms)이 끝나기 전에는 보내지 않음');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(flips, 1);
    // 남은 움직임과 손 떼기는 아무것도 바꾸지 않는다.
    await gesture.moveBy(const Offset(0, 90));
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 1);
  });
  testWidgets('아래로 당겨도 뒤집힌다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await push(tester, -130);
    expect(state(tester).flipping, isTrue);
    await tester.pump(Duration(milliseconds: flipMs + 10));
    await tester.pump();
    expect(flips, 1);
    await gesture.up();
  });
  testWidgets('중간에 손을 떼면 틀이 제자리로 돌아온다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await push(tester, 100);
    expect(turn(tester), greaterThan(90));
    await gesture.up();
    await tester.pump();
    expect(state(tester).axle, isNull);
    expect(turn(tester), 0);
    expect(caption(tester), '틀을 위로 밀어 올려 뒤집어요');
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    // 다시 밀면 처음부터 센다.
    final again = await push(tester, 40);
    expect(state(tester).axle!.degrees, closeTo(40, 2));
    await again.up();
  });
  testWidgets('조금 움직이는 것은 미는 것으로 보지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await tester.startGesture(centre(tester));
    await gesture.moveBy(const Offset(4, -4));
    await tester.pump();
    expect(state(tester).axle!.degrees, 0);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('두 번째 손가락은 각도를 바꾸지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final first = await push(tester, 50, pointer: 1);
    final before = state(tester).axle!.degrees;
    final second = await push(tester, 150, pointer: 2);
    expect(state(tester).axle!.degrees, before);
    await second.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    await first.up();
  });
  testWidgets('포인터 취소·단계 변경·앱 비활성은 제자리로 되돌린다', (tester) async {
    await tester.pumpWidget(view());
    final cancelled = await push(tester, 80);
    await cancelled.cancel();
    await tester.pump();
    expect(state(tester).axle, isNull);

    final stale = await push(tester, 80);
    await tester.pumpWidget(view(token: 1));
    expect(state(tester).axle, isNull);
    await stale.moveBy(const Offset(0, -150));
    await stale.up();
    expect(state(tester).axle, isNull);

    final away = await push(tester, 80);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(state(tester).axle, isNull);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await away.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('연출 중 일시정지(차단)되면 보내지 않고 원위치', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await push(tester, 130);
    expect(state(tester).flipping, isTrue);
    await tester.pump(Duration(milliseconds: flipMs ~/ 2));
    await tester.pumpWidget(view(blocked: true));
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    expect(state(tester).flipping, isFalse);
    expect(state(tester).axle, isNull);
    await gesture.up();
    // 차단된 틀은 밀기를 시작하지 않는다.
    final late = await push(tester, 130);
    expect(state(tester).axle, isNull);
    await late.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('명령이 거부되면 다시 밀 수 있게 제자리로 돌아간다', (tester) async {
    answer = false;
    await tester.pumpWidget(view());
    final gesture = await push(tester, 130);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    await tester.pump();
    expect(flips, 1);
    expect(state(tester).flipping, isFalse);
    expect(state(tester).axle, isNull);
    expect(caption(tester), '틀을 위로 밀어 올려 뒤집어요');
  });
  testWidgets('화면 읽기 두 번 활성화로 뒤집는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(view());
    tester.semantics.tap(find.semantics.byLabel('틀 뒤집기'));
    await tester.pump();
    expect(state(tester).flipping, isTrue);
    await tester.pump(Duration(milliseconds: flipMs + 10));
    await tester.pump();
    expect(flips, 1);
    semantics.dispose();
  });
  testWidgets('모션 줄이기면 틀이 돌지 않지만 판정과 대기 시간은 같다', (tester) async {
    await tester.pumpWidget(view(reduceMotion: true));
    final gesture = await push(tester, 60);
    expect(find.byKey(const Key('flip-turn')), findsNothing);
    expect(state(tester).axle!.degrees, closeTo(60, 2));
    await gesture.moveBy(Offset(0, -moldHeight * 70 / 180));
    await tester.pump();
    expect(state(tester).flipping, isTrue);
    expect(find.byKey(const Key('flip-turn')), findsNothing);
    await tester.pump(Duration(milliseconds: flipMs - 50));
    expect(flips, 0);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(flips, 1);
    await gesture.up();
  });
  testWidgets('진동 설정이 켜져 있으면 다 그렸을 때 한 번 진동한다', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(view(vibration: true));
    final gesture = await push(tester, 130);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    expect(calls, ['HapticFeedbackType.selectionClick']);
    calls.clear();
    await tester.pumpWidget(view(token: 1));
    final quiet = await push(tester, 130);
    await quiet.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    expect(flips, 2);
    expect(calls, isEmpty);
  });
}
