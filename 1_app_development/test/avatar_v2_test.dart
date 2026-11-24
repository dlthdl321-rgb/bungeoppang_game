import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_rig_config.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/avatar_v2_atlas.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

// 26번 4-7단계: the vendor from a bare base (avatar_v2/). Until every v2
// picture is there the v1 vendor is drawn unchanged; the drawing rules
// (layer order, hairmask on the hair only, no _cut, one base per skin) are
// checked here on made-up pictures, so they hold before the art comes.

const _newBottoms = [
  'jeans', 'denimshorts', 'joggers', 'checkskirt', 'cargopants', 'longskirt'
];

// Made-up v2 art: flat colours in known places of the 280x520 canvas.
const _skin = {
  'skin1': Color(0xFFFFD9C0),
  'skin2': Color(0xFFF0C8A8),
  'skin3': Color(0xFFD9A07A),
};
const _hairLong = Color(0xFF6B3A1E), _hairShort = Color(0xFF8B5A2B);
const _shorts = Color(0xFFD8C8A0), _jeans = Color(0xFF7BA4D0);
const _hat = Color(0xFFE04040), _tee = Color(0xFFFFFFFE);
const _apron = Color(0xFF8B5E3C);

Future<ui.Image> _image(void Function(Canvas c) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(280, 520);
}

Future<ui.Image> _rect(Color colour, Rect r) =>
    _image((c) => c.drawRect(r, Paint()..color = colour));

Future<Map<String, ui.Image>> _fakeArt() async {
  final art = <String, ui.Image>{};
  for (final c in ['girl', 'boy']) {
    for (final e in _skin.entries) {
      art[avatarV2Base(c, e.key)] =
          await _rect(e.value, const Rect.fromLTWH(80, 60, 120, 459));
    }
    // Long hair reaches the shoulders; short hair stays on the head. Both
    // rise to row 40, above the hat's top (row 50).
    art[avatarV2Item(c, CosmeticSlot.hair, 'long')] =
        await _rect(_hairLong, const Rect.fromLTWH(70, 40, 140, 200));
    art[avatarV2Item(c, CosmeticSlot.hair, 'short')] =
        await _rect(_hairShort, const Rect.fromLTWH(78, 40, 124, 70));
    art[avatarV2Item(c, CosmeticSlot.bottom, 'shorts')] =
        await _rect(_shorts, const Rect.fromLTWH(85, 300, 110, 60));
    art[avatarV2Item(c, CosmeticSlot.bottom, 'jeans')] =
        await _rect(_jeans, const Rect.fromLTWH(85, 300, 110, 200));
    art[avatarV2Item(c, CosmeticSlot.top, 'tee')] =
        await _rect(_tee, const Rect.fromLTWH(82, 200, 116, 110));
    art[avatarV2Item(c, CosmeticSlot.outfit, 'apron')] =
        await _rect(_apron, const Rect.fromLTWH(100, 220, 80, 120));
    art[avatarV2Item(c, CosmeticSlot.hat, 'beanie')] =
        await _rect(_hat, const Rect.fromLTWH(76, 50, 128, 40));
    // Erases the hair above the hat's lower edge (row 90) in its columns.
    art[avatarV2HairMask(c, 'beanie')] =
        await _rect(Colors.black, const Rect.fromLTWH(74, 0, 132, 90));
  }
  return art;
}

/// The vendor drawn at one canvas pixel per rig pixel, as RGBA bytes.
Future<ByteData> _render(AvatarLook look) async {
  final recorder = ui.PictureRecorder();
  AvatarRig(look.character, frontPose, look: look).paint(
      Canvas(recorder), Paint()..filterQuality = FilterQuality.none);
  final image = await recorder.endRecording().toImage(280, 520);
  return (await image.toByteData())!;
}

Color _at(ByteData px, int x, int y) {
  final i = (y * 280 + x) * 4;
  return Color.fromARGB(px.getUint8(i + 3), px.getUint8(i),
      px.getUint8(i + 1), px.getUint8(i + 2));
}

bool _has(ByteData px, Color colour) {
  for (var i = 0; i < px.lengthInBytes; i += 4) {
    if (px.getUint8(i + 3) == 255 &&
        px.getUint8(i) == (colour.r * 255).round() &&
        px.getUint8(i + 1) == (colour.g * 255).round() &&
        px.getUint8(i + 2) == (colour.b * 255).round()) {
      return true;
    }
  }
  return false;
}

AvatarLook _look(Map<CosmeticSlot, String> worn, {String character = 'girl'}) =>
    AvatarLook.of((s) => s == CosmeticSlot.character
        ? character
        : worn[s] ?? defaultCosmetics[s]!);

