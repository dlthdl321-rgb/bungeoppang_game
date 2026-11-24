// 26번 4차 피드백 g1 레벨 고리 게이지 미리보기(한글 글꼴): 진행 0%·약 45%·약 95%의 홈.
// flutter test tools/preview_i4_g1_ring_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 결과: build/preview/i4g1_ring_<태그>_<진행>_<폭>.png (실제 앱 크기 390×844·360×800)
// 예전 코드에서도 돌도록 상태만 바꾸고 새 API는 쓰지 않는다.
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
import '../test/test_support.dart' show setUpAccount;

void main() {
  const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');
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

  // Lv.1 → Lv.2 asks 누적 100, 탭 30, 판매 1.
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    for (final (name, lifetime, taps, sale) in [('0', 0, 0, false), ('45', 100, 10, false), ('95', 100, 26, true)]) {
      testWidgets('고리 $name $w', (tester) async {
        await fonts(tester);
        final account = await setUpAccount(tester, size, reduced: true);
        final config = DevelopmentBalance.fromJson(
            jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
        final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 19, 3), monotonicMs: () => 0);
        await tester.runAsync(() async {
          await c.initialize();
          await c.openBusiness();
          await c.command(() => c.state.tutorial = 'done');
          if (sale) {
            await c.command(() {
              c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_1', flavor: 'redbean', variant: 2,
                quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
              c.state.customers.insert(0, CustomerOrder(id: 'sale_1', remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
            });
            await c.sellToCustomer('sale_1');
          }
          for (var i = 0; i < taps; i++) {
            c.tap();
          }
          await c.command(() {
            c.state.lifetime = BigInt.from(lifetime);
            c.state.buns = BigInt.from(lifetime);
            c.state.customers.clear();
          });
        });
        // ignore: avoid_print
        print('$tag $name $w: level ${c.state.level} taps ${c.state.taps} sales ${c.state.completedSales} lifetime ${c.state.lifetime}');
        await tester.pumpWidget(GameApp(controller: account, workshop: c));
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await shot(tester, 'i4g1_ring_${tag}_${name}_$w');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
