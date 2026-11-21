// 26번 4차 g5(잠긴 기능도 자물쇠와 함께 보이기) 확인용 화면(한글 글꼴): 메뉴의 도감·배경 테마,
// 꾸미기의 붕어빵 탭·가게 탭 화로/장식/등불, 설정의 배경 바꾸기, 안내 중 '오늘' 쪽지와
// 잠긴 것을 눌렀을 때의 가운데 알림을 390×844로 그린다.
// flutter test tools/preview_g5_locks_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/g5/<TAG>_<이름>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/center_toast.dart';
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
        // Text with no family (the guide card) uses the test font.
        if (korean.isNotEmpty) await load('FlutterTest', korean);
      });

  Future<void> shot(WidgetTester tester, String name) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/g5/${tag}_$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size,
      {required int level, bool business = true, BigInt? buns, String tutorial = 'done'}) async {
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
      c.state.tutorial = tutorial;
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
    // The 'before' build may not list a locked entry at all.
    if (f.evaluate().isEmpty) return;
    await tester.ensureVisible(f.first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (look) return;
    await tester.tap(f.first);
    // Short: a center toast stays readable in the picture.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // (이름, 레벨, 안내 단계, 누를 키들)
  const screens = <(String, int, String, List<String>)>[
    ('menu_lv1', 1, 'done', ['menu-menubar']),
    ('menu_lv1_tap_collection', 1, 'done', ['menu-menubar', 'menu-collection']),
    ('menu_guide', 1, 'sell', ['menu-menubar']),
    ('menu_guide_tap_theme', 1, 'sell', ['menu-menubar', 'menu-theme']),
    ('home_guide', 1, 'sell', []),
    ('home_guide_tap_daily', 1, 'sell', ['daily-ticket-locked']),
    ('settings_guide', 1, 'sell', ['home-settings']),
    ('wardrobe_lv4', 4, 'done', ['menu-skins']),
    ('wardrobe_lv4_tap_fish', 4, 'done', ['menu-skins', 'cosmetic-category-bungeoppang']),
    ('wardrobe_lv4_stall', 4, 'done', ['menu-skins', 'cosmetic-category-stall']),
    ('wardrobe_lv4_stall_tap_lamp', 4, 'done', ['menu-skins', 'cosmetic-category-stall', 'cosmetic-slot-lamp']),
    ('shop_lv4', 4, 'done', ['menu-shop']),
    ('wardrobe_lv8_stall', 8, 'done', ['menu-skins', 'cosmetic-category-stall']),
    ('menu_lv3', 3, 'done', ['menu-menubar']),
  ];

  // 소개 카드와 짧은 안내(4차 g5 추가 요청): (이름, 레벨, 아직 안 본 소개, 누를 키들)
  const tours = <(String, int, String, List<String>)>[
    ('intro_wardrobe', 1, 'wardrobe', []),
    ('tour_wardrobe_1', 1, 'wardrobe', ['feature-intro-ok']),
    ('tour_wardrobe_2', 1, 'wardrobe', ['feature-intro-ok', 'tour-next']),
    ('tour_wardrobe_3', 1, 'wardrobe', ['feature-intro-ok', 'tour-next', 'tour-next']),
    ('intro_collection', 3, 'collection', []),
    ('tour_collection_1', 3, 'collection', ['feature-intro-ok']),
    ('tour_skills_1', 2, 'skills', ['feature-intro-ok']),
    ('tour_skills_2', 2, 'skills', ['feature-intro-ok', 'tour-next']),
    ('tour_special_orders_1', 5, 'specialOrders', ['feature-intro-ok']),
    ('settings_tours', 4, '', ['home-settings', 'settings-tours']),
  ];
  for (final (name, level, unseen, keys) in tours) {
    testWidgets('$name 390x844', (tester) async {
      final c = await open(tester, const Size(390, 844), level: level, buns: BigInt.from(5000000));
      await c.command(() {
        c.state.featureIntros.remove(unseen);
        if (unseen == 'wardrobe') c.state.guideJustEnded = true;
      });
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      for (final k in keys) {
        await tapKey(tester, k);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
      expect(tester.takeException(), isNull);
      await shot(tester, '${name}_390x844');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in const [Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    for (final (name, level, tutorial, keys) in screens) {
      testWidgets('$name $s', (tester) async {
        await open(tester, size, level: level, tutorial: tutorial, buns: BigInt.from(5000000));
        for (final k in keys) {
          await tapKey(tester, k);
        }
        expect(tester.takeException(), isNull);
        await shot(tester, '${name}_$s');
        CenterToast.hide();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
