import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 5단계: 실제 진입 화면(WorkshopPage 홈)을 지키는 골든.
///
/// Unlike the other goldens these load the app's own fonts (Jua, the
/// BungeoSymbols fallback and Material icons), so Korean text, `·`-style
/// punctuation and icons show as they do on a phone and a missing glyph
/// shows as a box in the picture.
void main() {
  Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        // Written by `flutter test` itself (uses-material-design).
        await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      });

  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    await loadFonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  // Anonymous customers keep the picture independent of the random visitor.
  Future<void> serve(WorkshopController c) async {
    await c.openBusiness();
    await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
        flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
    // Last: a later command would age the wait rings by real elapsed ms.
    await c.command(() => c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/workshop_home_$name.png'));
    expect(tester.takeException(), isNull);
  }

  String tag(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

  for (final size in [const Size(360, 640), const Size(360, 800), const Size(390, 844), const Size(412, 915)]) {
    testWidgets('영업 중 홈과 메뉴 창 골든 ${tag(size)}', (tester) async {
      final c = await mount(tester, size);
      await serve(c);
      await tester.pump();
      await shoot(tester, 'open_${tag(size)}');
      await tester.tap(find.byKey(const Key('menu-menu')));
      await tester.pumpAndSettle();
      await shoot(tester, 'menu_${tag(size)}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('영업 준비와 스페셜 붕어빵 제작 중 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await shoot(tester, 'ready_390x844');
    await c.startPractice();
    // The phase clock follows real elapsed time; pin it for the picture.
    await c.command(() => c.state.phaseMs = 0);
    await tester.pump();
    await shoot(tester, 'baking_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
