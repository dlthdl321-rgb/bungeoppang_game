import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../feedback_config.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// The automatic 승급's big celebration (4차 피드백 IA1, user decision: a
/// brief screen-covering effect, not a small notice): the screen dims,
/// honey rays turn behind a large level emblem, '레벨 업!' pops in and
/// pixel confetti falls. It lasts [levelUpCelebrationMs] (shorter with
/// reduced motion, no rays turning or confetti then). Touches pass through
/// it, so a tap on the clicker or a guest is never lost. Drawn in code from the app's own icons (`icons/levelup.png`,
/// `icons/star.png`), no new art.
class LevelUpCelebration extends StatefulWidget {
  final int level;
  final bool reduceMotion;
  final VoidCallback onDone;
  const LevelUpCelebration({super.key, required this.level, required this.onDone, this.reduceMotion = false});

  @override
  State<LevelUpCelebration> createState() => _LevelUpCelebrationState();
}

/// How long the celebration stays (fading in and out included).
const levelUpCelebrationMs = celebrationMs + 600;

OverlayEntry? _showing;

/// Shows [LevelUpCelebration] above every window (the root overlay); a new
/// one replaces the one showing.
void showLevelUpCelebration(BuildContext context, int level, {bool reduceMotion = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideLevelUpCelebration();
  late final OverlayEntry entry;
  entry = OverlayEntry(
      builder: (_) => LevelUpCelebration(
          level: level,
          reduceMotion: reduceMotion,
          onDone: () {
            if (_showing == entry) hideLevelUpCelebration();
          }));
  _showing = entry;
  overlay.insert(entry);
}

/// Removes the celebration showing, if any.
void hideLevelUpCelebration() {
  final entry = _showing;
  _showing = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _Piece {
  final double x, speed, sway, phase;
  final int colour;
  final bool big;
  _Piece(math.Random r)
      : x = r.nextDouble(),
        speed = .55 + r.nextDouble() * .6,
        sway = 6 + r.nextDouble() * 14,
        phase = r.nextDouble() * 6,
        colour = r.nextInt(4),
        big = r.nextBool();
}

class _LevelUpCelebrationState extends State<LevelUpCelebration> with SingleTickerProviderStateMixin {
  late final bool _still = widget.reduceMotion;
  late final AnimationController _t = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _still ? reducedCelebrationMs : levelUpCelebrationMs))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    })
    ..forward();
  final _pieces = List.generate(maxConfetti * 2, (i) => _Piece(math.Random(11 + i)));
  bool _done = false;

  void _finish() {
    if (_done) return;
    _done = true;
    // Never remove the overlay entry while it builds.
    scheduleMicrotask(widget.onDone);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Positioned.fill(
      child: IgnorePointer(
        key: const Key('level-up-celebration'),
        child: Semantics(
          liveRegion: true,
          label: '레벨 업! Lv.${widget.level} 달성',
          excludeSemantics: true,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final t = _t.value;
              final fade = still ? 1.0 : (t < .08 ? t / .08 : t > .86 ? (1 - t) / .14 : 1.0).clamp(0.0, 1.0);
              final pop = still ? 1.0 : Curves.elasticOut.transform((t * 2.2).clamp(0.0, 1.0));
              return Opacity(
                opacity: fade,
                // The root overlay has no Material: give the texts the app's
                // text style (no yellow debug underline, Korean glyphs).
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(fit: StackFit.expand, children: [
                  const ColoredBox(color: Color(0x99140b06)),
                  CustomPaint(painter: _RaysPainter(still ? 0 : t, _pieces, confetti: !still)),
                  SafeArea(
                    child: Center(
                      child: Transform.scale(
                        scale: .6 + .4 * pop,
                        // Large text never pushes it off a narrow screen.
                        child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            const PixelIcon('star', size: 34),
                            const SizedBox(width: 6),
                            Text('레벨 업!',
                                style: TextStyle(
                                    fontFamily: 'Jua',
                                    fontFamilyFallback: Cozy.fontFallback,
                                    fontSize: 44,
                                    height: 1.1,
                                    color: Cozy.honeyLight,
                                    shadows: [
                                      const Shadow(color: Cozy.woodDark, offset: Offset(0, 3)),
                                      Shadow(color: Cozy.amber.withValues(alpha: .8), blurRadius: 14),
                                    ])),
                            const SizedBox(width: 6),
                            const PixelIcon('star', size: 34),
                          ]),
                          const SizedBox(height: 14),
                          Container(
                            key: const Key('level-up-emblem'),
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              color: Cozy.cream,
                              shape: BoxShape.circle,
                              border: Border.all(color: Cozy.honey, width: 7),
                              boxShadow: [BoxShadow(color: Cozy.honey.withValues(alpha: .7), blurRadius: 28, spreadRadius: 4)],
                            ),
                            padding: const EdgeInsets.all(10),
                            // Large text scales down inside the circle.
                            child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const PixelIcon('levelup', size: 30),
                              const Text('Lv',
                                  style: TextStyle(fontSize: 16, height: 1, fontWeight: FontWeight.w800, color: Cozy.wood)),
                              FittedBox(
                                child: Text('${widget.level}',
                                    style: const TextStyle(
                                        fontFamily: 'Jua',
                                        fontFamilyFallback: Cozy.fontFallback,
                                        color: Cozy.ink,
                                        fontSize: 46,
                                        height: 1.05)),
                              ),
                            ]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Lv.${widget.level} 달성! 새 레벨 미션이 시작돼요.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Cozy.cream,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                        ]),
                        ),
                        ),
                      ),
                    ),
                  ),
                ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Honey rays turning slowly round the screen's centre and, unless motion
/// is reduced, square confetti on a 4px grid falling over everything.
class _RaysPainter extends CustomPainter {
  static const _colours = [Color(0xfff8d27a), Color(0xffff9e4a), Color(0xffb9e3a8), Color(0xfff6b3c2)];
  final double t;
  final List<_Piece> pieces;
  final bool confetti;
  _RaysPainter(this.t, this.pieces, {required this.confetti});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final rays = Paint()
      ..shader = RadialGradient(colors: [Cozy.honey.withValues(alpha: .55), Cozy.honey.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r * .6));
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi + t * .9;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - .09) * r, c.dy + math.sin(a - .09) * r)
        ..lineTo(c.dx + math.cos(a + .09) * r, c.dy + math.sin(a + .09) * r)
        ..close();
      canvas.drawPath(path, rays);
    }
    if (!confetti) return;
    final paint = Paint();
    for (final p in pieces) {
      paint.color = _colours[p.colour];
      final y = -20 + p.speed * t * size.height * 1.3;
      final x = p.x * size.width + math.sin(t * 10 + p.phase) * p.sway;
      final side = p.big ? 8.0 : 4.0;
      canvas.drawRect(Rect.fromLTWH((x / 4).roundToDouble() * 4, (y / 4).roundToDouble() * 4, side, side), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.t != t;
}
