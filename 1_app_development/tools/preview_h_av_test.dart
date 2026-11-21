// 26번 3차 AV 미리보기: 새 아바타(42번 바탕 + 43~49번 입은 아이템)를 켠 화면을
// 실제 앱 크기로 그린다. 꾸미기 탭별·상점(황금 뒤집개)·홈(남녀)·공유 카드(자랑 포즈).
//   flutter test --update-goldens tools/preview_h_av_test.dart
// 결과: build/preview_av/<이름>.png (390×844는 2배, 공유 카드는 1080×1350)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/share_card.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/share_card_view.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;
import '../test/workshop_controller_test.dart' show Gateway;

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    });

Future<void> _shot(WidgetTester tester, String name) async {
  // The golden matcher writes the picture (390x844, what the goldens use;
  // run with --update-goldens).
  await expectLater(find.byType(GameApp), matchesGoldenFile('../build/preview_av/$name.png'));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<GameController> _open(WidgetTester tester, Map<CosmeticSlot, String> worn) async {
  final online = FakeOnlineBackend(products: const {}, prices: const {})
    ..signedIn = true
    ..gold = 1;
  final game = await mountGame(tester, const Size(390, 844), reduced: true, online: online);
  await _fonts(tester);
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final c = WorkshopController(config, MemoryRepository(),
      purchaseGateway: Gateway(), now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
  await c.initialize();
  await c.command(() {
    c.state.tutorial = 'done';
    c.state.level = 8;
    c.state.claimedLevels.addAll([for (var n = 2; n <= 8; n++) n]);
    c.state.featureIntros.addAll(['skills', 'pantry', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'stallCosmetics']);
    c.state.lifetime = BigInt.from(20000);
    c.state.buns = BigInt.from(1500);
  });
  game.state.premium.gold = 1;
  worn.forEach((slot, id) {
    game.state.wardrobe.owned.add(id);
    game.state.wardrobe.equipped[slot] = id;
  });
  await tester.pumpWidget(GameApp(controller: game, workshop: c));
  await tester.pump();
  return game;
}

void main() {
  // Wardrobe tabs, both characters: hair tab (character, skin, hair, hat),
  // outfit tab (top, bottom, shoes, apron), props tab (accessory, tool).
  for (final c in ['girl', 'boy']) {
    for (final (tab, slots) in [
      ('hair', ['character', 'skin', 'hair', 'hat']),
      ('outfit', ['top', 'bottom', 'shoes', 'outfit']),
      ('props', ['accessory', 'tool']),
    ]) {
      testWidgets('꾸미기 $c $tab', (tester) async {
        await _open(tester, {
          CosmeticSlot.character: c,
          CosmeticSlot.hair: defaultHairOf(c),
          if (c == 'boy') CosmeticSlot.skin: 'skin2',
        });
        await _tap(tester, 'menu-skins');
        if (tab != 'hair') {
          final key = tab == 'outfit' ? 'cosmetic-category-outfit' : 'cosmetic-category-props';
          await _tap(tester, key);
        }
        for (final s in slots) {
          await _tap(tester, 'cosmetic-slot-$s');
          await _shot(tester, 'wardrobe_${c}_${tab}_$s');
        }
      });
    }
  }

  testWidgets('꾸미기 붕어빵·가게 탭', (tester) async {
    await _open(tester, const {});
    await _tap(tester, 'menu-skins');
    await _tap(tester, 'cosmetic-category-bungeoppang');
    await _shot(tester, 'wardrobe_girl_bungeoppang');
    await _tap(tester, 'cosmetic-category-stall');
    await _shot(tester, 'wardrobe_girl_stall');
  });

  testWidgets('상점 도구 칸(황금 뒤집개)', (tester) async {
    await _open(tester, const {});
    await _tap(tester, 'menu-shop');
    await _tap(tester, 'cosmetic-category-props');
    await _tap(tester, 'cosmetic-slot-tool');
    await _shot(tester, 'shop_tool');
    await _tap(tester, 'preview-goldtongs');
    await _shot(tester, 'shop_tool_goldtongs');
  });

  for (final c in ['girl', 'boy']) {
    testWidgets('홈 $c', (tester) async {
      await _open(tester, {CosmeticSlot.character: c, CosmeticSlot.hair: defaultHairOf(c)});
      await _shot(tester, 'home_$c');
    });
  }

  // Share cards at their real size (1080x1350), the proud pose.
  const stall = {'background': 'clear', 'decoration': 'starlights', 'lamp': 'amberlamp'};
  final cards = {
    'girl_default': const ShareCardData(moment: ShareMoment.perfect, title: '팥 붕어빵', speaker: '도윤',
        line: '와, 이건 진짜 반짝반짝해요!', guestArt: 'npc_doyun', variant: 2, shine: true, equipped: stall),
    'boy_default': const ShareCardData(moment: ShareMoment.shop, title: '우리 가게',
        line: '따끈한 붕어빵 구워 놓고 기다릴게요!', equipped: {...stall, 'character': 'boy'}),
    'girl_skin3_sweater': const ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '어서 오세요!',
        equipped: {...stall, 'skin': 'skin3', 'hair': 'ponytail', 'top': 'creamlong', 'bottom': 'jeans',
          'hat': 'beanie', 'outfit': 'stripe', 'tool': 'goldtongs'}),
    'boy_skin2_padding': const ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '어서 오세요!',
        equipped: {...stall, 'character': 'boy', 'skin': 'skin2', 'hair': 'curly', 'top': 'padding',
          'bottom': 'cargopants', 'hat': 'santa', 'accessory': 'mittens', 'outfit': 'noapron'}),
  };
  for (final entry in cards.entries) {
    testWidgets('공유 카드 ${entry.key}', (tester) async {
      await _fonts(tester);
      await tester.runAsync(PixelSprites.load);
      await tester.binding.setSurfaceSize(const Size(400, 500));
      tester.view.devicePixelRatio = 1;
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final texts = ShareCardTexts.of(config);
      await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: const Key('cap'),
          child: ShareCardView(data: entry.value, texts: texts)))));
      await tester.pump();
      await tester.runAsync(() async {
        final png = await captureShareCard(tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('cap'))), texts);
        final out = File('build/preview_av/share_${entry.key}.png');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(png);
      });
      await tester.binding.setSurfaceSize(null);
    });
  }
}
