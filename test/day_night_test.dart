import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  test('밤낮 선택: 배경 그대로가 기본, 기기 시간은 19시~6시가 밤', () {
    expect(defaultCosmetics[CosmeticSlot.time], 'scenetime');
    final noon = DateTime(2026, 10, 7, 12), late = DateTime(2026, 10, 7, 22);
    expect(isNightTime('scenetime', late), isNull);
    expect(isNightTime('day', late), isFalse);
    expect(isNightTime('night_time', noon), isTrue);
    expect(isNightTime('clock', noon), isFalse);
    expect(isNightTime('clock', late), isTrue);
    expect(isNightTime('clock', DateTime(2026, 10, 7, 5)), isTrue);
  });

  test('밤낮 칸은 무료이고 처음부터 보유하며 수집 대상이 아니다', () {
    final s = GameState.initial(DateTime.utc(2026, 10, 7));
    for (final d in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.time)) {
      expect(d.cost, BigInt.zero, reason: d.id);
      expect(d.collectible, isFalse, reason: d.id);
      expect(s.ownsCosmetic(d), isTrue, reason: d.id);
    }
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
    final clear = PixelSprites.cosmetic(CosmeticSlot.background, 'clear');
    final (image, darken) = PixelSprites.sceneBackground('clear', true);
    // Until bg/clear_night.png arrives.
    expect(image, clear);
    expect(darken, isTrue);
  });
}
