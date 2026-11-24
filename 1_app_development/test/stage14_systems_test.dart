import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';

Iterable<CosmeticDefinition> inSlot(CosmeticSlot slot) =>
    cosmeticDefinitions.where((d) => d.slot == slot);

void main() {
  group('날씨', () {
    test('배경마다 날씨가 있고, 어느 시각이든 예외 없이 그린다', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      for (final bg in inSlot(CosmeticSlot.background)) {
        final weather = weatherFor(bg.id);
        expect(weather, isNotNull, reason: bg.id);
        for (final t in [0.0, 1.7, 3600.0]) {
          for (final size in const [Size(360, 800), Size(412, 915)]) {
            WeatherPainter(weather!, t).paint(canvas, size);
          }
        }
      }
    });

  });

  test('대체 그림은 실제 꾸미기 ID만 가리키고, 기본 차림은 언제나 그릴 수 있다', () {
    final ids = cosmeticDefinitions.map((d) => d.id).toSet();
    expect(ids.containsAll(PixelSprites.artStandIns.keys), isTrue);
    expect(ids.containsAll(PixelSprites.artStandIns.values), isTrue);
    // Every default avatar item is drawn by the base or its own layer, so
    // the wardrobe never hides what a new vendor wears.
    for (final character in ['girl', 'boy']) {
      for (final e in defaultCosmetics.entries) {
        if (e.key.category != CosmeticCategory.avatar) continue;
        expect(PixelSprites.avatarArtReady(character, e.key, e.value), isTrue,
            reason: '$character ${e.value}');
      }
    }
  });

  test('그림이 없는 예전 배경은 폴더의 시안 배경을 빌려 쓴다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PixelSprites.load();
    for (final id in ['clear', 'rain', 'autumn', 'snowday', 'snow', 'cherry',
        'night', 'dusk', 'forest', 'seaside']) {
      expect(PixelSprites.cosmetic(CosmeticSlot.background, id), isNotNull,
          reason: id);
    }
    for (final character in ['girl', 'boy']) {
      expect(PixelSprites.avatarBase(character), isNotNull, reason: character);
    }
  });



}
