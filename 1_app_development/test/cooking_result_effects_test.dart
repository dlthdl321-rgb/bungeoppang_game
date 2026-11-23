import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'test_support.dart' show FakeAudio;
import 'step02_controller_test.dart' show MemoryRepository;

/// 26번 4단계: 결과 등급 연출 — 소리·진동은 결과마다 한 번, 설정을 따르고,
/// 모션 줄이기면 움직이는 효과 없이 글·소리만. 주문 손님은 등급 대사를 한다.
void main() {
  setUp(() => CookingResultView.celebrated = null);

  Future<List<String>> show(WidgetTester tester, FakeAudio audio, CookingGrade grade,
      {String id = 'r1', bool vibration = true, bool reduce = false, bool disable = false}) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: MaterialApp(
            home: GameAudioScope(
                audio: audio,
                child: Center(
                    child: SizedBox(
                        width: 300,
                        height: 180,
                        child: CookingResultView(
                            sessionId: id,
                            grade: grade,
                            line: 'line',
                            reduceMotion: reduce,
                            vibration: vibration)))))));
    return haptics;
  }

  testWidgets('등급별 소리·진동 한 번, 다시 그려도 한 번', (tester) async {
    final expected = {
      CookingGrade.perfect: (Sfx.resultPerfect, ['HapticFeedbackType.heavyImpact']),
      CookingGrade.good: (Sfx.resultGood, ['HapticFeedbackType.mediumImpact']),
      CookingGrade.fair: (Sfx.resultFair, ['HapticFeedbackType.lightImpact']),
      CookingGrade.near: (Sfx.resultNear, ['HapticFeedbackType.lightImpact']),
      CookingGrade.fail: (Sfx.resultFail, <String>[]),
    };
    for (final MapEntry(key: grade, value: (sound, vibrate)) in expected.entries) {
      final audio = FakeAudio();
      final haptics = await show(tester, audio, grade, id: grade.name);
      expect(audio.sounds, [sound], reason: grade.name);
      expect(haptics, vibrate, reason: grade.name);
      expect(find.text(cookingGradeTitle(grade)), findsOneWidget);
      expect(find.byKey(const Key('mold-result-effects')), findsOneWidget);
      // Rebuilt (or shown again) for the same result: no second sound.
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, audio, grade, id: grade.name);
      await tester.pump(const Duration(milliseconds: 200));
      expect(audio.sounds, [sound], reason: grade.name);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('진동 끔이면 진동 없음, 효과음 끔이면 소리 없음', (tester) async {
    final audio = FakeAudio()..sfxOn = false;
    final haptics = await show(tester, audio, CookingGrade.perfect, vibration: false);
    expect(haptics, isEmpty);
    expect(audio.sounds, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('모션 줄이기(설정·시스템)면 효과 없이 글·소리·진동만', (tester) async {
    for (final (reduce, disable) in [(true, false), (false, true)]) {
      CookingResultView.celebrated = null;
      final audio = FakeAudio();
      final haptics = await show(tester, audio, CookingGrade.perfect, reduce: reduce, disable: disable);
      expect(find.byKey(const Key('mold-result-effects')), findsNothing);
      expect(find.text('완벽해요!'), findsOneWidget);
      expect(find.byKey(const Key('mold-result-caption')), findsOneWidget);
      expect(audio.sounds, [Sfx.resultPerfect]);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
      // Still from the first frame: the big word is not hopping.
      final scale = tester.widget<Transform>(find.ancestor(
          of: find.text('완벽해요!'), matching: find.byType(Transform)).first);
      expect(scale.transform.getMaxScaleOnAxis(), 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('입자 수는 상한 안', () {
    for (final grade in CookingGrade.values) {
      for (final burnt in [false, true]) {
        final (a, b, c) = CookingResultView.particles(grade, burnt: burnt);
        expect(a + b + c, lessThanOrEqualTo(CookingResultView.maxParticles));
      }
    }
  });

  group('주문 손님 반응', () {
    late DevelopmentBalance config;
    late MemoryRepository repository;
    late WorkshopController controller;
    setUp(() async {
      config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      repository = MemoryRepository();
      controller = WorkshopController(config, repository,
          now: () => DateTime.utc(2026, 10, 18), random: Random(2));
      await controller.initialize();
    });
    tearDown(() => controller.dispose());

    Future<void> bake(WorkshopController c) async {
      var s = c.state.session!;
      s = s.pour(s.token, PaintAmount.even);
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, PaintAmount.even);
      s = s.close(s.token);
      final flipped = s.flip(s.token);
      await c.command(() {
        c.state.session = flipped;
        c.state.phaseMs = 15000;
      });
      expect(await c.cookingCommand(flipped.takeOut(flipped.token, 15000)), isTrue);
      expect(c.state.session!.phase, CookingPhase.result);
    }

    test('주문 제작 결과에 등급 대사, 재시작 뒤엔 없음', () async {
      await controller.openBusiness();
      await controller.command(() => controller.state.customers.add(CustomerOrder(
          id: 'order', remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
      expect(await controller.startOrderProduction('order', 'redbean'), isTrue);
      await bake(controller);
      final session = controller.state.session!;
      final grade = cookingGrade(config, session, difficulty: controller.difficulty('redbean'));
      expect(grade, CookingGrade.perfect);
      final line = controller.resultReaction(grade);
      expect(line, endsWith(': 와, 이건 사진 찍고 싶을 만큼 예뻐요!'));
      expect(controller.resultReaction(CookingGrade.fail), endsWith(': 괜찮아요, 천천히 해 주세요.'));
      // Memory only: a restarted controller has no reaction.
      final again = WorkshopController(config, repository,
          now: () => DateTime.utc(2026, 10, 18), random: Random(2));
      await again.initialize();
      expect(again.state.session?.id, session.id);
      expect(again.resultReaction(grade), isNull);
      again.dispose();
    });

    // 4차 피드백 IA5 · 사용자 답(2026-11-21): the order customer's words stay
    // by them after the result closes, until they leave or speak again.
    test('결과를 닫아도 주문 손님 대사는 그 손님이 있는 동안 남는다', () async {
      await controller.openBusiness();
      await controller.command(() => controller.state.customers.add(CustomerOrder(
          id: 'order', remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
      final who = controller.state.customers.single.customerId;
      expect(await controller.startOrderProduction('order', 'redbean'), isTrue);
      await bake(controller);
      expect(await controller.storeResult(true), isTrue);
      expect(controller.guestWords[who], (order: 'order', text: '와, 이건 사진 찍고 싶을 만큼 예뻐요!'));
      // Business closed: everyone leaves, the words with them.
      expect(await controller.closeBusiness(), isTrue);
      expect(controller.guestWords, isEmpty);
    });

    test('연습에는 반응 없음', () async {
      expect(await controller.startPractice(), isTrue);
      await bake(controller);
      expect(controller.resultReaction(CookingGrade.perfect), isNull);
    });
  });
}

