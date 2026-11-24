import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/workshop_mold_stage.dart' show MoldAxlePainter;

/// 원 그려 뒤집기 조작(24번 6단계 DEC-034 → 4차 피드백 IC5 2026-11-20 사용자 결정) 위젯:
/// 그리는 만큼 틀이 축을 따라 돌고(320도 = 반 바퀴) 다 그리면 바로 명령, 손 떼면 0도,
/// 취소·차단·두 번째 손가락·화면 읽기(flip_ms 연출 뒤 명령)·모션 줄이기·진동, 진행 고리 없음(IC8).
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
  Finder turning() => find.byKey(const Key('flip-turn'));

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
    expect(caption(tester), '틀 둘레에 원을 그려 뒤집어요');
    await tester.tap(find.byType(FlipCircleControl));
    await tester.pump(Duration(milliseconds: flipMs * 2));
    expect(flips, 0);
    expect(state(tester).flipping, isFalse);
  });
  testWidgets('원을 그리면 그린 만큼 틀이 돌고, 320도를 다 그리면 반 바퀴 돌아 한 번 뒤집는다', (tester) async {
    await tester.pumpWidget(view());
    final gesture = await draw(tester, 180);
    expect(caption(tester), matches(RegExp(r'^뒤집기 5\d% · 손을 떼면 처음부터$')));
    expect(turn(tester), closeTo(180 * 180 / 320, 2));
    expect(turning(), findsOneWidget);
    // 진행 고리(오른쪽 고리의 노란 원)는 없다(IC8).
    expect(find.byKey(const Key('flip-ring')), findsNothing);
    for (var a = 195.0; a <= 330; a += 15) {
      await gesture.moveTo(centre(tester) + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * 90);
      await tester.pump();
    }
    expect(state(tester).flipping, isTrue);
    expect(caption(tester), '뒤집는 중…');
    expect(turn(tester), 180);
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
    expect(turn(tester), greaterThan(100));
    await gesture.up();
    await tester.pump();
    expect(state(tester).circle, isNull);
    expect(turn(tester), 0);
    expect(caption(tester), '틀 둘레에 원을 그려 뒤집어요');
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
  testWidgets('그리는 중·화면 읽기 연출 중 일시정지(차단)되면 보내지 않고 원위치', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(view());
    final drawing = await draw(tester, 200);
    await tester.pumpWidget(view(blocked: true));
    expect(state(tester).circle, isNull);
    expect(turn(tester), 0);
    await drawing.up();
    await tester.pumpWidget(view());
    tester.semantics.tap(find.semantics.byLabel('틀 뒤집기'));
    await tester.pump();
    semantics.dispose();
    final gesture = await draw(tester, 30);
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
    await tester.pump();
    await tester.pump();
    expect(flips, 1);
    expect(state(tester).flipping, isFalse);
    expect(state(tester).circle, isNull);
    expect(caption(tester), '틀 둘레에 원을 그려 뒤집어요');
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
    expect(turning(), findsNothing);
    expect(state(tester).circle!.degrees, closeTo(180, 1));
    await gesture.moveTo(centre(tester) + const Offset(-90, 0));
    await tester.pump();
    await gesture.moveTo(centre(tester) + const Offset(-64, -64));
    await tester.pump();
    await gesture.moveTo(centre(tester) + const Offset(0, -90));
    await tester.pump();
    expect(state(tester).flipping, isTrue);
    expect(turning(), findsNothing);
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
  testWidgets('대기 중에는 원 화살표 안내, 그리기 시작하면 사라진다', (tester) async {
    MoldAxlePainter pins() => tester.widget<CustomPaint>(find.byKey(const Key('flip-pins'))).painter!
        as MoldAxlePainter;
    await tester.pumpWidget(view());
    expect(pins().hint, isTrue);
    final gesture = await draw(tester, 60);
    expect(pins().hint, isFalse);
    await gesture.up();
    await tester.pump();
    expect(pins().hint, isTrue);
  });
  testWidgets('틀 상자 밖(touchOutset 안)에서 그려도 뒤집힌다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 300, height: 200,
        child: FlipCircleControl(stageToken: 0, blocked: false, config: config,
            touchOutset: const EdgeInsets.all(40),
            mold: const ColoredBox(color: Colors.brown),
            onFlip: () async {
              flips++;
              return true;
            }))))));
    // 큰 원(반지름 95): 안쪽 틀 상자(220x120) 밖을 지나간다.
    final gesture = await draw(tester, 330, radius: 95);
    await tester.pump();
    expect(flips, 1);
    await gesture.up();
  });
}
