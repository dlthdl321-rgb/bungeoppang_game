// 재료 타이쿤 D('재료 준비' 창·미니게임 3종) 확인용 화면(한글 글꼴).
// flutter test tools/preview_t_d_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/t_d/<이름>_<크기>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart' show FlavorMasteryProgress;
import 'package:todays_bungeoppang/prep_minigames.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/prep_art.dart';
import 'package:todays_bungeoppang/ui/prep_minigames.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show setUpAccount;

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
    final size = view.size;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/t_d/${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> window(WidgetTester tester, Size size, {void Function(WorkshopController c)? setup}) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    final account = await setUpAccount(tester, size, reduced: true);
    await fonts(tester);
    await tester.runAsync(PrepArt.load);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 21, 3),
        monotonicMs: () => 0);
    await c.initialize();
    final ok = await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = 6;
      c.state.buns = BigInt.from(123456);
      c.state.lifetime = BigInt.from(987654);
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= 6; i++) i]);
      c.state.featureIntros.addAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
      setup?.call(c);
    });
    expect(ok, isTrue, reason: c.notice ?? c.error);
    c.dismissPromotion();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    tester.widget<NightHome>(find.byType(NightHome)).onOpen('pantry');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return c;
  }

  Future<void> make(WidgetTester tester, {String kind = 'batter'}) async {
    if (kind != 'batter') {
      await tester.tap(find.byKey(Key('pantry-tab-$kind')));
      await tester.pump();
    }
    await tester.ensureVisible(find.byKey(const Key('pantry-make')));
    await tester.tap(find.byKey(const Key('pantry-make')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  PrepGame game(WidgetTester tester) => tester.state<PrepGameScreenState>(find.byType(PrepGameScreen)).game!;

  void all(WorkshopController c) {
    for (final f in ['custard', 'cocoa']) {
      c.state.recipes.add(f);
      c.state.recipeMissions.add(f);
      c.state.flavorMasteries[f] = FlavorMasteryProgress(flavor: f, difficulty: c.difficulty(f));
    }
    c.state.pantry.basic.addAll({'milk': 6, 'egg': 4, 'sugar': 4, 'cocoa_powder': 2});
    c.state.pantry.premium['cultured_butter'] = 2;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('창 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await shot(tester, 'window_batter');
      await tester.tap(find.byKey(const Key('pantry-tubs-3')));
      await tester.pump();
      await shot(tester, 'window_batter_3_short');
      await tester.tap(find.byKey(const Key('pantry-tab-custard')));
      await tester.pump();
      await shot(tester, 'window_custard');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('특제 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await tester.ensureVisible(find.byKey(const Key('pantry-premium')));
      await tester.tap(find.byKey(const Key('pantry-premium')));
      await tester.pump();
      await shot(tester, 'window_premium');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('반죽 젓기 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await make(tester);
      await shot(tester, 'stir_start');
      final box = tester.getRect(find.byKey(const Key('prep-game-area')));
      final r = math.min(box.width, box.height) * .3;
      Offset at(double a) => box.center + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * r;
      final g = await tester.startGesture(at(0));
      for (var a = 10.0; a <= 1100; a += 10) {
        await g.moveTo(at(a));
      }
      await tester.pump(const Duration(milliseconds: 1500));
      await shot(tester, 'stir_green');
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await shot(tester, 'stir_result');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('불 조절 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await make(tester, kind: 'redbean');
      await tester.pump(const Duration(milliseconds: 1200));
      await shot(tester, 'heat_idle');
      final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('prep-game-area'))));
      await tester.pump(const Duration(milliseconds: 600));
      await shot(tester, 'heat_holding');
      await g.up();
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      await shot(tester, 'heat_fail_result');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('불 조절 초코 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await make(tester, kind: 'cocoa');
      final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('prep-game-area'))));
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'heat_cocoa_holding');
      await g.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('휘젓기 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      await make(tester, kind: 'custard');
      final box = tester.getRect(find.byKey(const Key('prep-game-area')));
      final g = await tester.startGesture(box.center);
      for (var i = 0; i < 9; i++) {
        await g.moveTo(box.center + Offset(i.isEven ? 70 : -70, 0));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await shot(tester, 'whisk_half');
      expect(game(tester).playing, isTrue);
      await g.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('화면 읽기 ${size.width}', (tester) async {
      await window(tester, size, setup: all);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
      await make(tester);
      await shot(tester, 'reader');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
