// 26번 3차 피드백 E묶음(H31·H41·H42) 확인용 화면(한글 글꼴): 공통 테마가 바뀐 뒤
// 주요 화면 열몇 곳(홈·메뉴·상점 두 탭·꾸미기·가게 배경·설정·오늘·스킬·기록·주간·업적·레벨 미션)을
// 실제 앱 크기로 그린다.
// flutter test tools/preview_theme_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/theme/<TAG>_<이름>.png (화면 크기 2배)
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
      final out = File('build/preview/theme/${tag}_$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size,
      {required int level, bool business = true, BigInt? buns}) async {
    WeatherLayer.animate = false;
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await mountGame(tester, size, reduced: true, online: online);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway(),
        now: () => DateTime.utc(2026, 11, 2, 3), monotonicMs: () => 0);
    await c.initialize();
    if (business) await c.openBusiness();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels..clear()..addAll([for (var l = 2; l <= level; l++) l]);
      c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders',
        'fishCosmetics', 'freshness', 'stallCosmetics'].where(workshopIntroIds.contains));
      if (buns != null) {
        c.state.lifetime = buns * BigInt.two;
        c.state.buns = buns;
      }
    });
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    // '?key': only scroll it into view.
    final look = key.startsWith('?');
    final f = find.byKey(Key(look ? key.substring(1) : key));
    await tester.ensureVisible(f.first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (look) return;
    await tester.tap(f.first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  // (이름, 레벨, 누를 키들)
  const screens = <(String, int, List<String>)>[
    ('menu', 5, ['menu-menubar']),
    ('shop_cosmetics', 5, ['menu-shop']),
    ('shop_gold', 5, ['menu-shop', 'shop-tab-gold']),
    ('wardrobe_hair', 5, ['menu-skins']),
    ('wardrobe_stall_lv1', 1, ['menu-skins', 'cosmetic-category-stall']),
    ('shop_stall_lv1', 1, ['menu-shop', 'cosmetic-category-stall']),
    ('settings', 5, ['home-settings']),
    ('settings_background', 1, ['home-settings', '?settings-background']),
    ('settings_background_open', 1, ['home-settings', 'settings-background']),
    ('shop_stall_lv1_more', 1, ['menu-shop', 'cosmetic-category-stall', '?preview-seaside']),
    ('menu_lv1', 1, ['menu-menubar']),
    ('daily', 5, ['daily-ticket']),
    ('skills', 5, ['menu-skills']),
    ('records', 5, ['menu-menubar', 'menu-records']),
    ('achievements', 5, ['menu-menubar', 'menu-achievements']),
    ('missions', 5, ['menu-menubar', 'menu-missions']),
  ];

  for (final size in const [Size(360, 800), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('홈 영업 중 $s', (tester) async {
      await open(tester, size, level: 5);
      await shot(tester, 'home_open_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('홈 영업 준비 $s', (tester) async {
      await open(tester, size, level: 1, business: false);
      await shot(tester, 'home_closed_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final (name, level, keys) in screens) {
      testWidgets('$name $s', (tester) async {
        await open(tester, size, level: level, buns: BigInt.from(5000000));
        for (final k in keys) {
          await tapKey(tester, k);
        }
        expect(tester.takeException(), isNull);
        await shot(tester, '${name}_$s');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
