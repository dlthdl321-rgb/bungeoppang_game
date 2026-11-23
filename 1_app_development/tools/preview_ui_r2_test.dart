// 26번 시안 확인 2차 비교용 화면(한글 글꼴): 홈 상단(영업 시작·종료), '오늘' 버튼,
// 하단 메뉴 자물쇠, 스킬 창, 꾸미기 창(머리 탭·가게 탭).
// flutter test tools/preview_ui_r2_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/ui_r2/<TAG>_<이름>.png (화면 크기 1배)
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
import 'package:todays_bungeoppang/ui/workshop_wardrobe.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;
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
      final out = File('build/preview/ui_r2/${tag}_$name.png');
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
  }

  testWidgets('스킬 창', (tester) async {
    await open(tester, const Size(390, 844), level: 5, buns: BigInt.from(5000000));
    await tester.tap(find.byKey(const Key('menu-skills')));
    await tester.pumpAndSettle();
    await shot(tester, 'skills_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (tab, key) in [('hair', 'cosmetic-category-hair'), ('stall', 'cosmetic-category-stall')]) {
    testWidgets('꾸미기 창 $tab', (tester) async {
      await open(tester, const Size(390, 844), level: 9, buns: BigInt.from(5000000));
      await tester.tap(find.byKey(const Key('menu-skins')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await shot(tester, 'wardrobe_${tab}_390x844');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // The 가게 preview painter alone with each decoration and lamp colour.
  testWidgets('가게 미리보기 장식별', (tester) async {
    await mountGame(tester, const Size(700, 640), reduced: true);
    const looks = [('none', 'amberlamp', 'clear', false), ('lantern', 'roselamp', 'autumn', false),
      ('bunting', 'mintlamp', 'cherry', false), ('snowman', 'lilaclamp', 'snow', false),
      ('paperlanterns', 'amberlamp', 'clear', true), ('starlights', 'roselamp', 'night', true)];
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Colors.white,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (deco, lamp, bg, night) in looks)
              SizedBox(width: 336, height: 200, child: CustomPaint(
                  painter: StallPreviewPainter(background: bg, night: night, stove: 'iron', decoration: deco, lamp: lamp))),
          ]),
        )));
    await tester.pump();
    await shot(tester, 'stall_preview_variants');
  });
}
