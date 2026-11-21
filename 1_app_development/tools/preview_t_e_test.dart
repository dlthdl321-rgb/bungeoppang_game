// 재료 타이쿤 E(홈 재료 표시·재료 준비 버튼·떨어짐 말풍선·Lv.2 소개) 확인용 화면(한글 글꼴).
// flutter test tools/preview_t_e_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/t_E/<TAG>_<이름>_<크기>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;

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
      final out = File('build/preview/t_E/${tag}_${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void drain(PantryState pantry, String kind, {int keep = 0}) {
    var left = keep;
    for (final lot in pantry.lots.where((l) => l.kind == kind)) {
      final take = lot.portions - (left > lot.portions ? lot.portions : left);
      left -= lot.portions - take;
      pantry.ledger[kind]!.used += take;
      lot.portions -= take;
    }
    pantry.lots.removeWhere((l) => l.kind == kind && l.portions == 0);
  }

  Future<WorkshopController> home(WidgetTester tester, Size size,
      {int level = 2, bool open = false, Set<String>? seen, void Function(WorkshopController c)? edit, double textScale = 1}) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    final account = await mountGame(tester, size, reduced: true, textScale: textScale);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= level; i++) i]);
      c.state.featureIntros.addAll(seen ?? workshopIntroIds);
    });
    if (open) {
      await c.openBusiness();
      await c.command(() => c.state.customers
        ..add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    }
    if (edit != null) await c.command(() => edit(c));
    c.takePantryNews();
    c.dismissPromotion();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    testWidgets('영업 준비 ${size.width}', (tester) async {
      await home(tester, size);
      await shot(tester, 'prep_home');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Lv.1 잠금 ${size.width}', (tester) async {
      await home(tester, size, level: 1);
      await shot(tester, 'prep_locked_lv1');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('영업 중 조금 남음 ${size.width}', (tester) async {
      await home(tester, size, open: true, edit: (c) => drain(c.state.pantry, 'batter', keep: 137));
      await shot(tester, 'open_low');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('영업 중 떨어짐 ${size.width}', (tester) async {
      await home(tester, size, open: true, edit: (c) {
        drain(c.state.pantry, 'redbean');
        c.state.buns = BigInt.from(1000000000);
        c.state.lifetime = c.state.buns;
      });
      await tester.pump();
      await shot(tester, 'open_out_bubble');
      await tester.tap(find.byKey(const Key('pantry-out-bubble')));
      await tester.pump();
      await shot(tester, 'open_out_red');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('소개 카드와 안내 ${size.width}', (tester) async {
      await home(tester, size, seen: workshopIntroIds.difference({'pantry'}));
      await tester.pumpAndSettle();
      await shot(tester, 'intro_card');
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      await shot(tester, 'tour_1');
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      await shot(tester, 'tour_2');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('재료 준비 창(임시) ${size.width}', (tester) async {
      await home(tester, size);
      await tester.tap(find.byKey(const Key('pantry-prep')));
      await tester.pumpAndSettle();
      await shot(tester, 'prep_window_stub');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final size in const [Size(360, 640)]) {
    testWidgets('작은 화면 큰 글자 손님 ${size.width}', (tester) async {
      final c = await home(tester, size, open: true, textScale: 1.3);
      expect(await c.welcomeCustomer(visitor: 'npc_taeo'), isTrue);
      await tester.pump();
      await shot(tester, 'small_large_text_guest');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('작은 화면 떨어짐 ${size.width}', (tester) async {
      final c = await home(tester, size, open: true, edit: (c) {
        drain(c.state.pantry, 'batter');
        c.state.buns = BigInt.from(1000000000);
        c.state.lifetime = c.state.buns;
      });
      expect(await c.welcomeCustomer(visitor: 'npc_taeo'), isTrue);
      await tester.pump();
      await shot(tester, 'small_out_bubble');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('작은 화면 영업 준비 ${size.width}', (tester) async {
      await home(tester, size);
      await shot(tester, 'small_prep');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('작은 화면 손님 ${size.width}', (tester) async {
      final c = await home(tester, size, open: true);
      expect(await c.welcomeCustomer(visitor: 'npc_taeo'), isTrue);
      await tester.pump();
      await shot(tester, 'small_guest');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
