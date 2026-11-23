// 26번 4차 녹화 피드백 g2(스페셜 틀 굽기: IC3·IC4·IC5·IC6·IC8·IC9) 확인용 화면(한글 글꼴).
// flutter test tools/preview_i4_g2_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_g2/<TAG>_<이름>_<크기>.png (화면 크기 2배)
// PREVIEW_TAG=before 는 4차 전 코드(위로 밀어 뒤집기)에서 같은 장면을 찍는다.
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
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/ui/workshop_guide.dart' show WorkshopSalePraiseBanner;
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
      final out = File('build/preview/i4_g2/${tag}_${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  /// In business with two guests waiting, an order bake of the first.
  Future<WorkshopController> order(WidgetTester tester, Size size, {bool reduced = true}) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    final account = await mountGame(tester, size, reduced: reduced);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await c.openBusiness();
    await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
        flavor: 'redbean', variant: 2, quantity: 0, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
    await c.command(() => c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    expect(await c.startOrderProduction('first', 'redbean'), isTrue);
    await tester.pump();
    await tester.pump();
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('반죽 시작 ${size.width}', (tester) async {
      await order(tester, size);
      await shot(tester, 'batter');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('틀 가장자리 밖에서 문질러 흘림 ${size.width}', (tester) async {
      await order(tester, size);
      final box = tester.getRect(find.byType(MoldPaintControl));
      // From the left rim (outside the fish) across the middle.
      final y = box.center.dy;
      final gesture = await tester.startGesture(Offset(box.left + 12, y));
      await tester.pump();
      for (var x = box.left + 12; x <= box.center.dx + 20; x += 8) {
        await gesture.moveTo(Offset(x, y + math.sin(x / 18) * 10));
        await tester.pump();
      }
      await shot(tester, 'spill');
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('뒤집기 ${size.width}', (tester) async {
      final c = await order(tester, size, reduced: false);
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
      if (tag == 'before') {
        final start = box.center + Offset(0, box.height * .2);
        final gesture = await tester.startGesture(start);
        for (var d = 0.0; d <= box.height * .3; d += 8) {
          await gesture.moveTo(start - Offset(0, d));
          await tester.pump();
        }
        await shot(tester, 'flipping');
        await gesture.up();
      } else {
        final r = math.min(box.width, box.height) * .4;
        Offset at(double a) => box.center + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * r;
        final gesture = await tester.startGesture(at(0));
        for (var a = 15.0; a <= 120; a += 15) {
          await gesture.moveTo(at(a));
          await tester.pump();
        }
        await shot(tester, 'flipping');
        for (var a = 135.0; a <= 225; a += 15) {
          await gesture.moveTo(at(a));
          await tester.pump();
        }
        await shot(tester, 'flipping_edge');
        await gesture.up();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
    // IC6: 1차를 적게, 2차를 많이 — 예전에는 '반죽이 넘쳤어요', 이제 합으로 성공.
    for (final (name, first, second) in const [
      ('made_up', PaintAmount(600, 700), PaintAmount(1000, 1500)),
      ('perfect', PaintAmount(980, 1100), PaintAmount(970, 1120)),
      ('near_over', PaintAmount(1000, 1300), PaintAmount(1000, 1400)),
    ]) {
      testWidgets('결과 $name ${size.width}', (tester) async {
        CookingResultView.celebrated = null;
        final c = await order(tester, size);
        var s = c.state.session!;
        s = s.pour(s.token, first);
        s = s.squeezeFilling(s.token, PaintAmount.even);
        s = s.pour(s.token, second);
        s = s.close(s.token);
        s = s.flip(s.token);
        final done = s.takeOut(s.token, 15000);
        await c.command(() => c.state.session = done);
        await tester.pump();
        await shot(tester, 'result_$name');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('판매 칭찬 별 390', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await fonts(tester);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(backgroundColor: const Color(0xff3a2a20),
        body: WorkshopSalePraiseBanner(praise: const WorkshopSalePraise('도윤', 4, '와, 따끈해요!'),
            reduceMotion: true, onDone: () {}))));
    await tester.pump();
    await shot(tester, 'sale_praise');
    await tester.pump(WorkshopSalePraiseBanner.duration);
  });
}
