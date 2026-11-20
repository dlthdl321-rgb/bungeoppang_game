import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/ui/workshop_home_layout.dart';
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
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
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
      await tester.tap(find.byKey(const Key('menu-menubar')));
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

  // 24번 6단계 → 26번 3차 피드백 H21: 걸이 축 밀어 뒤집기 도중, 가장 작은 화면.
  testWidgets('축 밀어 뒤집기 도중 골든 360x640', (tester) async {
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
    // 26번 3차 피드백 H21: pushed a third of the way over its axle.
    final box = tester.getRect(find.byType(FlipCircleControl));
    final start = box.center + Offset(0, box.height * .2);
    final gesture = await tester.startGesture(start);
    for (var d = 0.0; d <= box.height * .3; d += 8) {
      await gesture.moveTo(start - Offset(0, d));
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

  // 26번 4단계: 결과 등급별 화면(큰 글씨·칭찬/이유·익힘 색·넘침 방울·윤기).
  // Reduced motion (mountGame): the still picture, no effect particles.
  for (final (name, first, second, bakeMs) in const [
    ('perfect', PaintAmount(980, 1100), PaintAmount(970, 1120), 15000),
    ('good', PaintAmount(920, 1250), PaintAmount(940, 1200), 18000),
    ('near', PaintAmount(1000, 1400), PaintAmount(960, 1100), 15000),
    ('fail', PaintAmount.even, PaintAmount.even, 26000),
  ]) {
    testWidgets('결과 등급 $name 골든 390x844', (tester) async {
      CookingResultView.celebrated = null;
      final c = await mount(tester, const Size(390, 844));
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
      expect(cookingGrade(c.config, done, difficulty: c.difficulty(done.flavor)).name, name);
      await shoot(tester, 'result_${name}_390x844');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
      // 26번 2단계: the griddle's introduction card was seen (its own test).
      c.state.featureIntros.add('griddle');
    });
    expect(await c.startCell(1), isTrue);
    expect(await c.startCell(4), isTrue);
    await tester.pump();
    await shoot(tester, 'griddle_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 26번 4-1단계: 손님이 매대 앞에 서는 새 구도. 빈 매대(배경 + 큰 붕어빵),
  // 최대 손님 4명(맨 앞 크게 + 뒤 0.8배), 주문 손님 말풍선,
  // 판매 직후 기쁜 얼굴, 그리고 그림이 덜 들어왔을 때의 예전 구도.
  Future<void> openWithStock(WorkshopController c, {int stock = 1}) async {
    await c.openBusiness();
    await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'one',
        flavor: 'redbean', variant: 2, quantity: stock, madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
  }

  for (final size in [const Size(360, 640), const Size(412, 915)]) {
    testWidgets('빈 매대 골든 ${tag(size)}', (tester) async {
      final c = await mount(tester, size);
      await openWithStock(c);
      await tester.pump();
      expect(find.byKey(const Key('customer-0')), findsNothing);
      await shoot(tester, 'empty_${tag(size)}');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('최대 손님 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await openWithStock(c, stock: 0);
    await c.command(() => c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_a', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 20000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]))
      ..add(CustomerOrder(id: 'third', customerId: 'anonymous_third', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]))
      ..add(CustomerOrder(id: 'fourth', customerId: 'anonymous_d', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 3)])));
    await tester.pump();
    await shoot(tester, 'guests_max_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('판매 직후 기쁜 손님 골든 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await openWithStock(c, stock: 2);
    await c.command(() => c.state.customers
      ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]))
      ..add(CustomerOrder(id: 'second', customerId: 'anonymous_second', remainingMs: 100000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    expect(await c.sellToCustomer('first'), isTrue, reason: '${c.notice} ${c.error}');
    await tester.pump();
    expect(find.byKey(const Key('customer-leaving')), findsOneWidget);
    await shoot(tester, 'sold_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('주문 제작 결과 손님 말풍선 골든 390x844', (tester) async {
    CookingResultView.celebrated = null;
    final c = await mount(tester, const Size(390, 844));
    await openWithStock(c, stock: 0);
    await c.command(() => c.state.customers.add(CustomerOrder(id: 'first', customerId: 'anonymous_first',
        remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    expect(await c.startOrderProduction('first', 'redbean'), isTrue, reason: '${c.notice} ${c.error}');
    var s = c.state.session!;
    s = s.pour(s.token, const PaintAmount(980, 1100));
    s = s.squeezeFilling(s.token, PaintAmount.even);
    s = s.pour(s.token, const PaintAmount(970, 1120));
    s = s.close(s.token);
    s = s.flip(s.token);
    final done = s.takeOut(s.token, 15000);
    await c.command(() => c.state.session = done);
    await tester.pump();
    expect(find.byKey(const Key('guest-reaction')), findsOneWidget);
    expect(find.byKey(const Key('mold-result-reaction')), findsNothing);
    await shoot(tester, 'reaction_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('예전 구도(배경 14장이 다 없을 때) 골든 390x844', (tester) async {
    WorkshopHomeLayout.enabled = false;
    addTearDown(() => WorkshopHomeLayout.enabled = true);
    final c = await mount(tester, const Size(390, 844));
    await serve(c);
    await tester.pump();
    expect(find.byKey(const Key('customer-queue')), findsOneWidget);
    await shoot(tester, 'old_layout_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
