import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 4차 피드백 IC3 '터치가 잘 안 됨': 주문 굽기 중 손님 머리 탭 영역이 틀 위를 덮어
/// 반죽·뒤집기 터치의 약 3분의 1을 가져가던 것. 이제 틀(가장자리 여백 포함) 어디를
/// 눌러도 짤주머니·뒤집기 조작이 받는다.
void main() {
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('주문 굽기 중 틀 전체가 조작에 닿는다 $size', (tester) async {
      final account = await mountGame(tester, size, reduced: true);
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
          monotonicMs: () => 0);
      await c.initialize();
      await c.command(() => c.state.tutorial = 'done');
      await c.openBusiness();
      await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
          flavor: 'redbean', variant: 2, quantity: 0, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
      await c.command(() => c.state.customers
        ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]))
        ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      expect(await c.startOrderProduction('first', 'redbean'), isTrue, reason: '${c.notice} ${c.error}');
      await tester.pump();
      await tester.pump();
      final mold = tester.getRect(find.byType(MoldPaintControl));
      // 틀 상자보다 넓게(가장자리·손잡이까지) 받는다.
      expect(mold.width, greaterThan(300 * size.width / 390));
      // 굽는 동안 손님 머리 탭 영역은 없다.
      expect(find.byKey(const Key('customer-0')), findsNothing);
      final target = tester.renderObject(find.descendant(of: find.byType(MoldPaintControl), matching: find.byType(Listener)).first);
      var miss = 0, total = 0;
      for (var y = mold.top + 4; y < mold.bottom; y += 10) {
        for (var x = mold.left + 4; x < mold.right; x += 10) {
          total++;
          final result = HitTestResult();
          tester.binding.hitTestInView(result, Offset(x, y), tester.view.viewId);
          final hitsMold = result.path.any((e) => identical(e.target, target));
          if (!hitsMold) miss++;
        }
      }
      expect(total, greaterThan(300));
      expect(miss, 0, reason: '틀 위 $total곳 중 $miss곳이 다른 위젯에 가로막힘');
      // 결과가 나오면 손님 탭은 다시 된다.
      var s = c.state.session!;
      s = s.pour(s.token, const PaintAmount(980, 1100));
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, const PaintAmount(970, 1120));
      s = s.close(s.token);
      s = s.flip(s.token);
      final done = s.takeOut(s.token, 15000);
      await c.command(() => c.state.session = done);
      await tester.pump();
      expect(find.byKey(const Key('customer-0')), findsOneWidget);
    });
  }
}


