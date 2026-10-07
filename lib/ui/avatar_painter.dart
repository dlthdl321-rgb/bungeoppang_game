import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../avatar_atlas.dart';
import '../avatar_rig_config.dart';
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

  /// The item worn in [slot] (only the slots with a layer).
  String worn(CosmeticSlot slot) => switch (slot) {
        CosmeticSlot.top => top,
        CosmeticSlot.bottom => bottom,
        CosmeticSlot.shoes => shoes,
        CosmeticSlot.outfit => outfit,
        CosmeticSlot.hat => hat,
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
      bool flip = false}) {
    const scale = 56 / 280; // scene units per rig pixel
    final hop = (lift * 2).roundToDouble(), raise = (lift * 3).roundToDouble();
    AvatarRig(character, frontPose, look: this, face: face, flip: flip).paint(
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
  const RigSprite(this.asset, this.image, this.layer, this.placement,
      this.anchor, this.pivot, this.trim);

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
  const AvatarRig(this.character, this.pose,
      {this.look, this.face = const {}, this.flip = false});

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

  /// The pictures to draw, back to front. Missing pictures are left out, so
  /// a face frame without art shows the face as drawn.
  List<RigSprite> get sprites {
    final out = <RigSprite>[];
    void add(String asset, RigLayer layer, {(double, double)? anchor}) {
      final image = PixelSprites.byPath(asset);
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
      out.add(RigSprite(asset, image, layer, place, Offset(at.$1, at.$2),
          Offset(px, py), Offset(tx.toDouble(), ty.toDouble())));
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
      for (final MapEntry(key: slot, value: layer) in rigSlotLayers.entries) {
        final id = look.worn(slot);
        if (blankCosmetics.contains(id)) continue;
        final main = PixelSprites.avatarPartPath(character, slot, id);
        add(main, layer);
        for (final MapEntry(key: half, value: halfLayer)
            in rigItemHalves.entries) {
          add(main.replaceFirst('.png', '_$half.png'), halfLayer);
        }
      }
    }
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
    final sprites = this.sprites;
    canvas.save();
    if (flip) {
      canvas.translate(2 * at.dx + size.width * scale, 0);
      canvas.scale(-1, 1);
    }
    for (final s in sprites) {
      final p = s.placement;
      final lift = s.layer == RigLayer.tool ? toolLift : 0.0;
      final origin =
          at + (s.anchor + Offset(p.dx, p.dy - lift)) * scale;
      final w = s.image.width.toDouble(), h = s.image.height.toDouble();
      final src = Rect.fromLTWH(0, 0, w, h);
      final box = Rect.fromLTWH((s.trim.dx - s.pivot.dx) * scale,
          (s.trim.dy - s.pivot.dy) * scale, w * scale, h * scale);
      if (p.rotation == 0 && p.scale == 1) {
        canvas.drawImageRect(s.image, src, box.shift(origin), paint);
        continue;
      }
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(p.rotation);
      canvas.scale(p.scale);
      canvas.drawImageRect(s.image, src, box, paint);
      canvas.restore();
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
