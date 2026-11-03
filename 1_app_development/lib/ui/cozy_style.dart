import 'package:flutter/material.dart';
import 'pixel_sprites.dart';

/// Colours of the concept art (3_original_images_and_visual_references/3.2_visual_design_references_20261006):
/// cream panels in wooden frames, dark chocolate text, orange buttons.
/// The button and control colours below are sampled from
/// 3.5_completed_game_mockups/서브UI5종 (coordination/visual-00-gap.md).
class Cozy {
  Cozy._();
  static const cream = Color(0xfffef1d6);
  static const creamDeep = Color(0xfffee6bc);
  static const wood = Color(0xff7d3419);
  static const woodLight = Color(0xffc1682d);
  static const woodDark = Color(0xff68311f);
  static const ink = Color(0xff3a1e1a);
  static const inkSoft = Color(0xff7a6963);
  static const orange = Color(0xfffbaf5a);
  static const orangeDeep = Color(0xffe39e57);
  static const brick = Color(0xffac3613);

  /// Yellow face of the main buttons and the picked tab, top to bottom.
  static const honeyLight = Color(0xffffd054);
  static const honey = Color(0xfffdbe38);
  static const honeyDeep = Color(0xfffeb432);

  /// The orange ledge under a yellow button; the ON toggle.
  static const amber = Color(0xfff07d0c);
  static const tangerine = Color(0xfffd9607);

  /// Pale inner line of cards and the border of unpicked tabs.
  static const tan = Color(0xffe9b47e);

  /// Effect chips ("클릭 +2").
  static const peach = Color(0xfffdd09c);
  static const peachEdge = Color(0xfff0b47a);

  /// OFF toggle and the empty part of a slider.
  static const taupe = Color(0xff8a6e62);

  /// Toggle and slider knobs.
  static const knob = Color(0xfffff6e8);

  /// Drop shadows under panels (light) and frames (deep).
  static const shadow = Color(0x55000000);
  static const shadowDeep = Color(0x66000000);

  /// How far a chunky button sinks while pressed.
  static const pressDepth = 2.0;
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
  static const depth = 3.0;
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

/// Cream panel with the double wooden border of the concept HUD and menus:
/// a wooden outline, then a pale inner line.
class CozyPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const CozyPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      this.radius = 12});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.wood,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(2),
        child: Container(
            decoration: BoxDecoration(
                color: Cozy.cream,
                borderRadius: BorderRadius.circular(radius - 2),
                border: Border.all(color: Cozy.tan, width: 1.5)),
            padding: padding,
            child: DefaultTextStyle.merge(
                style: const TextStyle(color: Cozy.ink), child: child)),
      );
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
                color: Cozy.woodDark,
                border: Border.fromBorderSide(
                    BorderSide(color: Cozy.orangeDeep, width: 2)),
                boxShadow: [
                  BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))
                ]),
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
  const wood = BorderSide(color: Cozy.wood, width: 2);
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
  );
  final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), side: wood);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Jua',
    colorScheme: scheme,
    scaffoldBackgroundColor: Cozy.cream,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme()
        .apply(bodyColor: Cozy.ink, displayColor: Cozy.ink, fontFamily: 'Jua'),
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
            textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'Jua', fontSize: 16)),
            shape: WidgetStateProperty.resolveWith((states) =>
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: states.contains(WidgetState.disabled)
                        ? const BorderSide(color: Cozy.tan, width: 2)
                        : const BorderSide(color: Cozy.woodDark, width: 2))))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            backgroundColor: Cozy.cream,
            foregroundColor: Cozy.ink,
            side: wood,
            textStyle: const TextStyle(fontFamily: 'Jua', fontSize: 16),
            shape: shape)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Cozy.wood)),
    chipTheme: ChipThemeData(
        backgroundColor: Cozy.cream,
        selectedColor: Cozy.honey,
        side: const BorderSide(color: Cozy.woodLight, width: 1.5),
        labelStyle: const TextStyle(fontFamily: 'Jua', color: Cozy.ink),
        checkmarkColor: Cozy.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    cardTheme: CardThemeData(
        color: Cozy.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Cozy.woodLight, width: 1.5))),
    dialogTheme: DialogThemeData(
        backgroundColor: Cozy.cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Cozy.wood, width: 3))),
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
    // The mockup's thick yellow volume bar with a cream knob.
    sliderTheme: SliderThemeData(
        trackHeight: 12,
        activeTrackColor: Cozy.honey,
        inactiveTrackColor: Cozy.taupe,
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
            const TextStyle(fontFamily: 'Jua', color: Cozy.cream)),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Cozy.orangeDeep),
    listTileTheme: const ListTileThemeData(textColor: Cozy.ink),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: Cozy.woodDark,
        contentTextStyle: TextStyle(fontFamily: 'Jua', color: Cozy.cream)),
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
          ..strokeWidth = 2
          ..color = isEnabled ? Cozy.woodDark : Cozy.tan);
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
    canvas.drawCircle(
        center.translate(0, 2), radius, Paint()..color = Cozy.shadow);
    canvas.drawCircle(
        center, radius, Paint()..color = enabled ? Cozy.knob : Cozy.creamDeep);
    canvas.drawCircle(
        center,
        radius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = enabled ? Cozy.woodDark : Cozy.tan);
  }
}

/// The concept sub-window frame: a cream panel with a thick double wooden
/// border.
class CozyFrame extends StatelessWidget {
  final Widget child;
  const CozyFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.woodDark,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Cozy.shadowDeep, offset: Offset(0, 3))
            ]),
        padding: const EdgeInsets.all(4),
        // A Material, so list tiles inside can paint their ink.
        child: Material(
            color: Cozy.cream,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Cozy.woodLight, width: 3)),
            child: child),
      );
}

