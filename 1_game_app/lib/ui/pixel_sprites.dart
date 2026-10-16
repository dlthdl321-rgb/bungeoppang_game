import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../avatar_rig_config.dart';
import '../cosmetic_config.dart';

/// Pixel-art images in assets/images, drawn by tools/draw_pixel_assets.py
/// (or AI art cleaned up by tools/pixelize.py into the same paths).
///
/// [load] decodes them once before the first frame so painters can draw
/// synchronously. A file that is missing or fails to decode is skipped.
/// Always drawn nearest-neighbour so pixels stay crisp at any scale.
class PixelSprites {
  PixelSprites._();

  static const iconNames = [
    'shop',
    'skins',
    'records',
    'share',
    'daily',
    'achievements',
    'settings',
    'leaderboard',
    'star',
    'butter',
    // Extra art (이미지/이미지 raw, 이미지생성프롬프트_통합 부록 S3, E1, E2).
    'bun',
    'coin',
    'title',
    'prestige',
    'levelup',
    'mission',
    'weekly',
    'invite',
    'combo',
    'lock',
    'check',
    'warning',
    'theme',
    'skill',
    'tab_tap',
    'tab_auto',
    'buy10',
    'tab_hair',
    'tab_outfit',
    'tab_acc',
    'tab_fish',
    'tab_stall',
    'tab_gear',
    // Settings, sheets and the menu (추가 생성 이미지, stage 3).
    'back',
    'bgm',
    'sfx',
    'vibration',
    'volume',
    'save',
    'menu',
  ];

  /// Effects in assets/images/fx: a tiny bungeoppang for tap particles
  /// (12x9), a 4-point sparkle (7x7), two fairy frames (24x24, 160 ms each)
  /// and a golden butter shine over the 96x72 centre bungeoppang.
  static const fxNames = [
    'minifish',
    'sparkle',
    'fairy_up',
    'fairy_down',
    'butter_glow',
  ];

  /// Screen art in assets/images/ui: the wardrobe preview's stall interior
  /// (120x72), the offline reward bag (64x48) and the small fish beside
  /// panel titles (16x12).
  static const uiNames = ['wardrobe_bg', 'offline', 'title_fish'];

  /// Weekly challenge banners in assets/images/event (160x48), one per
  /// season of weekly_config.dart.
  static const seasonBanners = ['spring', 'summer', 'autumn', 'winter'];

  /// Coloured glass for the stall post lamps (`stall/postlamp_<colour>.png`,
  /// the same 9x14 as stall/postlamp.png).
  static const postlampColors = ['rose', 'mint', 'lilac'];

  /// Characters with concept cooking frames (assets/images/cook/
  /// `<character>_1..6.png`, 04_조리프레임 as drawn: 준비, 반죽, 닫기, 굽기,
  /// 꺼내기, 포장).
  // The concept frames wear fixed clothes; cooking frames that follow the
  // wardrobe need new art (오늘의붕어빵_이미지생성프롬프트_통합 §6).
  static const cookCharacters = ['girl'];
  static const cookFrameCount = 6;

