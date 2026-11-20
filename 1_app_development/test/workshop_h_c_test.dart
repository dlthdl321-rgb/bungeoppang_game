import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/feedback_config.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import 'package:todays_bungeoppang/ui/center_toast.dart';
import 'package:todays_bungeoppang/ui/flavor_picker.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 26번 3차 녹화 피드백 C 묶음(홈·굽기 H17~H30): 다시 켤 때 반죽부터,
/// 품질 별, 가운데 알림, 맛 고르기, 메뉴 한 곳, 결과 버튼.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  test('H20: 속을 짜던 세션을 다시 켜면 같은 맛으로 첫 반죽부터 (명령 되돌림은 그대로)', () async {
    final repo = MemoryRepository();
    final c = WorkshopController(config, repo, now: () => DateTime.utc(2026, 10, 18));
    await c.initialize();
    expect(await c.startPractice(), isTrue);
    final s = c.state.session!;
    expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
    expect(c.state.session!.phase, CookingPhase.filling);
    // A failing command rolls back through the saved form: still filling.
    expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isFalse);
    expect(c.state.session!.phase, CookingPhase.filling);
    final id = c.state.session!.id;
    c.dispose();
    final again = WorkshopController(config, repo, now: () => DateTime.utc(2026, 10, 18));
    await again.initialize();
    final restarted = again.state.session!;
    expect(restarted.id, id);
    expect(restarted.phase, CookingPhase.firstBatter);
    expect(restarted.firstBatterDone, isFalse);
    expect(restarted.flavor, 'redbean');
    expect(restarted.practice, isTrue);
    again.dispose();
  });

  test('H24 → 4차 IC9: 등급별 별 수(5개 만점, 주문 품질 별처럼 최소 1개)', () {
    expect(cookingStarsMax, 5);
    expect(cookingStars(CookingGrade.perfect), 5);
    expect(cookingStars(CookingGrade.good), 4);
    expect(cookingStars(CookingGrade.near), 2);
    expect(cookingStars(CookingGrade.fail), 1);
  });

  Future<WorkshopController> mount(WidgetTester tester) async {
    final account = await mountGame(tester, const Size(390, 844), reduced: true);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  testWidgets('H23·H27·H28·H30: 메뉴는 하단에만, 황금 붕어빵 표시, 잠긴 버튼은 가운데 알림', (tester) async {
    final c = await mount(tester);
    expect(find.byKey(const Key('menu-menu')), findsNothing);
    expect(find.byKey(const Key('menu-menubar')), findsOneWidget);
    expect(find.byKey(const Key('hud-gold-value')), findsOneWidget);
    expect(find.byKey(const Key('flavor-button')), findsOneWidget);
    expect(c.featureLock(WorkshopFeature.skills), isNotNull);
    await tester.tap(find.byKey(const Key('menu-skills-locked')));
    await tester.pump();
    expect(find.byKey(const Key('center-toast')), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    final toast = tester.getRect(find.byKey(const Key('center-toast')));
    expect(toast.center.dy, closeTo(844 / 2, 60));
    await tester.pump(CenterToast.duration + const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byKey(const Key('center-toast')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('H26: 맛이 둘 이상이면 제작 시작 때 먼저 고르고, 고른 맛으로 연습', (tester) async {
    final c = await mount(tester);
    await c.command(() {
      c.state.recipes.add('custard');
      c.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: c.difficulty('custard'));
    });
    await tester.pump();
    await tester.tap(find.byKey(const Key('workshop-mold-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flavor-picker')), findsOneWidget);
    expect(find.byKey(const Key('flavor-pick-cocoa')), findsOneWidget);
    await tester.tap(find.byKey(const Key('flavor-pick-custard')));
    await tester.pumpAndSettle();
    expect(c.state.session!.flavor, 'custard');
    expect(find.text('슈크림 붕어빵 연습'), findsOneWidget);
    expect(find.textContaining('반죽 목표'), findsNothing);
    // While baking the flavor button shows it and cannot change it.
    expect(tester.widget<Text>(find.byKey(const Key('flavor-label'))).data, '슈크림');
    expect(flavorChoices(c).first.$2, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('H25: 연습 결과에는 보관하기·버리기 버튼 둘 다', (tester) async {
    final c = await mount(tester);
    expect(await c.startPractice(), isTrue);
    var s = c.state.session!;
    s = s.pour(s.token, PaintAmount.even);
    s = s.squeezeFilling(s.token, PaintAmount.even);
    s = s.pour(s.token, PaintAmount.even);
    s = s.close(s.token);
    s = s.flip(s.token);
    final done = s.takeOut(s.token, 15000);
    await c.command(() => c.state.session = done);
    await tester.pump();
    expect(find.byKey(const Key('mold-store')), findsOneWidget);
    expect(find.byKey(const Key('mold-discard')), findsOneWidget);
    expect(find.byKey(const Key('mold-result-stars')), findsOneWidget);
    expect(find.byKey(const Key('mold-result-band')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mold-discard')));
    await tester.pump();
    expect(c.state.session, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
