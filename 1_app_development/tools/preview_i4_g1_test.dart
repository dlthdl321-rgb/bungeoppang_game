// 26번 4차 피드백 g1 묶음 미리보기(한글 글꼴): 자동 승급 축하(IA1)·레시피 받기 빨간 숫자·레벨 미션 창.
// flutter test tools/preview_i4_g1_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4g1_<장면>_<폭>.png (실제 앱 크기 390×844·360×800)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;

Future<void> settle(WidgetTester tester, [int frames = 15]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<void> fonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        const korean = String.fromEnvironment('PREVIEW_FONT');
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
        if (korean.isNotEmpty) await load('Roboto', korean);
      });

  Future<void> shot(WidgetTester tester, String name) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & view.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    testWidgets('g1 미리보기 $w', (tester) async {
      await fonts(tester);
      final account = await mountGame(tester, size);
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 19, 3), monotonicMs: () => 0);
      await tester.runAsync(() async {
        await c.initialize();
        await c.openBusiness();
        await c.command(() {
          c.state.tutorial = 'done';
          c.state.level = 4;
          c.state.claimedLevels..clear()..addAll([2, 3, 4]);
          c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
        });
        // Eight sales: the 슈크림 레시피 mission is ready (Lv.4, 판매 8).
        for (var i = 0; i < 8; i++) {
          await c.command(() {
            c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_$i', flavor: 'redbean', variant: 2,
              quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
            c.state.customers.insert(0, CustomerOrder(id: 'sale_$i', remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
          });
          await c.sellToCustomer('sale_$i');
        }
        c.dismissPromotion();
      });
      // ignore: avoid_print
      print('level ${c.state.level} sales ${c.state.completedSales} recipes ${c.claimableRecipeCount} error ${c.error}');
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await settle(tester);
      await shot(tester, 'i4g1_home_badge_$w');
      await tester.tap(find.byKey(const Key('level-mission-entry')));
      await settle(tester);
      await shot(tester, 'i4g1_levelmissions_$w');
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      while (nav.canPop()) {
        nav.pop();
        await settle(tester);
      }
      // Lv.5: 누적 1600·탭 30 more·판매 1 more — the next save raises it.
      await tester.runAsync(() async {
        for (var i = 0; i < 30; i++) {
          c.tap();
        }
        await c.command(() {
          c.state.lifetime = BigInt.from(1700);
          c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_x', flavor: 'redbean', variant: 2,
            quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
          c.state.customers.insert(0, CustomerOrder(id: 'sale_x', remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
        });
        await c.sellToCustomer('sale_x');
      });
      // ignore: avoid_print
      print('after: level ${c.state.level} promoted ${c.promotedTo}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await shot(tester, 'i4g1_levelup_a_$w');
      await tester.pump(const Duration(milliseconds: 900));
      await shot(tester, 'i4g1_levelup_b_$w');
      await settle(tester, 30);
      await shot(tester, 'i4g1_after_levelup_$w');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
