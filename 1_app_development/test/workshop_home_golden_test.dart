import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 5단계: 실제 진입 화면(WorkshopPage 홈)을 지키는 골든.
///
/// Unlike the other goldens these load the app's own fonts (Jua, the
/// BungeoSymbols fallback and Material icons), so Korean text, `·`-style
/// punctuation and icons show as they do on a phone and a missing glyph
/// shows as a box in the picture.
void main() {
  Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        // Written by `flutter test` itself (uses-material-design).
        await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      });

  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    await loadFonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    // A still monotonic clock: the phase time ('현재 단계 경과') and wait
    // rings do not follow the real stopwatch, so a busy machine cannot
    // change the picture.
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  // Anonymous customers keep the picture independent of the random visitor.
  Future<void> serve(WorkshopController c) async {
    await c.openBusiness();
    await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
        flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
    // Last, so no later command touches the wait rings.
    await c.command(() => c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/workshop_home_$name.png'));
    expect(tester.takeException(), isNull);
  }

  String tag(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

  for (final size in [const Size(360, 640), const Size(360, 800), const Size(390, 844), const Size(412, 915)]) {
    testWidgets('영업 중 홈과 메뉴 창 골든 ${tag(size)}', (tester) async {
      final c = await mount(tester, size);
      await serve(c);
      await tester.pump();
      await shoot(tester, 'open_${tag(size)}');
      await tester.tap(find.byKey(const Key('menu-menu')));
      await tester.pumpAndSettle();
      await shoot(tester, 'menu_${tag(size)}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('영업 준비와 스페셜 붕어빵 제작 중 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await shoot(tester, 'ready_390x844');
    expect(await c.startPractice(), isTrue);
    await tester.pump();
    expect(c.activePhaseElapsedMs, 0);
    await shoot(tester, 'baking_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 24번 6단계: 원 그려 뒤집기 도중(반 바퀴), 가장 작은 화면.
  testWidgets('원 그려 뒤집기 도중 골든 360x640', (tester) async {
    final c = await mount(tester, const Size(360, 640));
    expect(await c.startPractice(), isTrue);
    var s = c.state.session!;
    s = s.pour(s.token, PaintAmount.even);
    s = s.squeezeFilling(s.token, PaintAmount.even);
    s = s.pour(s.token, PaintAmount.even);
    s = s.close(s.token);
    final flipping = s;
    await c.command(() => c.state.session = flipping);
    await tester.pump();
    final box = tester.getRect(find.byType(FlipCircleControl));
    final r = box.width * .55;
    Offset at(double a) => box.center + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * r;
    // Starts on the mold (in the dead zone, ignored), then circles.
    final gesture = await tester.startGesture(box.center + Offset(0, -box.height * .3));
    for (var a = 0.0; a <= 180; a += 15) {
      await gesture.moveTo(at(a));
      await tester.pump();
    }
    await shoot(tester, 'flipping_360x640');
    await gesture.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 25번 그림 적용: 속을 짜는 도중(짤주머니 짜는 중, 130% 넘어 흘러내림 방울).
  testWidgets('속 색칠 도중 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    expect(await c.startPractice(), isTrue);
    var s = c.state.session!;
    s = s.pour(s.token, PaintAmount.even);
    final filling = s;
    await c.command(() => c.state.session = filling);
    await tester.pump();
    final box = tester.getRect(find.byType(MoldPaintControl));
    final gesture = await tester.startGesture(box.center);
    // Back and forth over the whole fish, again and again: over 130%.
    for (var pass = 0; pass < 2; pass++) {
      for (var row = 0; row < 8; row++) {
        final y = box.top + box.height * (.22 + row * .065);
        await gesture.moveTo(Offset(box.left + box.width * .15, y));
        await gesture.moveTo(Offset(box.left + box.width * .85, y));
      }
    }
    await gesture.moveTo(box.center + Offset(box.width * .1, 0));
    await tester.pump();
    expect(find.textContaining('넘쳤어요'), findsOneWidget);
    await shoot(tester, 'filling_390x844');
    await gesture.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 25번 그림 적용: 영업 중 숙련된 붕어빵 틀 1·4번 칸만 굽는 중(빈 판 위 붕어빵).
  testWidgets('영업 중 굽는 칸 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await c.openBusiness();
    await c.command(() {
      final rule = c.config.mastery(0);
      var mastery = c.state.mastery;
      final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
      for (var i = 0; i < count; i++) {
        mastery = mastery.record(MasteryResult(id: 'practice-$i', flavor: 'redbean',
            variant: i < 5 ? i : 2, completed: true, practice: true, techniquePassed: i >= 5));
      }
      c.state.mastery = mastery;
      c.state.masteryAward = {
        'revision': c.config.revision,
        'resultId': 'practice-0',
        'practiceRequired': DevelopmentBalance.integer(rule, 'practice_required'),
        'techniqueRequired': DevelopmentBalance.integer(rule, 'technique_passes_required'),
      };
    });
    expect(await c.startCell(1), isTrue);
    expect(await c.startCell(4), isTrue);
    await tester.pump();
    await shoot(tester, 'griddle_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
