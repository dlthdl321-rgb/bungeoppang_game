import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../avatar_atlas.dart';
import '../avatar_rig_config.dart';
import '../avatar_v2.dart';
import '../avatar_v2_atlas.dart';
import '../cosmetic_config.dart';
import 'pixel_sprites.dart';

/// What the vendor wears: one id per avatar slot.
class AvatarLook {
  final String character, skin, hair, top, bottom, shoes, outfit, hat;
  final String accessory, tool;

  const AvatarLook(
      {this.character = 'girl',
      this.skin = 'skin1',
      this.hair = 'long',
      this.top = 'tee',
      this.bottom = 'shorts',
      this.shoes = 'flats',
      this.outfit = 'apron',
      this.hat = 'nohat',
      this.accessory = 'noacc',
      this.tool = 'tongs'});
  factory AvatarLook.of(String Function(CosmeticSlot) equipped) => AvatarLook(
      character: equipped(CosmeticSlot.character),
      skin: equipped(CosmeticSlot.skin),
      hair: equipped(CosmeticSlot.hair),
      top: equipped(CosmeticSlot.top),
      bottom: equipped(CosmeticSlot.bottom),
      shoes: equipped(CosmeticSlot.shoes),
      outfit: equipped(CosmeticSlot.outfit),
      hat: equipped(CosmeticSlot.hat),
      accessory: equipped(CosmeticSlot.accessory),
      tool: equipped(CosmeticSlot.tool));

  /// Size of the vendor in scene units. The front rig is the 280x520
  /// canvas ([rigFrontCanvas]) drawn into this box.
  static const size = Size(56, 104);

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// The item worn in [slot] (only the slots with a layer). A hat that
  /// cannot go over the hair (26번 3차 AV3, [hairHatClash]) is not drawn.
  String worn(CosmeticSlot slot) => switch (slot) {
        CosmeticSlot.hair => hair,
        CosmeticSlot.top => top,
        CosmeticSlot.bottom => bottom,
        CosmeticSlot.shoes => shoes,
        CosmeticSlot.outfit => outfit,
        CosmeticSlot.hat => wearableHat(hair, hat),
        CosmeticSlot.accessory => accessory,
        CosmeticSlot.tool => tool,
        _ => defaultCosmetics[slot]!,
      };

  /// Draws the vendor from the front with its top-left at [at], in scene
  /// units. [lift] (0..1) hops the vendor and raises the tool for a tap;
  /// [face] picks eye and mouth frames ([AvatarMotion.frames]); [flip]
  /// mirrors the whole vendor to face the other way.
  void paint(Canvas canvas, Offset at,
      {double lift = 0,
      Map<String, String> face = const {},
      bool flip = false,
      bool proud = false}) {
    const scale = 56 / 280; // scene units per rig pixel
    final hop = (lift * 2).roundToDouble(), raise = (lift * 3).roundToDouble();
    AvatarRig(character, frontPose,
            look: this, face: face, flip: flip, proud: proud)
        .paint(
        canvas, _paint,
        at: at.translate(0, -hop), scale: scale, toolLift: raise / scale);
  }

  List<String> get _ids =>
      [character, skin, hair, top, bottom, shoes, outfit, hat, accessory, tool];

  @override
  bool operator ==(Object other) =>
      other is AvatarLook &&
      Iterable.generate(_ids.length).every((i) => other._ids[i] == _ids[i]);

  @override
  int get hashCode => Object.hashAll(_ids);
}

/// Development switch (설정 > 레이어 기준점 보기): outlines every layer and
/// marks the anchors, so misplaced parts show at a glance.
class AvatarRigDebug {
  AvatarRigDebug._();
  static final show = ValueNotifier<bool>(false);
}

/// One picture placed on the rig.
class RigSprite {
  final String asset;
  final ui.Image image;
  final RigLayer layer;
  final RigPlacement placement;

  /// Rig point the picture hangs on.
  final Offset anchor;

  /// Picture point that lands on [anchor] (before the placement nudge).
  final Offset pivot;

  /// Where the picture's top-left sits in its own (untrimmed) canvas.
  final Offset trim;

