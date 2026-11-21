// 4차 피드백 g10 비교용 화면(한글 글꼴): 꾸미기 창·상점 꾸미기의 배경(예전 '가게') 탭
// 미리보기, 밤낮 칸, 설정의 밤낮 고르기.
// flutter test tools/preview_i4_g10_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_g10/<TAG>_<이름>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
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
      final out = File('build/preview/i4_g10/${tag}_$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size, {required int level, BigInt? buns}) async {
    WeatherLayer.animate = false;
    // Noon, so '기기 시간 따라' shows the day like the old '배경 그대로'.
    sceneClock = () => DateTime(2026, 11, 2, 12);
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
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
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 800), Size(390, 844)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    for (final level in const [3, 9]) {
      testWidgets('꾸미기 창 가게(배경) 탭 Lv.$level $s', (tester) async {
        await open(tester, size, level: level, buns: BigInt.from(5000000));
        await tapKey(tester, 'menu-skins');
        await tapKey(tester, 'cosmetic-category-stall');
        await shot(tester, 'ID5_ID8_wardrobe_stall_lv${level}_$s');
        await tapKey(tester, 'cosmetic-slot-time');
        await shot(tester, 'ID9_wardrobe_time_lv${level}_$s');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('상점 꾸미기 가게(배경) 탭 $s', (tester) async {
      await open(tester, size, level: 9, buns: BigInt.from(5000000));
      await tapKey(tester, 'menu-shop');
      await tapKey(tester, 'cosmetic-category-stall');
      await shot(tester, 'ID5_ID8_shop_stall_$s');
      if (find.byKey(const Key('cosmetic-slot-time')).evaluate().isNotEmpty) {
        await tapKey(tester, 'cosmetic-slot-time');
        await shot(tester, 'ID9_shop_time_$s');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