/// The concept's red square close button with a white X inside a cream
/// border and a dark outline.
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
          child: Container(
            decoration: BoxDecoration(
                color: Cozy.woodDark,
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))
                ]),
            padding: const EdgeInsets.all(1.5),
            child: CozyPressable(
              onPressed: onPressed,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                    color: Cozy.brick,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Cozy.cream, width: 3)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      );
}

/// The concept's wooden '↶ 돌아가기' button under a sub-window.
class CozyBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CozyBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.wood,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))
            ]),
        child: CozyPressable(
          key: const Key('sheet-back'),
          borderRadius: BorderRadius.circular(14),
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: _Ledge(
              color: Cozy.peachEdge,
              radius: 11,
              // 48 in all with the ledge, as before.
              child: Container(
                constraints: const BoxConstraints(minHeight: 48 - _Ledge.depth),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                decoration: BoxDecoration(
                    color: Cozy.cream,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Cozy.tan, width: 1.5)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  PixelIcon('back', size: 24),
                  SizedBox(width: 8),
                  Text('돌아가기',
                      style: TextStyle(
                          fontFamily: 'Jua', fontSize: 20, color: Cozy.ink)),
                ]),
              ),
            ),
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
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Cozy.woodLight, width: 1.5)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
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
                                fontFamily: 'Jua', fontSize: 20)),
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
        decoration: BoxDecoration(
            color: Cozy.knob,
            shape: BoxShape.circle,
            border: Border.all(color: Cozy.woodDark, width: 2)));
    // Shrinks to fit the pill whatever the font.
    final text = Flexible(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value ? 'ON' : 'OFF',
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                    fontFamily: 'Jua', fontSize: 16, color: Colors.white))));
    return AnimatedContainer(
      duration: CozyMotion.reduceOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      width: 84,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: value ? Cozy.tangerine : Cozy.taupe,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Cozy.woodDark, width: 2)),
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
    final (face, ledge) = !enabled
        ? (const BoxDecoration(color: Cozy.creamDeep), Cozy.tan)
        : primary
            ? (
                const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Cozy.honeyLight, Cozy.honey, Cozy.honeyDeep])),
                Cozy.amber
              )
            : (const BoxDecoration(color: Cozy.cream), Cozy.peachEdge);
    return Container(
      decoration: BoxDecoration(
          color: enabled ? Cozy.woodDark : Cozy.tan,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled
              ? const [BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))]
              : null),
      padding: const EdgeInsets.all(2),
      child: CozyPressable(
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(radius - 2),
        child: _Ledge(
          color: ledge,
          radius: radius - 2,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight - _Ledge.depth),
            padding: padding,
            decoration:
                face.copyWith(borderRadius: BorderRadius.circular(radius - 2)),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon case final icon?) ...[icon, const SizedBox(width: 6)],
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Jua',
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

/// The mockup's small effect chip ("클릭 +2", "초당 +5", "30초 2배").
class CozyChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  const CozyChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Cozy.peach,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Cozy.peachEdge, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon case final icon?) ...[icon, const SizedBox(width: 4)],
          Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Jua', fontSize: 14, color: Cozy.ink))),
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

/// The mockup's row of equal tabs (장비/꾸미기/테마, 헤어/의상/소품): the
/// picked one is a yellow button with a small point under it, the others
/// cream.
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
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: _tab(tabs[i])),
        ],
      ]);

  Widget _tab(CozyTab<T> tab) {
    final picked = tab.value == selected;
    return Semantics(
      button: true,
      selected: picked,
      label: tab.label,
      excludeSemantics: true,
      onTap: onSelected == null ? null : () => onSelected!(tab.value),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
              color: picked ? Cozy.woodDark : Cozy.tan,
              borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(1.5),
          child: CozyPressable(
            key: tab.key,
            onPressed: onSelected == null ? null : () => onSelected!(tab.value),
            borderRadius: BorderRadius.circular(9),
            child: _Ledge(
              color: picked ? Cozy.amber : Cozy.peachEdge,
              radius: 9,
              child: Container(
                height: height - _Ledge.depth,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    gradient: picked
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Cozy.honeyLight, Cozy.honeyDeep])
                        : null,
                    color: picked ? null : Cozy.cream,
                    borderRadius: BorderRadius.circular(9)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (tab.icon case final icon?) ...[
                      icon,
                      const SizedBox(width: 4)
                    ],
                    Text(tab.label,
                        style: const TextStyle(
                            fontFamily: 'Jua', fontSize: 18, color: Cozy.ink)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (picked)
          const Positioned(
              left: 0,
              right: 0,
              bottom: -5,
              child: IgnorePointer(
                  child: Center(
                      child: CustomPaint(
                          size: Size(12, 7), painter: _TabPointPainter())))),
      ]),
    );
  }
}

class _TabPointPainter extends CustomPainter {
  const _TabPointPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final point = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(point, Paint()..color = Cozy.amber);
    canvas.drawPath(
        point,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Cozy.woodDark);
  }

  @override
  bool shouldRepaint(covariant _TabPointPainter oldDelegate) => false;
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
            color: Cozy.wood,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(2),
        child: CozyPressable(
          onPressed: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Cozy.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Cozy.tan, width: 1.5)),
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
                            fontFamily: 'Jua', fontSize: 22, color: Cozy.ink)),
                    if (subtitle case final text?)
                      Text(text,
                          key: subtitleKey,
                          style: const TextStyle(
                              color: Cozy.inkSoft, fontSize: 12)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: Cozy.wood, size: 30),
            ]),
          ),
        ),
      );
}
