import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
  ];

  static final _images = <String, ui.Image>{};
  static Future<void>? _loading;
  static final _paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Null for blank items and for patterns, which are baked into the fish
  /// images (see [fish]).
  static String? _cosmeticPath(CosmeticDefinition d) =>
      blankCosmetics.contains(d.id)
          ? null
          : switch (d.slot) {
              CosmeticSlot.fish => 'assets/images/fish/${d.id}.png',
              CosmeticSlot.pattern => null,
              CosmeticSlot.topping => 'assets/images/topping/${d.id}.png',
              CosmeticSlot.skin ||
              CosmeticSlot.hair ||
              CosmeticSlot.outfit ||
              CosmeticSlot.hat ||
              CosmeticSlot.tool =>
                'assets/images/avatar/${d.slot.name}/${d.id}.png',
              CosmeticSlot.background => 'assets/images/bg/${d.id}.png',
              CosmeticSlot.stove => 'assets/images/stove/${d.id}.png',
              CosmeticSlot.decoration => 'assets/images/deco/${d.id}.png',
            };

  static String _fishPath(String flavor, String pattern) =>
      'assets/images/fish/$flavor${pattern == defaultCosmetics[CosmeticSlot.pattern] ? '' : '@$pattern'}.png';

  static String _handsPath(String skin) => 'assets/images/avatar/hands/$skin.png';

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
    for (final skin in _slot(CosmeticSlot.skin)) {
      yield _handsPath(skin.id);
    }
    yield 'assets/images/stall/counter.png';
    yield 'assets/images/stall/counter_snow.png';
    for (final name in iconNames) {
      yield 'assets/images/icons/$name.png';
    }
  }

  static Future<void> load() => _loading ??= Future.wait(_paths.map(_loadOne));

  static Future<void> _loadOne(String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _images[path] = (await codec.getNextFrame()).image;
    } catch (_) {
      // Missing art: painters leave that layer out.
    }
  }

  static ui.Image? cosmetic(CosmeticSlot slot, String id) {
    for (final d in cosmeticDefinitions) {
      if (d.slot == slot && d.id == id) {
        final path = _cosmeticPath(d);
        return path == null ? null : _images[path];
      }
    }
    return null;
  }

  /// The bungeoppang of [flavor] embossed with [pattern].
  static ui.Image? fish(String flavor, String pattern) =>
      _images[_fishPath(flavor, pattern)];

  /// The vendor's hands, drawn over the held tool.
  static ui.Image? hands(String skin) => _images[_handsPath(skin)];

  static ui.Image? counter({bool snow = false}) =>
      _images['assets/images/stall/counter${snow ? '_snow' : ''}.png'];

  static ui.Image? icon(String name) => _images['assets/images/icons/$name.png'];

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

/// A square pixel-art icon from assets/images/icons.
class PixelIcon extends StatelessWidget {
  final String name;
  final double size;
  const PixelIcon(this.name, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(PixelSprites.icon(name))));
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
