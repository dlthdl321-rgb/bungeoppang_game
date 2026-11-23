// 26번 3차 녹화 피드백 C 묶음(홈·굽기, H17~H30) 확인용 화면(한글 글꼴).
// flutter test tools/preview_h_c_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/h_c/<TAG>_<이름>_<크기>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
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
    final size = view.size;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/h_c/${tag}_${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size,
      {int level = 1, bool business = false, List<String> recipes = const [], bool reduced = true}) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await mountGame(tester, size, reduced: reduced, online: online);
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
      c.state.buns = BigInt.from(469);
      c.state.lifetime = BigInt.from(469);
      c.state.claimedLevels..clear()..addAll([for (var l = 2; l <= level; l++) l]);
      c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders',
        'fishCosmetics', 'freshness', 'stallCosmetics'].where(workshopIntroIds.contains));
      for (final r in recipes) {
        if (!c.state.recipes.contains(r)) c.state.recipes.add(r);
      }
    });
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('영업 준비 ${size.width}', (tester) async {
      await open(tester, size);
      await shot(tester, 'ready');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('영업 중 ${size.width}', (tester) async {
      await open(tester, size, level: 3, business: true);
      await shot(tester, 'open');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('반죽 시작 ${size.width}', (tester) async {
      final c = await open(tester, size);
      expect(await c.startPractice(), isTrue);
      await tester.pump();
      await shot(tester, 'batter');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    // 25번 36번 틀 그림(26번 3차 F3): 속·덮기 단계의 틀과 걸이 축.
    for (final (name, steps) in const [('filling', 1), ('second', 2), ('closing', 3)]) {
      testWidgets('틀 $name ${size.width}', (tester) async {
        final c = await open(tester, size);
        expect(await c.startPractice(), isTrue);
        var s = c.state.session!;
        if (steps >= 1) s = s.pour(s.token, PaintAmount.even);
        if (steps >= 2) s = s.squeezeFilling(s.token, PaintAmount.even);
        if (steps >= 3) s = s.pour(s.token, PaintAmount.even);
        final at = s;
        await c.command(() => c.state.session = at);
        await tester.pump();
        await shot(tester, 'mold_$name');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('뒤집기 ${size.width}', (tester) async {
      final c = await open(tester, size, reduced: false);
      expect(await c.startPractice(), isTrue);
      var s = c.state.session!;
      s = s.pour(s.token, PaintAmount.even);
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, PaintAmount.even);
      s = s.close(s.token);
      final flipping = s;
      await c.command(() => c.state.session = flipping);
      await tester.pump();
      await shot(tester, 'flip_idle');
      final box = tester.getRect(find.byType(FlipCircleControl));
      final gesture = await tester.startGesture(box.center + Offset(0, box.height * .2));
      for (var d = 0.0; d <= box.height * .3; d += 8) {
        await gesture.moveTo(box.center + Offset(0, box.height * .2 - d));
        await tester.pump();
      }
      await shot(tester, 'flipping');
      // Past standing on edge (about 100°, before 120° falls over).
      for (var d = box.height * .3; d <= box.height * .55; d += 8) {
        await gesture.moveTo(box.center + Offset(0, box.height * .2 - d));
        await tester.pump();
      }
      await shot(tester, 'flipping_edge');
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final (name, first, second, bakeMs) in const [
      ('perfect', PaintAmount(980, 1100), PaintAmount(970, 1120), 15000),
      ('near', PaintAmount(1000, 1400), PaintAmount(960, 1100), 15000),
      ('fail', PaintAmount.even, PaintAmount.even, 26000),
    ]) {
      testWidgets('결과 $name ${size.width}', (tester) async {
        CookingResultView.celebrated = null;
        final c = await open(tester, size);
        expect(await c.startPractice(), isTrue);
        var s = c.state.session!;
        s = s.pour(s.token, first);
        s = s.squeezeFilling(s.token, PaintAmount.even);
        s = s.pour(s.token, second);
        s = s.close(s.token);
        s = s.flip(s.token);
        final done = s.takeOut(s.token, bakeMs);
        await c.command(() => c.state.session = done);
        await tester.pump();
        await shot(tester, 'result_$name');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('잠긴 메뉴 알림 ${size.width}', (tester) async {
      await open(tester, size);
      await tester.tap(find.byKey(const Key('menu-skills-locked')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'lock_notice');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
