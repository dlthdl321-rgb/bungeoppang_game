import 'package:flutter/material.dart';
import 'pixel_sprites.dart';

/// The app's colours. 26번 3차 피드백 H41 (2026-11-19): the old look was
/// brown and beige everywhere (thick wooden outlines on every panel, the
/// same beige for every bubble and window). Panels are now warm white with a
/// hairline and a soft shadow, text a deep cocoa, and each kind of message
/// has its own tint ([CozyTone]: info blue, reward gold, warning coral,
/// success green). The names stay so every screen follows; the old values
/// are in MASTER 11장.
class Cozy {
  Cozy._();

  /// Jua lacks punctuation such as `·`, `…`, `→`, `●○`; these come from a
  /// small symbol cut (tools/build_symbol_font.py) instead of a box.
  static const fontFallback = <String>['BungeoSymbols'];

  /// Panel and window face (warm white).
  static const cream = Color(0xfffffaf3);

  /// Disabled faces, sunk wells, the unpicked part of a segmented tab row.
  static const creamDeep = Color(0xfff4ece2);

  /// Strong accents: a picked outline, wooden props on the home.
  static const wood = Color(0xff6b4532);

  /// A visible but light line (cards on cream).
  static const woodLight = Color(0xffdcc6ae);

  /// Dark home pieces (level box, bottom strip of a window).
  static const woodDark = Color(0xff3d2b23);
  static const ink = Color(0xff2f221c);
  static const inkSoft = Color(0xff85766c);
  static const orange = Color(0xffffb65c);
  static const orangeDeep = Color(0xfff29a38);

  /// Close button face, badges, the warning tone.
  static const brick = Color(0xffd0533a);

  /// Yellow face of the main buttons and the picked tab, top to bottom.
  static const honeyLight = Color(0xffffd96b);
  static const honey = Color(0xffffc83d);
  static const honeyDeep = Color(0xffffb92e);

  /// The soft orange ledge under a yellow button; the ON toggle.
  static const amber = Color(0xffeb960f);
  static const tangerine = Color(0xffffa21a);

  /// Hairline of cards and the border of unpicked tabs.
  static const tan = Color(0xffebdccb);

  /// Effect chips ("클릭 +2").
  static const peach = Color(0xffffe7c7);
  static const peachEdge = Color(0xfff3d1a8);

  /// OFF toggle and the empty part of a slider.
  static const taupe = Color(0xffd3c6ba);

  /// Toggle and slider knobs.
  static const knob = Color(0xffffffff);

  /// Soft drop shadows under panels (light) and windows (deep).
  static const shadow = Color(0x24000000);
  static const shadowDeep = Color(0x40000000);

  /// The hairline round every panel (H41: one thin line, no wooden frame).
  static const line = Color(0xffeadfd2);

  /// The window title's small caption colour and quiet section heads.
  static const caption = Color(0xffa3928a);

  /// How far a chunky button sinks while pressed.
  static const pressDepth = 2.0;

  /// The one soft shadow of a card.
  static const cardShadow = [BoxShadow(color: Color(0x14000000), offset: Offset(0, 1), blurRadius: 4)];
}

/// What a message, bubble or card is about; each kind has its own tint so
/// the windows are no longer all one beige (H41).
enum CozyTone {
  /// Plain warm white.
  neutral(Cozy.cream, Cozy.line, Cozy.ink),
  /// Explanations and hints ('로그인하면 충전할 수 있어요').
  info(Color(0xffedf4fb), Color(0xffc6dbef), Color(0xff2f6596)),
  /// Rewards and gold (출석 보상, 레벨업, 황금붕어빵력).
  reward(Color(0xfffff5d8), Color(0xfff3d27f), Color(0xff9a6200)),
  /// Errors and things to fix (저장 확인 필요, 실패).
  warning(Color(0xfffdeeea), Color(0xfff2c3b8), Color(0xffb23f28)),
  /// Done and good results (완료, 성공).
  success(Color(0xffebf6ee), Color(0xffc3e3cd), Color(0xff2e7a4c));

  /// The face, its hairline and the text/icon colour on it.
  final Color fill, edge, text;
  const CozyTone(this.fill, this.edge, this.text);
}

