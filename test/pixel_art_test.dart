import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

// All art comes from the user's folders (concept art and the extra art
// set); items still without art are listed in PixelSprites.artPending.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);

  (double, double) sizeOf(image) =>
      (image.width.toDouble(), image.height.toDouble());

  test('붕어빵·가게 꾸미기는 그림이 있거나 그림 대기 목록에 있다', () {
    for (final d in cosmeticDefinitions) {
      if (d.slot.category == CosmeticCategory.avatar) continue; // below
      // Blank items draw nothing; patterns are baked into the fish images.
      if (blankCosmetics.contains(d.id) || d.slot == CosmeticSlot.pattern) {
        expect(PixelSprites.cosmetic(d.slot, d.id), isNull, reason: d.id);
        continue;
      }
      final image = PixelSprites.cosmetic(d.slot, d.id);
      if (PixelSprites.artPending.contains(d.id)) {
        // A stand-in, if any, is another item's art.
        expect(image == null || PixelSprites.artStandIns.containsKey(d.id),
            isTrue,
            reason: d.id);
        continue;
      }
      expect(image, isNotNull, reason: d.id);
      if (d.slot.category == CosmeticCategory.bungeoppang) {
        // 96x72 sprites or the concept fish at its own resolution: 4:3.
        final (w, h) = sizeOf(image);
        expect(w / h, closeTo(4 / 3, .01), reason: d.id);
      }
      if (d.slot == CosmeticSlot.background) {
        // Concept backgrounds keep their raw size; the scene's aspect.
        final (w, h) = sizeOf(image);
        expect(w / h, closeTo(180 / 400, .02), reason: d.id);
      }
      if (d.slot == CosmeticSlot.decoration) {
        expect(NightStallPainter.decorationAt, contains(d.id), reason: d.id);
      }
    }
  });

  test('팥 붕어빵의 모든 무늬 이미지가 있다', () {
    for (final flavor
        in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.fish)) {
      for (final pattern
          in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.pattern)) {
        final image = PixelSprites.fish(flavor.id, pattern.id);
        expect(image, isNotNull, reason: '${flavor.id}@${pattern.id}');
        final (w, h) = sizeOf(image);
        expect(w / h, closeTo(4 / 3, .01));
      }
    }
  });

  test('사장님: 캐릭터마다 기본 몸과, 대기 목록 밖의 모든 항목 그림이 같은 캔버스다', () {
    const canvas = (280.0, 520.0);
    expect(AvatarLook.size.width / AvatarLook.size.height,
        closeTo(canvas.$1 / canvas.$2, .01));
    // The base figure already wears the default hair, tee, shorts and flats.
    const worn = {'long', 'tee', 'shorts', 'flats'};
    // The sheets have no boy skirt or ribbon.
    const missing = {('boy', 'skirt'), ('boy', 'ribbon')};
    for (final character
        in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.character)) {
      expect(sizeOf(PixelSprites.avatarBase(character.id)), canvas,
          reason: character.id);
      for (final d in cosmeticDefinitions.where((d) =>
          d.slot.category == CosmeticCategory.avatar &&
          d.slot != CosmeticSlot.character &&
          d.slot != CosmeticSlot.skin &&
          d.slot != CosmeticSlot.hair)) {
        final image = PixelSprites.avatarPart(character.id, d.slot, d.id);
        if (blankCosmetics.contains(d.id) ||
            worn.contains(d.id) ||
            PixelSprites.artPending.contains(d.id) ||
            missing.contains((character.id, d.id))) {
          continue;
        }
        expect(image, isNotNull, reason: '${character.id} ${d.id}');
        expect(sizeOf(image), canvas, reason: '${character.id} ${d.id}');
      }
    }
  });

  test('모든 스킬에 정사각형 그림이 있다 (논리 32×32, 더 촘촘한 도트 허용)', () {
    expect(PixelSprites.skillIds.toSet(), upgrades.map((u) => u.id).toSet());
    for (final u in upgrades) {
      final (w, h) = sizeOf(PixelSprites.skill(u.id));
      // Drawn into a fixed box, so any whole multiple of 32 looks the same
      // size on screen (the art may be exported at finer dots).
      expect(w, h, reason: u.id);
      expect(w % 32, 0, reason: u.id);
    }
  });

  test('아이콘은 그림이 있거나 시스템 글리프로 대신한다', () {
    for (final name in PixelSprites.iconNames) {
      expect(
          PixelSprites.icon(name) != null ||
              PixelIcon.glyphs.containsKey(name),
          isTrue,
          reason: name);
    }
  });

  test('가게 미리보기의 사장님은 화로 오른쪽에 선다', () {
    const at = NightStallPainter.avatarAt;
    expect(at.dx, greaterThanOrEqualTo(NightStallPainter.stoveAt.dx + 80));
    expect(at.dx + AvatarLook.size.width,
        lessThanOrEqualTo(NightStallPainter.sceneSize.width + 1));
    expect(at.dy, lessThan(NightStallPainter.counterTop));
  });
}
