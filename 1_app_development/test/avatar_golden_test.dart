import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

// Stage 26 4-4: the vendor in every skin tone and hair style, girl and boy,
// with the default apron, plus a hat on a short cut and no apron. Catches
// a broken _cut mask, a missing skin copy or a hair layer out of place.
void main() {
  testWidgets('사장님 피부톤 × 머리 모양 골든', (tester) async {
    await tester.runAsync(PixelSprites.load);
    const skins = ['skin1', 'skin2', 'skin3'];
    const hairs = ['long', 'short', 'ponytail', 'curly'];
    const extras = <Map<CosmeticSlot, String>>[
      {CosmeticSlot.hair: 'short', CosmeticSlot.hat: 'chefhat'},
      {CosmeticSlot.outfit: 'noapron'},
    ];
    Widget vendor(String character, Map<CosmeticSlot, String> worn) =>
        SizedBox(
            width: 56,
            height: 104,
            child: CustomPaint(
                painter: AvatarPainter(AvatarLook.of((s) =>
                    s == CosmeticSlot.character
                        ? character
                        : worn[s] ?? defaultCosmetics[s]!))));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2 * 6 * 56, 3 * 104);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
            key: const Key('avatars'),
            child: ColoredBox(
                color: const Color(0xFF6E8F64),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final skin in skins)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final character in ['girl', 'boy']) ...[
                        for (final hair in hairs)
                          vendor(character, {
                            CosmeticSlot.skin: skin,
                            CosmeticSlot.hair: hair
                          }),
                        for (final extra in extras)
                          vendor(character, {CosmeticSlot.skin: skin, ...extra}),
                      ],
                    ]),
                ])))));
    await expectLater(find.byKey(const Key('avatars')),
        matchesGoldenFile('goldens/avatar_skin_hair.png'));
  });

  // 25번 문서 17번: every hat drawn from a picture of the vendor wearing it,
  // girl and boy, long and short hair. Catches a hat floating off the head.
  testWidgets('사장님 모자 9종 골든', (tester) async {
    await tester.runAsync(PixelSprites.load);
    const hats = [
      'beanie', 'bandana', 'ballcap', 'newsboy', //
      'chefhat', 'earmuffs', 'santa', 'redbandana', 'blackcap',
    ];
    Widget vendor(String character, String hair, String hat) => SizedBox(
        width: 56,
        height: 104,
        child: CustomPaint(
            painter: AvatarPainter(AvatarLook.of((s) => switch (s) {
                  CosmeticSlot.character => character,
                  CosmeticSlot.hair => hair,
                  CosmeticSlot.hat => hat,
                  _ => defaultCosmetics[s]!,
                }))));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(hats.length * 56.0, 4 * 104);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
            key: const Key('hats'),
            child: ColoredBox(
                color: const Color(0xFF6E8F64),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final character in ['girl', 'boy'])
                    for (final hair in ['long', 'short'])
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        for (final hat in hats) vendor(character, hair, hat),
                      ]),
                ])))));
    await expectLater(find.byKey(const Key('hats')),
        matchesGoldenFile('goldens/avatar_hats.png'));
  });
}
