import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);

  test('모든 꾸미기에 도트 이미지가 있고 크기가 장면 규격과 맞다', () {
    for (final d in cosmeticDefinitions) {
      if (d.slot == CosmeticSlot.decoration && d.id == 'none') continue;
      final image = PixelSprites.cosmetic(d.slot, d.id);
      expect(image, isNotNull, reason: d.id);
      if (d.slot == CosmeticSlot.fish) {
        expect((image!.width, image.height), (64, 48), reason: d.id);
      }
      if (d.slot == CosmeticSlot.background) {
        expect((image!.width.toDouble(), image.height.toDouble()),
            (NightStallPainter.sceneSize.width, NightStallPainter.sceneSize.height),
            reason: d.id);
      }
      if (d.slot == CosmeticSlot.decoration) {
        expect(NightStallPainter.decorationAt, contains(d.id), reason: d.id);
      }
    }
  });

  test('카운터와 모든 아이콘 도트 이미지가 있다', () {
    expect(PixelSprites.counter(), isNotNull);
    expect(PixelSprites.counter(snow: true), isNotNull);
    for (final name in PixelSprites.iconNames) {
      expect(PixelSprites.icon(name), isNotNull, reason: name);
    }
  });
}