/// Whether the cozy widgets below keep still: the player's 모션 줄이기
/// setting, given by [GameApp], or the platform's reduced animations.
class CozyMotion extends InheritedWidget {
  final bool reduce;
  const CozyMotion({super.key, required this.reduce, required super.child});

  static bool reduceOf(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true ||
      (context.dependOnInheritedWidgetOfExactType<CozyMotion>()?.reduce ??
          false);

  @override
  bool updateShouldNotify(CozyMotion oldWidget) => oldWidget.reduce != reduce;
}

/// Ink and tap handling for the chunky buttons: the child sinks by
/// [Cozy.pressDepth] while pressed (not with [CozyMotion] reduced, and not
/// when disabled).
class CozyPressable extends StatefulWidget {
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final ShapeBorder? customBorder;
  final Widget child;
  const CozyPressable(
      {super.key,
      required this.onPressed,
      required this.child,
      this.borderRadius = BorderRadius.zero,
      this.customBorder});

  @override
  State<CozyPressable> createState() => _CozyPressableState();
}

class _CozyPressableState extends State<CozyPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sink =
        _down && widget.onPressed != null && !CozyMotion.reduceOf(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onPressed,
        onHighlightChanged: (down) => setState(() => _down = down),
        borderRadius: widget.borderRadius,
        customBorder: widget.customBorder,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            transform:
                Matrix4.translationValues(0, sink ? Cozy.pressDepth : 0, 0),
            child: widget.child),
      ),
    );
  }
}

/// The mockup's chunky bottom edge: [child] (with the same [radius]) sits on
/// a [color] strip showing [depth] below it. A rounded [Border] cannot vary
/// its colour per side, so the ledge is a backing instead.
class _Ledge extends StatelessWidget {
  static const depth = 2.0;
  final Color color;
  final double radius;
  final Widget child;
  const _Ledge(
      {required this.color, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(radius)),
      child:
          Padding(padding: const EdgeInsets.only(bottom: depth), child: child));
}

/// A card: warm white with one hairline and a soft shadow (H41; it used to
/// be a double wooden border). [tone] tints it for a kind of message.
class CozyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final CozyTone tone;
  const CozyPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      this.radius = 14,
      this.tone = CozyTone.neutral});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: tone.fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: tone.edge),
            boxShadow: Cozy.cardShadow),
        padding: padding,
        child: DefaultTextStyle.merge(
            style: TextStyle(color: tone == CozyTone.neutral ? Cozy.ink : tone.text), child: child),
      );
}

/// A one-line message in a tinted box with its icon: the info, reward,
/// warning or success line of a window (H41).
class CozyNotice extends StatelessWidget {
  final String text;
  final CozyTone tone;
  final Widget? icon;
  final double fontSize;
  const CozyNotice(this.text, {super.key, this.tone = CozyTone.info, this.icon, this.fontSize = 13});

  IconData get _glyph => switch (tone) {
        CozyTone.info || CozyTone.neutral => Icons.info_outline_rounded,
        CozyTone.reward => Icons.card_giftcard_rounded,
        CozyTone.warning => Icons.error_outline_rounded,
        CozyTone.success => Icons.check_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: tone.fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.edge)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: icon ?? Icon(_glyph, size: fontSize + 3, color: tone.text)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: fontSize, height: 1.3, color: tone.text))),
        ]),
      );
}

/// A speech bubble with a small tail (손님 말, 결과 한마디): white for a
/// voice, or a [CozyTone] tint for a game message (H41).
class CozyBubble extends StatelessWidget {
  final Widget child;
  final CozyTone tone;

