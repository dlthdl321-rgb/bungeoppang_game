import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/cook_cut.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_home_layout.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 4차 피드백 g11 (사용자 결정 2026-11-21 '손님 누르면 6구가 옆으로 밀려나고 그
/// 자리에'): 스페셜 붕어빵 틀은 손님 위 공중이 아니라 아래 작업대의 6구 자리에서
/// 쓰고, 그동안 6구는 옆(왼쪽 화면 밖)으로 밀려났다가 끝나면 돌아온다.
void main() {
  late DevelopmentBalance config;
  setUpAll(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

  Future<WorkshopController> mount(WidgetTester tester, Size size, {bool reduced = true}) async {
    final account = await mountGame(tester, size, reduced: reduced);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state..tutorial = 'done'..featureIntros.addAll(['fairy', 'griddle']));
    await c.openBusiness();
    await c.command(() => c.state.customers.add(CustomerOrder(id: 'first', customerId: 'anonymous_first',
        remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    return c;
  }

  Finder key(String name) => find.byKey(Key(name));

  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('주문 제작: 틀은 6구 자리, 6구는 화면 밖, 끝나면 돌아옴 $tag', (tester) async {
      final c = await mount(tester, size);
      final griddle = tester.getRect(key('griddle'));
      final nav = tester.getRect(key('home-nav'));
      expect(key('workshop-mold'), findsNothing);
      expect(await c.startOrderProduction('first', 'redbean'), isTrue);
      await tester.pump();
      await tester.pump();
      // The griddle is off the screen to the left, the cooking cut to the
      // right (사용자 답: the mold never overlaps the cut).
      expect(tester.getRect(key('griddle')).right, lessThanOrEqualTo(0));
      final cut = tester.getRect(find.byType(CookCut));
      expect(cut.left, greaterThanOrEqualTo(size.width));
      // The mold works in the griddle's place: centred on it, its feet on
      // the bench over the menu bar, below the counter's line.
      final mold = tester.getRect(key('active-empty-mold'));
      expect(mold.center.dx, closeTo(griddle.center.dx, 1));
      expect(mold.bottom, lessThan(nav.top));
      expect(mold.bottom, greaterThan(griddle.top));
      expect(mold.width, greaterThan(size.width * .5));
      // The title and the cancel button stand over the mold picture.
      final cancel = tester.getRect(key('mold-cancel'));
      final title = tester.getRect(key('workshop-session-title'));
      expect(cancel.bottom, lessThanOrEqualTo(mold.top + mold.height * .2));
      expect(title.bottom, lessThanOrEqualTo(cancel.top));
      expect(title.top, greaterThan(tester.getRect(key('workshop-status-badge')).bottom));
      // Cancel: the mold leaves and the griddle comes back as it was.
      await tester.tap(key('mold-cancel'));
      await tester.pump();
      await tester.pump();
      expect(c.state.session, isNull);
      expect(tester.getRect(key('griddle')), griddle);
      expect(tester.getRect(find.byType(CookCut)).right, lessThanOrEqualTo(size.width));
      expect(key('workshop-mold'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('움직임: 6구가 왼쪽으로 밀려나는 동안 틀이 오른쪽에서 들어옴', (tester) async {
    final c = await mount(tester, const Size(390, 844), reduced: false);
    final griddle = tester.getRect(key('griddle'));
    expect(await c.startOrderProduction('first', 'redbean'), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: WorkshopHomeLayout.benchSlideMs ~/ 2));
    final half = tester.getRect(key('griddle'));
    expect(half.left, lessThan(griddle.left - 50));
    expect(half.right, greaterThan(0));
    final coming = tester.getRect(key('active-empty-mold'));
    expect(coming.center.dx, greaterThan(griddle.center.dx + 50));
    await tester.pump(const Duration(milliseconds: WorkshopHomeLayout.benchSlideMs));
    expect(tester.getRect(key('active-empty-mold')).center.dx, closeTo(griddle.center.dx, 1));
    expect(tester.getRect(key('griddle')).right, lessThanOrEqualTo(0));
    // While sliding back the griddle takes no touches; once back it does.
    await c.cookingCommand(c.state.session!.cancel());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: WorkshopHomeLayout.benchSlideMs ~/ 2));
    expect(key('idle-mold'), findsOneWidget);
    expect(tester.getRect(key('griddle')).left, lessThan(griddle.left));
    await tester.pump(const Duration(milliseconds: WorkshopHomeLayout.benchSlideMs));
    expect(tester.getRect(key('griddle')), griddle);
    expect(key('idle-mold'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
