// Game screens for each stage of the extra art set (tools/apply_extra_art.py),
// with a local Korean font; the font is never copied into the app.
// flutter test tools/preview_extra_art_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=STAGE=bg
// Writes build/preview/extra/<stage>_<name>.png (390x844).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import '../test/widget_test.dart' show FixedTime;

typedef Look = Map<CosmeticSlot, String>;

/// Home screens to capture per stage: name -> what is equipped.
final Map<String, Map<String, Look>> stages = {
  'fish': {
    for (final p in ['heartscale', 'starmark', 'crispgrid'])
      for (final t in ['almond', 'choco', 'sprinkle', 'sugar'])
        '${p}_$t': {CosmeticSlot.pattern: p, CosmeticSlot.topping: t},
    for (final s in ['iron', 'castiron', 'copper', 'golden'])
      'stove_$s': {CosmeticSlot.stove: s},
  },
  'deco': {
    for (final d in [
      'lantern', 'windchime', 'bunting', 'starlights', 'paperlanterns', //
      'snowman',
    ])
      d: {CosmeticSlot.decoration: d},
    'snowman_snow': {
      CosmeticSlot.decoration: 'snowman',
      CosmeticSlot.background: 'snowday'
    },
  },
  // Home only; the settings and menu screens are captured after it.
  'icons': {'home': {}},
  'bg': {
    for (final bg in [
      'clear', 'rain', 'autumn', 'cherry', 'snowday', //
      'dusk', 'forest', 'night', 'seaside',
    ])
      bg: {CosmeticSlot.background: bg, CosmeticSlot.time: 'day'},
    for (final bg in [
      'clear', 'rain', 'autumn', 'cherry', 'snowday', //
      'dusk', 'forest', 'night', 'seaside',
    ])
      '${bg}_night': {
        CosmeticSlot.background: bg,
        CosmeticSlot.time: 'night_time'
      },
  },
};

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/preview/extra/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('추가 이미지 적용 화면', (tester) async {
    const stage = String.fromEnvironment('STAGE');
    expect(stages, contains(stage), reason: 'STAGE: ${stages.keys}');
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
        ..level = 9);
    repo.current!.missions = MissionState.forLevel(9, clock.utcNow);
    final c = GameController(repo, clock);
    await c.initialize();
    c.state.wardrobe.owned.addAll(cosmeticDefinitions.map((d) => d.id));
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('app-capture'),
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: cozyTheme(),
          home: GameHome(controller: c)),
    ));
    await tester.pump();
    for (final MapEntry(key: name, value: look) in stages[stage]!.entries) {
      c.state.wardrobe.equipped
        ..clear()
        ..addAll(defaultCosmetics)
        ..addAll(look);
      c.tick();
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
      await capture(tester, '${stage}_$name');
    }
    if (stage == 'icons') {
      for (final (tap, name) in [
        (find.byTooltip('설정'), 'settings'),
        (find.byKey(const Key('menu-menu')), 'menu'),
      ]) {
        await tester.tap(tap);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        await capture(tester, '${stage}_$name');
        if (name == 'settings') {
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
          await tester.pumpAndSettle();
          await capture(tester, '${stage}_${name}_2');
        }
        await tester.tap(find.byTooltip('닫기').last);
        await tester.pumpAndSettle();
      }
    }
    c.dispose();
  });
}
