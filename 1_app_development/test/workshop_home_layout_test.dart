import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_griddle.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
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
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
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
      // Before opening: the practice button keeps its place over the
      // floating button's room (26번 4-1단계); '영업 시작' itself is small
      // beside the '영업 준비' sign, right of it, inside the HUD row and
      // clear of the settings button (시안 확인 2차).
      final pill = tester.getRect(find
          .ancestor(of: find.text('스페셜 붕어빵 제작 시작'), matching: find.byType(Container))
          .first);
      // 4차 피드백 g11: the pill sits on the closed griddle on the lower
      // workbench (no mold hangs over the guests), under the counter and
      // over the menu bar.
      expect(find.byKey(const Key('idle-mold')), findsNothing);
      expect(pill.top, greaterThan(counter.bottom));
      expect(pill.bottom, lessThan(tester.getRect(find.byKey(const Key('home-nav'))).top));
      expect(griddle.contains(pill.center), isTrue);
      expect(find.byKey(const Key('counter-action')), findsNothing);
      final open = tester.getRect(find.byKey(const Key('business-open')));
      final sign = tester.getRect(find.byKey(const Key('workshop-status-badge')));
      final settings = tester.getRect(find.byKey(const Key('home-settings')));
      expect(open.height, closeTo(WorkshopHomeLayout.businessHeight, .5));
      expect(open.left, greaterThanOrEqualTo(sign.right));
      expect(open.right, lessThanOrEqualTo(settings.left));
      expect(open.center.dy, closeTo(sign.center.dy, 2));
      expect(open.bottom, lessThan(pill.top));
      // The '오늘' slip hangs under the settings button, right edges lined up.
      final slip = tester.getRect(find.byKey(const Key('daily-ticket')));
      expect(slip.top, closeTo(settings.bottom + WorkshopHomeLayout.slipGap, .5));
      expect(slip.right, closeTo(settings.right, .5));
      expect(slip.bottom, lessThan(counter.top));
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
      // No guest: the next step is '영업 종료', small at the top (시안 확인
      // 2차), so the floating button's room above the counter is empty.
      expect(find.byKey(const Key('counter-action')), findsNothing);
      final close = tester.getRect(find.byKey(const Key('business-close')));
      // The clicker keeps the room the old floating button had (4차 사용자 결정).
      final actionTop = counter.top - WorkshopHomeLayout.clickerLift;
      final clicker = tester.getRect(find.byKey(const Key('workshop-clicker')));
      final hud = tester.getRect(find.byKey(const Key('level-mission-entry')));
      expect(close.height, closeTo(WorkshopHomeLayout.businessHeight, .5));
      expect(close.bottom, lessThan(clicker.top));
      expect(clicker.bottom, lessThanOrEqualTo(actionTop + .5));
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
        // 4차 IA3: the 붕어빵 요정 hides from guests at the right edge, half
        // on screen and clear of the front guest; tapping it still counts.
        final hiding = tester.getRect(find.byKey(const Key('workshop-clicker')));
        expect(find.byKey(const Key('fairy-hiding')), findsOneWidget);
        expect(hiding.left, greaterThan(front.right - 1));
        expect(hiding.right, greaterThan(size.width));
        expect(size.width - hiding.left, greaterThanOrEqualTo(56));
        expect(hiding.bottom, lessThanOrEqualTo(counter.top));
        final before = c.state.taps;
        await tester.tapAt(Offset(size.width - 20, hiding.center.dy));
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

  // 24번 6단계: 제작 단계 안내 글이 '제작 취소' 버튼과 겹치지 않음. 4차 g11부터
  // 버튼은 작업대 틀 위, 안내 글은 틀 아래끝이고 하단 메뉴 위.
  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    testWidgets('단계 안내 글은 제작 취소 버튼 아래, 하단 메뉴 위 ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      final c = await mount(tester, size);
      expect(await c.startPractice(), isTrue);
      await tester.pump();
      await tester.pump();
      final caption = tester.getRect(find
          .ancestor(of: find.byKey(const Key('piping-amount')), matching: find.byType(Container))
          .first);
      final cancel = tester.getRect(find.byKey(const Key('mold-cancel')));
      expect(caption.top, greaterThan(cancel.bottom));
      expect(caption.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('workshop-mold'))).bottom));
      expect(caption.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('home-nav'))).top));
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
    // 4차 g6: past the automatic batter and filling, so the cells cook.
    await c.command(() => c.state.grid = c.state.grid.advanceActive(GriddleProgress.prepMs(c.config)));
    await tester.pump();
    expect(painter(tester).filled, {1, 4});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 26번 4-2단계 F8 (S4-2-Q1 '닫힌 판·불 꺼짐'): 영업 준비 중·숙련 전에는 닫히고
  // 불이 꺼진 판, 영업 중 + 쓸 수 있으면 열린 판(불 켜짐)과 판 위로 선 뚜껑.
  // 뚜껑은 굽는 판 상자 위에 따로 그려 칸 위치는 그대로다.
  testWidgets('6구 그림: 영업 준비·숙련 전 닫힘, 숙련 뒤 열림과 뚜껑, 칸 위치 그대로', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    final griddle = tester.getRect(find.byKey(const Key('griddle')));
    expect(painter(tester).closed, isTrue, reason: '영업 준비 중');
    expect(find.byKey(const Key('griddle-lid')), findsNothing);
    await c.openBusiness();
    await tester.pump();
    expect(painter(tester).closed, isTrue, reason: '숙련 전');
    expect(find.byKey(const Key('griddle-locked')), findsOneWidget);
    expect(find.byKey(const Key('griddle-lid')), findsNothing);
    await master(c);
    await tester.pump();
    expect(painter(tester).closed, isFalse);
    expect(tester.getRect(find.byKey(const Key('griddle'))), griddle, reason: '판 상자는 그대로');
    final lid = tester.getRect(find.byKey(const Key('griddle-lid')));
    expect(lid.bottom, closeTo(griddle.top, .01));
    expect((lid.left, lid.width), (griddle.left, griddle.width));
    final stove = PixelSprites.cosmetic(CosmeticSlot.stove, 'iron')!;
    expect(lid.height, closeTo(griddle.width * PixelSprites.openStoveLidRoom / stove.width, .01));
    // The cells stay on the plate's cavities (griddleCavities on the 941x470 art).
    for (var i = 0; i < 6; i++) {
      final cell = tester.getRect(find.byKey(Key('workshop-cell-$i')));
      expect(cell.top, greaterThan(griddle.top), reason: 'cell $i');
      expect(cell.bottom, lessThanOrEqualTo(griddle.bottom), reason: 'cell $i');
    }
    // Closing the stall closes the griddle again.
    expect(await c.closeBusiness(), isTrue);
    await tester.pump();
    expect(painter(tester).closed, isTrue);
    expect(find.byKey(const Key('griddle-lid')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 26번 4-2단계 F10: 하단 메뉴 아이콘은 여백을 자른 nav_* 그림을 이름 위에 모두
  // 같은 크기로 그린다(가장 긴 이름이 들어가도록 넷이 같은 비율로 줄어듦).
  for (final size in const [Size(360, 640), Size(390, 844), Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('하단 메뉴 아이콘 넷이 같은 크기 $tag', (tester) async {
      await mount(tester, size);
      final icons = tester
          .widgetList<PixelIcon>(find.descendant(
              of: find.byKey(const Key('home-nav')), matching: find.byType(PixelIcon)))
          .toList();
      expect(icons.map((i) => i.name), ['nav_menu', 'nav_skill', 'nav_skins', 'nav_shop']);
      final shown = [
        for (final i in find
            .descendant(of: find.byKey(const Key('home-nav')), matching: find.byType(PixelIcon))
            .evaluate())
          tester.getSize(find.byWidget(i.widget)).width
      ];
      // The drawn part is 87-88 of 96 in every icon, so the same box shows
      // them within 1 px of each other.
      for (final s in shown) {
        expect((s - shown.first).abs() * 88 / 96, lessThanOrEqualTo(2));
        expect(s * 87 / 96, greaterThanOrEqualTo(26), reason: '보이는 그림이 충분히 크다');
      }
      for (final id in ['menubar', 'skills', 'skins', 'shop']) {
        final key = find.byKey(Key('menu-$id'));
        if (key.evaluate().isEmpty) continue; // locked: the lock overlay's own key
        final button = tester.getRect(key);
        expect(button.height, lessThanOrEqualTo(NightHome.navHeight - 6));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
