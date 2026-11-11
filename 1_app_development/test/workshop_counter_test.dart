import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 3단계: "가게 관리" 시트 없이 홈에서 손님 줄 → 주문 → 재고 → 판매.
void main() {
  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
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
    expect(find.byKey(const Key('customer-welcome')), findsOneWidget);
    expect(find.byKey(const Key('business-close')), findsOneWidget);

    await queue(c);
    await stock(c, 'one');
    await tester.pump();
    expect(find.byKey(const Key('customer-0')), findsOneWidget);
    expect(find.byKey(const Key('customer-1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('counter-order'))).data, '팥 0/2, 재고 1');
    expect(label(tester, 'sale-button'), '1개 먼저 판매');

    await tester.tap(find.byKey(const Key('sale-button')));
    await tester.pump();
    expect(c.state.completedSales, 0);
    expect(c.state.customers.first.delivered(0), 1);
    expect(c.state.buns, greaterThan(BigInt.zero));
    expect(tester.widget<Text>(find.byKey(const Key('counter-order'))).data, '팥 1/2, 재고 0');
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

  testWidgets('손님 배지와 재고 버튼은 작은 창을 열고, 주문 제작은 창을 닫고 큰 틀을 시작한다', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await c.openBusiness();
    await queue(c);
    await stock(c, 'one');
    await tester.pump();

    await tester.tap(find.byKey(const Key('stock-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stock-card')), findsOneWidget);
    expect(find.text('재고 1개'), findsOneWidget);
    expect(c.gridVisible, isFalse);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(c.gridVisible, isTrue);

    await tester.tap(find.byKey(const Key('customer-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-card')), findsOneWidget);
    expect(find.text('2번 지나가는 손님'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('menu-menu')));
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
}
