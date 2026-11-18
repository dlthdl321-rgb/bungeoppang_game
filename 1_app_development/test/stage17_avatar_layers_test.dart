import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_atlas.dart';
import 'package:todays_bungeoppang/avatar_motion.dart';
import 'package:todays_bungeoppang/avatar_rig_config.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_face.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/boost_effects.dart' show lookFromServer;
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/public_menus.dart';
import 'widget_test.dart' show mountGame;

// Stage 17: the vendor as separate layers (lib/avatar_rig_config.dart),
// eye and mouth frames over the drawn face, and their motions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);
  tearDown(() => AvatarRigDebug.show.value = false);

  AvatarLook dressed(Map<CosmeticSlot, String> worn,
          {String character = 'girl'}) =>
      AvatarLook.of((s) => s == CosmeticSlot.character
          ? character
          : worn[s] ?? defaultCosmetics[s]!);

  // The default apron is drawn since stage 26 4-4.
  const restLook = [
    'avatar/girl/base.png',
    'avatar/girl/outfit_apron.png',
    'avatar/girl/tool_tongs.png'
  ];
  const winter = {
    CosmeticSlot.hat: 'beanie',
    CosmeticSlot.accessory: 'scarf',
    // 26번 4-5단계(G12): the padded vest is a top; an apron goes over it.
    CosmeticSlot.top: 'padding',
    CosmeticSlot.outfit: 'darkapron',
    CosmeticSlot.shoes: 'sneakers',
    CosmeticSlot.bottom: 'skirt',
  };

  Future<Uint8List> pixels(AvatarRig rig) async {
    final recorder = ui.PictureRecorder();
    rig.paint(Canvas(recorder), Paint()..filterQuality = FilterQuality.none);
    final size = rig.size;
    final image = await recorder
        .endRecording()
        .toImage(size.width.ceil(), size.height.ceil());
    return (await image.toByteData())!.buffer.asUint8List();
  }

  group('레이어 구성', () {
    test('기본 차림은 몸 그림·기본 앞치마·집게이고, 얼굴은 그려진 그대로다', () {
      // The base already wears the default hair, tee, shorts and flats.
      final rig = AvatarRig('girl', frontPose, look: dressed({}));
      expect(rig.sprites.map((s) => s.asset), restLook);
    });

    test('아이템은 칸마다 독립 레이어로, 정해진 순서대로 쌓인다', () {
      final sprites =
          AvatarRig('girl', frontPose, look: dressed(winter)).sprites;
      final layers = sprites.map((s) => s.layer.index).toList();
      expect(layers, [...layers]..sort());
      expect(sprites.first.layer, RigLayer.base);
      expect(sprites.last.layer, RigLayer.tool);
      expect(sprites.map((s) => s.asset), contains('avatar/girl/hat_beanie.png'));
    });

    test('한 칸을 바꿔도 다른 레이어는 그대로다', () {
      Set<String> assets(Map<CosmeticSlot, String> worn) =>
          AvatarRig('girl', frontPose, look: dressed(worn))
              .sprites
              .map((s) => s.asset)
              .toSet();
      final before = assets(winter);
      final after = assets({...winter, CosmeticSlot.hat: 'ballcap'});
      expect(before.difference(after), {'avatar/girl/hat_beanie.png'});
      expect(after.difference(before), {'avatar/girl/hat_ballcap.png'});
    });

    test('잘라낸 그림은 원래 캔버스 자리에 놓인다', () {
      for (final s
          in AvatarRig('boy', frontPose, look: dressed(winter, character: 'boy'))
              .sprites) {
        final at = avatarTrimOffsets[s.asset];
        if (at == null) continue;
        expect(s.bounds.topLeft, Offset(at.$1.toDouble(), at.$2.toDouble()),
            reason: s.asset);
      }
    });

    test('입 프레임은 입 기준점에 걸리고, 다른 레이어는 바뀌지 않는다', () {
      final rest = AvatarRig('girl', frontPose, look: dressed(winter)).sprites;
      final talking = AvatarRig('girl', frontPose,
          look: dressed(winter), face: {'mouth': 'wide'}).sprites;
      final mouth = talking.singleWhere((s) => s.layer == RigLayer.mouth);
      expect(mouth.asset, 'parts/girl_front_mouth_wide.png');
      final (ax, ay) = frontPose.anchor('girl', 'mouth')!;
      expect(mouth.bounds.contains(Offset(ax, ay)), isTrue);
      expect(talking.where((s) => s.layer != RigLayer.mouth).map((s) => s.asset),
          rest.map((s) => s.asset));
    });

    test('그림이 없는 프레임·캐릭터·포즈는 그려진 얼굴로 안전하게 대체된다', () {
      final unknownFrame = AvatarRig('girl', frontPose,
          look: dressed({}), face: {'mouth': 'shout', 'eyes': 'wink'});
      expect(unknownFrame.sprites.map((s) => s.asset), restLook);
      // The boy has no cooking frames; nobody has no art at all.
      expect(AvatarRig('boy', cookPoses.first, face: {'mouth': 'wide'}).sprites,
          isEmpty);
      expect(AvatarRig('nobody', frontPose, look: dressed({})).sprites, isEmpty);
    });

    test('측면 조리 프레임 6장 모두 눈·입 기준점이 있고, 머리 위치를 따라간다', () {
      final mouths = <Offset>[];
      for (final pose in cookPoses) {
        final rig = AvatarRig('girl', pose,
            face: {'mouth': 'small', 'eyes': 'closed'});
        final sprites = rig.sprites;
        expect(sprites.map((s) => s.layer),
            [RigLayer.base, RigLayer.eyes, RigLayer.mouth],
            reason: pose.id);
        final frame = Offset.zero & rig.size;
        expect(frame.isEmpty, isFalse, reason: pose.id);
        for (final s in sprites) {
          expect(frame.expandToInclude(s.bounds), frame,
              reason: '${pose.id} ${s.asset} ${s.bounds}');
        }
        mouths.add(sprites.last.anchor);
      }
      // One shared mouth picture, placed per frame (frame 1's head is 30
      // pixels right of frame 2's, measured by tools/avatar_layers.py).
      expect(mouths[0] - mouths[1], const Offset(30, -1));
    });

    test('서버 외형(아이템 id)과 저장된 차림은 같은 레이어가 된다', () {
      final fromServer = lookFromServer({
        for (final e in winter.entries) e.key.name: e.value,
        'character': 'girl',
        'hat': 'not-an-item',
      });
      expect(fromServer, dressed({...winter, CosmeticSlot.hat: 'nohat'}));
    });
  });

  group('그림 매칭 (26번 4-4)', () {
    final avatarItems = cosmeticDefinitions.where((d) =>
        d.slot.category == CosmeticCategory.avatar &&
        d.slot != CosmeticSlot.character);

    test('꾸미기에 보이는 모든 아이템은 남녀 모두 그림이 실제로 바뀐다', () {
      for (final character in ['girl', 'boy']) {
        final rest = AvatarRig(character, frontPose,
                look: dressed({}, character: character))
            .sprites
            .map((s) => s.asset)
            .toList();
        for (final d in avatarItems) {
          if (!PixelSprites.avatarArtReady(character, d.slot, d.id)) continue;
          if (d.id == defaultCosmetics[d.slot]) continue;
          final worn = AvatarRig(character, frontPose,
                  look: dressed({d.slot: d.id}, character: character))
              .sprites
              .map((s) => s.asset)
              .toList();
          expect(worn, isNot(equals(rest)), reason: '$character ${d.id}');
        }
      }
    });

    test('그림이 준비되지 않은 유료 아이템은 숨기고, 무료 선택지는 숨기지 않는다', () {
      for (final character in ['girl', 'boy']) {
        // Flat hats wait for their worn picture (25번 문서 17번).
        for (final id in ['beanie', 'bandana', 'ballcap', 'newsboy']) {
          expect(
              PixelSprites.avatarArtReady(character, CosmeticSlot.hat, id),
              avatarWornLayers.contains('avatar/$character/hat_$id.png'),
              reason: '$character $id');
        }
        for (final d in avatarItems) {
          final ready = PixelSprites.avatarArtReady(character, d.slot, d.id);
          final drawnByBase = blankCosmetics.contains(d.id) ||
              d.id == defaultCosmetics[d.slot];
          if (ready && !drawnByBase && d.slot != CosmeticSlot.skin) {
            expect(
                PixelSprites.byPath(
                    PixelSprites.avatarPartPath(character, d.slot, d.id)),
                isNotNull,
                reason: '$character ${d.id}');
          }
        }
        for (final id in ['skin1', 'skin2', 'skin3', 'long', 'noapron']) {
          final d = cosmeticDefinitions.firstWhere((d) => d.id == id);
          expect(PixelSprites.avatarArtReady(character, d.slot, id), isTrue,
              reason: '$character $id');
        }
      }
    });

    test('생성 목록은 실제 에셋과 같다', () {
      for (final path in avatarArtFiles) {
        expect(PixelSprites.byPath(path), isNotNull, reason: path);
      }
      for (final path in avatarWornLayers) {
        expect(avatarArtFiles, contains(path));
      }
    });

    test('피부톤을 고르면 몸·얼굴 그림이 그 피부색 복사본으로 바뀌고 점점 어두워진다',
        () async {
      for (final character in ['girl', 'boy']) {
        final (mx, my) = frontPose.anchor(character, 'mouth')!;
        final lum = <int>[];
        for (final skin in ['skin1', 'skin2', 'skin3']) {
          final rig = AvatarRig(character, frontPose,
              look: dressed({CosmeticSlot.skin: skin}, character: character));
          expect(rig.sprites.first.asset,
              rigSkinPicture('avatar/$character/base.png', skin));
          final px = await pixels(rig);
          // Cheek skin left of the mouth.
          final i = ((my.round() - 14) * 280 + mx.round() - 22) * 4;
          lum.add(px[i] + px[i + 1] + px[i + 2]);
        }
        expect(lum[0], greaterThan(lum[1]), reason: character);
        expect(lum[1], greaterThan(lum[2]), reason: character);
        final talking = AvatarRig(character, frontPose,
            look: dressed({CosmeticSlot.skin: 'skin3'}, character: character),
            face: {'mouth': 'wide'});
        expect(talking.sprites.map((s) => s.asset),
            contains('parts/${character}_front_mouth_wide@skin3.png'));
      }
    });

    test('머리 모양은 base 바로 위 hair 레이어이고, _cut이 긴 머리를 지운다', () async {
      for (final character in ['girl', 'boy']) {
        final rig = AvatarRig(character, frontPose,
            look: dressed({CosmeticSlot.hair: 'short'}, character: character));
        final hair = rig.sprites[1];
        expect(hair.asset, 'avatar/$character/hair_short.png');
        expect(hair.layer, RigLayer.hair);
        final cut = rig.cuts
            .singleWhere((s) => s.asset.endsWith('hair_short_cut.png'));
        final long = await pixels(AvatarRig(character, frontPose,
            look: dressed({}, character: character)));
        final short = await pixels(rig);
        final mask = (await cut.image.toByteData())!;
        var erased = 0;
        for (var y = 0; y < cut.image.height; y++) {
          for (var x = 0; x < cut.image.width; x++) {
            if (mask.getUint8((y * cut.image.width + x) * 4 + 3) == 0) {
              continue;
            }
            final i = ((cut.trim.dy.round() + y) * 280 +
                        cut.trim.dx.round() +
                        x) *
                    4 +
                3;
            if (long[i] > 0 && short[i] == 0) erased++;
          }
        }
        expect(erased, greaterThan(200), reason: character);
      }
    });

    test('모자 _cut 마스크는 그 모자를 쓸 때만 그려진다', () {
      final plain = AvatarRig('girl', frontPose, look: dressed({}));
      expect(plain.cuts.where((s) => s.asset.contains('/hat_')), isEmpty);
      final chef = AvatarRig('girl', frontPose,
          look: dressed({CosmeticSlot.hat: 'chefhat'}));
      expect(chef.cuts.map((s) => s.asset),
          contains('avatar/girl/hat_chefhat_cut.png'));
    });

    test('앞치마 없음을 고르면 앞치마 레이어가 빠진다', () {
      for (final character in ['girl', 'boy']) {
        final sprites = AvatarRig(character, frontPose,
                look: dressed({CosmeticSlot.outfit: 'noapron'},
                    character: character))
            .sprites;
        expect(sprites.where((s) => s.layer == RigLayer.outfit), isEmpty);
        expect(
            AvatarRig(character, frontPose,
                    look: dressed({}, character: character))
                .sprites
                .map((s) => s.asset),
            contains('avatar/$character/outfit_apron.png'));
      }
    });

    testWidgets('잠긴 아이템도 눌러서 미리 볼 수 있고, 숨긴 아이템은 목록에 없다',
        (tester) async {
      final c = await mountGame(tester, const Size(390, 844));
      final access = CosmeticMenuAccess(
          equipped: c.state.equippedCosmetic,
          owned: (d) => d.free,
          unlocked: (d) => d.free,
          canApply: (_) => false,
          price: (_) => '',
          action: (_) => '잠김',
          apply: (_) async => false,
          // Every hat has its worn art now (25번 문서 17번), so the test
          // hides one itself to check the panel leaves hidden items out.
          listed: (d) =>
              d.id != 'ballcap' &&
              (d.slot.category != CosmeticCategory.avatar ||
                  PixelSprites.avatarArtReady('girl', d.slot, d.id)));
      // 26번 4-5단계: locked items are tried on in the shop's 꾸미기 tab.
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: WardrobePanel(
                  controller: c, access: access, mode: WardrobeMode.shop))));
      await tester.tap(find.byKey(const Key('cosmetic-slot-hat')));
      await tester.pump();
      expect(find.byKey(const Key('preview-ballcap')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('preview-chefhat')));
      await tester.tap(find.byKey(const Key('preview-chefhat')));
      await tester.pump();
      expect(find.text('입어 보는 중'), findsOneWidget);
      final painter = tester
          .widget<CustomPaint>(find.byKey(const Key('preview-avatar-face')))
          .painter! as AvatarPainter;
      expect(painter.look.hat, 'chefhat');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('렌더링', () {
    test('좌우 반전하면 모든 레이어가 함께 거울상이 된다', () async {
      final look = dressed(winter);
      final plain = await pixels(AvatarRig('girl', frontPose, look: look));
      final flipped =
          await pixels(AvatarRig('girl', frontPose, look: look, flip: true));
      const w = 280, h = 520;
      var checked = 0;
      for (var y = 0; y < h; y += 3) {
        for (var x = 0; x < w; x += 3) {
          final a = (y * w + x) * 4, b = (y * w + (w - 1 - x)) * 4;
          // Same pixel, give or take rounding in the mirrored sampling.
          for (var k = 0; k < 4; k++) {
            expect((flipped[b + k] - plain[a + k]).abs(), lessThanOrEqualTo(2),
                reason: '($x, $y)');
          }
          checked++;
        }
      }
      expect(checked, greaterThan(10000));
    });

    test('입만 바꾸면 입 레이어 영역 밖의 픽셀은 그대로다', () async {
      final look = dressed({});
      final rest = await pixels(AvatarRig('girl', frontPose, look: look));
      final rig =
          AvatarRig('girl', frontPose, look: look, face: {'mouth': 'small'});
      final talking = await pixels(rig);
      final box = rig.sprites.singleWhere((s) => s.layer == RigLayer.mouth).bounds;
      var changed = 0;
      for (var y = 0; y < 520; y++) {
        for (var x = 0; x < 280; x++) {
          final i = (y * 280 + x) * 4;
          final same = rest[i] == talking[i] &&
              rest[i + 1] == talking[i + 1] &&
              rest[i + 2] == talking[i + 2] &&
              rest[i + 3] == talking[i + 3];
          if (same) continue;
          changed++;
          expect(box.contains(Offset(x + .5, y + .5)), isTrue,
              reason: '($x, $y) outside the mouth');
        }
      }
      expect(changed, greaterThan(0));
    });

    test('디버그 표시는 개발용 스위치를 켤 때만 그려진다', () async {
      final rig = AvatarRig('girl', frontPose, look: dressed(winter));
      final off = await pixels(rig);
      AvatarRigDebug.show.value = true;
      final on = await pixels(rig);
      expect(on, isNot(equals(off)));
    });
  });

  group('모션', () {
    test('말하기와 눈 깜빡임은 동시에 재생된다', () {
      final m = AvatarMotion(autoBlink: false)
        ..play(talkClip, 0, loops: 0)
        ..play(blinkClip, 50);
      expect(m.frames(60), {'mouth': 'small', 'eyes': 'half'});
      expect(m.frames(100), {'mouth': 'wide', 'eyes': 'closed'});
      // The blink ends by itself (at 200 ms); talking goes on.
      expect(m.frames(210), {'mouth': 'small'});
      m.stop(talkClip.id);
      expect(m.frames(220), isEmpty);
    });

    test('한 클립의 트랙은 같은 시계로 함께 움직인다', () {
      final m = AvatarMotion(autoBlink: false)..play(cheerClip, 1000);
      expect(m.frames(1000), {'eyes': 'closed', 'mouth': 'wide'});
      expect(m.frames(1519), {'eyes': 'closed', 'mouth': 'wide'});
      expect(m.frames(1520), isEmpty);
    });

    test('새 클립은 자기 채널만 가져가고, 나머지 채널은 이어서 재생된다', () {
      final m = AvatarMotion(autoBlink: false)
        ..play(cheerClip, 0)
        ..play(talkClip, 100);
      expect(m.frames(100), {'eyes': 'closed', 'mouth': 'small'});
    });

    test('자동 깜빡임은 정해진 간격 안에서 반복된다', () {
      final m = AvatarMotion(seed: 7);
      var blinks = 0;
      String? last;
      for (var t = 0; t <= 20000; t += 10) {
        final eyes = m.frames(t)['eyes'];
        if (eyes == 'closed' && last != 'closed') blinks++;
        last = eyes;
      }
      expect(blinks, greaterThanOrEqualTo(20000 ~/ blinkGapMs.$2 - 1));
      expect(blinks, lessThanOrEqualTo(20000 ~/ blinkGapMs.$1 + 1));
    });

    testWidgets('차림을 바꿔도 진행 중인 말하기는 끊기지 않는다', (tester) async {
      var hat = 'nohat';
      late StateSetter setOuter;
      final seen = <Map<String, String>>[];
      await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        return AvatarFace(
            talking: true,
            builder: (context, face) {
              seen.add(face);
              return CustomPaint(
                  painter: AvatarPainter(
                      dressed({CosmeticSlot.hat: hat}),
                      face: face));
            });
      }));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(seen.last['mouth'], 'small'); // 200..280 ms
      setOuter(() => hat = 'beanie');
      await tester.pump(const Duration(milliseconds: 60));
      // Still on the same clock: 310 ms is the closed beat, not a restart.
      expect(seen.last['mouth'] ?? 'closed', 'closed');
      await tester.pump(const Duration(milliseconds: 60));
      expect(seen.last['mouth'], 'wide'); // 350..450 ms
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('모션 줄이기에서는 얼굴이 그려진 그대로 멈춘다', (tester) async {
      final seen = <Map<String, String>>[];
      await tester.pumpWidget(AvatarFace(
          animate: false,
          talking: true,
          builder: (context, face) {
            seen.add(face);
            return const SizedBox();
          }));
      await tester.pump(const Duration(seconds: 3));
      expect(seen.every((f) => f.isEmpty), isTrue);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
