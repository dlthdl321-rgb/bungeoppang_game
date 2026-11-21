import 'package:flutter/material.dart';
import '../pantry_home.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';

/// 재료 타이쿤 E — the pantry on the Workshop home.
///
/// * [PantryStockLine]: under the business sign, the batter and the chosen
///   flavor's filling in tubs (orange below 20% of the stock limit, red at
///   none), with the out-of-ingredients bubble under it once per run-out.
/// * [PantryPrepButton]: '재료 준비' beside '스페셜 붕어빵 제작 시작' during
///   영업 준비 (locked under the common lock until `pantry_prep`, Lv.2).
/// Both open 묶음 D's '재료 준비' window (`WorkshopPage._openPantry`, 4차 병합 3).

/// The tub icon of a prepared kind (25번 62번 `tub_<kind>`).
String pantryTubIcon(String kind) => 'tub_$kind';

class PantryStockLine extends StatelessWidget {
  final WorkshopController controller;
  final VoidCallback onTap;
  /// The out-of-ingredients bubble's first line, or null when it is not shown.
  final String? bubble;
  final VoidCallback? onBubbleTap;
  /// Short screens: the two stocks one above the other, left-aligned under
  /// the HUD's top-left slot (NightHome.statusBelow).
  final bool compact;
  const PantryStockLine({super.key, required this.controller, required this.onTap, this.bubble, this.onBubbleTap,
      this.compact = false});

  static const out = Color(0xffc8392b), low = Color(0xffffa94a);

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, p = c.pantryConfig, now = c.now().millisecondsSinceEpoch;
    final flavor = s.selectedFlavor;
    Widget item(String kind, String role) {
      final portions = s.pantry.usable(p, kind, now);
      final level = pantryStockLevel(p, s.pantry, kind, s.level, now);
      final text = pantryTubsShort(p, portions);
      return Container(
        key: Key('pantry-stock-$role'),
        padding: const EdgeInsets.fromLTRB(2, 1, 7, 1),
        decoration: BoxDecoration(
            color: level == PantryStockLevel.out ? out : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          PixelIcon(pantryTubIcon(kind), size: 20),
          const SizedBox(width: 2),
          Text(text,
              key: Key('pantry-stock-$role-text'),
              style: TextStyle(
                  fontFamily: 'Jua',
                  fontFamilyFallback: Cozy.fontFallback,
                  fontSize: 13,
                  height: 1.1,
                  color: level == PantryStockLevel.low ? low : Cozy.cream)),
        ]),
      );
    }

    final batterLabel = p.kind(p.batterKind).label, fillingLabel = p.kind(flavor).label;
    final line = Semantics(
      button: true,
      label: '남은 재료, $batterLabel ${pantryTubsShort(p, s.pantry.usable(p, p.batterKind, now))}, '
          '$fillingLabel ${pantryTubsShort(p, s.pantry.usable(p, flavor, now))}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: const Key('pantry-stock'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(color: const Color(0x99221410), borderRadius: BorderRadius.circular(12)),
          child: compact
              ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  item(p.batterKind, 'batter'),
                  const SizedBox(height: 2),
                  item(flavor, 'filling'),
                ])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  item(p.batterKind, 'batter'),
                  const SizedBox(width: 2),
                  item(flavor, 'filling'),
                ]),
        ),
      ),
    );
    if (bubble == null) return line;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          line,
          const SizedBox(height: 2),
          PantryOutBubble(title: bubble!, onTap: onBubbleTap, tipLeft: compact ? 18 : null),
        ]);
  }
}

/// '반죽이 떨어졌어요 / 영업을 마치고 ‘재료 준비’에서 만들어요': a small
/// speech bubble pointing up at the stock line. A tap closes it.
class PantryOutBubble extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  /// Where the tip points from the left (null: the middle).
  final double? tipLeft;
  const PantryOutBubble({super.key, required this.title, this.onTap, this.tipLeft});

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: '$title. $pantryOutHint',
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          key: const Key('pantry-out-bubble'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: tipLeft == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
            Padding(
                padding: EdgeInsets.only(left: tipLeft ?? 0),
                child: CustomPaint(size: const Size(14, 7), painter: _BubbleTip())),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
                decoration: BoxDecoration(
                    color: Cozy.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PantryStockLine.out, width: 1.5),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(title,
                      key: const Key('pantry-out-title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 15, color: PantryStockLine.out)),
                  const SizedBox(height: 1),
                  const Text(pantryOutHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cozy.ink)),
                ]),
              ),
            ),
          ]),
        ),
      );
}

class _BubbleTip extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height + 1)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height + 1)
      ..close();
    canvas.drawPath(path, Paint()..color = PantryStockLine.out);
    final inner = Path()
      ..moveTo(2.2, size.height + 1)
      ..lineTo(size.width / 2, 2.2)
      ..lineTo(size.width - 2.2, size.height + 1)
      ..close();
    canvas.drawPath(inner, Paint()..color = Cozy.cream);
  }

  @override
  bool shouldRepaint(_BubbleTip oldDelegate) => false;
}

/// '재료 준비' beside '스페셜 붕어빵 제작 시작' (the same pill look). With
/// [lock] ('Lv.2 달성하면 열려요') it sits faded under the common lock and a
/// tap tells why.
class PantryPrepButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? lock;
  final VoidCallback? onLocked;
  const PantryPrepButton({super.key, required this.onPressed, this.lock, this.onLocked});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(
            color: Cozy.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Cozy.woodLight, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))]),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          PixelIcon('btn_prep', size: 28),
          SizedBox(width: 4),
          Text('재료 준비', style: TextStyle(color: Cozy.ink, fontWeight: FontWeight.bold, fontSize: 15)),
        ]));
    if (lock != null) {
      return KeyedSubtree(
          key: const Key('pantry-prep'),
          child: LockedOverlay(caption: lock!, onTap: onLocked, maxLock: 22, showCaption: false, child: pill));
    }
    return Semantics(
        button: true,
        label: '재료 준비',
        excludeSemantics: true,
        child: InkWell(key: const Key('pantry-prep'), borderRadius: BorderRadius.circular(18), onTap: onPressed, child: pill));
  }
}
