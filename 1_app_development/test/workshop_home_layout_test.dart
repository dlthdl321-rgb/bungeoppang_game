import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/workshop_arrivals.dart';
import 'package:todays_bungeoppang/ui/workshop_home_layout.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 24번 4단계: 숙련된 붕어빵 틀 폭, 판매 카운터 높이(행주 윗변), 빈 굽는 판.
/// 26번 4-1단계: 매대 앞 손님 자리, 낮춘 클리커, 가운데 카운터 버튼.
void main() {
  late DevelopmentBalance config;
  setUpAll(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    return c;
  }

  GriddlePainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('griddle'))).painter! as GriddlePainter;

  Future<void> master(WorkshopController c) => c.command(() {
        final rule = config.mastery(0);
        var mastery = c.state.mastery;
        final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
        for (var i = 0; i < count; i++) {
          mastery = mastery.record(MasteryResult(id: 'practice-$i', flavor: 'redbean',
              variant: i < 5 ? i : 2, completed: true, practice: true, techniquePassed: i >= 5));
        }
        c.state.mastery = mastery;
        c.state.masteryAward = {
          'revision': config.revision,
          'resultId': 'practice-0',
          'practiceRequired': DevelopmentBalance.integer(rule, 'practice_required'),
          'techniqueRequired': DevelopmentBalance.integer(rule, 'technique_passes_required'),
        };
        // Its introduction card is not what these layouts check.
        c.state.featureIntros.add('griddle');
      });

  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('숙련된 붕어빵 틀 폭 = 화면 폭 − 16, 카운터 윗변 = 행주 윗변, 겹침 없음 $tag', (tester) async {
      final c = await mount(tester, size);
      // The griddle art fills its box: 8 from each side, the art's shape.
      final griddle = tester.getRect(find.byKey(const Key('griddle')));
      expect(griddle.left, 8);
      expect(griddle.width, size.width - 16);
      final stove = PixelSprites.cosmetic(CosmeticSlot.stove, 'iron')!;
      expect(griddle.height, closeTo(griddle.width * stove.height / stove.width, .01));
      // The counter's top is the towel's top of the shown background.
      final counter = tester.getRect(find.byKey(const Key('sale-counter')));
      // 26번 4-1단계: the lowered background (all 14 are in the app).
      expect(WorkshopHomeLayout.active, isTrue);
      final towel = NightStallPainter.towelTopOnScreen(size, 'clear', null, low: true);
      expect(towel, isNotNull);
      expect(counter.top, closeTo(towel!, .01));
      // Before opening: the practice button ends 4 above the counter's
      // floating '영업 시작' (26번 4-1단계).
      final pill = tester.getRect(find
          .ancestor(of: find.text('스페셜 붕어빵 제작 시작'), matching: find.byType(Container))
          .first);
      final action = tester.getRect(find.byKey(const Key('counter-action')));
      expect(pill.bottom, closeTo(counter.top - WorkshopHomeLayout.practiceLift, .5));
      expect(pill.bottom, lessThanOrEqualTo(action.top - 4 + .5));
      // The counter stays above the griddle's cells, the cells above the menu
      // (cells show once a flavor is mastered, 26번 2단계).
      await master(c);
      await c.openBusiness();
      await tester.pump();
      final nav = tester.getRect(find.byKey(const Key('home-nav')));
      for (var i = 0; i < 6; i++) {
        final cell = tester.getRect(find.byKey(Key('workshop-cell-$i')));
        expect(cell.top, greaterThan(counter.bottom), reason: 'cell $i');
        expect(cell.bottom, lessThan(nav.top), reason: 'cell $i');
        expect(cell.left, greaterThanOrEqualTo(griddle.left));
        expect(cell.right, lessThanOrEqualTo(griddle.right));
      }
      expect(find.byKey(const Key('customer-queue')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 26번 4-1단계: 손님이 매대 앞에 선다. 손님 아래끝 ≤ 카운터 윗변, 맨 앞은 가로
  // 가운데, 클리커는 카운터 버튼 위·HUD 아래, 손님 0·1·최대.
  Future<void> guests(WorkshopController c, int n) => c.command(() {
        for (var i = 0; i < n; i++) {
          c.state.customers.add(CustomerOrder(id: 'o$i', customerId: 'anonymous_$i', remainingMs: 100000 - i * 30000,
              lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
        }
      });
  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('매대 앞 손님 자리: 0·1·최대 $tag', (tester) async {
      final c = await mount(tester, size);
      await c.openBusiness();
      await tester.pump();
      expect(find.byKey(const Key('customer-guests')), findsOneWidget);
      expect(find.byKey(const Key('customer-0')), findsNothing);
      final counter = tester.getRect(find.byKey(const Key('sale-counter')));
      final action = tester.getRect(find.byKey(const Key('counter-action')));
      final clicker = tester.getRect(find.byKey(const Key('workshop-clicker')));
      final hud = tester.getRect(find.byKey(const Key('level-mission-entry')));
      expect(clicker.bottom, lessThanOrEqualTo(action.top + .5));
      expect(clicker.top, greaterThanOrEqualTo(hud.bottom));
      expect(clicker.center.dx, closeTo(size.width / 2, 2));
      final max = c.arrivalRules.slots(ArrivalKind.regular) + c.arrivalRules.slots(ArrivalKind.named);
      for (final n in [1, max]) {
        await c.command(() => c.state.customers.clear());
        await guests(c, n);
        await tester.pump();
        final front = tester.getRect(find.byKey(const Key('customer-art-0')));
        // The front guest's tap target is over the head, above the clicker.
        final tap = tester.getRect(find.byKey(const Key('customer-0')));
        expect(tap.bottom, lessThanOrEqualTo(clicker.top + .5));
        expect(tap.height, greaterThan(0));
        expect(front.center.dx, closeTo(size.width / 2, 1));
        for (var i = 0; i < n; i++) {
          final g = tester.getRect(find.byKey(Key('customer-art-$i')));
          expect(g.bottom, lessThanOrEqualTo(counter.top + 1), reason: 'guest $i');
          if (i > 0) expect(g.width, lessThan(front.width), reason: 'guest $i');
        }
        // Tapping the clicker still counts (the guests are behind it).
        final before = c.state.taps;
        await tester.tapAt(clicker.center);
        await tester.pump();
        expect(c.state.taps, before + 1);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('모션 줄이기: 떠나는 손님은 흐려지지 않고 그대로 보인다', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await c.openBusiness();
    await guests(c, 1);
    await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
        flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
    expect(await c.sellToCustomer('o0'), isTrue);
    await tester.pump();
    final leaving = tester.widget<Opacity>(find.byKey(const Key('customer-leaving')));
    expect(leaving.opacity, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('그림이 다 없으면 예전 구도: 왼쪽 손님 줄, 안내 카드 왼쪽 72', (tester) async {
    WorkshopHomeLayout.enabled = false;
    addTearDown(() => WorkshopHomeLayout.enabled = true);
    final c = await mount(tester, const Size(390, 844));
    await c.openBusiness();
    await guests(c, 2);
    await tester.pump();
    expect(find.byKey(const Key('customer-queue')), findsOneWidget);
    expect(find.byKey(const Key('customer-guests')), findsNothing);
    final counter = tester.getRect(find.byKey(const Key('sale-counter')));
    final towel = NightStallPainter.towelTopOnScreen(const Size(390, 844), 'clear', null,
        clean: PixelSprites.hasCleanBackground('clear', null));
    expect(counter.top, closeTo(towel!, .01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 24번 6단계: 제작 단계 안내 글이 '제작 취소' 버튼(누르는 영역 48)과 겹치지 않음.
  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('단계 안내 글은 제작 취소 버튼 4 위 ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final c = await mount(tester, size);
      expect(await c.startPractice(), isTrue);
      await tester.pump();
      await tester.pump();
      final caption = tester.getRect(find
          .ancestor(of: find.byKey(const Key('piping-amount')), matching: find.byType(Container))
          .first);
      final cancel = tester.getRect(find.widgetWithText(TextButton, '제작 취소'));
      expect(caption.bottom, lessThanOrEqualTo(cancel.top - 4 + .5));
      expect(caption.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('workshop-mold'))).bottom));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('빈 굽는 판: 영업 준비 중 칸 없음, 영업 중 굽는 칸만 붕어빵', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    for (final id in ['iron', 'copper', 'castiron', 'golden']) {
      final full = PixelSprites.cosmetic(CosmeticSlot.stove, id)!;
      final empty = PixelSprites.emptyStove(id);
      expect(empty, isNotNull, reason: id);
      // Same canvas, so griddleCavities and the fish clips line up.
      expect((empty!.width, empty.height), (full.width, full.height), reason: id);
    }
    expect(painter(tester).filled, isEmpty);
    await c.openBusiness();
    await tester.pump();
    expect(painter(tester).filled, isEmpty);
    await master(c);
    expect(await c.startCell(1), isTrue);
    expect(await c.startCell(4), isTrue);
    await tester.pump();
    expect(painter(tester).filled, {1, 4});
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
