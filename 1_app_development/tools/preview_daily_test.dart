// 26번 7단계 미리보기(한글 글꼴): 홈 카운터 옆 '오늘' 쪽지와 쪽지 카드.
// flutter test tools/preview_daily_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/daily_*.png
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
        // Plain text (no family) uses the platform default: give it Korean glyphs.
        if (korean.isNotEmpty) await load('Roboto', korean);
      });

  Future<void> shot(WidgetTester tester, Finder target, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(target);
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final (name, at) in [('christmas', DateTime.utc(2026, 12, 24, 3)), ('plain', DateTime.utc(2026, 11, 2, 3))]) {
    testWidgets('오늘 쪽지 미리보기 $name', (tester) async {
      await fonts(tester);
      final account = await setUpAccount(tester, const Size(390, 844), reduced: true);
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final c = WorkshopController(config, MemoryRepository(), now: () => at, monotonicMs: () => 0);
      await c.initialize();
      await c.openBusiness();
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = 5;
        c.state.claimedLevels..clear()..addAll([2, 3, 4, 5]);
        c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
        c.state.relationships = c.state.relationships.visit('known-doyun', 'npc_doyun', 1, c.customerCatalog);
      });
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await shot(tester, find.byKey(const Key('home-capture')), 'daily_home_$name');
      await tester.tap(find.byKey(const Key('daily-ticket')));
      await tester.pumpAndSettle();
      await shot(tester, find.ancestor(of: find.byKey(const Key('daily-card')), matching: find.byType(RepaintBoundary)).first, 'daily_card_$name');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