  /// Where the tail points: down from the bubble's bottom centre (null: no
  /// tail).
  final bool tail;
  final EdgeInsetsGeometry padding;
  const CozyBubble(
      {super.key,
      required this.child,
      this.tone = CozyTone.neutral,
      this.tail = true,
      this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7)});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BubblePainter(tone.fill, tone.edge, tail),
        child: Padding(
          padding: EdgeInsets.only(bottom: tail ? _BubblePainter.tailHeight : 0),
          child: Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                  style: TextStyle(color: tone == CozyTone.neutral ? Cozy.ink : tone.text), child: child)),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  static const tailHeight = 7.0;
  final Color fill, edge;
  final bool tail;
  const _BubblePainter(this.fill, this.edge, this.tail);

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height - (tail ? tailHeight : 0));
    final r = body.height / 2 < 14 ? body.height / 2 : 14.0;
    final path = Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(r)));
    if (tail) {
      final cx = size.width / 2;
      path.addPath(
          Path()
            ..moveTo(cx - 7, body.bottom - 1)
            ..lineTo(cx, size.height)
            ..lineTo(cx + 7, body.bottom - 1)
            ..close(),
          Offset.zero);
    }
    canvas.drawShadow(path, Cozy.shadow, 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = edge);
    // Hide the seam between the body and the tail.
    if (tail) {
      final cx = size.width / 2;
      canvas.drawRect(Rect.fromLTRB(cx - 6, body.bottom - 2, cx + 6, body.bottom + 0.5), Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.fill != fill || old.edge != edge || old.tail != tail;
}

/// Round wooden button of the concept HUD (menu, settings).
class CozyRoundButton extends StatelessWidget {
  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
  const CozyRoundButton(
      {super.key,
      required this.tooltip,
      required this.icon,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          excludeSemantics: true,
          onTap: onPressed,
          child: Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Cozy.cream,
                border: Border.fromBorderSide(BorderSide(color: Cozy.line)),
                boxShadow: Cozy.cardShadow),
            child: CozyPressable(
                onPressed: onPressed,
                customBorder: const CircleBorder(),
                child:
                    SizedBox.square(dimension: 44, child: Center(child: icon))),
          ),
        ),
      );
}

/// The app theme in the concept UI's look (3.5_completed_game_mockups): the rounded Jua font,
/// dark chocolate text, cream surfaces with wooden borders and yellow
/// buttons, chips and toggles.
ThemeData cozyTheme() {
  const line = BorderSide(color: Cozy.woodLight, width: 1);
  final scheme = ColorScheme.fromSeed(
    seedColor: Cozy.orangeDeep,
    primary: Cozy.orangeDeep,
    onPrimary: Cozy.ink,
    primaryContainer: Cozy.orange,
    onPrimaryContainer: Cozy.ink,
    secondaryContainer: Cozy.honey,
    onSecondaryContainer: Cozy.ink,
    surface: Cozy.cream,
    onSurface: Cozy.ink,
    surfaceContainerLow: Cozy.cream,
    surfaceContainer: Cozy.cream,
    surfaceContainerHigh: Cozy.creamDeep,
    surfaceContainerHighest: Cozy.creamDeep,
    outline: Cozy.woodLight,
    outlineVariant: Cozy.line,
  );
  final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), side: line);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
    colorScheme: scheme,
    scaffoldBackgroundColor: Cozy.cream,
    splashFactory: InkRipple.splashFactory,
    dividerTheme: const DividerThemeData(color: Cozy.line, thickness: 1, space: 16),
    textTheme: const TextTheme()
        .apply(bodyColor: Cozy.ink, displayColor: Cozy.ink, fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback),
    // H41: a flat honey face with no dark outline; quiet when disabled.
    filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? Cozy.creamDeep
                    : Cozy.honey),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? Cozy.inkSoft
                    : Cozy.ink),
            elevation: const WidgetStatePropertyAll(0),
            textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16)),
            shape: WidgetStateProperty.resolveWith((states) =>
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: states.contains(WidgetState.disabled)
                        ? const BorderSide(color: Cozy.line)
                        : const BorderSide(color: Cozy.honeyDeep))))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            backgroundColor: Cozy.cream,
            foregroundColor: Cozy.ink,
            side: line,
            textStyle: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16),
            shape: shape)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Cozy.wood)),
    chipTheme: ChipThemeData(
        backgroundColor: Cozy.cream,
        selectedColor: Cozy.honey,
        side: const BorderSide(color: Cozy.line),
        labelStyle: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, color: Cozy.ink),
        checkmarkColor: Cozy.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    cardTheme: CardThemeData(
        color: Cozy.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Cozy.line))),
    dialogTheme: DialogThemeData(
        backgroundColor: Cozy.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Cozy.line))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0),
    switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Cozy.knob),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Cozy.tangerine
                : Cozy.taupe),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)),
    // A rounded honey bar with a white knob.
    sliderTheme: SliderThemeData(
        trackHeight: 10,
        activeTrackColor: Cozy.honey,
        inactiveTrackColor: Cozy.creamDeep,
        disabledActiveTrackColor: Cozy.tan,
        disabledInactiveTrackColor: Cozy.creamDeep,
        thumbColor: Cozy.knob,
        disabledThumbColor: Cozy.creamDeep,
        overlayColor: Cozy.honeyDeep.withValues(alpha: .2),
        trackShape: const CozySliderTrackShape(),
        thumbShape: const CozySliderThumbShape(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        valueIndicatorColor: Cozy.woodDark,
        valueIndicatorTextStyle:
            const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, color: Cozy.cream)),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Cozy.orangeDeep),
    listTileTheme: const ListTileThemeData(textColor: Cozy.ink),
    snackBarTheme: SnackBarThemeData(
        backgroundColor: Cozy.ink.withValues(alpha: .92),
        contentTextStyle: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, color: Cozy.cream)),
  );
}