  static final _images = <String, ui.Image>{};
  static Future<void>? _loading;
  static final _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Null for blank items, for patterns (baked into the fish images, see
  /// [fish]) and for the character and hair, whose art depends on each
  /// other (see [face] and [hair]).
  static String? _cosmeticPath(CosmeticDefinition d) =>
      blankCosmetics.contains(d.id)
          ? null
          : switch (d.slot) {
              CosmeticSlot.fish => 'assets/images/fish/${d.id}.png',
              CosmeticSlot.pattern ||
              CosmeticSlot.character ||
              CosmeticSlot.hair =>
                null,
              CosmeticSlot.topping => 'assets/images/topping/${d.id}.png',
              // The vendor's art depends on the character: see
              // [avatarBase] and [avatarPart].
              CosmeticSlot.skin ||
              CosmeticSlot.top ||
              CosmeticSlot.bottom ||
              CosmeticSlot.shoes ||
              CosmeticSlot.outfit ||
              CosmeticSlot.hat ||
              CosmeticSlot.accessory ||
              CosmeticSlot.tool =>
                null,
              CosmeticSlot.background => 'assets/images/bg/${d.id}.png',
              CosmeticSlot.stove => 'assets/images/stove/${d.id}.png',
              CosmeticSlot.decoration => 'assets/images/deco/${d.id}.png',
              CosmeticSlot.time => null,
              // amberlamp is the original stall/postlamp.png; the others
              // are stall/postlamp_<colour>.png ([postlampColors]).
              CosmeticSlot.lamp => d.id == defaultCosmetics[CosmeticSlot.lamp]
                  ? _stallPartPath('postlamp')
                  : _stallPartPath(
                      'postlamp_${d.id.substring(0, d.id.length - 'lamp'.length)}'),
            };

  static String _fishPath(String flavor, String pattern) =>
      'assets/images/fish/$flavor${pattern == defaultCosmetics[CosmeticSlot.pattern] ? '' : '@$pattern'}.png';

  /// The vendor, cut from the concept sheets by tools/concept_avatar.py:
  /// `avatar/<character>/base.png` (body, face, default hair and clothes)
  /// and `avatar/<character>/<slot>_<id>.png`, placed on one 280x520
  /// canvas. tools/avatar_layers.py trims their empty margins and records
  /// where each sat ([avatarTrimOffsets]).
  static String _avatarPath(String character, String layer) =>
      'assets/images/avatar/$character/$layer.png';

  /// [avatarPart]'s file, relative to assets/images (the rig's key).
  static String avatarPartPath(String character, CosmeticSlot slot, String id) =>
      'avatar/$character/${slot.name}_$id.png';

  static String _skillPath(String id) => 'assets/images/skills/$id.png';

  static String _stallPartPath(String part) => 'assets/images/stall/$part.png';

  /// The stall frame around the screen (see StallFramePainter).
  static const stallParts = ['awning', 'post', 'postlamp'];

  /// Skill ids with art: tap_1..16 and auto_1..16 (tools/art_icons.py).
  static final skillIds = [
    for (final kind in const ['tap', 'auto'])
      for (var i = 1; i <= 16; i++) '${kind}_$i'
  ];

  static Iterable<CosmeticDefinition> _slot(CosmeticSlot slot) =>
      cosmeticDefinitions.where((d) => d.slot == slot);

  static Iterable<String> get _paths sync* {
    for (final d in cosmeticDefinitions) {
      final path = _cosmeticPath(d);
      if (path != null) yield path;
    }
    for (final flavor in _slot(CosmeticSlot.fish)) {
      for (final pattern in _slot(CosmeticSlot.pattern)) {
        yield _fishPath(flavor.id, pattern.id);
      }
    }
    for (final character in _slot(CosmeticSlot.character)) {
      yield _avatarPath(character.id, 'base');
      for (final d in cosmeticDefinitions) {
        if (d.slot.category == CosmeticCategory.avatar &&
            !blankCosmetics.contains(d.id)) {
          yield _avatarPath(character.id, '${d.slot.name}_${d.id}');
          // An item's back and front halves (rigItemHalves), when drawn.
          for (final half in rigItemHalves.keys) {
            yield _avatarPath(character.id, '${d.slot.name}_${d.id}_$half');
          }
        }
      }
      // Eye and mouth frames for every view, rest frames included (they
      // may be drawn one day; today the art's own face is the rest).
      for (final view in const ['front', 'side']) {
        for (final channel in rigChannels) {
          for (final frame in channel.frames) {
            yield 'assets/images/'
                '${rigFeaturePicture(character.id, view, channel.id, frame)}';
          }
        }
      }
    }
    yield* skillIds.map(_skillPath);
    yield 'assets/images/stall/counter.png';
    yield 'assets/images/stall/counter_snow.png';
    for (final part in stallParts) {
      yield _stallPartPath(part);
    }
    for (final name in iconNames) {
      yield 'assets/images/icons/$name.png';
    }
    for (final colour in postlampColors) {
      yield _stallPartPath('postlamp_$colour');
    }
    yield* fxNames.map((n) => 'assets/images/fx/$n.png');
    yield* uiNames.map((n) => 'assets/images/ui/$n.png');
    yield* seasonBanners.map((n) => 'assets/images/event/$n.png');
    for (final bg in _slot(CosmeticSlot.background)) {
      yield 'assets/images/bg/${bg.id}_night.png';
    }
    for (final c in cookCharacters) {
      for (var i = 1; i <= cookFrameCount; i++) {
        yield 'assets/images/cook/${c}_$i.png';
      }
    }
  }

  static Future<void> load() => _loading ??= _loadAll();

  /// Loads every known path that the app ships. Optional pictures (item
  /// halves, face frames) are only tried when the asset list has them; if
  /// the list cannot be read, every path is tried and misses are skipped.
  static Future<void> _loadAll() async {
    Set<String>? shipped;
    try {
      shipped = (await AssetManifest.loadFromAssetBundle(rootBundle))
          .listAssets()
          .toSet();
    } catch (_) {}
    await Future.wait(_paths
        .toSet()
        .where((p) => shipped == null || shipped.contains(p))
        .map(_loadOne));
  }

  static Future<void> _loadOne(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _images[path] = (await codec.getNextFrame()).image;
    } catch (_) {
      // Missing art: painters leave that layer out.
    }
  }

