// 26번 4차 피드백 g11(스페셜 틀을 아래 작업대 6구 자리로) 확인용 화면(한글 글꼴).
// flutter test tools/preview_i4_g11_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_g11/<TAG>_<이름>_<크기>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;

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
      final out = File('build/preview/i4_g11/${tag}_${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  var seq = 0;

  /// In business, the six-cell griddle open with cells cooking, two guests
  /// waiting. [open] false: before opening (practice).
  Future<WorkshopController> home(WidgetTester tester, Size size, {bool reduced = true, bool open = true, String tutorial = 'done'}) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    final account = await mountGame(tester, size, reduced: reduced);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = tutorial;
      c.state.level = 5;
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= 5; i++) i]);
      c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
      var m = c.state.flavorMasteries['redbean']!;
      for (final (v, n) in const [(0, 2), (1, 3), (2, 5), (3, 3), (4, 2)]) {
        for (var i = 0; i < n; i++) {
          m = m.record(MasteryResult(id: 'p-${seq++}', flavor: 'redbean', variant: v,
              completed: true, practice: true, techniquePassed: true));
        }
      }
      c.state.flavorMasteries['redbean'] = m;
      c.state.masteryAwards['redbean'] = {'revision': 'old', 'resultId': m.results.keys.first, 'practiceRequired': 5, 'techniqueRequired': 3};
    });
    if (open) {
      await c.openBusiness();
      for (final (cell, wait) in [(4, 9000), (1, 5000), (0, 3000)]) {
        await c.startCell(cell);
        await c.command(() => c.state.grid = c.state.grid.advanceActive(wait));
      }
      await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
          flavor: 'redbean', variant: 2, quantity: 0, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
      await c.command(() => c.state.customers
        ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]))
        ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    }
    c.dismissPromotion();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    return c;
  }

  Future<void> start(WidgetTester tester, WorkshopController c) async {
    expect(await c.startOrderProduction('first', 'redbean'), isTrue, reason: '${c.notice} ${c.error}');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('기다림 ${size.width}', (tester) async {
      await home(tester, size);
      await shot(tester, 'idle');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('연습 전 ${size.width}', (tester) async {
      await home(tester, size, open: false);
      await shot(tester, 'practice_idle');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('밀려남 ${size.width}', (tester) async {
      final c = await home(tester, size, reduced: false);
      expect(await c.startOrderProduction('first', 'redbean'), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await shot(tester, 'sliding_in');
      await tester.pump(const Duration(seconds: 1));
      await c.cookingCommand(c.state.session!.cancel());
      c.takeCollectionNews();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      await shot(tester, 'sliding_out');
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot(tester, 'after_cancel');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('반죽 ${size.width}', (tester) async {
      final c = await home(tester, size);
      await start(tester, c);
      await shot(tester, 'batter');
      final box = tester.getRect(find.byType(MoldPaintControl));
      final y = box.center.dy;
      final gesture = await tester.startGesture(Offset(box.left + 40, y));
      await tester.pump();
      for (var x = box.left + 40; x <= box.center.dx + 30; x += 8) {
        await gesture.moveTo(Offset(x, y + math.sin(x / 18) * 10));
        await tester.pump();
      }
      await shot(tester, 'pouring');
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('뒤집기 ${size.width}', (tester) async {
      final c = await home(tester, size);
      await start(tester, c);
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
      final r = math.min(box.width, box.height) * .4;
      Offset at(double a) => box.center + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * r;
      final gesture = await tester.startGesture(at(0));
      for (var a = 15.0; a <= 135; a += 15) {
        await gesture.moveTo(at(a));
        await tester.pump();
      }
      await shot(tester, 'flipping');
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('결과 ${size.width}', (tester) async {
      CookingResultView.celebrated = null;
      final c = await home(tester, size);
      await start(tester, c);
      var s = c.state.session!;
      s = s.pour(s.token, const PaintAmount(980, 1100));
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, const PaintAmount(970, 1120));
      s = s.close(s.token);
      s = s.flip(s.token);
      final done = s.takeOut(s.token, 15000);
      await c.command(() => c.state.session = done);
      c.takeCollectionNews();
      await tester.pump();
      // Past the collection news toast (the seeded 도감).
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await shot(tester, 'result');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  // 첫 실행 안내 카드: 연습 시작(작업대의 버튼)과 반죽 단계(틀 위 묶음 위).
  for (final size in const [Size(390, 844), Size(360, 640)]) {
    testWidgets('첫 실행 안내 ${size.width}x${size.height}', (tester) async {
      final c = await home(tester, size, open: false, tutorial: 'cook');
      await shot(tester, 'tutorial_start');
      expect(await c.startPractice(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await shot(tester, 'tutorial_batter');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('작은 화면 반죽 360x640', (tester) async {
    final c = await home(tester, const Size(360, 640));
    await start(tester, c);
    await shot(tester, 'batter');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
