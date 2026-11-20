import 'package:flutter/material.dart';
import '../economy.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// The two currencies a Workshop price can ask for.
enum Currency {
  /// 붕어빵력 (`icons/bun.png`).
  buns,
  /// 황금붕어빵력 (`icons/gold_bun.png`, 25번 18번).
  gold;

  String get label => this == buns ? '붕어빵력' : '황금붕어빵력';
  String get icon => this == buns ? 'bun' : 'gold_bun';
}

/// A price or balance as the currency's icon and a number (26번 4-3단계,
/// shared with the wardrobe of 4-5단계). [short] shortens big numbers
/// ('3.2만', [compactNumber]); then a long press shows the exact number.
/// [short] amounts in [missing] colour (red) mark what the player lacks.
/// The icon is [defaultSize] by default (4차 피드백 ID2: the 붕어빵 before
/// a price was too small to see at 18; the art fills about two thirds of
/// its square, so the icon is drawn well above the number's height).
class CurrencyAmount extends StatelessWidget {
  final Currency kind;
  final BigInt amount;
  final bool short;
  /// Red when the player does not have this much.
  final bool missing;
  final double size;
  final double fontSize;
  const CurrencyAmount(this.kind, this.amount,
      {super.key, this.short = true, this.missing = false, this.size = defaultSize, this.fontSize = 14});

  static const defaultSize = 30.0;

  static const missingColor = Color(0xffc0392b);

  @override
  Widget build(BuildContext context) {
    final text = short ? compactNumber(amount) : exactNumber(amount);
    final exact = exactNumber(amount);
    final row = Semantics(
      label: '${kind.label} $exact${missing ? ', 모자라요' : ''}',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PixelIcon(kind.icon, size: size),
        const SizedBox(width: 2),
        Text(text,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: missing ? missingColor : Cozy.ink)),
      ]),
    );
    if (text == exact) return row;
    return Tooltip(message: '${kind.label} $exact', triggerMode: TooltipTriggerMode.longPress, child: row);
  }
}