void main() {
  tearDown(() {
    debugAvatarV2Override = null;
    debugAvatarV2Files = null;
  });

  group('v2 스위치', () {
    test('필수 그림 목록: 바탕 3 + 노출 아이템 전부(기본 포함) + 머리 뒤 조각, 남녀', () {
      final required = avatarV2Required().toList();
      expect(required.toSet().length, required.length);
      // 25번 문서 23~30번: 110장 (아이콘 31번은 칸 단위로 따로; 집게는 26번 3차
      // H8로 '도구 없음'이 되어 그림이 없다). 26번 3차 AV3: 피부톤 1만 → 106장.
      expect(required.length, 106);
      for (final c in ['girl', 'boy']) {
        for (final s in ['skin1']) {
          expect(required, contains('avatar_v2/$c/base@$s.png'));
        }
        for (final id in ['long', 'tee', 'shorts', 'flats', 'apron',
          ..._newBottoms]) {
          expect(required.where((f) => f.startsWith('avatar_v2/$c/') && f.endsWith('_$id.png')),
              isNotEmpty, reason: '$c $id');
        }
        expect(required, contains('avatar_v2/$c/hair_ponytail_back.png'));
        expect(required, isNot(contains('avatar_v2/$c/hair_short_back.png')));
        for (final blank in ['nohat', 'noapron', 'noacc', 'tongs']) {
          expect(required.any((f) => f.endsWith('_$blank.png')), isFalse);
        }
      }
    });

    test('생성 상수 avatarV2Ready는 실제 파일 목록으로 계산한 값과 같다', () {
      expect(avatarV2Ready, avatarV2ReadyFor(avatarV2Files));
      // 그림이 다 오기 전(2026-11-19): 지금 아바타 그대로.
      if (!avatarV2Ready) expect(avatarV2On, isFalse);
    });

    test('필수 파일이 하나라도 없으면 v2를 켜지 않는다(섞이지 않음)', () {
      final all = avatarV2Required().toSet();
      expect(avatarV2ReadyFor(all), isTrue);
      for (final missing in [
        'avatar_v2/girl/base@skin1.png',
        'avatar_v2/boy/bottom_longskirt.png',
        'avatar_v2/girl/hair_curly_back.png',
      ]) {
        expect(avatarV2ReadyFor({...all}..remove(missing)), isFalse,
            reason: missing);
      }
    });

    test('v2가 꺼져 있으면 정면 아바타는 전부 v1 그림, 새 하의 6종은 숨김', () {
      debugAvatarV2Override = false;
      for (final c in ['girl', 'boy']) {
        final rig = AvatarRig(c, frontPose, look: _look({}, character: c));
        expect(rig.v2, isFalse);
        expect(rig.sprites.every((s) => !s.asset.startsWith('avatar_v2/')),
            isTrue);
        for (final id in _newBottoms) {
          expect(PixelSprites.avatarArtReady(c, CosmeticSlot.bottom, id),
              isFalse, reason: '$c $id');
        }
      }
    });

    test('v2가 켜지면 v2 파일 기준으로 보이고 새 하의도 보인다', () {
      debugAvatarV2Override = true;
      debugAvatarV2Files = avatarV2Required().toSet();
      for (final c in ['girl', 'boy']) {
        for (final d in cosmeticDefinitions.where((d) =>
            d.slot.category == CosmeticCategory.avatar)) {
          // 26번 3차 H8: withdrawn items (the golden tongs) stay hidden.
          expect(PixelSprites.avatarArtReady(c, d.slot, d.id),
              !avatarItemWithdrawn(c, d.id),
              reason: '$c ${d.id}');
        }
      }
      debugAvatarV2Files = {...avatarV2Required()}
        ..remove('avatar_v2/girl/bottom_jeans.png');
      expect(PixelSprites.avatarArtReady('girl', CosmeticSlot.bottom, 'jeans'),
          isFalse);
    });

    test('조리 장면(옆모습)은 v2가 켜져도 지금 그림 그대로', () {
      debugAvatarV2Override = true;
      for (final pose in cookPoses) {
        expect(AvatarRig('girl', pose, look: _look({})).v2, isFalse);
      }
    });
  });

  group('v2 그리기(가짜 그림)', () {
    late Map<String, ui.Image> art;
    setUp(() async {
      art = await _fakeArt();
      art.forEach(PixelSprites.debugPut);
      debugAvatarV2Override = true;
    });
    tearDown(() {
      for (final k in art.keys) {
        PixelSprites.debugPut(k, null);
      }
    });

    test('레이어 순서: 바탕 → 눈·입 → 하의 → 신발 → 상의 → 앞치마 → 머리 → 모자 → 소품 → 도구', () {
      final rig = AvatarRig('girl', frontPose,
          look: _look({CosmeticSlot.hat: 'beanie'}),
          face: const {'eyes': 'closed'});
      expect(rig.v2, isTrue);
      expect(rig.cuts, isEmpty);
      final layers = rig.sprites.map((s) => s.layer).toList();
      final ranks = layers.map(rigV2Order.indexOf).toList();
      expect(ranks, orderedEquals([...ranks]..sort()));
      expect(layers.indexOf(RigLayer.hair),
          greaterThan(layers.indexOf(RigLayer.outfit)));
      expect(layers.indexOf(RigLayer.hat),
          greaterThan(layers.indexOf(RigLayer.hair)));
      // 모자 hairmask는 머리 레이어에만 붙는다.
      for (final s in rig.sprites) {
        expect(s.erase.isNotEmpty, s.layer == RigLayer.hair, reason: s.asset);
      }
    });

    test('피부톤 1 바탕 그림(색 치환 복사본 없음, 26번 3차 AV3: 피부톤 1만)', () async {
      for (final skin in ['skin1']) {
        final rig =
            AvatarRig('boy', frontPose, look: _look({CosmeticSlot.skin: skin}, character: 'boy'));
        expect(rig.sprites.first.asset, 'avatar_v2/boy/base@$skin.png');
        expect(rig.sprites.any((s) => s.asset.contains('@skin') &&
            !s.asset.contains('base@') && !s.asset.contains('face_')), isFalse);
        final px = await _render(_look({CosmeticSlot.skin: skin}, character: 'boy'));
        // 다리(반바지 아래, 바탕만 보이는 곳)가 그 피부색.
        expect(_at(px, 140, 400), _skin[skin]);
      }
    });

    test('속옷 바탕은 상의·하의를 모두 안 입었을 때만, 옷을 입으면 맨 바탕(2026-11-24)', () {
      for (final c in ['girl', 'boy']) {
        final underwear = 'avatar_v2/$c/base_underwear@skin1.png';
        PixelSprites.debugPut(underwear, art['avatar_v2/$c/base@skin1.png']);
        addTearDown(() => PixelSprites.debugPut(underwear, null));
        final dressed = AvatarRig(c, frontPose, look: _look({}, character: c));
        expect(dressed.sprites.first.asset, 'avatar_v2/$c/base@skin1.png');
        expect(dressed.sprites.any((s) => s.asset.contains('base_underwear')), isFalse);
        final topOnly = AvatarRig(c, frontPose,
            look: _look({CosmeticSlot.bottom: 'none'}, character: c));
        expect(topOnly.sprites.first.asset, 'avatar_v2/$c/base@skin1.png');
        final undressed = AvatarRig(c, frontPose,
            look: _look({CosmeticSlot.top: 'none', CosmeticSlot.bottom: 'none'}, character: c));
        expect(undressed.sprites.first.asset, 'avatar_v2/$c/base_underwear@skin1.png');
      }
    });

    testWidgets('G10: 다른 하의를 입으면 반바지 픽셀이 없다', (tester) async {
      await tester.runAsync(() async {
        expect(_has(await _render(_look({})), _shorts), isTrue);
        final px = await _render(_look({CosmeticSlot.bottom: 'jeans'}));
        expect(_has(px, _shorts), isFalse);
        expect(_has(px, _jeans), isTrue);
      });
    });

    testWidgets('G6: 머리를 바꾸면 긴 머리 픽셀이 없다', (tester) async {
      await tester.runAsync(() async {
        final px = await _render(_look({CosmeticSlot.hair: 'short'}));
        expect(_has(px, _hairLong), isFalse);
        expect(_has(px, _hairShort), isTrue);
      });
    });

    testWidgets('G7: 모자 위로 머리가 삐져나오지 않고, 바탕·모자 아래 머리는 남는다',
        (tester) async {
      await tester.runAsync(() async {
        for (final hair in ['long', 'short']) {
          final colour = hair == 'long' ? _hairLong : _hairShort;
          final bare = await _render(_look({CosmeticSlot.hair: hair}));
          expect(_at(bare, 140, 45), colour, reason: '모자 없이 정수리 머리');
          final px = await _render(_look(
              {CosmeticSlot.hair: hair, CosmeticSlot.hat: 'beanie'}));
          // 모자 폭(x 76~203) 안에서 모자 꼭대기(y 50) 위로 머리가 없음.
          // 모자보다 넓은 머리는 옆으로 내려와 보여도 된다.
          for (var y = 0; y < 50; y++) {
            for (var x = 76; x < 204; x++) {
              expect(_at(px, x, y) == colour, isFalse,
                  reason: '$hair ($x, $y): 모자 위 머리');
            }
          }
          expect(_at(px, 140, 70), _hat);
        }
        // 모자 아래(어깨까지 내려온 긴 머리)는 그대로.
        final long = await _render(
            _look({CosmeticSlot.hair: 'long', CosmeticSlot.hat: 'beanie'}));
        expect(_at(long, 72, 150), _hairLong);
        // hairmask는 머리만 지운다: 마스크 안의 바탕(정수리 아래 이마)은 남음.
        final shortHat = await _render(
            _look({CosmeticSlot.hair: 'short', CosmeticSlot.hat: 'beanie'}));
        expect(_at(shortHat, 81, 120), _skin['skin1']);
      });
    });
  });

  test('G4: 피부톤 밝기 skin1 > skin2 > skin3, 새 skin3 = 지금까지의 skin2 색', () {
    final ratios = (jsonDecode(File('tools/avatar_layers.json')
            .readAsStringSync()) as Map<String, dynamic>)['skin']
        as Map<String, dynamic>;
    // tools/avatar_layers.py skin (2026-11-18까지): skin2 비율.
    const oldSkin2 = {
      'girl': [0.9412, 0.7972, 0.6354],
      // 26번 3차 G: the boy's original v1 base is back (the rebuilt one of
      // 3차 H9 is gone), with its original skin copies and ratio.
      'boy': [0.9163, 0.6981, 0.5027],
    };
    for (final c in ['girl', 'boy']) {
      final two = (ratios['$c@skin2'] as List).cast<num>();
      final three = (ratios['$c@skin3'] as List).cast<num>();
      for (var i = 0; i < 3; i++) {
        expect(1 > two[i] && two[i] > three[i], isTrue, reason: '$c $i');
        expect(three[i], closeTo(oldSkin2[c]![i], 0.0001), reason: '$c $i');
        expect(two[i], closeTo((1 + three[i]) / 2, 0.0002), reason: '$c $i');
      }
    }
  });

  group('v2 그림 검사(그림이 들어온 뒤)', () {
    final data = jsonDecode(File('tools/avatar_v2.json').readAsStringSync())
        as Map<String, dynamic>;

    test('바탕 6장: 눈 앵커(v1 자리) 오차 1px 이하, 발바닥은 캔버스 안', () {
      final align = (data['align'] as Map<String, dynamic>?) ?? {};
      for (final MapEntry(:key, :value) in align.entries) {
        if ((value as Map)['state'] != 'ok') continue;
        final err = value['error'] as Map;
        // 26번 3차 AV: the 42번 base stands where the v1 vendor stood (its
        // eyes on the v1 anchors), so its soles are above row 519.
        expect(err['sole'] as num, lessThanOrEqualTo(0), reason: key);
        expect((err['eyes_x'] as num).abs(), lessThanOrEqualTo(1), reason: key);
        expect((err['eyes_y'] as num).abs(), lessThanOrEqualTo(1), reason: key);
      }
      if (avatarV2Ready) {
        expect(align.values.where((v) => (v as Map)['state'] == 'ok').length, 6);
      }
    });

    test('켜진 v2의 아이템 레이어는 모두 규격대로 들어왔다(피부색 경고는 도구 보고서에서 눈으로 확인)', () {
      final items = (data['items'] as Map<String, dynamic>?) ?? {};
      if (!avatarV2Ready) return;
      for (final MapEntry(:key, :value) in items.entries) {
        expect('${(value as Map)['state']}', isNot(startsWith('규격 미달')),
            reason: key);
      }
    });

    test('G3: v2 바탕의 얼굴 좌우 폭 차이 평균 3px 이하', () {
      final audit = (data['faceaudit'] as Map<String, dynamic>?) ?? {};
      for (final MapEntry(:key, :value) in audit.entries) {
        if (!key.contains(' v2 ') || value == null) continue;
        expect(((value as Map)['diff_mean'] as num).abs(), lessThanOrEqualTo(3),
            reason: key);
      }
    });

    test('v2 그림은 모두 280×520 리그 안에 있고 필수 목록 밖 파일은 생성물뿐', () {
      final required = avatarV2Required().toSet();
      for (final f in avatarV2Files) {
        final name = f.split('/').last;
        expect(
            required.contains(f) ||
                name.startsWith('face_') ||
                name.endsWith('_hairmask.png') ||
                name.endsWith('_basemask.png') ||
                // 26번 3차 AV: halves behind / in front of the body (one per
                // skin when drawn in skin) and the share card's proud pose.
                RegExp(r'_(back|front)(@skin\d)?\.png$').hasMatch(name) ||
                name.startsWith('pose_proud_') ||
                // 2026-11-24: the base with its light grey underwear, drawn
                // only when the vendor wears no top and no bottom.
                name.startsWith('base_underwear@'),
            isTrue,
            reason: f);
        final (x, y) = avatarV2TrimOffsets[f] ?? (0, 0);
        expect(x >= 0 && y >= 0 && x < 280 && y < 520, isTrue, reason: f);
      }
      expect(avatarV2FaceAnchors['girl']!['eyes'], (153.5, 155));
      expect(avatarV2FaceAnchors['boy']!['mouth'], (150, 184));
    });
  });
}