  /// Masks erased from this picture alone (v2: the worn hat's hairmask on
  /// the hair layer), drawn with it in a group of its own.
  final List<RigSprite> erase;
  const RigSprite(this.asset, this.image, this.layer, this.placement,
      this.anchor, this.pivot, this.trim,
      {this.erase = const []});

  /// The picture's box in rig pixels, ignoring rotation.
  Rect get bounds {
    final s = placement.scale;
    final topLeft = anchor +
        Offset(placement.dx, placement.dy) +
        (trim - pivot) * s;
    return topLeft &
        Size(image.width.toDouble() * s, image.height.toDouble() * s);
  }
}

/// The vendor in one [pose]: the pose's picture, the face frames and, when
/// the pose wears them, every item of [look], sorted back to front.
class AvatarRig {
  final String character;
  final RigPose pose;
  final AvatarLook? look;
  final Map<String, String> face;
  final bool flip;

  /// The share card's proud pose (25번 39번, v2 only): the hanging arms
  /// erased, both arms raised with a bungeoppang, no tool.
  final bool proud;
  const AvatarRig(this.character, this.pose,
      {this.look, this.face = const {}, this.flip = false, this.proud = false});

  /// Size of the pose in rig pixels: the front canvas, or the picture's own.
  Size get size {
    if (pose.view == frontPose.view) {
      return Size(rigFrontCanvas.$1, rigFrontCanvas.$2);
    }
    final base = PixelSprites.byPath(pose.picture(character));
    return base == null
        ? Size.zero
        : Size(base.width.toDouble(), base.height.toDouble());
  }

  /// The skin the pictures are recoloured for.
  String get _skin => look?.skin ?? defaultCosmetics[CosmeticSlot.skin]!;

  /// The pictures to draw, back to front. Missing pictures are left out, so
  /// a face frame without art shows the face as drawn. A picture with a
  /// copy for the worn skin ([rigSkinPicture]) draws that copy.
  List<RigSprite> get sprites =>
      v2 ? _v2Sprites() : _sprites(cuts: false);

  /// Whether this rig draws the v2 vendor (26번 4-7단계): the front pose
  /// wearing items, once every v2 picture is there ([avatarV2On]).
  bool get v2 => avatarV2On && pose.view == frontPose.view && pose.wearsItems;

  /// Masks of the worn items ([rigCutPicture]): drawn over the base to
  /// erase what the items hide, before the hair, the face and the items.
  List<RigSprite> get cuts => v2 ? const [] : _sprites(cuts: true);

