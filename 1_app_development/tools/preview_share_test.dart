// 26번 8단계 미리보기(한글 글꼴): 공유 카드 네 가지(1080×1350 실제 크기).
// flutter test tools/preview_share_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/share_card_*.png
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

  const look = {'background': 'clear', 'decoration': 'starlights', 'lamp': 'amberlamp'};
  final cards = {
    'perfect': const ShareCardData(moment: ShareMoment.perfect, title: '팥 붕어빵', speaker: '도윤',
        line: '와, 이건 진짜 반짝반짝해요!', guestArt: 'npc_doyun', variant: 2, shine: true, equipped: look),
    'story': const ShareCardData(moment: ShareMoment.story, title: '간식 지도 공개', speaker: '도윤',
        line: '이거 제가 만든 동네 간식 지도예요. 여기 붕어빵집이 1등이에요!', guestArt: 'npc_doyun', equipped: look),
    'collection': const ShareCardData(moment: ShareMoment.collection, title: '팥 붕어빵 도감',
        line: '다섯 가지 익힘을 모두 찾았어요.', variant: 3, equipped: look),
    'shop': const ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '따끈한 붕어빵 구워 놓고 기다릴게요!', equipped: look),
  };
  for (final entry in cards.entries) {
    testWidgets('공유 카드 미리보기 ${entry.key}', (tester) async {
      await fonts(tester);
      await tester.runAsync(PixelSprites.load);
      await tester.binding.setSurfaceSize(const Size(400, 500));
      tester.view.devicePixelRatio = 1;
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final texts = ShareCardTexts.of(config);
      await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: const Key('cap'),
          child: ShareCardView(data: entry.value, texts: texts)))));
      await tester.pump();
      await tester.runAsync(() async {
        final png = await captureShareCard(tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('cap'))), texts);
        final out = File('build/preview/share_card_${entry.key}.png');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(png);
      });
      await tester.binding.setSurfaceSize(null);
    });
  }
}
