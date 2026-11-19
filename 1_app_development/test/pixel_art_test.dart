import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_atlas.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/workshop_daily.dart';

// All art comes from the user's folders (concept art and the extra art
// set); avatar items without art are hidden (PixelSprites.avatarArtReady).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);

  (double, double) sizeOf(image) =>
      (image.width.toDouble(), image.height.toDouble());

  test('붕어빵·가게 꾸미기는 모두 그림이 있다', () {
    for (final d in cosmeticDefinitions) {
      if (d.slot.category == CosmeticCategory.avatar) continue; // below
      // Blank items draw nothing; patterns are baked into the fish images.
      if (blankCosmetics.contains(d.id) || d.slot == CosmeticSlot.pattern) {
        expect(PixelSprites.cosmetic(d.slot, d.id), isNull, reason: d.id);
        continue;
      }
      final image = PixelSprites.cosmetic(d.slot, d.id);
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

  test('겨울 행사 장식(25번 32번)은 그림·자리가 있고 판매 목록에 없다', () {
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final events = seasonalEvents(config);
    expect(events.map((e) => e.decoration).toSet(), PixelSprites.eventDecorations.toSet());
    for (final e in events) {
      final image = PixelSprites.cosmetic(CosmeticSlot.decoration, e.decoration);
      expect(image, isNotNull, reason: e.decoration);
      // starlights' width (540 = 180 scene units x decorationScale).
      expect(image!.width, 540, reason: e.decoration);
      expect(NightStallPainter.decorationAt, contains(e.decoration));
      expect(cosmeticDefinitions.where((d) => d.id == e.decoration), isEmpty);
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

  test('사장님: 캐릭터마다 기본 몸과, 꾸미기에 보이는 모든 항목 그림이 같은 캔버스에 놓인다', () {
    const canvas = (280.0, 520.0);
    expect(AvatarLook.size.width / AvatarLook.size.height,
        closeTo(canvas.$1 / canvas.$2, .01));
    // Full canvases sit at (0, 0); trimmed ones at their recorded spot
    // (tools/avatar_layers.py), still inside the canvas.
    void onCanvas(String path, image) {
      final (w, h) = sizeOf(image);
      if ((w, h) == canvas) return;
      final at = avatarTrimOffsets[path];
      expect(at, isNotNull, reason: '$path is trimmed but has no offset');
      expect(at!.$1 + w, lessThanOrEqualTo(canvas.$1), reason: path);
      expect(at.$2 + h, lessThanOrEqualTo(canvas.$2), reason: path);
    }

    // The base figure already wears the default hair, tee, shorts and flats.
    const worn = {'long', 'tee', 'shorts', 'flats'};
    for (final character
        in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.character)) {
      onCanvas('avatar/${character.id}/base.png',
          PixelSprites.avatarBase(character.id));
      for (final d in cosmeticDefinitions.where((d) =>
          d.slot.category == CosmeticCategory.avatar &&
          d.slot != CosmeticSlot.character &&
          d.slot != CosmeticSlot.skin &&
          d.slot != CosmeticSlot.hair)) {
        final image = PixelSprites.avatarPart(character.id, d.slot, d.id);
        if (blankCosmetics.contains(d.id) ||
            worn.contains(d.id) ||
            !PixelSprites.avatarArtReady(character.id, d.slot, d.id)) {
          continue;
        }
        expect(image, isNotNull, reason: '${character.id} ${d.id}');
        onCanvas(PixelSprites.avatarPartPath(character.id, d.slot, d.id),
            image);
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

  test('모든 아이콘에 72×72 그림이 있다 (논리 24×24의 3배)', () {
    for (final name in PixelSprites.iconNames) {
      // The bottom menu's own icons are 96x96 (26번 4-2단계 F10, below).
      if (name.startsWith('nav_')) continue;
      // The stall wardrobe's day/night tiles are 64x64 (26번 4-5단계,
      // 25번 16번 그림).
      final size = name.startsWith('time_') ? 64.0 : 72.0;
      expect(sizeOf(PixelSprites.icon(name)), (size, size), reason: name);
    }
  });

  test('가게 미리보기의 사장님은 화로 오른쪽에 선다', () {
    const at = NightStallPainter.avatarAt;
    expect(at.dx, greaterThanOrEqualTo(NightStallPainter.stoveAt.dx + 80));
    expect(at.dx + AvatarLook.size.width,
        lessThanOrEqualTo(NightStallPainter.sceneSize.width + 1));
    expect(at.dy, lessThan(NightStallPainter.counterTop));
  });

  // 26번 4-2단계 F8: 닫힌 판은 굽는 판과 같은 캔버스, 열린 판은 위 230px에 뚜껑을
  // 세우고 아래 941x470은 빈 굽는 판 그대로(칸 위치가 같다).
  test('닫힌 판·열린 판 그림 4종: 크기, 열린 판 아래는 빈 굽는 판과 같은 픽셀', () async {
    for (final id in ['iron', 'copper', 'castiron', 'golden']) {
      final stove = PixelSprites.cosmetic(CosmeticSlot.stove, id)!;
      final closed = PixelSprites.closedStove(id);
      final open = PixelSprites.openStove(id);
      final empty = PixelSprites.emptyStove(id)!;
      expect(sizeOf(closed), sizeOf(stove), reason: id);
      expect(sizeOf(open), (stove.width.toDouble(),
          stove.height.toDouble() + PixelSprites.openStoveLidRoom), reason: id);
      final o = (await open!.toByteData())!, e = (await empty.toByteData())!;
      final skip = PixelSprites.openStoveLidRoom * open.width * 4;
      var differ = 0;
      for (var i = 0; i < e.lengthInBytes; i += 4) {
        // Only where the empty griddle is drawn (the lid may stand behind
        // its transparent top).
        if (e.getUint8(i + 3) < 255) continue;
        for (var k = 0; k < 4; k++) {
          if (o.getUint8(skip + i + k) != e.getUint8(i + k)) {
            differ++;
            break;
          }
        }
      }
      expect(differ, 0, reason: id);
      // The lid is drawn above the plate's back edge, where the empty
      // griddle is transparent (25번 34번: the low lid lies in the empty
      // griddle's clear top strip, GriddleLidPainter.plateBack).
      var lid = 0;
      final back = (PixelSprites.openStoveLidRoom + GriddleLidPainter.plateBack) * open.width * 4;
      for (var i = 3; i < back; i += 4) {
        if (o.getUint8(i) > 128 && (i < skip || e.getUint8(i - skip) == 0)) lid++;
      }
      expect(lid, greaterThan(open.width * 40), reason: id);
    }
  });

  // 26번 4-2단계 F10: 하단 메뉴 아이콘은 여백을 잘라 96x96을 거의 채운다.
  test('하단 메뉴 아이콘 nav_* 4종은 96x96의 그림이 86~90px', () async {
    for (final name in ['nav_menu', 'nav_skill', 'nav_skins', 'nav_shop']) {
      final img = PixelSprites.icon(name)!;
      expect((img.width, img.height), (96, 96), reason: name);
      final px = (await img.toByteData())!;
      var top = 96, bottom = 0, left = 96, right = 0;
      for (var y = 0; y < 96; y++) {
        for (var x = 0; x < 96; x++) {
          if (px.getUint8((y * 96 + x) * 4 + 3) == 0) continue;
          if (y < top) top = y;
          if (y >= bottom) bottom = y + 1;
          if (x < left) left = x;
          if (x >= right) right = x + 1;
        }
      }
      final longer = bottom - top > right - left ? bottom - top : right - left;
      expect(longer, inInclusiveRange(86, 90), reason: name);
    }
  });
}