  /// Stage 14 items whose art is not drawn yet borrow the closest existing
  /// art, so a new default never leaves the scene blank. Remove an entry
  /// once its own file is in assets/images.
  // Only the user's own art is used (concept folder and the extra art set).
  // Every background has its own picture now (추가 생성 이미지, stage 2).
  static const artStandIns = <String, String>{};

  /// Stage 14 items still waiting for their art (오늘의붕어빵_이미지교체
  /// 프롬프트 B4, B8, B9). Until then they draw a stand-in ([artStandIns])
  /// or nothing. Remove an id when its file is added, and add the new
  /// avatar folders (top, bottom, shoes, accessory) to pubspec.yaml.
  static const artPending = {
    // Vendor items the concept sheets do not have (the base figure's own
    // hair, tee, shorts and flats are the defaults).
    'short', 'ponytail', 'curly', 'skin2', 'skin3', 'stripe', 'chefcoat',
    'earmuffs', 'chefhat', 'santa', 'goldtongs', 'redbandana', 'blackcap',
    // The sheets draw these laid flat, not worn.
    'widepants', 'brownpants', 'apron', 'darkapron', 'creamapron',
    'waistapron',
  };

  static ui.Image? cosmetic(CosmeticSlot slot, String id) {
    for (final d in cosmeticDefinitions) {
      if (d.slot == slot && d.id == id) {
        final path = _cosmeticPath(d);
        final image = path == null ? null : _images[path];
        if (image != null || !artStandIns.containsKey(id)) return image;
        return cosmetic(slot, artStandIns[id]!);
      }
    }
    return null;
  }

  /// The bungeoppang of [flavor] embossed with [pattern].
  static ui.Image? fish(String flavor, String pattern) =>
      _images[_fishPath(flavor, pattern)];

  /// [character]'s base figure: body, face, default hair, tee, shorts and
  /// flats.
  static ui.Image? avatarBase(String character) =>
      _images[_avatarPath(character, 'base')];

  /// One worn item on [character]'s canvas, or null when it has no art (a
  /// default the base already wears, or art still to come).
  static ui.Image? avatarPart(String character, CosmeticSlot slot, String id) =>
      _images[_avatarPath(character, '${slot.name}_$id')];

  /// Any loaded picture by its path under assets/images (one decoded copy
  /// per file, shared by every painter), or null when it is not shipped.
  static ui.Image? byPath(String path) => _images['assets/images/$path'];

  /// Icon of an upgrade skill (`tap_1`..`auto_16`).
  static ui.Image? skill(String id) => _images[_skillPath(id)];

  static ui.Image? counter({bool snow = false}) =>
      _images['assets/images/stall/counter${snow ? '_snow' : ''}.png'];

