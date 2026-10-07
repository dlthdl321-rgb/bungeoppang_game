import 'package:flutter/material.dart';
import 'pixel_sprites.dart';

/// Colours of the concept art (이미지/붕어빵게임_개발에셋_261006_1905_01):
/// cream panels in wooden frames, dark chocolate text, orange buttons.
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
}

/// Cream panel with the double wooden border of the concept HUD and menus.
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
              BoxShadow(color: Color(0x55000000), offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(2),
        child: Container(
            decoration: BoxDecoration(
                color: Cozy.cream,
                borderRadius: BorderRadius.circular(radius - 2),
                border: Border.all(color: Cozy.woodLight, width: 1.5)),
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
          child: Material(
              color: Cozy.woodDark,
              shape: const CircleBorder(
                  side: BorderSide(color: Cozy.orangeDeep, width: 2)),
              child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: SizedBox.square(
                      dimension: 48, child: Center(child: icon)))),
        ),
      );
}

/// The app theme in the concept UI's look (07_UI): the rounded Jua font,
/// dark chocolate text, cream surfaces with wooden borders and orange
/// buttons, chips and toggles.
ThemeData cozyTheme() {
  const wood = BorderSide(color: Cozy.wood, width: 2);
  final scheme = ColorScheme.fromSeed(
    seedColor: Cozy.orangeDeep,
    primary: Cozy.orangeDeep,
    onPrimary: Cozy.ink,
    primaryContainer: Cozy.orange,
    onPrimaryContainer: Cozy.ink,
    secondaryContainer: Cozy.orange,
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
        style: FilledButton.styleFrom(
            backgroundColor: Cozy.orange,
            foregroundColor: Cozy.ink,
            disabledBackgroundColor: Cozy.creamDeep,
            disabledForegroundColor: Cozy.inkSoft,
            textStyle: const TextStyle(fontFamily: 'Jua', fontSize: 16),
            shape: shape)),
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
        selectedColor: Cozy.orange,
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
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Cozy.orangeDeep
                : const Color(0xffb8b0a8)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)),
    sliderTheme: const SliderThemeData(
        activeTrackColor: Cozy.orangeDeep,
        thumbColor: Cozy.orange,
        inactiveTrackColor: Cozy.creamDeep),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Cozy.orangeDeep),
    listTileTheme: const ListTileThemeData(textColor: Cozy.ink),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: Cozy.woodDark,
        contentTextStyle: TextStyle(fontFamily: 'Jua', color: Cozy.cream)),
  );
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
              BoxShadow(color: Color(0x66000000), offset: Offset(0, 3))
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

/// The concept's red square close button with a white X.
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
          child: Material(
            color: Cozy.brick,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Cozy.cream, width: 3)),
            child: InkWell(
                customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: onPressed,
                child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: 30))),
          ),
        ),
      );
}

/// The concept's wooden '↶ 돌아가기' button under a sub-window.
class CozyBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CozyBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
        color: Cozy.wood,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('sheet-back'),
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Container(
            margin: const EdgeInsets.all(3),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
                color: Cozy.cream,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Cozy.woodLight, width: 1.5)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              PixelIcon('back', size: 24),
              SizedBox(width: 8),
              Text('돌아가기',
                  style: TextStyle(
                      fontFamily: 'Jua', fontSize: 20, color: Cozy.ink)),
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

/// The concept's ON/OFF pill: orange with ON, grey with OFF.
class CozyOnOff extends StatelessWidget {
  final bool value;
  const CozyOnOff({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final knob = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: Colors.white,
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
      duration: const Duration(milliseconds: 150),
      width: 84,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: value ? Cozy.orangeDeep : const Color(0xff8f8178),
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
