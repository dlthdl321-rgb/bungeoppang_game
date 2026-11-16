import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';

/// 원 그려 뒤집기 조작(24번 6단계, DEC-034) 위젯: 320도에서 flip_ms 연출 뒤 명령,
/// 손 떼면 0도, 취소·차단·두 번째 손가락·화면 읽기·모션 줄이기·진동.
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
  double turn(WidgetTester tester) {
    final rotate = find.descendant(of: find.byType(FlipCircleControl), matching: find.byType(Transform));
    if (rotate.evaluate().isEmpty) return 0;
    final m = tester.widget<Transform>(rotate.first).transform;
    return math.atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / math.pi;
  }

  /// Draws [degrees] (sign = direction) on a circle of [radius] from the top
  /// and returns the gesture still down.
  Future<TestGesture> draw(WidgetTester tester, double degrees,
      {double radius = 90, int pointer = 1}) async {
    final c = centre(tester);
    Offset at(double a) => c + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * radius;
    final gesture = await tester.startGesture(at(0), pointer: pointer);
    await tester.pump();
    final step = degrees >= 0 ? 15.0 : -15.0;
    for (var a = step; degrees >= 0 ? a <= degrees : a >= degrees; a += step) {
      await gesture.moveTo(at(a));
      await tester.pump();
    }
    return gesture;
  }

  testWidgets('탭만으로는 뒤집히지 않는다', (tester) async {
    await tester.pumpWidget(view());
    expect(caption(tester), '틀 둘레로 원을 한 바퀴 그려 뒤집어요');
    await tester.tap(find.byType(FlipCircleControl));
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    expect(state(tester).flipping, isFalse);
  });
  testWidgets('원을 그리면 틀이 따라 돌고, 320도에서 flip_ms 연출 뒤 한 번 뒤집는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 180);
    expect(caption(tester), matches(RegExp(r'^뒤집기 5\d% · 손을 떼면 처음부터$')));
    expect(turn(tester).abs(), closeTo(180, 1));
    for (var a = 195.0; a <= 330; a += 15) {
      await gesture.moveTo(centre(tester) + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * 90);
      await tester.pump();
    }
    expect(state(tester).flipping, isTrue);
    expect(caption(tester), '뒤집는 중…');
    await tester.pump(Duration(milliseconds: flipMs - 50));
    expect(flips, 0, reason: '연출(flip_ms)이 끝나기 전에는 보내지 않음');
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(flips, 1);
    // 남은 움직임과 손 떼기는 아무것도 바꾸지 않는다.
    await gesture.moveTo(centre(tester) + const Offset(0, 90));
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 1);
  });
  testWidgets('반시계 방향으로 그려도 뒤집힌다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, -330);
    await tester.pump(Duration(milliseconds: flipMs + 10));
    await tester.pump();
    expect(flips, 1);
    await gesture.up();
  });
  testWidgets('중간에 손을 떼면 0도로 돌아가고 틀도 원위치', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 240);
    expect(turn(tester).abs(), greaterThan(100));
    await gesture.up();
    await tester.pump();
    expect(state(tester).circle, isNull);
    expect(turn(tester), 0);
    expect(caption(tester), '틀 둘레로 원을 한 바퀴 그려 뒤집어요');
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    // 다시 그리면 처음부터 센다: 120도로는 부족.
    final again = await draw(tester, 120);
    expect(state(tester).circle!.degrees, closeTo(120, 1));
    await again.up();
  });
  testWidgets('중심 가까이에서 맴돌면 뒤집히지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 720, radius: 8);
    expect(state(tester).circle!.degrees, 0);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('두 번째 손가락은 각도를 바꾸지 않는다', (tester) async {
    await tester.pumpWidget(view());
    final first = await draw(tester, 90, pointer: 1);
    final before = state(tester).circle!.degrees;
    final second = await draw(tester, 300, pointer: 2);
    expect(state(tester).circle!.degrees, before);
    await second.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    await first.up();
  });
  testWidgets('포인터 취소·단계 변경·앱 비활성은 0도로 되돌린다', (tester) async {
    await tester.pumpWidget(view());
    final cancelled = await draw(tester, 200);
    await cancelled.cancel();
    await tester.pump();
    expect(state(tester).circle, isNull);

    final stale = await draw(tester, 200);
    await tester.pumpWidget(view(token: 1));
    expect(state(tester).circle, isNull);
    await stale.moveTo(centre(tester) + const Offset(-90, 0));
    await stale.up();
    expect(state(tester).circle, isNull);

    final away = await draw(tester, 200);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(state(tester).circle, isNull);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await away.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('연출 중 일시정지(차단)되면 보내지 않고 원위치', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 330);
    expect(state(tester).flipping, isTrue);
    await tester.pump(Duration(milliseconds: flipMs ~/ 2));
    await tester.pumpWidget(view(blocked: true));
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    expect(state(tester).flipping, isFalse);
    expect(state(tester).circle, isNull);
    await gesture.up();
    // 차단된 틀은 그리기를 시작하지 않는다.
    final late = await draw(tester, 330);
    expect(state(tester).circle, isNull);
    await late.up();
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
  });
  testWidgets('명령이 거부되면 다시 그릴 수 있게 0도로 돌아간다', (tester) async {
    answer = false;
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 330);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    await tester.pump();
    expect(flips, 1);
    expect(state(tester).flipping, isFalse);
    expect(state(tester).circle, isNull);
    expect(caption(tester), '틀 둘레로 원을 한 바퀴 그려 뒤집어요');
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
    final gesture = await draw(tester, 180);
    expect(find.descendant(of: find.byType(FlipCircleControl), matching: find.byType(Transform)),
        findsNothing);
    expect(state(tester).circle!.degrees, closeTo(180, 1));
    await gesture.moveTo(centre(tester) + const Offset(-90, 0));
    await tester.pump();
    await gesture.moveTo(centre(tester) + const Offset(-64, -64));
    await tester.pump();
    await gesture.moveTo(centre(tester) + const Offset(0, -90));
    await tester.pump();
    expect(state(tester).flipping, isTrue);
    expect(find.descendant(of: find.byType(FlipCircleControl), matching: find.byType(Transform)),
        findsNothing);
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
    final gesture = await draw(tester, 330);
    await gesture.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    expect(calls, ['HapticFeedbackType.selectionClick']);
    calls.clear();
    await tester.pumpWidget(view(token: 1));
    final quiet = await draw(tester, 330);
    await quiet.up();
    await tester.pump(Duration(milliseconds: flipMs + 10));
    expect(flips, 2);
    expect(calls, isEmpty);
  });
}
