// Optional local Korean-font preview; the font is never copied into the app.
// flutter test tools/preview_home_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import '../test/widget_test.dart' show FixedTime;

void main() {
  testWidgets('한글 홈 미리보기 생성', (tester) async {
    const fontPath = String.fromEnvironment('PREVIEW_FONT');
    expect(fontPath, isNotEmpty, reason: 'PREVIEW_FONT에 로컬 한글 폰트 경로를 지정하세요.');
    await tester.runAsync(() async {
      final bytes = await File(fontPath).readAsBytes();
      await (FontLoader('Preview')
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
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
    repo.current!.upgradeCounts['auto_3'] = 2;
    repo.current!.missions = MissionState.forLevel(6, clock.utcNow);
    final c = GameController(repo, clock);
    await c.initialize();
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('app-capture'),
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              fontFamily: 'Preview',
              colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff9b4436),
                  surface: const Color(0xfffff8e8)),
              scaffoldBackgroundColor: const Color(0xfffff8e8),
              splashFactory: InkRipple.splashFactory,
              useMaterial3: true),
          home: GameHome(controller: c)),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('home-capture')));
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/preview/home_390x844.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byKey(const Key('menu-shop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quantity-maximum')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final shop = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('app-capture')));
    await tester.runAsync(() async {
      final image = await shop.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/preview/shop_390x844.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    c.state.level = 9;
    c.state.missions = MissionState.forLevel(9, clock.utcNow);
    c.state.upgradeCounts['auto_14'] = 2;
    c.tick();
    await tester.pump();
    for (final preview in [
      ('level-mission-entry', 'missions'),
      ('mission-open-achievements', 'mission-shortcut'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(preview.$1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(preview.$1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final capture = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('app-capture')));
      await tester.runAsync(() async {
        final image = await capture.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/preview/${preview.$2}_390x844.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
    }
    c.state.level = 10;
    c.state.missions = MissionState.forLevel(10, clock.utcNow);
    c.state.support
        .transact('preview:coins', BigInt.from(100), '미리보기', clock.utcNow);
    c.state.support.daily.taps = BigInt.from(50);
    c.state.support.daily.production = BigInt.from(1000);
    c.state.support.daily.purchases = BigInt.from(3);
    c.tick();
    await tester.pump();
    for (final preview in [
      ('menu-daily', 'daily'),
      ('daily-store', 'items'),
      ('support-shop', 'coins'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(preview.$1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(preview.$1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final capture = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('app-capture')));
      await tester.runAsync(() async {
        final image = await capture.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/preview/${preview.$2}_390x844.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
    }
    for (final preview in [
      ('menu-skins', 'wardrobe'),
      ('menu-records', 'records'),
      ('menu-achievements', 'achievements'),
      ('menu-share', 'share'),
      ('event-entry', 'weekly'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(preview.$1)));
      await tester.tap(find.byKey(Key(preview.$1)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final capture = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('app-capture')));
      await tester.runAsync(() async {
        final image = await capture.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('build/preview/${preview.$2}_390x844.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(null);
  });
}
