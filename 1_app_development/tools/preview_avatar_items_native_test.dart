// 2026-11-24 꾸미기 검수용(동작 시험 아님): 아이템마다 기본 차림 위에 하나씩 입힌 사장님을
// 리그 원래 크기(280×520, 1칸 = 1px)로 그린다. 확대는 python으로.
//   flutter test tools/preview_avatar_items_native_test.dart
// 결과: build/avatar_items_native/<girl|boy>/<slot>_<id>.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_rig_config.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('아이템별 원래 크기 그림', () async {
    await PixelSprites.load();
    const v1 = bool.fromEnvironment('AVATAR_V1');
    if (v1) debugAvatarV2Override = false;
    for (final c in ['girl', 'boy']) {
      String Function(CosmeticSlot) look(Map<CosmeticSlot, String> worn) =>
          (s) => s == CosmeticSlot.character
              ? c
              : worn[s] ??
                  (s == CosmeticSlot.hair
                      ? characterDefaultHair[c]!
                      : defaultCosmetics[s]!);
      final items = <(String, Map<CosmeticSlot, String>)>[
        ('_default', {}),
        ('_undressed', {CosmeticSlot.top: 'none', CosmeticSlot.bottom: 'none'}),
        for (final d in cosmeticDefinitions)
          if (d.slot.category == CosmeticCategory.avatar &&
              d.slot != CosmeticSlot.character &&
              d.slot != CosmeticSlot.skin)
            ('${d.slot.name}_${d.id}', {d.slot: d.id}),
      ];
      for (final (name, worn) in items) {
        final recorder = ui.PictureRecorder();
        final lk = AvatarLook.of(look(worn));
        AvatarRig(c, frontPose, look: lk).paint(
            Canvas(recorder), Paint()..filterQuality = FilterQuality.none);
        final image = await recorder.endRecording().toImage(280, 520);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/avatar_items_native${v1 ? '_v1' : ''}/$c/$name.png');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(bytes!.buffer.asUint8List());
      }
    }
  });
}
