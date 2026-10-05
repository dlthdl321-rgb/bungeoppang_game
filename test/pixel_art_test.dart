import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);

  (double, double) sizeOf(image) =>
      (image.width.toDouble(), image.height.toDouble());

  test('모든 꾸미기에 도트 이미지가 있고 크기가 장면 규격과 맞다', () {
    for (final d in cosmeticDefinitions) {
      // Blank items draw nothing; patterns are baked into the fish images.
      if (blankCosmetics.contains(d.id) || d.slot == CosmeticSlot.pattern) {
        expect(PixelSprites.cosmetic(d.slot, d.id), isNull, reason: d.id);
        continue;
      }
      final image = PixelSprites.cosmetic(d.slot, d.id);
      expect(image, isNotNull, reason: d.id);
      switch (d.slot.category) {
        case CosmeticCategory.bungeoppang:
          expect(sizeOf(image), (64.0, 48.0), reason: d.id);
        case CosmeticCategory.avatar:
          expect(sizeOf(image),
              (AvatarLook.size.width, AvatarLook.size.height),
              reason: d.id);
        case CosmeticCategory.stall:
          break;
      }
      if (d.slot == CosmeticSlot.background) {
        expect(sizeOf(image),
            (NightStallPainter.sceneSize.width, NightStallPainter.sceneSize.height),
            reason: d.id);
      }
      if (d.slot == CosmeticSlot.decoration) {
        expect(NightStallPainter.decorationAt, contains(d.id), reason: d.id);
      }
    }
  });

  test('모든 맛·무늬 조합과 피부톤별 손 이미지가 있다', () {
    for (final flavor
        in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.fish)) {
      for (final pattern
          in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.pattern)) {
        final image = PixelSprites.fish(flavor.id, pattern.id);
        expect(image, isNotNull, reason: '${flavor.id}@${pattern.id}');
        expect(sizeOf(image), (64.0, 48.0));
      }
    }
    for (final skin
        in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.skin)) {
      expect(sizeOf(PixelSprites.hands(skin.id)),
          (AvatarLook.size.width, AvatarLook.size.height),
          reason: skin.id);
    }
  });

  test('카운터와 모든 아이콘 도트 이미지가 있다', () {
    expect(PixelSprites.counter(), isNotNull);
    expect(PixelSprites.counter(snow: true), isNotNull);
    for (final name in PixelSprites.iconNames) {
      expect(PixelSprites.icon(name), isNotNull, reason: name);
    }
  });

  test('사장님은 화로 오른쪽, 카운터 뒤에 상반신만 보인다', () {
    const at = NightStallPainter.avatarAt;
    expect(at.dx, greaterThanOrEqualTo(NightStallPainter.stoveAt.dx + 80));
    expect(at.dx + AvatarLook.size.width,
        lessThanOrEqualTo(NightStallPainter.sceneSize.width));
    expect(at.dy, lessThan(NightStallPainter.counterTop));
    expect(at.dy + AvatarLook.size.height,
        greaterThan(NightStallPainter.counterTop));
  });
}