/// The mockup's volume bar: a rounded bar with a wooden outline, yellow up
/// to the knob and taupe after it.
class CozySliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const CozySliderTrackShape();

  @override
  void paint(PaintingContext context, Offset offset,
      {required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required Animation<double> enableAnimation,
      required TextDirection textDirection,
      required Offset thumbCenter,
      Offset? secondaryOffset,
      bool isEnabled = false,
      bool isDiscrete = false}) {
    final rect = getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete);
    final radius = Radius.circular(rect.height / 2);
    final whole = RRect.fromRectAndRadius(rect, radius);
    final canvas = context.canvas;
    canvas.drawRRect(
        whole,
        Paint()
          ..color = (isEnabled
                  ? sliderTheme.inactiveTrackColor
                  : sliderTheme.disabledInactiveTrackColor) ??
              Cozy.taupe);
    final ltr = textDirection == TextDirection.ltr;
    final active = ltr
        ? Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom)
        : Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom);
    canvas.save();
    canvas.clipRRect(whole);
    canvas.drawRect(
        active,
        isEnabled
            ? (Paint()
              ..shader = const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Cozy.honeyLight, Cozy.honeyDeep])
                  .createShader(active))
            : (Paint()
              ..color = sliderTheme.disabledActiveTrackColor ?? Cozy.tan));
    canvas.restore();
    canvas.drawRRect(
        whole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Cozy.line);
  }
}

/// The volume bar's knob: a cream disc with a wooden outline.
class CozySliderThumbShape extends SliderComponentShape {
  const CozySliderThumbShape({this.radius = 12});
  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final enabled = enableAnimation.value > 0;
    final canvas = context.canvas;
    canvas.drawCircle(center.translate(0, 1.5), radius,
        Paint()
          ..color = Cozy.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(
        center, radius, Paint()..color = enabled ? Cozy.knob : Cozy.creamDeep);
    canvas.drawCircle(
        center,
        radius - .5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = enabled ? Cozy.honeyDeep : Cozy.line);
  }
}

/// A window: warm white with one hairline, rounded 22, and a deep soft
/// shadow (H41; it used to be a thick double wooden frame).
class CozyFrame extends StatelessWidget {
  final Widget child;
  const CozyFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0x2e000000), offset: Offset(0, 4), blurRadius: 16)
            ]),
        // A Material, so list tiles inside can paint their ink.
        child: Material(
            color: Cozy.cream,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Cozy.line)),
            child: child),
      );
}

/// The round close button: a white disc with a dark X (H41; it was a red
/// square in a cream and dark frame). 44 to tap, 36 seen.
class CozyCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CozyCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '닫기',
        child: Semantics(
          button: true,
          label: '닫기',
          excludeSemantics: true,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                decoration: const BoxDecoration(
                    color: Cozy.cream,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Cozy.line)),
                    boxShadow: Cozy.cardShadow),
                child: CozyPressable(
                  onPressed: onPressed,
                  customBorder: const CircleBorder(),
                  child: const SizedBox.square(
                      dimension: 36,
                      child: Icon(Icons.close_rounded, color: Cozy.ink, size: 22)),
                ),
              ),
            ),
          ),
        ),
      );
}

