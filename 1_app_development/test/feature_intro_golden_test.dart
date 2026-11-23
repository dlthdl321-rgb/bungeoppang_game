@Tags(['golden'])
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/workshop_guide.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';

/// 25번 22번: the eight feature introduction cards with their drawn
/// pictures (160x120, tools/apply_25_art.py --only intro), 1:1 in the card.
void main() {
  // The 붕어빵 요정 card (4차 IA3) waits for its picture (ui/intro_fairy, to
  // be ordered); until then it shows the 'bun' icon (checked below).
  final features = [for (final f in WorkshopFeature.values)
    if (f != WorkshopFeature.wardrobe && f != WorkshopFeature.fairy && f != WorkshopFeature.pantry) f];

  test('붕어빵 요정 카드: 그림 자리는 등록돼 있고, 그림이 없으면 아이콘', () {
    final intro = featureIntro(WorkshopFeature.fairy);
    expect(PixelSprites.uiNames, contains(intro.art));
    expect(intro.fallbackIcon, 'bun');
  });

  test('재료 준비 카드(재료 타이쿤 E): 그림 자리는 등록돼 있고, 그림이 없으면 재료 준비 아이콘', () {
    final intro = featureIntro(WorkshopFeature.pantry);
    expect(PixelSprites.uiNames, contains(intro.art));
    expect(intro.fallbackIcon, 'btn_prep');
    expect(PixelSprites.iconNames, contains('btn_prep'));
  });

  test('소개 카드 8장 모두 그림 파일이 160×120으로 있다', () async {
    for (final f in features) {
      final name = featureIntro(f).art;
      final file = File('assets/images/ui/$name.png');
      expect(file.existsSync(), isTrue, reason: name);
      final bytes = file.readAsBytesSync();
      // PNG IHDR: width and height, big-endian, at bytes 16..23.
      final data = ByteData.sublistView(bytes);
      expect([data.getUint32(16), data.getUint32(20)], [160, 120], reason: name);
      expect(PixelSprites.uiNames, contains(name));
    }
  });

  testWidgets('소개 카드 8장 골든: 그림이 틀 안에 1:1로 보인다', (tester) async {
    await tester.runAsync(PixelSprites.load);
    await tester.runAsync(() async {
      final file = File('assets/fonts/Jua-Regular.ttf');
      if (!file.existsSync()) return;
      await (FontLoader('Jua')..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    });
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: const Color(0xff2a211c),
            body: Wrap(children: [
              for (final f in features)
                SizedBox(
                    width: 360,
                    height: 480,
                    child: WorkshopFeatureIntroCard(feature: f, onDone: () {})),
            ]))));
    await tester.pump();
    expect(find.byKey(const Key('feature-intro-art')), findsNWidgets(features.length));
    expect(find.byKey(const Key('feature-intro-standin')), findsNothing);
    for (final e in find.byKey(const Key('feature-intro-art')).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)), const Size(160, 120));
    }
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/feature_intro_cards.png'));
    expect(tester.takeException(), isNull);
  });
}
