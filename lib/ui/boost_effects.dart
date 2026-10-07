import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../game_controller.dart';
import '../support_config.dart';
import 'avatar_face.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'fish_painter.dart';
import 'pixel_sprites.dart';
import 'support_panels.dart' show remainingLabel;
import 'weather_layer.dart';

/// Recolours a sprite to shining gold, keeping its shading (brightness).
const goldTint = ColorFilter.matrix([
  0.50, 0.60, 0.12, 0, 40, //
  0.38, 0.45, 0.10, 0, 18, //
  0.10, 0.12, 0.04, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// A bungeoppang dipped in gold (boosts, golden chances).
class GoldenFish extends StatelessWidget {
  final String pattern;
  const GoldenFish({super.key, this.pattern = 'scales'});
  @override
  Widget build(BuildContext context) => ColorFiltered(
      colorFilter: goldTint,
      child: CustomPaint(painter: FishPainter(pattern: pattern)));
}

/// Centre of each griddle cavity as a fraction of the stove sprite: two
/// rows of three, measured on the concept griddle by
/// tools/concept_griddle.py.
const griddleCavities = [
  Offset(.284, .524),
  Offset(.502, .525),
  Offset(.719, .525),
  Offset(.257, .715),
  Offset(.501, .715),
  Offset(.743, .715),
];

/// Where GriddlePainter draws a [sprite]-sized stove in [box]: fitted and
/// bottom-aligned.
Rect griddleSpriteRect(Size box, Size sprite) {
  final scale =
      math.min(box.width / sprite.width, box.height / sprite.height);
  final w = sprite.width * scale, h = sprite.height * scale;
  return Rect.fromLTWH((box.width - w) / 2, box.height - h, w, h);
}

/// The golden chance on the griddle: one cavity's bungeoppang turns gold for
/// a few seconds; tapping it starts a [BoostKind.golden] boost.
class GoldenGriddleLayer extends StatelessWidget {
  final GameController controller;
  final bool reduceMotion;
  const GoldenGriddleLayer(
      {super.key, required this.controller, this.reduceMotion = false});

  @override
  Widget build(BuildContext context) {
    final chance = controller.goldenChance;
    if (chance == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final stove = PixelSprites.cosmetic(CosmeticSlot.stove,
          controller.state.equippedCosmetic(CosmeticSlot.stove));
      final sprite = griddleSpriteRect(
          box.biggest,
          stove == null
              ? const Size(80, 40)
              : Size(stove.width.toDouble(), stove.height.toDouble()));
      final c = griddleCavities[chance.slot];
      final w = sprite.width * .22, h = w * .75;
      return Stack(children: [
        Positioned(
          left: sprite.left + sprite.width * c.dx - w / 2,
          top: sprite.top + sprite.height * c.dy - h / 2,
          width: w,
          height: h,
          child: Semantics(
            button: true,
            label: '황금 붕어빵 잡기',
            onTap: () => controller.catchGoldenChance(chance.slot),
            excludeSemantics: true,
            child: GestureDetector(
              key: Key('golden-chance-${chance.slot}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.catchGoldenChance(chance.slot),
              child: _Pulse(enabled: !reduceMotion, child: const GoldenFish()),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Gently grows and shrinks its child; still when disabled.
class _Pulse extends StatefulWidget {
  final bool enabled;
  final Widget child;
  const _Pulse({required this.enabled, required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (context, child) =>
          Transform.scale(scale: 1 + .12 * _c.value, child: child),
      child: widget.child);
}

/// '황금 부스트 ×5 · 9분 41초' while a boost runs.
class BoostBadge extends StatelessWidget {
  final GameController controller;
  const BoostBadge({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final boost = controller.activeBoost;
    if (boost == null) return const SizedBox.shrink();
    final def = boostOf(boost.kind);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('boost-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xfffed794),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Cozy.orangeDeep, width: 2)),
        child: Text(
            '${def.name} ×${boost.multiplierPermille ~/ BigInt.from(1000)} · '
            '${remainingLabel(boost.remainingMs(controller.gameNow))}',
            style: const TextStyle(
                color: Cozy.ink, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// A visitor (invite guest or friend) walks up to the counter, says hello
/// and walks away; the boost is already running. Shows the first of
/// [GameController.guestArrivals], then the next.
class GuestArrivalLayer extends StatefulWidget {
  final GameController controller;
  final bool reduceMotion;
  const GuestArrivalLayer(
      {super.key, required this.controller, this.reduceMotion = false});
  static const showMs = 4200;
  @override
  State<GuestArrivalLayer> createState() => _GuestArrivalLayerState();
}

class _GuestArrivalLayerState extends State<GuestArrivalLayer>
    with SingleTickerProviderStateMixin {
  late final _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GuestArrivalLayer.showMs));
  GuestVisit? _showing;

  @override
  void initState() {
    super.initState();
    _walk.addStatusListener((status) {
      if (status == AnimationStatus.completed && _showing != null) {
        final done = _showing!;
        _showing = null;
        widget.controller.guestShown(done);
      }
    });
  }

  @override
  void dispose() {
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.controller.guestArrivals;
    if (_showing == null && queue.isNotEmpty) {
      _showing = queue.first;
      _walk.forward(from: 0);
    }
    final visit = _showing;
    if (visit == null) return const SizedBox.shrink();
    final look = lookFromServer(visit.look);
    final boost = boostOf(visit.kind);
    return LayoutBuilder(builder: (context, box) => AnimatedBuilder(
        animation: _walk,
        builder: (context, _) {
          final t = _walk.value;
          // 0-35% walk in from the far street, 35-80% at the counter,
          // 80-100% walk away; still with reduced motion.
          final approach = widget.reduceMotion
              ? 1.0
              : t < .35
                  ? Curves.easeOut.transform(t / .35)
                  : t < .8
                      ? 1.0
                      : 1 - (t - .8) / .2;
          final size = box.maxWidth * (.18 + .2 * approach);
          final x = box.maxWidth * (.2 + .05 * math.sin(t * math.pi));
          final y = box.maxHeight * (.42 + .16 * approach);
          return Stack(children: [
            Positioned(
              left: x,
              top: y - size * 1.15,
              width: size,
              height: size * 1.15,
              child: Opacity(
                opacity: approach.clamp(0.0, 1.0),
                // The visitor blinks, and talks while saying hello.
                child: AvatarFace(
                  animate: WeatherLayer.animate && !widget.reduceMotion,
                  talking: approach > .9 && t < .8,
                  builder: (context, face) => CustomPaint(
                      key: const Key('guest-arrival'),
                      painter: AvatarPainter(look, face: face)),
                ),
              ),
            ),
            if (approach > .9)
              Positioned(
                left: x + size * .75,
                top: y - size * 1.25,
                child: CozyPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                      '${visit.name} 놀러 왔어요!\n${boost.name} ×${boost.multiplierPermille ~/ 1000} · ${boost.durationSeconds ~/ 60}분',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        }));
  }
}

/// A look from the server (slot name -> item id) as an [AvatarLook]; unknown
/// or missing slots fall back to the defaults.
AvatarLook lookFromServer(Map<String, String> look) {
  String pick(CosmeticSlot slot) {
    final id = look[slot.name];
    return id != null &&
            cosmeticDefinitions.any((d) => d.slot == slot && d.id == id)
        ? id
        : defaultCosmetics[slot]!;
  }

  return AvatarLook.of(pick);
}