  /// The v2 pictures, back to front ([rigV2Order]): the bare base for the
  /// worn skin, its own face frames, then every worn item (the defaults
  /// too). The hat's hairmask goes with the hair layer only.
  List<RigSprite> _v2Sprites() {
    final out = <RigSprite>[];
    final look = this.look ?? const AvatarLook();
    final skin = look.skin;
    RigSprite? make(String asset, RigLayer layer,
        {(double, double)? anchor, List<RigSprite> erase = const []}) {
      final image = PixelSprites.byPath(asset);
      if (image == null) return null;
      final at = anchor ?? (0.0, 0.0);
      final (tx, ty) = image.width == rigFrontCanvas.$1 &&
              image.height == rigFrontCanvas.$2
          ? (0, 0)
          : avatarV2TrimOffsets[asset] ?? (0, 0);
      final (px, py) = avatarV2PartPivots[asset] ?? (0.0, 0.0);
      return RigSprite(asset, image, layer, const RigPlacement(),
          Offset(at.$1, at.$2), Offset(px, py),
          Offset(tx.toDouble(), ty.toDouble()),
          erase: erase);
    }

    void add(String asset, RigLayer layer,
        {(double, double)? anchor, List<RigSprite> erase = const []}) {
      final sprite = make(asset, layer, anchor: anchor, erase: erase);
      if (sprite != null) out.add(sprite);
    }

    // What the worn items leave bare goes from the base: the head beside
    // the hair (26번 3차 H10) or above a hat, a sliver of leg beside slim
    // trousers or boots (26번 3차 AV) - each item's optional
    // `<slot>_<id>_basemask.png` (avatarV2ItemBaseMask, tools/avatar_v2.py).
    final bare = <RigSprite>[
      for (final slot in rigSlotLayers.keys)
        if (!blankCosmetics.contains(look.worn(slot)) &&
            !avatarItemWithdrawn(character, look.worn(slot)))
          if (make(avatarV2ItemBaseMask(character, slot, look.worn(slot)),
                  RigLayer.base)
              case final mask?)
            mask,
    ];
    add(avatarV2Base(character, skin), RigLayer.base, erase: bare);
    for (final channel in rigChannels) {
      final frame = face[channel.id] ?? channel.rest;
      final anchor = avatarV2FaceAnchors[character]?[channel.id];
      if (anchor == null || frame == channel.rest) continue;
      add(avatarV2Feature(character, skin, channel.id, frame), channel.layer,
          anchor: anchor);
    }
    final hat = look.worn(CosmeticSlot.hat);
    final hairMask = blankCosmetics.contains(hat)
        ? null
        : make(avatarV2HairMask(character, hat), RigLayer.hair);
    final posed = proud && avatarV2ProudReady(character, skin);
    for (final MapEntry(key: slot, value: layer) in rigSlotLayers.entries) {
      final id = look.worn(slot);
      if (blankCosmetics.contains(id) || avatarItemWithdrawn(character, id)) {
        continue;
      }
      // The raised hands hold the bungeoppang, not the tool.
      if (posed && slot == CosmeticSlot.tool) continue;
      final main = avatarV2Item(character, slot, id);
      add(main, layer,
          erase: slot == CosmeticSlot.hair && hairMask != null
              ? [hairMask]
              : const []);
      for (final MapEntry(key: half, value: halfLayer)
          in rigItemHalves.entries) {
        // A half drawn in skin (the fingers round a tool, 26번 3차 AV) has
        // a copy per skin tone.
        final plain = main.replaceFirst('.png', '_$half.png');
        final skinned = plain.replaceFirst('.png', '@$skin.png');
        // 26번 3차 AV: the hat presses the hair behind the head too (no
        // back hair standing above a cap). AV3c dropped this for the v1
        // hair art (tools/avatar_v1art.py PONY_TAIL); 4차 병합 keeps the
        // 43~49 art, whose back hair needs it (s26/i4_merge).
        add(PixelSprites.byPath(skinned) != null ? skinned : plain, halfLayer,
            erase: slot == CosmeticSlot.hair && hairMask != null
                ? [hairMask]
                : const []);
      }
    }
    if (posed) {
      // 26번 3차 AV (25번 39번): the hanging arms go from the body and what
      // is worn over them (sleeves, apron, mittens), never from the hair;
      // the raised arms come on top.
      final hide = make(avatarV2ProudHide(character), RigLayer.base)!;
      const hidden = {
        RigLayer.base, RigLayer.top, RigLayer.outfit, RigLayer.accessory,
      };
      for (var i = 0; i < out.length; i++) {
        final s = out[i];
        if (!hidden.contains(s.layer)) continue;
        out[i] = RigSprite(s.asset, s.image, s.layer, s.placement, s.anchor,
            s.pivot, s.trim,
            erase: [...s.erase, hide]);
      }
      add(avatarV2ProudArms(character, skin), RigLayer.front);
      // 26번 3차 AV2 (25번 50번): the worn top's sleeves over the raised
      // arms, so a long-sleeved top does not look sleeveless.
      final top = look.worn(CosmeticSlot.top);
      if (!blankCosmetics.contains(top) && !avatarItemWithdrawn(character, top)) {
        add(avatarV2ProudSleeve(character, top), RigLayer.front);
      }
    }
    final indexed = out.indexed.toList()
      ..sort((a, b) {
        final byLayer = rigV2Order
            .indexOf(a.$2.layer)
            .compareTo(rigV2Order.indexOf(b.$2.layer));
        return byLayer != 0 ? byLayer : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }

  List<RigSprite> _sprites({required bool cuts}) {
    final out = <RigSprite>[], masks = <RigSprite>[];
    void add(String asset, RigLayer layer,
        {(double, double)? anchor, List<RigSprite>? into}) {
      final skinned = rigSkinPicture(asset, _skin);
      final drawn = PixelSprites.byPath(skinned) != null ? skinned : asset;
      final image = PixelSprites.byPath(drawn);
      if (image == null) return;
      final place = rigPlacements[asset] ?? const RigPlacement();
      final at = anchor ??
          (place.anchor == rigOrigin
              ? (0.0, 0.0)
              : pose.anchor(character, place.anchor));
      if (at == null) return;
      final (tx, ty) = image.width == rigFrontCanvas.$1 &&
              image.height == rigFrontCanvas.$2
          ? (0, 0)
          : avatarTrimOffsets[asset] ?? (0, 0);
      final (px, py) = avatarPartPivots[asset] ?? (0.0, 0.0);
      (into ?? out).add(RigSprite(drawn, image, layer, place,
          Offset(at.$1, at.$2), Offset(px, py),
          Offset(tx.toDouble(), ty.toDouble())));
    }

    add(pose.picture(character), RigLayer.base);
    for (final channel in rigChannels) {
      final frame = face[channel.id] ?? channel.rest;
      final anchor = pose.anchor(character, channel.id);
      if (anchor == null) continue;
      // The rest frame is the art itself unless a picture for it exists.
      add(rigFeaturePicture(character, pose.view, channel.id, frame),
          channel.layer,
          anchor: anchor);
    }
    final look = this.look;
    if (look != null && pose.wearsItems) {
      final hatOn = !blankCosmetics.contains(look.worn(CosmeticSlot.hat));
      for (final MapEntry(key: slot, value: layer) in rigSlotLayers.entries) {
        var id = look.worn(slot);
        // 26번 3차 G: v1 hats were cut with the base hair they press, so
        // under a hat the character's own default hair (the boy's short
        // hair) is drawn as the base hair (v1HatHairAsBase).
        if (slot == CosmeticSlot.hair && hatOn &&
            v1HatHairAsBase[character] == id) {
          id = defaultCosmetics[CosmeticSlot.hair]!;
        }
        // Withdrawn items (26번 3차 H10) are drawn as not worn.
        if (blankCosmetics.contains(id) ||
            avatarItemWithdrawn(character, id)) {
          continue;
        }
        final main = PixelSprites.avatarPartPath(character, slot, id);
        add(main, layer);
        add(rigCutPicture(main), RigLayer.base, into: masks);
        for (final MapEntry(key: half, value: halfLayer)
            in rigItemHalves.entries) {
          add(main.replaceFirst('.png', '_$half.png'), halfLayer);
        }
      }
    }
    if (cuts) return masks;
    // Stable: same layer and order keep the order they were added in.
    final indexed = out.indexed.toList()
      ..sort((a, b) {
        final byLayer = a.$2.layer.index.compareTo(b.$2.layer.index);
        if (byLayer != 0) return byLayer;
        final byOrder =
            a.$2.placement.order.compareTo(b.$2.placement.order);
        return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }

  /// Draws the rig with its top-left at [at], [scale] canvas units per rig
  /// pixel. [toolLift] raises the tool layer (rig pixels) for the tap
  /// motion. Each picture goes straight into its destination box (as the
  /// single-picture painters always drew), so a pose without face frames
  /// looks exactly as before.
  void paint(Canvas canvas, Paint paint,
      {Offset at = Offset.zero, double scale = 1, double toolLift = 0}) {
    final size = this.size;
    final sprites = this.sprites, cuts = this.cuts;
    canvas.save();
    if (flip) {
      canvas.translate(2 * at.dx + size.width * scale, 0);
      canvas.scale(-1, 1);
    }
    void draw(RigSprite s, Paint paint) {
      final p = s.placement;
      final lift = s.layer == RigLayer.tool ? toolLift : 0.0;
      final origin =
          at + (s.anchor + Offset(p.dx, p.dy - lift)) * scale;
      final w = s.image.width.toDouble(), h = s.image.height.toDouble();
      final src = Rect.fromLTWH(0, 0, w, h);
      final box = Rect.fromLTWH((s.trim.dx - s.pivot.dx) * scale,
          (s.trim.dy - s.pivot.dy) * scale, w * scale, h * scale);
      if (s.erase.isNotEmpty) {
        // The picture and its masks in a group of their own, so the masks
        // erase only it (v2 hair under a hat), never the body or face.
        canvas.saveLayer(null, Paint());
        draw(RigSprite(s.asset, s.image, s.layer, s.placement, s.anchor,
            s.pivot, s.trim), paint);
        final erase = Paint()
          ..filterQuality = paint.filterQuality
          ..blendMode = BlendMode.dstOut;
        for (final m in s.erase) {
          draw(m, erase);
        }
        canvas.restore();
        return;
      }
      if (p.rotation == 0 && p.scale == 1) {
        canvas.drawImageRect(s.image, src, box.shift(origin), paint);
        return;
      }
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(p.rotation);
      canvas.scale(p.scale);
      canvas.drawImageRect(s.image, src, box, paint);
      canvas.restore();
    }

    // The body goes into a group of its own so the items' masks erase only
    // it; the hair style, the face and the items come after, untouched.
    var i = 0;
    if (cuts.isNotEmpty) {
      canvas.saveLayer(null, Paint());
      for (;
          i < sprites.length &&
              sprites[i].layer.index <= RigLayer.base.index;
          i++) {
        draw(sprites[i], paint);
      }
      final erase = Paint()
        ..filterQuality = paint.filterQuality
        ..blendMode = BlendMode.dstOut;
      for (final s in cuts) {
        draw(s, erase);
      }
      canvas.restore();
    }
    for (; i < sprites.length; i++) {
      draw(sprites[i], paint);
    }
    if (AvatarRigDebug.show.value) {
      canvas.translate(at.dx, at.dy);
      canvas.scale(scale);
      _debug(canvas, size, sprites);
    }
    canvas.restore();
  }

  void _debug(Canvas canvas, Size size, List<RigSprite> sprites) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0;
    canvas.drawRect(Offset.zero & size, line..color = const Color(0xFFFFEB3B));
    for (final s in sprites) {
      canvas.drawRect(
          s.bounds,
          line
            ..color = s.layer == RigLayer.base
                ? const Color(0x99FFFFFF)
                : const Color(0xFF00E5FF));
      final cross = math.max(size.width, size.height) / 60;
      final mark = line..color = const Color(0xFFFF2BD6);
      final at = s.anchor + Offset(s.placement.dx, s.placement.dy);
      canvas.drawLine(at.translate(-cross, 0), at.translate(cross, 0), mark);
      canvas.drawLine(at.translate(0, -cross), at.translate(0, cross), mark);
    }
    // Face anchors even while the face rests (no part drawn there).
    final dot = Paint()..color = const Color(0xFFFF2BD6);
    for (final channel in rigChannels) {
      if (pose.anchor(character, channel.id) case (final x, final y)) {
        canvas.drawCircle(
            Offset(x, y), math.max(size.width, size.height) / 160, dot);
      }
    }
  }
}

/// The vendor alone, fitted into the canvas (wardrobe preview, visitors,
/// friends and ranking rows).
class AvatarPainter extends CustomPainter {
  final AvatarLook look;
  final Map<String, String> face;
  final bool flip;
  AvatarPainter(this.look, {this.face = const {}, this.flip = false})
      : super(repaint: AvatarRigDebug.show);

  @override
  void paint(Canvas canvas, Size size) {
    const art = AvatarLook.size;
    final scale = math.min(size.width / art.width, size.height / art.height);
    canvas.save();
    canvas.translate((size.width - art.width * scale) / 2,
        (size.height - art.height * scale) / 2);
    canvas.scale(scale);
    look.paint(canvas, Offset.zero, face: face, flip: flip);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) =>
      old.look != look || !mapEquals(old.face, face) || old.flip != flip;
}
