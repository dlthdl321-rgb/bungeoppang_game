import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// How a locked thing looks (S43-Q4). [hatch]: the thing itself, faded,
/// under diagonal stripes and a big padlock (26번 2단계, home buttons and
/// the six-cell griddle). [hidden]: only the thing's outline as a dark
/// silhouette (its colours and details stay secret) under the big padlock
/// (26번 4-3단계, the next skill to unlock).
enum LockStyle { hatch, hidden }

/// The common lock (26번 2단계 → 4-3단계 공통): [child] faded under warm
/// diagonal stripes (6px lines, 10px gaps, 35%, the 25번 13번 tile values)
/// with the big padlock (`ui/lock_badge.png`, 25번 13번) in the middle and
/// [caption] ('Lv.2에 열려요') under it when there is room. Touches pass to
/// [onTap] (a short reason) instead of [child].
class LockedOverlay extends StatelessWidget {
  final Widget child;
  final String caption;
  final LockStyle style;
  final VoidCallback? onTap;
  /// Largest padlock side; it also shrinks to fit the box.
  final double maxLock;
  /// Whether the caption may show under the lock (small buttons hide it and
  /// keep it for screen readers).
  final bool showCaption;
  /// Where the padlock sits; a menu button puts it over its icon so the
  /// label stays readable.
  final Alignment lockAlignment;
  const LockedOverlay({super.key, required this.child, required this.caption, this.style = LockStyle.hatch,
      this.onTap, this.maxLock = 56, this.showCaption = true, this.lockAlignment = Alignment.center});

  static const stripe = Color(0xff5b3a24);
  /// The [LockStyle.hidden] silhouette colour (the stripe's warm brown).
  static const silhouette = Color(0xff3e2a1d);

  @override
  Widget build(BuildContext context) => Semantics(
        label: '잠김, $caption',
        button: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight.isFinite ? box.maxHeight : 80.0;
            final w = box.maxWidth.isFinite ? box.maxWidth : 80.0;
            final roomForCaption = showCaption && h >= 64;
            final lock = math.min(maxLock, math.min(w * .6, (roomForCaption ? h - 22 : h) * .8)).clamp(12.0, maxLock);
            return Stack(fit: StackFit.passthrough, children: [
              if (style == LockStyle.hidden)
                IgnorePointer(child: Opacity(opacity: .55, child: ColorFiltered(key: const Key('lock-silhouette'),
                    colorFilter: const ColorFilter.mode(silhouette, BlendMode.srcIn), child: child)))
              else ...[
                IgnorePointer(child: Opacity(opacity: .5, child: child)),
                Positioned.fill(child: IgnorePointer(child: ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(key: const Key('lock-hatch'), painter: const LockHatchPainter())))),
              ],
              Positioned.fill(child: IgnorePointer(child: Align(alignment: lockAlignment, child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox.square(dimension: lock, child: const _LockBadge()),
                if (roomForCaption)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Cozy.cream.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(8), border: Border.all(color: Cozy.woodLight)),
                      child: Text(caption, key: const Key('lock-caption'), textAlign: TextAlign.center,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Cozy.ink)),
                    ),
                  ),
              ])))),
            ]);
          }),
        ),
      );
}

/// The padlock picture, or a drawn padlock until the art is loaded.
class _LockBadge extends StatelessWidget {
  const _LockBadge();
  @override
  Widget build(BuildContext context) {
    final art = PixelSprites.screenArt('lock_badge');
    if (art != null) return PixelArt(art, key: const Key('lock-badge'));
    return const Icon(Icons.lock, key: Key('lock-badge'), color: Cozy.woodDark);
  }
}

/// Diagonal stripes from bottom-left to top-right: 6px warm-brown lines at
/// 35% with 10px gaps (25번 13번 tile), fixed to the box so they never crawl.
class LockHatchPainter extends CustomPainter {
  const LockHatchPainter();
  static const line = 6.0, gap = 10.0;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cozy.woodDark.withValues(alpha: .18));
    final paint = Paint()
      ..color = LockedOverlay.stripe.withValues(alpha: .35)
      ..strokeWidth = line;
    // Stripes run at 45°: their spacing across is (line + gap).
    final step = (line + gap) * math.sqrt2;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }
  @override
  bool shouldRepaint(LockHatchPainter old) => false;
}
