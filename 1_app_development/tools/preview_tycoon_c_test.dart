// 재료 타이쿤 C 미리보기(한글 글꼴): 상점 '재료' 탭(기본 재료 칸·돌림판·사기, 특별한 재료 잠김/열림).
// flutter test tools/preview_tycoon_c_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/tycoonC_<장면>_<폭>.png (실제 앱 크기 390×844·360×800)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;
import '../test/workshop_controller_test.dart' show Gateway;

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

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    for (final scene in const ['lv2', 'lv5', 'lv5_bottom']) {
      testWidgets('재료 탭 $scene $w', (tester) async {
        final lv5 = scene.startsWith('lv5');
        final online = FakeOnlineBackend(products: const {}, prices: const {})
          ..signedIn = true
          ..gold = lv5 ? 3 : 0;
        final game = await mountGame(tester, size, reduced: true, online: online);
        await fonts(tester);
        final config = DevelopmentBalance.fromJson(
            jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
        final c = WorkshopController(config, MemoryRepository(),
            purchaseGateway: Gateway(), now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
        await tester.runAsync(() async {
          await c.initialize();
          final ok = await c.command(() {
            final level = lv5 ? 5 : 2;
            c.state.tutorial = 'done';
            c.state.level = level;
            c.state.claimedLevels.addAll([for (var n = 2; n <= level; n++) n]);
            c.state.featureIntros.addAll(['wardrobe', 'skills', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'stallCosmetics']);
            for (final flavor in lv5 ? const ['custard', 'cocoa'] : const <String>[]) {
              c.state.recipes.add(flavor);
              c.state.flavorMasteries[flavor] = FlavorMasteryProgress(flavor: flavor,
                  difficulty: DevelopmentBalance.integer(config.section('active_recipes')[flavor] as Map<String, dynamic>, 'difficulty'));
            }
            c.state.lifetime = BigInt.from(lv5 ? 4000000 : 30000);
            c.state.buns = BigInt.from(lv5 ? 1250000 : 900);
            if (lv5) {
              c.state.pantry.basic['flour'] = 99;
              c.state.pantry.basic['milk'] = 37;
              c.state.pantry.premium['cultured_butter'] = 4;
            }
          });
          // ignore: avoid_print
          print('setup $ok ${c.error} ${c.notice}');
        });
        game.state.premium.gold = lv5 ? 3 : 0;
        await tester.pumpWidget(GameApp(controller: game, workshop: c));
        await tester.pump();
        await tap(tester, 'menu-shop');
        await tap(tester, 'shop-tab-ingredients');
        if (scene == 'lv2') await tap(tester, 'step-egg-10');
        if (lv5) {
          await tap(tester, 'step-sugar-10');
          await tap(tester, 'step-sugar-100');
        }
        // The top of the list, or (lv5_bottom) the special ingredients.
        await tester.drag(find.byKey(const Key('pantry-shop')), Offset(0, scene == 'lv5_bottom' ? -2000 : 2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await shot(tester, 'tycoonC_${scene}_$w');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
