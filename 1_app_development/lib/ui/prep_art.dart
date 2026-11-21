import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 25번 62번 재료 타이쿤 그림 (tools/apply_62_prep_art.py): ingredient and
/// tub icons in assets/images/ingredients/, the mini-game scenes in
/// assets/images/prep/. Loaded on first use (the 재료 준비 window), apart
/// from PixelSprites so the 재료 타이쿤 packages do not all edit it; until a
/// picture is in, the screens draw a simple stand-in in code.
class PrepArt {
  PrepArt._();

  static const icons = ['ing_flour', 'ing_milk', 'ing_egg', 'ing_sugar', 'ing_salt', 'ing_redbean', 'ing_cocoa',
      'prem_butter', 'prem_redbean', 'prem_vanilla', 'prem_chocolate',
      'tub_batter', 'tub_redbean', 'tub_custard', 'tub_cocoa', 'tab_ingredients', 'btn_prep'];
  static const scenes = ['bowl_batter_lumpy', 'bowl_batter_smooth', 'pot_redbean', 'pot_cocoa', 'fire_high',
      'bowl_custard_low', 'bowl_custard_high', 'tool_spatula', 'tool_whisk'];

  /// Scene canvas (1200×880) and tool canvas (400×400), 4 px per dot.
  static const sceneSize = ui.Size(1200, 880), toolSize = ui.Size(400, 400);
  /// Where the finger holds each tool on its canvas (the spatula's blade
  /// tip from its metadata, the whisk's loop).
  static const toolGrip = {'tool_spatula': ui.Offset(120, 280), 'tool_whisk': ui.Offset(190, 360)};

  /// Config ingredient id → icon (`ingredients.basic`/`premium.items`).
  static const ingredientIcon = {
    'flour': 'ing_flour', 'milk': 'ing_milk', 'egg': 'ing_egg', 'sugar': 'ing_sugar', 'salt': 'ing_salt',
    'adzuki': 'ing_redbean', 'cocoa_powder': 'ing_cocoa',
    'cultured_butter': 'prem_butter', 'fresh_adzuki': 'prem_redbean', 'vanilla_bean': 'prem_vanilla',
    'fine_chocolate': 'prem_chocolate',
  };

  static final _images = <String, ui.Image>{};
  static Future<void>? _loading;

  /// Bumped when the pictures are in, for screens drawn before.
  static final loaded = ValueNotifier<int>(0);

  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    await Future.wait([
      for (final n in icons) _one('assets/images/ingredients/$n.png'),
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

  static ui.Image? icon(String name) => _images['assets/images/ingredients/$name.png'];
  static ui.Image? scene(String name) => _images['assets/images/prep/$name.png'];

  /// Tests only: forget what was loaded (to draw the stand-ins).
  @visibleForTesting
  static void debugClear() {
    _images.clear();
    _loading = null;
  }
}
