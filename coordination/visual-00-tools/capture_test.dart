// Capture of the current Workshop screens for coordination/visual-00-gap.md.
// Not part of the suite. To rerun, copy this file to
// 1_app_development/build/visual-00/capture_test.dart and, from 1_app_development:
//   flutter test --no-pub build/visual-00/capture_test.dart
// PNGs land in build/visual-00/shots/. Jua and Material Icons are loaded so
// Korean shows (glyphs Jua lacks, such as '·', still show as boxes).
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
import '../../test/step02_controller_test.dart' show MemoryRepository;
import '../../test/widget_test.dart' show mountGame;

Future<void> _font(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets('capture current workshop screens', (tester) async {
    await tester.runAsync(() async {
      await _font('Jua', 'assets/fonts/Jua-Regular.ttf');
      await _font('MaterialIcons',
          'C:/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    });
    final account = await mountGame(tester, const Size(390, 844), reduced: true);
    final config = DevelopmentBalance.fromJson(jsonDecode(
            File('config/development_balance.json').readAsStringSync())
        as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 10, 18));
    await c.initialize();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pumpAndSettle();
    final out = Directory('build/visual-00/shots')..createSync(recursive: true);
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final view = tester.binding.renderViews.first;
        final layer = view.debugLayer! as OffsetLayer;
        final image = await layer.toImage(Offset.zero & view.size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    Future<void> tapKey(String k) async {
      final f = find.byKey(Key(k));
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
    Future<void> close() async {
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
    }

    await shot('00_home');
    await tapKey('menu-menu');
    await shot('01_menu');
    await close();
    await tester.tap(find.byTooltip('설정'));
    await shot('02_settings');
    await close();
    await tapKey('menu-skills');
    await shot('03_skills');
    await close();
    await tapKey('menu-skins');
    await shot('04_wardrobe');
    await close();
    await tapKey('menu-shop');
    await shot('05_shop');
    await close();
    var n = 6;
    for (final route in [
      'menu-management', 'menu-collection', 'menu-achievements',
      'menu-records', 'menu-daily', 'event-entry', 'menu-missions',
      'menu-ranking', 'menu-friends', 'menu-share'
    ]) {
      await tapKey('menu-menu');
      await tapKey(route);
      await shot('${(n++).toString().padLeft(2, '0')}_${route.replaceFirst('menu-', '')}');
      await close();
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
