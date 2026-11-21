// 26번 3차 피드백 D 묶음 미리보기(한글 글꼴): '오늘' 창·출석·주간 도전·도감·생산 기록·메뉴.
// flutter test tools/preview_h_d_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/hd_<장면>_<폭>.png (실제 앱 크기 390×844·360×800)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;

/// Fixed frames instead of pumpAndSettle: the home keeps small looping
/// animations (since the C bundle), so it never fully settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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
      final image = await layer.toImage(Offset.zero & view.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> controller({required int level, required bool rich}) async {
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 19, 3), monotonicMs: () => 0);
    await c.initialize();
    await c.openBusiness();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= level; i++) i]);
      if (level >= 5) {
        c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
      }
      if (rich) {
        c.state.buns = BigInt.parse('1234567');
        c.state.lifetime = BigInt.parse('2345678');
        c.state.taps = 4321;
        c.state.daily = c.state.daily.copyWith(stamps: 3, stampDay: '2026-11-17');
        c.state.relationships = c.state.relationships.visit('known-doyun', 'npc_doyun', 1, c.customerCatalog);
      }
    });
    // ignore: avoid_print
    print('state error: ${c.error}');
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    for (final (label, level, rich) in [('lv1', 1, false), ('lv5', 5, true)]) {
      testWidgets('D 묶음 미리보기 $label $w', (tester) async {
        await fonts(tester);
        final account = await mountGame(tester, size, reduced: true);
        final c = await controller(level: level, rich: rich);
        await tester.pumpWidget(GameApp(controller: account, workshop: c));
        await tester.pump();
        await shot(tester, 'hd_home_${label}_$w');
        Future<void> close() async {
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          while (nav.canPop()) {
            nav.pop();
            await settle(tester);
          }
        }
        // '오늘' 창
        await tester.tap(find.byKey(const Key('daily-ticket')));
        await settle(tester);
        await shot(tester, 'hd_today_${label}_$w');
        final scroll = find.byKey(const Key('today-scroll'));
        if (scroll.evaluate().isNotEmpty) {
          await tester.drag(scroll, const Offset(0, -500));
          await settle(tester);
          await shot(tester, 'hd_today_${label}_${w}_b');
          await tester.drag(scroll, const Offset(0, -900));
          await settle(tester);
          await shot(tester, 'hd_today_${label}_${w}_c');
        }
        await close();
        // 메뉴와 메뉴 안 창들
        for (final (key, name) in [
          ('', 'menu'),
          ('menu-collection', 'collection'),
          ('menu-records', 'records'),
          ('event-entry', 'weekly'),
          ('menu-daily', 'daily'),
          ('menu-missions', 'levelmissions'),
        ]) {
          await tester.tap(find.byKey(const Key('menu-menubar')));
          await settle(tester);
          if (key.isNotEmpty) {
            final row = find.byKey(Key(key));
            if (row.evaluate().isEmpty) {
              await close();
              continue;
            }
            await tester.ensureVisible(row);
            await tester.tap(row);
            await settle(tester);
          }
          await shot(tester, 'hd_${name}_${label}_$w');
          await close();
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