/// The '↶ 돌아가기' pill under a window: white with a hairline (H41).
class CozyBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CozyBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Cozy.line),
            boxShadow: Cozy.cardShadow),
        child: CozyPressable(
          key: const Key('sheet-back'),
          borderRadius: BorderRadius.circular(24),
          onPressed: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              PixelIcon('back', size: 22),
              SizedBox(width: 8),
              Text('돌아가기',
                  style: TextStyle(
                      fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 18, color: Cozy.ink)),
            ]),
          ),
        ),
      );
}

/// A settings row like the concept: an icon, the name and an ON/OFF pill.
/// Tapping anywhere on the row toggles it.
class CozySettingRow extends StatelessWidget {
  /// A [PixelIcon], or a system [Icon] where no pixel art exists yet.
  final Widget icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const CozySettingRow(
      {super.key,
      required this.icon,
      required this.label,
      this.subtitle,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          toggled: value,
          label: label,
          excludeSemantics: true,
          onTap: () => onChanged(!value),
          child: Material(
            color: Cozy.cream,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Cozy.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(children: [
                  SizedBox.square(dimension: 28, child: Center(child: icon)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: const TextStyle(
                                fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 18)),
                        if (subtitle case final text?)
                          Text(text,
                              style: const TextStyle(
                                  fontSize: 12, color: Cozy.inkSoft)),
                      ])),
                  CozyOnOff(value: value),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// The concept's ON/OFF pill: tangerine with ON, taupe with OFF, and a
/// cream knob.
class CozyOnOff extends StatelessWidget {
  final bool value;
  const CozyOnOff({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final knob = Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
            color: Cozy.knob,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Cozy.shadow, offset: Offset(0, 1), blurRadius: 3)]));
    // Shrinks to fit the pill whatever the font.
    final text = Flexible(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value ? 'ON' : 'OFF',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                    fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: Colors.white))));
    return AnimatedContainer(
      duration: CozyMotion.reduceOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      width: 72,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: value ? Cozy.tangerine : Cozy.taupe,
          borderRadius: BorderRadius.circular(17)),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: value
              ? [const SizedBox(width: 4), text, knob]
              : [knob, text, const SizedBox(width: 4)]),
    );
  }
}

/// The shared face of [CozyPrimaryButton] and [CozyButton]: a dark wooden
/// outline, then a face with a ledge at the bottom.
class _CozyButtonFace extends StatelessWidget {
  final bool primary;
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final double minHeight, fontSize;
  final EdgeInsetsGeometry padding;
  const _CozyButtonFace(
      {required this.primary,
      required this.onPressed,
      required this.label,
      required this.icon,
      required this.minHeight,
      required this.fontSize,
      required this.padding});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    const radius = 12.0;
    // H41: no dark outline. The main button is honey on a soft amber
    // ledge; the other is white with a hairline; disabled is a flat well.
    final (face, ledge, edge) = !enabled
        ? (const BoxDecoration(color: Cozy.creamDeep), Cozy.creamDeep, Cozy.line)
        : primary
            ? (
                const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Cozy.honeyLight, Cozy.honey])),
                Cozy.amber,
                Cozy.honeyDeep
              )
            : (const BoxDecoration(color: Cozy.cream), Cozy.line, Cozy.woodLight);
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled ? Cozy.cardShadow : null),
      child: CozyPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: _Ledge(
          color: ledge,
          radius: radius,
          child: Container(
            // The same outer size as before H41 (it had a 2px wooden frame).
            constraints: BoxConstraints(minHeight: minHeight + 4 - _Ledge.depth),
            padding: padding.add(const EdgeInsets.symmetric(horizontal: 2)),
            decoration: face.copyWith(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: edge)),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon case final icon?) ...[icon, const SizedBox(width: 6)],
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                        fontSize: fontSize,
                        color: enabled ? Cozy.ink : Cozy.inkSoft)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mockup's yellow main button ("강화", "구매", "적용", "저장"): honey
