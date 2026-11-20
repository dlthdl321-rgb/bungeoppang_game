// 26번 3차 AV2 미리보기: 공유 카드 자랑 포즈의 든 팔 소매(25번 50번)를
// 상의 8종 × 남녀 × 피부톤 3으로 그리고, 앱 크기(390×844) 공유 창도 찍는다.
//   flutter test --update-goldens tools/preview_h_av2_test.dart
// 결과: build/preview_av2/<태그>/card_<성별>_<상의>_<피부>.png (1080×1350)
//       build/preview_av2/<태그>/dialog_<성별>_<상의>.png (390×844, 2배)
// 태그는 --dart-define=AV2_TAG=<이름>(기본 now).
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/share_card.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/share_card_view.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import '../test/usage_stats_test.dart' show RecordingSink;

const _tag = String.fromEnvironment('AV2_TAG', defaultValue: 'now');
const _tops = ['tee', 'creamlong', 'pinksweater', 'sagesweater', 'creamsweater', 'cardigan', 'chefcoat', 'padding'];
const _stall = {'background': 'clear', 'decoration': 'starlights', 'lamp': 'amberlamp'};

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    });

ShareCardTexts _texts() => ShareCardTexts.of(DevelopmentBalance.fromJson(
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

ShareCardData _card(String c, String top, String skin) => ShareCardData(
    moment: ShareMoment.shop, title: '우리 가게', line: '어서 오세요!',
    equipped: {..._stall, 'character': c, 'skin': skin, 'top': top});

void main() {
  for (final c in ['girl', 'boy']) {
    for (final top in _tops) {
      testWidgets('공유 카드 $c $top', (tester) async {
        await _fonts(tester);
        await tester.runAsync(PixelSprites.load);
        await tester.binding.setSurfaceSize(const Size(400, 500));
        tester.view.devicePixelRatio = 1;
        final texts = _texts();
        for (final skin in ['skin1', 'skin2', 'skin3']) {
          await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: const Key('cap'),
              child: ShareCardView(key: ValueKey(skin), data: _card(c, top, skin), texts: texts)))));
          await tester.pump();
          await tester.runAsync(() async {
            final png = await captureShareCard(
                tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('cap'))), texts);
            final out = File('build/preview_av2/$_tag/card_${c}_${top}_$skin.png');
            await out.parent.create(recursive: true);
            await out.writeAsBytes(png);
          });
        }
        await tester.binding.setSurfaceSize(null);
        tester.view.resetDevicePixelRatio();
      });
    }
  }

  // Aprons and accessories over the sleeves (what the hide mask erases).
  const combos = <String, Map<String, String>>{
    'noapron': {'outfit': 'noapron'},
    'stripe_scarf': {'outfit': 'stripe', 'accessory': 'scarf'},
    'waist_crossbag': {'outfit': 'waistapron', 'accessory': 'crossbag'},
    'cream_mittens': {'outfit': 'creamapron', 'accessory': 'mittens'},
    'dark_ponytail': {'outfit': 'darkapron', 'hair': 'ponytail', 'hat': 'beanie'},
  };
  for (final c in ['girl', 'boy']) {
    testWidgets('공유 카드 조합 $c', (tester) async {
      await _fonts(tester);
      await tester.runAsync(PixelSprites.load);
      await tester.binding.setSurfaceSize(const Size(400, 500));
      tester.view.devicePixelRatio = 1;
      final texts = _texts();
      for (final top in ['tee', 'sagesweater', 'chefcoat']) {
        for (final MapEntry(key: name, value: extra) in combos.entries) {
          final data = ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '어서 오세요!',
              equipped: {..._stall, 'character': c, 'top': top, ...extra});
          await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: const Key('cap'),
              child: ShareCardView(key: ValueKey('$top$name'), data: data, texts: texts)))));
          await tester.pump();
          await tester.runAsync(() async {
            final png = await captureShareCard(
                tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('cap'))), texts);
            final out = File('build/preview_av2/$_tag/combo_${c}_${top}_$name.png');
            await out.parent.create(recursive: true);
            await out.writeAsBytes(png);
          });
        }
      }
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }

  // The share window at the app's size (390x844), a few tops per character.
  for (final (c, top, skin) in [
    ('girl', 'tee', 'skin1'), ('girl', 'pinksweater', 'skin2'), ('girl', 'chefcoat', 'skin3'),
    ('girl', 'padding', 'skin1'), ('boy', 'tee', 'skin2'), ('boy', 'creamsweater', 'skin1'),
    ('boy', 'cardigan', 'skin3'), ('boy', 'sagesweater', 'skin2'),
  ]) {
    testWidgets('공유 창 390×844 $c $top', (tester) async {
      await _fonts(tester);
      await tester.runAsync(PixelSprites.load);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.devicePixelRatio = 2;
      final texts = _texts();
      await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
          home: Scaffold(backgroundColor: const Color(0xFF3B2A20), body: Builder(builder: (context) => Center(
              child: TextButton(key: const Key('open'), child: const Text('열기'),
                  onPressed: () => showShareCardDialog(context, data: _card(c, top, skin), texts: texts,
                      usage: UsageStats(RecordingSink()))))))));
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('../build/preview_av2/$_tag/dialog_${c}_$top.png'));
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
  }
}