  /// One of [stallParts].
  static ui.Image? stallPart(String part) => _images[_stallPartPath(part)];

  static ui.Image? icon(String name) =>
      _images['assets/images/icons/$name.png'];

  /// The concept cooking frames of [character] in order, or null when it
  /// has none (or they did not load).
  static List<ui.Image>? cookFrames(String character) {
    if (!cookCharacters.contains(character)) return null;
    final frames = [
      for (var i = 1; i <= cookFrameCount; i++)
        _images['assets/images/cook/${character}_$i.png']
    ];
    return frames.contains(null) ? null : frames.cast<ui.Image>();
  }

  /// The picture for [background] by day or at [night], and whether it is
  /// the day picture standing in for a missing night one (draw it darkened).
  static (ui.Image?, bool) sceneBackground(String background, bool? night) {
    if (night == null) {
      return (cosmetic(CosmeticSlot.background, background), false);
    }
    final day = cosmetic(CosmeticSlot.background, dayBackground(background));
    if (!night) return (day, false);
    final id = nightBackground(background);
    final own = cosmeticDefinitions.any((d) => d.id == id)
        ? cosmetic(CosmeticSlot.background, id)
        : _images['assets/images/bg/$id.png'];
    return own != null ? (own, false) : (day, true);
  }

  /// One of [fxNames].
  static ui.Image? fx(String name) => _images['assets/images/fx/$name.png'];

  /// One of [uiNames].
  static ui.Image? screenArt(String name) =>
      _images['assets/images/ui/$name.png'];

  /// The weekly banner of [season], one of [seasonBanners].
  static ui.Image? seasonBanner(String season) =>
      _images['assets/images/event/$season.png'];

  /// The post lamp with [colour] glass ([postlampColors]), or the default
  /// amber lamp for null or an unknown colour.
  static ui.Image? postlamp([String? colour]) =>
      (colour == null ? null : _images[_stallPartPath('postlamp_$colour')]) ??
      stallPart('postlamp');

  /// Draws [image] stretched into [dst]; does nothing if it is not loaded.
  static void draw(Canvas canvas, ui.Image? image, Rect dst) {
    if (image == null) return;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        _paint);
  }

  /// Draws [image] at its native pixel size with its top-left at [at].
  static void drawAt(Canvas canvas, ui.Image? image, Offset at) {
    if (image == null) return;
    draw(canvas, image,
        at & Size(image.width.toDouble(), image.height.toDouble()));
  }
}

/// A square pixel-art icon from assets/images/icons ([PixelSprites.iconNames]).
class PixelIcon extends StatelessWidget {
  final String name;
  final double size;
  const PixelIcon(this.name, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) =>
      PixelImage(PixelSprites.icon(name), size: size);
}

/// Any loaded sprite as a square widget (skill and item icons).
class PixelImage extends StatelessWidget {
  final ui.Image? image;
  final double size;
  const PixelImage(this.image, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size, child: CustomPaint(painter: _IconPainter(image)));
}

/// Any loaded sprite fitted into [width] x [height], centred, keeping its
/// aspect ratio (banners, scenes, effects). Draws nothing until loaded.
class PixelArt extends StatelessWidget {
  final ui.Image? image;
  final double? width, height;
  const PixelArt(this.image, {super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _FitPainter(image)));
}

class _FitPainter extends CustomPainter {
  final ui.Image? image;
  const _FitPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    final scale = (size.width / image.width) < (size.height / image.height)
        ? size.width / image.width
        : size.height / image.height;
    final w = image.width * scale, h = image.height * scale;
    PixelSprites.draw(canvas, image,
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h));
  }

  @override
  bool shouldRepaint(covariant _FitPainter old) => image != old.image;
}

class _IconPainter extends CustomPainter {
  final ui.Image? image;
  const _IconPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) =>
      PixelSprites.draw(canvas, image, Offset.zero & size);

  @override
  bool shouldRepaint(covariant _IconPainter old) => image != old.image;
}
