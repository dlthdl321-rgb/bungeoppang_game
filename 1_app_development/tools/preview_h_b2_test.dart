// 26번 3차 녹화 피드백 B2(꾸미기 창·규칙, H11~H16) 비교용 화면(한글 글꼴).
// flutter test tools/preview_h_b2_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/h_b2/<TAG>_<이름>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;
import '../test/workshop_controller_test.dart' show Gateway;

const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');

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
      final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/h_b2/${tag}_$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size, {int level = 9, int gold = 3}) async {
    WeatherLayer.animate = false;
    final online = FakeOnlineBackend(products: const {}, prices: const {})
      ..signedIn = true
      ..gold = gold;
    final account = await mountGame(tester, size, reduced: true, online: online);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway(),
        now: () => DateTime.utc(2026, 11, 2, 3), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels..clear()..addAll([for (var l = 2; l <= level; l++) l]);
      c.state.featureIntros.addAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders',
        'fishCosmetics', 'freshness', 'stallCosmetics'].where(workshopIntroIds.contains));
      c.state.lifetime = BigInt.from(40000);
      c.state.buns = BigInt.from(20000);
    });
    account.state.premium.gold = gold;
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 800), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('꾸미기 처음 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await shot(tester, 'H13_H16_wardrobe_idle_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 캐릭터 입어 보기 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await tap(tester, 'preview-boy');
      await shot(tester, 'H11_H13_H14_H15_wardrobe_character_try_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 피부톤 입어 보기 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await tap(tester, 'cosmetic-slot-skin');
      await tap(tester, 'preview-skin2');
      await shot(tester, 'H12_H15_wardrobe_skin_try_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 모자 여러 개 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await tap(tester, 'cosmetic-slot-hat');
      final beanie = find.byKey(const Key('preview-beanie'));
      if (beanie.evaluate().isNotEmpty) await tap(tester, 'preview-beanie');
      await shot(tester, 'H15_H16_wardrobe_hat_$s');
      final buyAll = find.byKey(const Key('wardrobe-buy-all'));
      if (buyAll.evaluate().isNotEmpty) {
        await tap(tester, 'wardrobe-buy-all');
        await shot(tester, 'H15_wardrobe_buy_all_dialog_$s');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 가진 것과 안 산 것 함께 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await tap(tester, 'cosmetic-slot-hat');
      await tap(tester, 'preview-beanie');
      await tap(tester, 'cosmetic-category-outfit');
      await tap(tester, 'cosmetic-slot-outfit');
      await tap(tester, 'preview-noapron');
      await shot(tester, 'H14_H15_wardrobe_three_buttons_$s');
      await tap(tester, 'wardrobe-apply-all');
      await shot(tester, 'H15_wardrobe_after_apply_owned_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 의상 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-skins');
      await tap(tester, 'cosmetic-category-outfit');
      await shot(tester, 'H16_wardrobe_outfit_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('상점 꾸미기 $s', (tester) async {
      await open(tester, size);
      await tap(tester, 'menu-shop');
      await shot(tester, 'H16_shop_avatar_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
