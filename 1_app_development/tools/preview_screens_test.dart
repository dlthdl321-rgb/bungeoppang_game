// Local screenshot of the home screen and the menu with a Korean font and
// all pixel art loaded; the font is never copied into the app.
// flutter test tools/preview_screens_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// Writes build/preview/home.png and build/preview/menu.png (390x844 at 2x).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import '../test/widget_test.dart' show FixedTime;

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/preview/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('홈·메뉴 미리보기', (tester) async {
    // Still frames: looping weather and cooking never let pumpAndSettle end.
    WeatherLayer.animate = false;
    const fontPath = String.fromEnvironment('PREVIEW_FONT');
    expect(fontPath, isNotEmpty, reason: 'PREVIEW_FONT에 로컬 한글 폰트 경로를 지정하세요.');
    await tester.runAsync(() async {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader('Preview')
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      final jua = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
      await (FontLoader('Jua')..addFont(Future.value(jua))).load();
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
      await PixelSprites.load();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final clock = FixedTime();
    final repo = MemoryGameRepository()
      ..current = (GameState.initial(clock.utcNow)
        ..tutorialDone = true
        ..buns = BigInt.parse('1234567890123')
        ..lifetime = BigInt.parse('2345678901234')
        ..level = 6);
    repo.current!.missions = MissionState.forLevel(6, clock.utcNow);
    // One daily goal done, so the menu shows its reward badge.
    repo.current!.support.daily.taps = BigInt.from(50);
    final c = GameController(repo, clock);
    await c.initialize();
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('app-capture'),
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: cozyTheme(),
          home: GameHome(controller: c)),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await capture(tester, 'home');
    await tester.tap(find.byKey(const Key('menu-menu')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'menu');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    // The wardrobe on the 의상 tab, the vendor wearing a sweater and apron.
    c.state.wardrobe.owned.addAll(['pinksweater', 'creamapron']);
    c.state.wardrobe.equipped
      ..[CosmeticSlot.top] = 'pinksweater'
      ..[CosmeticSlot.outfit] = 'creamapron';
    c.tick();
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-skins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cosmetic-category-outfit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'wardrobe');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    // Each concept background with its weather (a still frame).
    for (final bg in ['rain', 'autumn', 'snowday', 'snow', 'cherry']) {
      c.state.wardrobe.owned.add(bg);
      c.state.wardrobe.equipped[CosmeticSlot.background] = bg;
      c.tick();
      await tester.pump();
      await tester.pump();
      await capture(tester, 'home_$bg');
    }
    // The cherry theme at night (darkened until its night art arrives) and
    // the snow theme's own night picture.
    c.state.wardrobe.equipped[CosmeticSlot.time] = 'night_time';
    for (final bg in ['cherry', 'snowday']) {
      c.state.wardrobe.equipped[CosmeticSlot.background] = bg;
      c.tick();
      await tester.pump();
      await capture(tester, 'night_$bg');
    }
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'settings');
    c.dispose();
  });
}
