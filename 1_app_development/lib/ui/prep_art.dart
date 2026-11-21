import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pixel_sprites.dart';

/// 25번 62번 재료 타이쿤 그림: the mini-game scenes in assets/images/prep/
/// (tools/apply_62_prep_art.py), loaded on first use (the 재료 준비 window);
/// until a picture is in, the screens draw a simple stand-in in code. The
/// ingredient and tub icons are ordinary icons in assets/images/icons/
/// (tools/apply_25_art.py --only ingredients) loaded by [PixelSprites] —
/// 4차 병합 3 keeps one copy of them and one loader ([icon] reads
/// [PixelSprites.icon], [ingredientIcon] is [PixelSprites.ingredientIcons]).
class PrepArt {
  PrepArt._();

  static const scenes = ['bowl_batter_lumpy', 'bowl_batter_smooth', 'pot_redbean', 'pot_cocoa', 'fire_high',
      'bowl_custard_low', 'bowl_custard_high', 'tool_spatula', 'tool_whisk'];

  /// Scene canvas (1200×880) and tool canvas (400×400), 4 px per dot.
  static const sceneSize = ui.Size(1200, 880), toolSize = ui.Size(400, 400);
  /// Where the finger holds each tool on its canvas (the spatula's blade
  /// tip from its metadata, the whisk's loop).
  static const toolGrip = {'tool_spatula': ui.Offset(120, 280), 'tool_whisk': ui.Offset(190, 360)};

  /// Config ingredient id → icon (`ingredients.basic`/`premium.items`).
  static const ingredientIcon = PixelSprites.ingredientIcons;

  static final _images = <String, ui.Image>{};
  static Future<void>? _loading;

  /// Bumped when the pictures are in, for screens drawn before.
  static final loaded = ValueNotifier<int>(0);

  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    await Future.wait([
      PixelSprites.load(), // the icons (usually already in)
      for (final n in scenes) _one('assets/images/prep/$n.png'),
    ]);
    loaded.value++;
  }

  static Future<void> _one(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _images[path] = (await codec.getNextFrame()).image;
    } catch (_) {
      // Not delivered yet: the stand-in is drawn.
    }
  }

  static ui.Image? icon(String name) => PixelSprites.icon(name);
  static ui.Image? scene(String name) => _images['assets/images/prep/$name.png'];

  /// Tests only: forget what was loaded (to draw the stand-ins).
  @visibleForTesting
  static void debugClear() {
    _images.clear();
    _loading = null;
  }
}
