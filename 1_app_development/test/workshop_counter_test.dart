import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/workshop_home_layout.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 3단계: "가게 관리" 시트 없이 홈에서 손님 → 주문 → 재고 → 판매.
/// 26번 4-1단계: 손님은 매대 앞에 서고, 카운터 버튼은 화면 가운데에 뜨며,
/// 저장 점검(checkpoint) 중에도 버튼이 깜빡이지 않는다(F1).
void main() {
  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    // A still monotonic clock keeps the wait rings off the real stopwatch.
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    // A player past the first-run guide (workshop_guide_test covers the guide).
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }
  // Anonymous customers keep the picture independent of the random visitor.
  Future<void> queue(WorkshopController c) => c.command(() {
    c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
  });
  Future<void> stock(WorkshopController c, String id) => c.command(() {
    c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: id, flavor: 'redbean', variant: 2,
        quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
  });
  String label(WidgetTester tester, String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).first.data!;

  testWidgets('홈에서 영업 시작 → 부분 판매 → 판매 완료 → 영업 종료', (tester) async {
    final c = await mount(tester, const Size(360, 800));
    expect(find.text('가게 관리'), findsNothing);
    expect(find.byKey(const Key('customer-welcome')), findsNothing);
    await tester.tap(find.byKey(const Key('business-open')));
    await tester.pump();
    expect(c.state.business.open, isTrue);
    // 26번 5-1단계: after the first-run guide guests come in real time; no '맞이' button (S5-1-Q2).
    expect(find.byKey(const Key('customer-welcome')), findsNothing);
    expect(find.byKey(const Key('business-close')), findsOneWidget);

    await queue(c);
    await stock(c, 'one');
    await tester.pump();
    expect(find.byKey(const Key('customer-0')), findsOneWidget);
    expect(find.byKey(const Key('customer-1')), findsOneWidget);
    // 26번 4-1단계: one line, the short name and the order; seconds are the bar over the guest.
    expect(tester.widget<Text>(find.byKey(const Key('counter-title'))).data, '일반 손님 · 팥 0/2');
    expect(tester.widget<Text>(find.byKey(const Key('counter-order'))).data, '재고 1개');
    expect(label(tester, 'sale-button'), '1개 먼저 판매');

    await tester.tap(find.byKey(const Key('sale-button')));
    await tester.pump();
    expect(c.state.completedSales, 0);
    expect(c.state.customers.first.delivered(0), 1);
    expect(c.state.buns, greaterThan(BigInt.zero));
    expect(tester.widget<Text>(find.byKey(const Key('counter-title'))).data, '일반 손님 · 팥 1/2');
    expect(tester.widget<Text>(find.byKey(const Key('counter-order'))).data, '재고 0개');
    // Nothing left to hand over: the action becomes baking the missing flavor.
    expect(find.byKey(const Key('sale-button')), findsNothing);
    expect(label(tester, 'order-produce'), '팥 제작');

    await stock(c, 'two');
    await tester.pump();
    expect(label(tester, 'sale-button'), '판매 완료');
    expect(find.byKey(const Key('order-produce')), findsNothing);
    await tester.tap(find.byKey(const Key('sale-button')));
    await tester.pump();
    expect(c.state.completedSales, 1);
    expect(c.state.customers.single.id, 'second');
    expect(c.state.pendingGold.keys, ['sale:first']);

    await c.command(() => c.state.customers.clear());
    await tester.pump();
    await tester.tap(find.byKey(const Key('business-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('영업 종료').last);
    await tester.pumpAndSettle();
    expect(c.state.business.open, isFalse);
    expect(find.byKey(const Key('business-open')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('손님 배지와 재고 버튼은 작은 창을 열고, 주문 제작은 창을 닫고 스페셜 붕어빵 제작을 시작한다', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await c.openBusiness();
    await queue(c);
    await stock(c, 'one');
    await tester.pump();

    await tester.tap(find.byKey(const Key('stock-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-card')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('stock-card')), matching: find.text('재고 1개')), findsOneWidget);
    expect(c.gridVisible, isFalse);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(c.gridVisible, isTrue);

    await tester.tap(find.byKey(const Key('customer-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-card')), findsOneWidget);
    // 26번 4-1단계: no queue number; walk-ins are '일반 손님'.
    expect(tester.widget<Text>(find.byKey(const Key('customer-card-title'))).data, '일반 손님');
    expect(find.text('판매는 맨 앞 손님부터 해요.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer-produce-redbean')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-card')), findsNothing);
    expect(c.state.session?.practice, isFalse);
    // The counter makes room for the big mold while it is in use.
    expect(find.byKey(const Key('sale-counter')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('메뉴에는 관리 시트 대신 영업 종료와 황금 심사 대기만 남는다', (tester) async {
    final c = await mount(tester, const Size(360, 800));
    await c.openBusiness();
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-menubar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-management')), findsNothing);
    expect(find.byKey(const Key('menu-pending-gold')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('menu-close-business')));
    await tester.tap(find.byKey(const Key('menu-close-business')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('영업 종료').last);
    await tester.pumpAndSettle();
    expect(c.state.business.open, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Flutter's bundled test font keeps these baselines portable; Korean glyph
  // appearance is not validated here.
  for (final size in [const Size(360, 800), const Size(390, 844), const Size(412, 915)]) {
    testWidgets('판매 카운터 골든 ${size.width.toInt()}', (tester) async {
      final c = await mount(tester, size);
      await c.openBusiness();
      await stock(c, 'one');
      // Last: a later command would age the wait rings by real elapsed ms.
      await queue(c);
      await tester.pump();
      await expectLater(find.byKey(const Key('home-capture')),
          matchesGoldenFile('goldens/workshop_counter_${size.width.toInt()}x${size.height.toInt()}.png'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 26번 4-1단계 F1: 저장 점검(checkpoint_ms마다 빈 저장) 동안 버튼이 꺼지지 않는다.
  testWidgets('저장 점검 중에도 주문 제작·판매·손님·클리커가 살아 있고 안내 대사가 남는다', (tester) async {
    final account = await mountGame(tester, const Size(390, 844), reduced: true);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    var mono = 0;
    final repo = MemoryRepository();
    final c = WorkshopController(config, repo, now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => mono);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await c.openBusiness();
    await queue(c);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    final checkpointMs = DevelopmentBalance.integer(config.section('manual_cooking'), 'checkpoint_ms');
    bool enabled(String key) {
      final button = find.descendant(of: find.byKey(Key(key)), matching: find.byWidgetPredicate(
          (w) => w is ButtonStyleButton || w is InkWell));
      return tester.widgetList(button).any((w) => w is ButtonStyleButton ? w.onPressed != null : (w as InkWell).onTap != null);
    }
    expect(enabled('order-produce'), isTrue);
    // Five checkpoints, each held open: the button never turns off.
    for (var i = 0; i < 5; i++) {
      repo.pauseSave = Completer<void>();
      mono += checkpointMs + 10;
      await tester.pump(const Duration(milliseconds: 120));
      expect(c.busy, isTrue, reason: 'checkpoint $i saving');
      expect(c.inputBusy, isFalse);
      expect(enabled('order-produce'), isTrue, reason: 'checkpoint $i');
      expect(tester.widget<GestureDetector>(find.descendant(of: find.byKey(const Key('customer-0')),
          matching: find.byType(GestureDetector)).first).onTap, isNotNull);
      // A clicker tap during the save still counts.
      expect(c.clickerTap(), isNotNull);
      repo.pauseSave!.complete();
      repo.pauseSave = null;
      await tester.pump();
    }
    // A sale pressed while a checkpoint saves runs right after it.
    await stock(c, 'one');
    await tester.pump();
    repo.pauseSave = Completer<void>();
    mono += checkpointMs + 10;
    await tester.pump(const Duration(milliseconds: 120));
    expect(c.busy, isTrue);
    await tester.tap(find.byKey(const Key('sale-button')));
    await tester.pump();
    expect(c.state.customers.first.delivered(0), 0);
    repo.pauseSave!.complete();
    repo.pauseSave = null;
    await tester.pump();
    await tester.pump();
    expect(c.state.customers.first.delivered(0), 1);
    // A guest who runs out of time leaves words that a checkpoint and a
    // player command started in the same moment do not wipe.
    await c.command(() => c.state.customers[0] = CustomerOrder(id: 'first', customerId: 'anonymous_first',
        remainingMs: 200, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]));
    mono += 300;
    expect(await c.selectFlavor('redbean'), isTrue);
    expect(c.notice, startsWith('일반 손님: '));
    mono += checkpointMs + 10;
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(c.notice, startsWith('일반 손님: '));
    expect(find.byKey(const Key('counter-notice')), findsOneWidget);
    // A refused command still shows its reason (FormatException order).
    expect(await c.sellToCustomer('gone'), isFalse);
    expect(c.notice, '이미 종료된 주문이에요.');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('카운터 버튼은 화면 가로 가운데, 카운터 윗변 6 위에 뜬다 (폭 160 이상, 높이 44)', (tester) async {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      final c = await mount(tester, size);
      await c.openBusiness();
      await queue(c);
      await tester.pump();
      final counter = tester.getRect(find.byKey(const Key('sale-counter')));
      final action = tester.getRect(find.byKey(const Key('counter-action')));
      expect(action.center.dx, closeTo(size.width / 2, .5));
      expect(action.bottom, closeTo(counter.top - WorkshopHomeLayout.actionGap, .5));
      expect(action.width, greaterThanOrEqualTo(160));
      expect(action.height, greaterThanOrEqualTo(44));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('긴 이름 네임드 손님도 카운터 글이 잘리지 않는다(글자 1.3배)', (tester) async {
    final account = await mountGame(tester, const Size(360, 640), reduced: true, textScale: 1.3);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await c.openBusiness();
    expect(await c.welcomeCustomer(visitor: 'npc_taeo'), isTrue);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    final title = tester.widget<Text>(find.byKey(const Key('counter-title'))).data!;
    expect(title, startsWith('태오 씨 · '));
    final paragraph = tester.renderObject<RenderParagraph>(find.byKey(const Key('counter-title')));
    expect(paragraph.didExceedMaxLines, isFalse, reason: title);
    // The customer window keeps the full nickname.
    // The tap target is over the guest's head, above the clicker.
    await tester.tap(find.byKey(const Key('customer-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('customer-card-title'))).data, c.customerName('npc_taeo'));
    expect(c.customerName('npc_taeo'), isNot('태오 씨'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('행주 윗변 표: 낮춘 배경 14장 모두 524', () {
    for (final id in const ['autumn', 'clear', 'rain', 'seaside', 'snowday']) {
      expect(NightStallPainter.towelTops['bg_low/$id'], 524);
    }
  });
}
