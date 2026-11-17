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
}
