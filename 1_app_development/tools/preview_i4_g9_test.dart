// 4차 피드백 g9 미리보기(한글 글꼴): 레벨 창(레벨 미션)과 홈 레벨 고리.
// flutter test tools/preview_i4_g9_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_g9/<태그>_<장면>_<폭>.png (실제 앱 크기 390×844·360×800)
// 전후 비교용이라 옛 코드에서도 돌아가게 새 필드(soldPieces 등)는 dynamic으로만 건드린다.
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
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart' show workshopIntroIds;
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');
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
      final out = File('build/preview/i4_g9/$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  /// [level] with [taps]/[pieces] done in it and [buns] on hand.
  Future<WorkshopController> controller({required int level, required int taps, required int pieces,
      required String buns, int gold = 0}) async {
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 21, 3), monotonicMs: () => 0);
    await c.initialize();
    await c.openBusiness();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= level; i++) i]);
      c.state.featureIntros.addAll(workshopIntroIds);
      c.state.buns = BigInt.parse(buns);
      c.state.lifetime = BigInt.parse(buns) * BigInt.from(3);
      c.state.taps = 500 + taps;
      c.state.levelStartTaps = 500;
      try {
        (c.state as dynamic).soldPieces = 40 + pieces;
        (c.state as dynamic).levelStartPieces = 40;
      } on NoSuchMethodError {
        // The code before g9 counted sales (customers), not pieces.
      }
    });
    try {
      (c as dynamic).goldBalance = gold;
    } on NoSuchMethodError {
      // Before g9.
    }
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    for (final (label, level, taps, pieces, buns, gold) in [
      ('lv3_mid', 3, 12, 0, '320', 0),
      ('lv7_ready', 7, 60, 2, '15000', 0),
      ('lv9_gold', 9, 60, 2, '45000', 12),
      ('lv15_mid', 15, 30, 4, '41000', 0),
    ]) {
      testWidgets('g9 미리보기 $label $w', (tester) async {
        await fonts(tester);
        final account = await mountGame(tester, size, reduced: true);
        final c = await controller(level: level, taps: taps, pieces: pieces, buns: buns, gold: gold);
        await tester.pumpWidget(GameApp(controller: account, workshop: c));
        await settle(tester);
        await shot(tester, '${tag}_home_${label}_$w');
        final ring = find.byKey(const Key('level-mission-entry'));
        await tester.longPress(ring);
        await settle(tester);
        await shot(tester, '${tag}_hint_${label}_$w');
        await tester.tap(ring);
        await settle(tester);
        await shot(tester, '${tag}_window_${label}_$w');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
