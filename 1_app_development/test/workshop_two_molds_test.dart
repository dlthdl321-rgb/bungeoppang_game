import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_tutorial.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 24번 3단계: 영업 상태별 두 틀 규칙(DEC-035~037).
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final manual = config.section('manual_cooking');
  final limit = DevelopmentBalance.integer(config.section('server_validation'), 'max_taps_per_second');

  /// A controller on a fake monotonic clock ([mono]) so phase times and the
  /// tap limit do not follow the real stopwatch.
  Future<(WorkshopController, void Function(int))> make({String tutorial = 'done'}) async {
    var mono = 0;
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => mono);
    await c.initialize();
    await c.command(() => c.state..tutorial = tutorial..featureIntros.add('fairy'));
    return (c, (int ms) => mono += ms);
  }

  Future<void> order(WorkshopController c, {String id = 'first'}) => c.command(() => c.state.customers.add(
      CustomerOrder(id: id, customerId: 'anonymous_$id', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));

  /// Runs the open session through to its result.
  Future<void> bake(WorkshopController c) async {
    var session = c.state.session!;
    expect(await c.cookingCommand(session.pour(session.token, PaintAmount.even)), isTrue);
    session = c.state.session!;
    expect(await c.cookingCommand(session.squeezeFilling(session.token, const PaintAmount(720, 830))), isTrue);
    session = c.state.session!;
    expect(await c.cookingCommand(session.pour(session.token, PaintAmount.even)), isTrue);
    await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'lid_close_ms'));
    session = c.state.session!;
    expect(await c.cookingCommand(session.close(session.token)), isTrue);
    await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'flip_ms'));
    session = c.state.session!;
    expect(await c.cookingCommand(session.flip(session.token)), isTrue);
    session = c.state.session!;
    expect(await c.cookingCommand(session.takeOut(session.token, 0)), isTrue);
    expect(c.state.session!.phase, CookingPhase.result);
  }

  group('컨트롤러', () {
    test('영업 중에는 연습 제작을 명령에서 거부하고 주문 제작은 허용한다', () async {
      final (c, _) = await make();
      addTearDown(c.dispose);
      await c.openBusiness();
      expect(await c.startPractice(), isFalse);
      expect(c.notice, '연습 제작은 영업 준비 중에만 할 수 있어요.');
      expect(c.state.session, isNull);
      await order(c);
      expect(await c.startOrderProduction('first', 'redbean'), isTrue);
      expect(c.state.session!.practice, isFalse);
    });

    test('영업 준비 중에는 연습 제작이 되고, 제작 중에는 영업을 시작할 수 없다', () async {
      final (c, _) = await make();
      addTearDown(c.dispose);
      expect(await c.startPractice(), isTrue);
      expect(await c.openBusiness(), isFalse);
      expect(c.notice, '스페셜 붕어빵을 다 만든 뒤 영업을 시작해요.');
      expect(c.state.business.open, isFalse);
      await bake(c);
      // A finished result waiting to be stored is still in the mold.
      expect(await c.openBusiness(), isFalse);
      expect(await c.storeResult(true), isTrue);
      expect(await c.openBusiness(), isTrue);
      expect(c.state.business.open, isTrue);
    });

    test('클리커 탭은 영업 중에만 붕어빵력을 주고 1초에 상한을 넘는 탭은 넣지 않는다', () async {
      final (c, advance) = await make();
      addTearDown(c.dispose);
      expect(c.clickerTap(), isNull, reason: '영업 준비 중');
      expect(c.state.taps, 0);
      await c.openBusiness();
      final buns = c.state.buns;
      for (var i = 0; i < limit; i++) {
        expect(c.clickerTap(), c.tapRate);
      }
      expect(c.clickerTap(), isNull, reason: '같은 1초 안의 ${limit + 1}번째 탭');
      expect(c.state.taps, limit);
      expect(c.state.buns - buns, c.tapRate * BigInt.from(limit));
      advance(999);
      expect(c.clickerTap(), isNull);
      advance(1);
      expect(c.clickerTap(), c.tapRate);
      expect(c.state.taps, limit + 1);
    });

    test('주문 제작 중에는 클리커 탭과 기존 탭 경로를 모두 거부한다', () async {
      final (c, _) = await make();
      addTearDown(c.dispose);
      await c.openBusiness();
      await order(c);
      expect(await c.startOrderProduction('first', 'redbean'), isTrue);
      final taps = c.state.taps, buns = c.state.buns;
      expect(c.clickerTap(), isNull);
      c.tap();
      expect(c.state.taps, taps);
      expect(c.state.buns, buns);
    });

    test('안내 cook 단계에서 먼저 영업을 열면 주문 제작으로 안내한다', () async {
      final (c, _) = await make(tutorial: 'cook');
      addTearDown(c.dispose);
      expect(workshopTutorialStep(c.state, ready: 0)!.target, 'workshop-mold');
      await c.openBusiness();
      final waiting = workshopTutorialStep(c.state, ready: 0)!;
      expect(waiting.text, contains('붕어빵 요정을 톡톡'));
      expect(waiting.target, 'workshop-clicker');
      await order(c);
      final produce = workshopTutorialStep(c.state, ready: 0)!;
      expect(produce.text, contains('주문 제작'));
      expect(produce.target, 'order-produce');
      expect(await c.startOrderProduction('first', 'redbean'), isTrue);
      await bake(c);
      expect(await c.storeResult(true), isTrue);
      expect(c.state.tutorial, 'sell');
      expect(workshopTutorialStep(c.state, ready: 1)!.target, 'sale-button');
    });
  });

  group('화면', () {
    Future<WorkshopController> mount(WidgetTester tester) async {
      final account = await mountGame(tester, const Size(390, 844), reduced: true);
      final (c, _) = await make();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      return c;
    }

    Finder key(String name) => find.byKey(Key(name));

    testWidgets('영업 준비 중: 스페셜 붕어빵 틀과 제작 시작만, 숙련된 붕어빵 틀은 빈 틀', (tester) async {
      final c = await mount(tester);
      expect(key('idle-mold'), findsOneWidget);
      expect(find.text('스페셜 붕어빵 제작 시작'), findsOneWidget);
      // 26번 3차 피드백 H26: the flavor button at the HUD's top-left.
      expect(key('flavor-button'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('+${c.tapRate} 붕어빵력'), findsNothing);
      expect(key('workshop-clicker'), findsNothing);
      expect(key('floating-fish'), findsNothing);
      // The griddle picture only: no cell faces, words or touches.
      expect(key('griddle'), findsOneWidget);
      expect(key('griddle-idle'), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        expect(key('workshop-cell-$i'), findsNothing);
      }
      await tester.tap(key('workshop-mold-action'));
      await tester.pump();
      expect(c.state.session?.practice, isTrue);
      expect(key('active-empty-mold'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('영업 중 평소: 틀 없이 큰 붕어빵 클리커, 새 주문에도 틀이 나오지 않음', (tester) async {
      final c = await mount(tester);
      await c.openBusiness();
      await tester.pump();
      expect(key('workshop-clicker'), findsOneWidget);
      expect(key('floating-fish'), findsOneWidget);
      // 4차 IA3: the 붕어빵 요정 twinkles only when tapped.
      expect(key('twinkling-sparkles'), findsNothing);
      expect(key('fairy-twinkle'), findsNothing);
      expect(key('fairy-swimming'), findsOneWidget);
      expect(key('idle-mold'), findsNothing);
      expect(key('workshop-mold-action'), findsNothing);
      expect(find.text('스페셜 붕어빵 제작 시작'), findsNothing);
      expect(key('flavor-button'), findsNothing);
      // The griddle is out (not idle); before a flavor is mastered it shows
      // the common lock instead of cells (26번 2단계).
      expect(key('griddle-locked'), findsOneWidget);
      expect(key('workshop-cell-0'), findsNothing);
      expect(key('griddle-idle'), findsNothing);

      final buns = c.state.buns, taps = c.state.taps;
      await tester.tap(key('workshop-clicker'));
      await tester.pump();
      expect(c.state.taps, taps + 1);
      expect(c.state.buns, buns + c.tapRate);
      // Reduced motion (mountGame reduced): a still gain, no crumbs.
      expect(key('clicker-static-gain'), findsOneWidget);

      // A new order no longer brings the mold back for a while.
      final home = tester.getRect(key('workshop-clicker'));
      await order(c);
      await tester.pump();
      expect(key('workshop-clicker'), findsOneWidget);
      expect(key('idle-mold'), findsNothing);
      // 4차 IA3: shy, the fairy hides at the right edge, half on screen,
      // still a fair target, and its taps count the same.
      expect(key('fairy-hiding'), findsOneWidget);
      final hiding = tester.getRect(key('workshop-clicker'));
      expect(hiding.right, greaterThan(390));
      expect(hiding.width, lessThan(home.width));
      expect(390 - hiding.left, greaterThanOrEqualTo(56));
      expect(hiding.height, greaterThanOrEqualTo(56));
      final hiddenTaps = c.state.taps;
      await tester.tapAt(Offset(390 - 20, hiding.center.dy));
      await tester.pump();
      expect(c.state.taps, hiddenTaps + 1);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^숨어 있는 붕어빵 요정 누르기')), findsOneWidget);
      semantics.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(key('workshop-clicker'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('영업 중 주문 제작: 틀이 나오고 클리커는 막히며, 결과를 닫으면 클리커로 돌아옴', (tester) async {
      final c = await mount(tester);
      await c.openBusiness();
      await order(c);
      await tester.pump();
      // The counter's bake button starts the order in the mold.
      await tester.tap(key('order-produce'));
      await tester.pump();
      expect(c.state.session?.practice, isFalse);
      expect(key('active-empty-mold'), findsOneWidget);
      expect(key('workshop-clicker'), findsNothing);
      expect(key('floating-fish'), findsNothing);
      expect(c.clickerTap(), isNull);
      // The griddle stays locked (nothing mastered yet) while the mold is busy.
      expect(key('griddle-locked'), findsOneWidget);
      expect(key('workshop-cell-0'), findsNothing);

      await bake(c);
      await tester.pump();
      expect(find.text('결과 닫기'), findsOneWidget);
      expect(key('workshop-clicker'), findsNothing);
      await tester.tap(key('mold-store'));
      await tester.pump();
      expect(c.state.session, isNull);
      expect(key('workshop-clicker'), findsOneWidget);
      expect(key('floating-fish'), findsOneWidget);
      expect(key('active-empty-mold'), findsNothing);
      final taps = c.state.taps;
      // The order's guest may still wait (the fairy peeks from the right
      // edge): tap the part on screen.
      final fairy = tester.getRect(key('workshop-clicker'));
      await tester.tapAt(Offset(fairy.center.dx.clamp(0, 390 - 20), fairy.center.dy));
      await tester.pump();
      expect(c.state.taps, taps + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