/// face, orange ledge and a dark wooden outline. Cream with faded text when
/// [onPressed] is null.
class CozyPrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final double minHeight, fontSize;
  final EdgeInsetsGeometry padding;
  const CozyPrimaryButton(
      {super.key,
      required this.onPressed,
      required this.label,
      this.icon,
      this.minHeight = 44,
      this.fontSize = 18,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});

  @override
  Widget build(BuildContext context) => _CozyButtonFace(
      primary: true,
      onPressed: onPressed,
      label: label,
      icon: icon,
      minHeight: minHeight,
      fontSize: fontSize,
      padding: padding);
}

/// The secondary cream button next to a [CozyPrimaryButton] ("버리기",
/// "취소"): the same shape on cream.
class CozyButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;
  final double minHeight, fontSize;
  final EdgeInsetsGeometry padding;
  const CozyButton(
      {super.key,
      required this.onPressed,
      required this.label,
      this.icon,
      this.minHeight = 44,
      this.fontSize = 18,
      this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});

  @override
  Widget build(BuildContext context) => _CozyButtonFace(
      primary: false,
      onPressed: onPressed,
      label: label,
      icon: icon,
      minHeight: minHeight,
      fontSize: fontSize,
      padding: padding);
}

/// A small effect chip ("클릭 +2", "초당 +5"), peach or a [CozyTone] tint.
class CozyChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final CozyTone? tone;
  const CozyChip({super.key, required this.label, this.icon, this.tone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: tone?.fill ?? Cozy.peach,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tone?.edge ?? Cozy.peachEdge)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon case final icon?) ...[icon, const SizedBox(width: 4)],
          Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14,
                      color: tone?.text ?? Cozy.ink))),
        ]),
      );
}

/// One tab of a [CozyTabBar]; [key] goes on the tab's tap target.
class CozyTab<T> {
  final T value;
  final String label;
  final Widget? icon;
  final Key? key;
  const CozyTab(this.value, this.label, {this.icon, this.key});
}

/// A row of equal tabs as one segmented control (H41): a sunk well, the
/// picked tab a honey pill, the others plain text.
class CozyTabBar<T> extends StatelessWidget {
  final List<CozyTab<T>> tabs;
  final T selected;
  final ValueChanged<T>? onSelected;
  final double height;
  const CozyTabBar(
      {super.key,
      required this.tabs,
      required this.selected,
      required this.onSelected,
      this.height = 44});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: Cozy.creamDeep,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Cozy.line)),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(child: _tab(tabs[i])),
          ],
        ]),
      );

  Widget _tab(CozyTab<T> tab) {
    final picked = tab.value == selected;
    return Semantics(
      button: true,
      selected: picked,
      label: tab.label,
      excludeSemantics: true,
      onTap: onSelected == null ? null : () => onSelected!(tab.value),
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: picked ? Cozy.honey : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: picked ? Cozy.cardShadow : null),
        child: CozyPressable(
          key: tab.key,
          onPressed: onSelected == null ? null : () => onSelected!(tab.value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: height - 3,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (tab.icon case final icon?) ...[icon, const SizedBox(width: 4)],
                Text(tab.label,
                    style: TextStyle(
                        fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 17,
                        color: picked ? Cozy.ink : Cozy.inkSoft)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mockup's menu row: a big icon, the title and a '>' on a cream card
/// with a wooden outline. [icon] may come wrapped in a count badge.
class CozyMenuRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? subtitle;
  final Key? subtitleKey;
  final VoidCallback? onPressed;
  final double iconSize, minHeight;
  const CozyMenuRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.onPressed,
      this.subtitle,
      this.subtitleKey,
      this.iconSize = 48,
      this.minHeight = 64});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Cozy.line),
            boxShadow: Cozy.cardShadow),
        child: CozyPressable(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: FittedBox(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 20, color: Cozy.ink)),
                    if (subtitle case final text?)
                      Text(text,
                          key: subtitleKey,
                          style: const TextStyle(
                              color: Cozy.inkSoft, fontSize: 12)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: Cozy.caption, size: 26),
            ]),
          ),
        ),
      );
}
