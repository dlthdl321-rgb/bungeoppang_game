import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../avatar_atlas.dart';
import '../avatar_rig_config.dart';
import '../avatar_v2.dart';
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
    // The bottom menu's icons cut to fill 96x96 (26번 4-2단계 F10,
    // tools/fit_nav_icons.py).
    'nav_menu',
    'nav_skill',
    'nav_skins',
    'nav_shop',
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
    // 황금붕어빵력 (25번 18번, 26번 4-3단계; lib/ui/currency_amount.dart).
    'gold_bun',
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
    // Settings, sheets and the menu (3.3_additional_character_and_background_images, stage 3).
    'back',
    'bgm',
    'sfx',
    'vibration',
    'volume',
    'save',
    'menu',
    // The wardrobe's day/night tiles (25번 16번, 26번 4-5단계).
    'time_scenetime',
    'time_day',
    'time_night',
    'time_clock',
  ];

  /// Effects in assets/images/fx: a tiny bungeoppang for tap particles
  /// (12x9), three twinkle frames with no outline (32x32, 25번 12번 →
  /// 26번 4단계 F11, ui/sparkle_art.dart), two fairy frames (24x24, 160 ms
  /// each) and a golden butter shine over the 96x72 centre bungeoppang.
  static const fxNames = [
    'minifish',
    'sparkle_1',
    'sparkle_2',
    'sparkle_3',
    'fairy_up',
    'fairy_down',
    'butter_glow',
    // Special bungeoppang making (25번 필요한 그림 4·5번, tools/apply_25_art.py):
    // a 32x48 spilled drip per paste (top centre on the fish's edge) and the
    // 512x512 flip guide ring and its full honey ring (centre 256, radius 236).
    'overflow_batter',
    'overflow_redbean',
    'overflow_custard',
    'overflow_cocoa',
    'flip_ring',
    'flip_ring_fill',
  ];

  /// Piping bags in assets/images/cook (128x192, 25번 필요한 그림 2번):
  /// `piping_bag_<paste>` and the squeezing `piping_bag_<paste>_squeeze`,
  /// paste = batter or a flavor. The paste under the nozzle touches
  /// [pipingBagTip], where the finger is.
  static const pipingPastes = ['batter', 'redbean', 'custard', 'cocoa'];
  static const pipingBagTip = Offset(64, 188);

  /// Screen art in assets/images/ui: the wardrobe preview's stall interior
  /// (120x72), the offline reward bag (64x48) and the fish beside window
  /// titles (96x72, 25번 35번: not in the app until redrawn, 시안 확인 2차 —
  /// titles show none meanwhile), the big padlock of locked things
  /// (128x128, 25번 13번, lib/ui/lock_overlay.dart), the skill window's
  /// 'LEVEL UP' button, and the feature introduction cards' pictures
  /// (160x120, 25번 22번; until drawn the card shows an icon).
  static const uiNames = ['wardrobe_bg', 'offline', 'title_fish', 'lock_badge',
    // The wardrobe preview's room without the counter (1440x864, 25번 11번,
    // 26번 4-5단계); wardrobe_bg stays for the cooking scene.
    'wardrobe_room',
    // The skill window's 'LEVEL UP' word button, lit and dark (108x72, drawn
    // 54x36; temporary art by tools/make_levelup_button.py until 25번 33번).
    'levelup', 'levelup_off',
    'intro_skills', 'intro_griddle', 'intro_collection', 'intro_recipes', 'intro_special_orders',
    'intro_fish_cosmetics', 'intro_freshness', 'intro_stall_cosmetics',
    // The first-run screens' winter stall illustration (25번 H-A-1, 26번 3차
    // H2); until drawn they use the lowered snow background.
    'first_run'];

  /// Weekly challenge banners in assets/images/event (160x48), one per
  /// season of weekly_config.dart.
  static const seasonBanners = ['spring', 'summer', 'autumn', 'winter'];

  /// The wardrobe's lamp tiles: the whole post lamp (64x96,
  /// `stall/lamp_<colour>.png`, 25번 16번).
  static const lampTileColours = ['amber', 'rose', 'mint', 'lilac'];

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

  /// The big iron mold of the home stage, one picture per cooking step
  /// (assets/images/mold, tools/make_home_stage_art.py). Each is drawn
  /// around fish/redbean.png, so the fish fits its cavity.
  static const moldNames = [
    'empty',
    'batter',
    'filling_redbean',
    'filling_custard',
    'filling_cocoa',
    'batter_top',
    'closed',
  ];

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
      // Every picture also in each skin's recoloured copy, when made.
      Iterable<String> skinned(String path) sync* {
        for (final skin in _slot(CosmeticSlot.skin)) {
          yield 'assets/images/${rigSkinPicture(path, skin.id)}';
        }
      }

      yield* skinned('avatar/${character.id}/base.png');
      for (final d in cosmeticDefinitions) {
        if (d.slot.category == CosmeticCategory.avatar &&
            !blankCosmetics.contains(d.id)) {
          final main = avatarPartPath(character.id, d.slot, d.id);
          yield* skinned(main);
          // The worn item's mask (rigCutPicture) and its back and front
          // halves (rigItemHalves), when drawn.
          yield 'assets/images/${rigCutPicture(main)}';
          for (final half in rigItemHalves.keys) {
            yield* skinned(main.replaceFirst('.png', '_$half.png'));
          }
        }
      }
      // Eye and mouth frames for every view, rest frames included (they
      // may be drawn one day; today the art's own face is the rest).
      for (final view in const ['front', 'side']) {
        for (final channel in rigChannels) {
          for (final frame in channel.frames) {
            yield* skinned(
                rigFeaturePicture(character.id, view, channel.id, frame));
          }
        }
      }
    }
    // 26번 4-7단계: the v2 vendor's pictures (tools/avatar_v2.py).
    for (final f in avatarV2Shipped) {
      yield 'assets/images/$f';
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
    for (final colour in lampTileColours) {
      yield _stallPartPath('lamp_$colour');
    }
    yield _cosmeticIconPath('none');
    for (final d in cosmeticDefinitions) {
      if (d.slot.category == CosmeticCategory.avatar) {
        yield _cosmeticIconPath(d.id);
      }
    }
    yield* fxNames.map((n) => 'assets/images/fx/$n.png');
    yield* uiNames.map((n) => 'assets/images/ui/$n.png');
    yield* seasonBanners.map((n) => 'assets/images/event/$n.png');
    for (final bg in _slot(CosmeticSlot.background)) {
      yield 'assets/images/bg/${bg.id}_night.png';
      yield _cleanPath(bg.id);
      yield _cleanPath('${bg.id}_night');
    }
    yield* lowStallBackgrounds.map(_lowPath);
    for (final id in guestArt) {
      for (final mood in guestMoods) {
        yield 'assets/images/customer/${id}_$mood.png';
      }
    }
    yield* moldNames.map((n) => 'assets/images/mold/$n.png');
    for (final stove in _slot(CosmeticSlot.stove)) {
      yield _emptyStovePath(stove.id);
      yield _stoveFishPath(stove.id);
      yield _closedStovePath(stove.id);
      yield _openStovePath(stove.id);
    }
    for (final flavor in fillingTextureFlavors) {
      yield _fillingTexturePath(flavor);
    }
    for (final paste in pipingPastes) {
      yield 'assets/images/cook/piping_bag_$paste.png';
      yield 'assets/images/cook/piping_bag_${paste}_squeeze.png';
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
  // Every background has its own picture now (3.3_additional_character_and_background_images, stage 2).
  static const artStandIns = <String, String>{};

  /// Avatar slots whose items must be made from a picture of the vendor
  /// wearing them ([avatarWornLayers]): flat hats sit badly on the head
  /// (26번 녹화 피드백 F23), so an item without its worn picture (25번 문서
  /// 17번) is hidden in the wardrobe until it has one.
  static const avatarWornOnlySlots = {CosmeticSlot.hat, CosmeticSlot.hair};

  /// Whether [character] can show item [id] of avatar [slot]: what the
  /// base already wears (defaults, `blankCosmetics`), a skin tone with its
  /// recoloured base, or an item with its own art (worn art for
  /// [avatarWornOnlySlots]). Reads the generated [avatarArtFiles], so art
  /// added with tools/avatar_layers.py shows up without code changes.
  static bool avatarArtReady(String character, CosmeticSlot slot, String id) {
    // 26번 4-7단계: with the v2 vendor on, what v2 drew (the new bottoms
    // too); while it is off, items only v2 draws stay hidden.
    if (avatarV2On) {
      final files = avatarV2Shipped;
      if (slot == CosmeticSlot.character) {
        return files.contains(avatarV2Base(id, defaultCosmetics[CosmeticSlot.skin]!));
      }
      if (blankCosmetics.contains(id)) return true;
      if (slot == CosmeticSlot.skin) {
        return files.contains(avatarV2Base(character, id));
      }
      return files.contains(avatarV2Item(character, slot, id));
    }
    if (slot == CosmeticSlot.character) {
      return avatarArtFiles.contains('avatar/$id/base.png');
    }
    if (!avatarArtFiles.contains('avatar/$character/base.png')) return false;
    if (blankCosmetics.contains(id) || defaultCosmetics[slot] == id) {
      return true;
    }
    if (slot == CosmeticSlot.skin) {
      return avatarArtFiles
          .contains(rigSkinPicture('avatar/$character/base.png', id));
    }
    final path = avatarPartPath(character, slot, id);
    return avatarWornOnlySlots.contains(slot)
        ? avatarWornLayers.contains(path)
        : avatarArtFiles.contains(path);
  }

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

  /// Tests only: puts [image] at [path] (under assets/images), or removes
  /// it when null, e.g. to draw made-up v2 vendor art.
  @visibleForTesting
  static void debugPut(String path, ui.Image? image) {
    if (image == null) {
      _images.remove('assets/images/$path');
    } else {
      _images['assets/images/$path'] = image;
    }
  }

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
  ///
  /// With [clean], the copy without the baked mold (assets/images/bg_clean)
  /// is used when that picture has one; see [hasCleanBackground].
  static (ui.Image?, bool) sceneBackground(String background, bool? night,
      {bool clean = false}) {
    ui.Image? pick(String id, ui.Image? baked) =>
        (clean ? _images[_cleanPath(id)] : null) ?? baked;
    if (night == null) {
      return (pick(background, cosmetic(CosmeticSlot.background, background)), false);
    }
    final dayId = dayBackground(background);
    final day = cosmetic(CosmeticSlot.background, dayId);
    if (!night) return (pick(dayId, day), false);
    final id = nightBackground(background);
    final own = cosmeticDefinitions.any((d) => d.id == id)
        ? cosmetic(CosmeticSlot.background, id)
        : _images['assets/images/bg/$id.png'];
    if (own != null) return (pick(id, own), false);
    // The darkened day stand-in only goes clean if the day picture is.
    return (pick(dayId, day), true);
  }

  static String _cleanPath(String id) => 'assets/images/bg_clean/$id.png';

  /// The backgrounds with the stall lowered to the towel and no baked mold
  /// (assets/images/bg_low, 25번 20번, tools/apply_26_home_art.py): every
  /// day and night picture of [sceneBackground].
  static const lowStallBackgrounds = ['autumn', 'autumn_night', 'cherry',
    'cherry_night', 'clear', 'clear_night', 'dusk', 'forest', 'night', 'rain',
    'rain_night', 'seaside', 'snow', 'snowday'];

  static String _lowPath(String id) => 'assets/images/bg_low/$id.png';

  /// Whether every lowered background loaded: the new home layout waits for
  /// all of them (26번 4-1단계, S4-1-Q4).
  static bool get lowStallReady =>
      lowStallBackgrounds.every((id) => _images.containsKey(_lowPath(id)));

  /// The lowered picture for [background] by day or at [night], like
  /// [sceneBackground]: a missing night picture is the day one darkened.
  static (ui.Image?, bool) lowStallBackground(String background, bool? night) {
    ui.Image? low(String id) => _images[_lowPath(id)];
    if (night == null) return (low(background), false);
    final dayId = dayBackground(background);
    if (!night) return (low(dayId), false);
    final own = low(nightBackground(background));
    return own != null ? (own, false) : (low(dayId), true);
  }

  /// Guest art ids (assets/images/customer, 25번 6번): the eight named
  /// guests and four walk-in looks.
  static const guestArt = ['npc_yunha', 'npc_doyun', 'npc_makrye',
    'npc_seojin', 'npc_taeo', 'npc_eunchae', 'npc_minjae', 'npc_sua',
    'walkin_1', 'walkin_2', 'walkin_3', 'walkin_4'];
  static const guestMoods = ['normal', 'happy', 'sad'];

  /// A standing guest (256x320, body cut at the bottom): [mood] is one of
  /// [guestMoods]; falls back to the normal face, null when not drawn.
  static ui.Image? guest(String id, String mood) =>
      _images['assets/images/customer/${id}_$mood.png'] ??
      _images['assets/images/customer/${id}_normal.png'];

  /// Whether the picture [sceneBackground] shows has a copy without the
  /// baked mold and bungeoppang, so the stage can draw its own.
  static bool hasCleanBackground(String background, bool? night) {
    if (night == null) return _images.containsKey(_cleanPath(background));
    final dayId = dayBackground(background);
    if (!night) return _images.containsKey(_cleanPath(dayId));
    final id = nightBackground(background);
    final own = cosmeticDefinitions.any((d) => d.id == id)
        ? cosmetic(CosmeticSlot.background, id)
        : _images['assets/images/bg/$id.png'];
    return _images.containsKey(_cleanPath(own != null ? id : dayId));
  }

  /// [stove] without its six baked bungeoppang, at the same size and cavity
  /// positions (assets/images/stove_empty): drawn art fitted onto the stove
  /// by tools/apply_25_art.py (25번 필요한 그림 1번). Null when that stove
  /// has none.
  static ui.Image? emptyStove(String stove) => _images[_emptyStovePath(stove)];

  static String _emptyStovePath(String id) =>
      'assets/images/stove_empty/$id.png';

  /// Only the six baked bungeoppang of [stove], the rest transparent, at
  /// the stove's size (assets/images/stove_fish, tools/apply_25_art.py).
  /// GriddlePainter lays a cooking cell's fish over [emptyStove] from it.
  static ui.Image? stoveFish(String stove) => _images[_stoveFishPath(stove)];

  static String _stoveFishPath(String id) => 'assets/images/stove_fish/$id.png';

  /// [stove] closed and cold: the lid over the plate, no flames (26번
  /// 4-2단계 F8, assets/images/stove_closed, 941x470 like the stove,
  /// tools/apply_26_stoves.py). Null when that stove has none.
  static ui.Image? closedStove(String stove) => _images[_closedStovePath(stove)];

  static String _closedStovePath(String id) =>
      'assets/images/stove_closed/$id.png';

  /// [stove] open with the flames on (assets/images/stove_open, 941x700):
  /// the bottom 941x470 is [emptyStove] itself and the lid stands in the
  /// [openStoveLidRoom] rows above it. Null when that stove has none.
  static ui.Image? openStove(String stove) => _images[_openStovePath(stove)];

  static String _openStovePath(String id) => 'assets/images/stove_open/$id.png';

  /// Rows of [openStove] above the plate (the open lid), in picture pixels.
  static const openStoveLidRoom = 230;

  /// Filling textures (`assets/images/mold/paint_<flavor>.png`, 256x256
  /// seamless tiles, 25번 필요한 그림 3번, tools/apply_25_art.py). The
  /// painted filling falls back to a flat color (fillingPasteColors) when
  /// one is missing.
  static const fillingTextureFlavors = ['redbean', 'custard', 'cocoa'];

  static String _fillingTexturePath(String flavor) =>
      'assets/images/mold/paint_$flavor.png';

  static ui.Image? fillingTexture(String flavor) =>
      _images[_fillingTexturePath(flavor)];

  /// The piping bag for [paste] ([pipingPastes]), squeezing or not.
  static ui.Image? pipingBag(String paste, {bool squeeze = false}) =>
      _images['assets/images/cook/piping_bag_$paste${squeeze ? '_squeeze' : ''}.png'];

  /// The asset path of an image loaded by [load], or null (for example to
  /// tell which background picture [sceneBackground] picked).
  static String? pathOf(ui.Image? image) {
    if (image == null) return null;
    for (final e in _images.entries) {
      if (identical(e.value, image)) return e.key;
    }
    return null;
  }

  /// One of [moldNames].
  static ui.Image? mold(String name) => _images['assets/images/mold/$name.png'];

  /// One of [fxNames].
  static ui.Image? fx(String name) => _images['assets/images/fx/$name.png'];

  static String _cosmeticIconPath(String id) =>
      'assets/images/cosmetic_icons/$id.png';

  /// The wardrobe tile icon of avatar item [id] (64x64, both characters;
  /// 26번 4-5단계, G5): the 'none' hanger for the take-off items, null
  /// when not drawn.
  static ui.Image? cosmeticIcon(String id) => _images[_cosmeticIconPath(
      const {'nohat', 'noapron', 'noacc'}.contains(id) ? 'none' : id)];

  /// The wardrobe tile picture of a stall item when it has its own (lamps:
  /// the whole post lamp; day/night: an icon), else null.
  static ui.Image? stallTile(CosmeticDefinition d) => switch (d.slot) {
        CosmeticSlot.lamp => _images[_stallPartPath(
            'lamp_${d.id == defaultCosmetics[CosmeticSlot.lamp] ? 'amber' : d.id.substring(0, d.id.length - 'lamp'.length)}')],
        CosmeticSlot.time => icon('time_${d.id == 'night_time' ? 'night' : d.id}'),
        _ => null,
      };

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

/// The fish beside a window title (`ui/title_fish.png`, 25번 35번), facing
/// right or [flip]ped to face left. Takes no room at all while the picture
/// is not in the app (시안 확인 2차: the old one was taken out until the
/// redraw arrives), so the title stays centred.
class TitleFish extends StatelessWidget {
  final double width, height;
  final bool flip;
  const TitleFish({super.key, required this.width, required this.height, this.flip = false});

  @override
  Widget build(BuildContext context) {
    final art = PixelSprites.screenArt('title_fish');
    if (art == null) return const SizedBox.shrink();
    final fish = PixelArt(art, width: width, height: height);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: flip ? Transform.flip(flipX: true, child: fish) : fish);
  }
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
