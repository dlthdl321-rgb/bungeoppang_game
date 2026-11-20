import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  // 4차 피드백 g10(ID9, 2026-11-21): '기기 시간 따라' is the default and
  // '배경 그대로' is gone; a save wearing it wears the clock.
  test('밤낮 선택: 기기 시간 따라가 기본, 19시~6시가 밤, 낮·밤 고정', () {
    expect(defaultCosmetics[CosmeticSlot.time], 'clock');
    expect([for (final d in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.time)) d.name],
        ['기기 시간 따라', '낮 고정', '밤 고정']);
    expect(retiredCosmetics['scenetime'], 'clock');
    final noon = DateTime(2026, 10, 7, 12), late = DateTime(2026, 10, 7, 22);
    expect(isNightTime('day', late), isFalse);
    expect(isNightTime('night_time', noon), isTrue);
    expect(isNightTime('clock', noon), isFalse);
    expect(isNightTime('clock', late), isTrue);
    expect(isNightTime('clock', DateTime(2026, 10, 7, 5)), isTrue);
  });

  test('밤낮 칸은 수집 대상이 아니고, 예전 계정 저장의 배경 그대로는 기기 시간이 된다', () {
    final s = GameState.initial(DateTime.utc(2026, 10, 7));
    expect(s.equippedCosmetic(CosmeticSlot.time), 'clock');
    for (final d in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.time)) {
      expect(d.collectible, isFalse, reason: d.id);
    }
    final json = s.toJson();
    final wardrobe = json['wardrobe'] as Map<String, dynamic>;
    wardrobe['owned'] = [...wardrobe['owned'] as List, 'scenetime'];
    (wardrobe['equipped'] as Map)['time'] = 'scenetime';
    final restored = GameState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
    expect(restored.equippedCosmetic(CosmeticSlot.time), 'clock');
    expect(restored.wardrobe.owned.contains('scenetime'), isFalse);
  });

  test('눈 테마는 낮(눈 오는 낮)·밤(겨울밤) 그림이 짝이고, 밤 그림이 없으면 낮 그림을 어둡게 쓴다',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PixelSprites.load();
    final snowDay = PixelSprites.cosmetic(CosmeticSlot.background, 'snowday');
    final snowNight = PixelSprites.cosmetic(CosmeticSlot.background, 'snow');
    expect(PixelSprites.sceneBackground('snowday', true), (snowNight, false));
    expect(PixelSprites.sceneBackground('snow', false), (snowDay, false));
    expect(PixelSprites.sceneBackground('snow', null), (snowNight, false));
    // Four seasons have their own night picture (bg/<id>_night.png).
    for (final id in ['clear', 'rain', 'autumn', 'cherry']) {
      final (image, darken) = PixelSprites.sceneBackground(id, true);
      expect(image, isNotNull, reason: id);
      expect(image, isNot(PixelSprites.cosmetic(CosmeticSlot.background, id)),
          reason: id);
      expect(darken, isFalse, reason: id);
    }
    // 야간 골목 is already night.
    final night = PixelSprites.cosmetic(CosmeticSlot.background, 'night');
    expect(PixelSprites.sceneBackground('night', true), (night, false));
    // Without night art the day picture is darkened.
    final dusk = PixelSprites.cosmetic(CosmeticSlot.background, 'dusk');
    expect(PixelSprites.sceneBackground('dusk', true), (dusk, true));
  });
}
