import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../achievement_config.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../home_presentation.dart';
import '../mission_alerts.dart';
import '../missions.dart';
import '../prestige_rules.dart';
import '../progress_rules.dart';
import 'bake_target.dart';
import 'boost_effects.dart';
import 'cook_cut.dart';
import 'count_badge.dart';
import 'cozy_style.dart';
import 'fish_painter.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'weather_layer.dart';

/// Home screen laid out like the concept art (07_UI/메인UI_화면): striped
/// awning and HUD on top, the big bungeoppang in the middle, the griddle and
/// the vendor's cooking cut at the bottom, and a menu bar under them.
class NightHome extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;
  const NightHome({super.key, required this.controller, required this.onOpen});

  static const cream = Cozy.cream;

  /// Layout width is capped for tablets.
  static const maxWidth = 560.0;
  static const navHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final reduce = state.settings.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 19;
    final padding = MediaQuery.paddingOf(context);
    final e = state.equippedCosmetic;
    return Scaffold(
      backgroundColor: Cozy.woodDark,
      body: RepaintBoundary(
        key: const Key('home-capture'),
        child: LayoutBuilder(builder: (context, box) {
          final w = math.min(box.maxWidth, maxWidth);
          final side = (box.maxWidth - w) / 2;
          final griddleW = w * .94, griddleH = griddleW * 40 / 88;
          final cookW = w * .32, cookH = w * .27;
          final navBottom = navHeight + padding.bottom;
          final griddleBottom = navBottom - 10;
          final cookBottom = griddleBottom + griddleH * .7;
          // Space under the bungeoppang: the griddle and part of the cooking cut.
          final reserved = cookBottom + cookH * .35;
          final fishArea = box.maxHeight - padding.top - reserved;
          final scroll = largeText || fishArea < 360;
          // Large text scrolls the stage, so the fish keeps its own place.
          final stage = _stage(
              reduce,
              scroll
                  ? null
                  : NightStallPainter.bakedFishOnScreen(
                      box.biggest, e(CosmeticSlot.background)));
          return Stack(children: [
            Positioned.fill(
                child: RepaintBoundary(
                    child: CustomPaint(
                        key: const Key('stall-scene'),
                        painter: NightStallPainter(
                            background: e(CosmeticSlot.background),
                            night: isNightTime(
                                e(CosmeticSlot.time), DateTime.now()),
                            stove: null,
                            decoration: e(CosmeticSlot.decoration))))),
            Positioned.fill(
                child: IgnorePointer(
                    child: RepaintBoundary(
                        child: WeatherLayer(
                            background: e(CosmeticSlot.background),
                            reduceMotion: reduce)))),
            Positioned.fill(
                child: IgnorePointer(
                    child: CustomPaint(
                        painter:
                            StallFramePainter(lamp: e(CosmeticSlot.lamp))))),
            Positioned(
                left: side,
                width: w,
                top: padding.top,
                bottom: griddleBottom,
                child: IgnorePointer(
                    child: GuestArrivalLayer(
                        controller: controller, reduceMotion: reduce))),
            Positioned(
                left: side + (w - griddleW) / 2,
                width: griddleW,
                bottom: griddleBottom,
                height: griddleH,
                child: IgnorePointer(
                    child: CustomPaint(
                        key: const Key('griddle'),
                        painter: GriddlePainter(e(CosmeticSlot.stove))))),
            Positioned(
                left: side + (w - griddleW) / 2,
                width: griddleW,
                bottom: griddleBottom,
                height: griddleH,
                child: GoldenGriddleLayer(
                    controller: controller, reduceMotion: reduce)),
            Positioned(
                left: side,
                width: w,
                top: padding.top,
                bottom: reserved,
                child: scroll
                    ? SingleChildScrollView(
                        key: const Key('home-scroll'),
                        child: Column(children: [
                          _hud(),
                          SizedBox(height: largeText ? 300 : 260, child: stage),
                        ]))
                    : Column(children: [
                        _hud(),
                        Expanded(child: stage),
                      ])),
            Positioned(
                right: side + 8,
                width: cookW,
                bottom: cookBottom,
                height: cookH,
                child: CookCut(
                    equipped: e,
                    taps: state.records.lifetimeTaps,
                    reduceMotion: reduce,
                    greeting: controller.guestArrivals.isNotEmpty)),
            Positioned(
                left: side, width: w, bottom: 0, child: _nav(padding.bottom)),
          ]);
        }),
      ),
    );
  }

  Widget _hud() {
    final s = controller.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 26, child: _levelBadge()),
            const SizedBox(width: 6),
            Expanded(flex: 44, child: _balance()),
            const SizedBox(width: 6),
            Expanded(
                flex: 30,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _rate(const Key('auto-rate'), Icons.timer_outlined, '초당',
                          controller.currentAutoRate),
                      const SizedBox(height: 4),
                      _rate(const Key('tap-rate'), Icons.touch_app_outlined,
                          '클릭당', controller.currentTapRate),
                    ])),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          // Claimable mission rewards wait in the menu.
          CountBadge(
              count: claimableCount(s),
              badgeKey: const Key('menu-badge'),
              child: CozyRoundButton(
                  key: const Key('menu-menu'),
                  tooltip: '메뉴',
                  icon: const PixelIcon('menu', size: 28),
                  onPressed: () => onOpen('menu'))),
          Expanded(
              child: Column(children: [
            if (s.prestige.stars > 0)
              _note(const Key('home-prestige'),
                  '명성 별 ${s.prestige.stars} · 생산 +${(prestigePermille(s) - 1000) ~/ 10}%'),
            if (s.achievements.equippedTitle case final title?)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const PixelIcon('title', size: 16),
                const SizedBox(width: 3),
                Flexible(child: _note(const Key('home-title'), '칭호 · $title')),
              ]),
          ])),
          CozyRoundButton(
              tooltip: '설정',
              icon:
                  const PixelIcon('settings', size: 28),
              onPressed: () => onOpen('settings')),
        ]),
      ]),
    );
  }

  Widget _note(Key key, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(text,
          key: key,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: cream,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)])));

  Widget _levelBadge() {
    final s = controller.state;
    final next = activeLevelMission(s);
    final progress = levelProgressPermille(s);
    return Semantics(
      button: true,
      label:
          'Lv.${s.level} 레벨 미션 ${next == null ? '최고 레벨 달성' : '진행 ${progress ~/ 10}%'}',
      excludeSemantics: true,
      onTap: () => onOpen('missions'),
      child: InkWell(
        key: const Key('level-mission-entry'),
        onTap: () => onOpen('missions'),
        child: Container(
          decoration: BoxDecoration(
              color: Cozy.woodDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Cozy.orangeDeep, width: 2)),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(
                              text: 'Lv. ',
                              style:
                                  TextStyle(fontSize: 13, color: Cozy.orange)),
                          TextSpan(text: '${s.level}'),
                        ]),
                        key: const Key('current-level'),
                        style: const TextStyle(
                            color: cream,
                            fontSize: 22,
                            fontWeight: FontWeight.w900))),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                    key: const Key('level-progress'),
                    value: progress / 1000,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(4),
                    color: Cozy.orange,
                    backgroundColor: Cozy.ink,
                    semanticsLabel: '레벨 진행 상태',
                    semanticsValue: '${progress ~/ 10}%'),
              ]),
        ),
      ),
    );
  }

  Widget _balance() => Semantics(
        label: '보유 붕어빵 ${exactNumber(controller.state.buns)}개',
        onTap: () => onOpen('balance'),
        excludeSemantics: true,
        button: true,
        child: InkWell(
          onTap: () => onOpen('balance'),
          child: CozyPanel(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
            child: Row(children: [
              const PixelIcon('bun', size: 34),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('보유 붕어빵',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Cozy.inkSoft)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(compactNumber(controller.state.buns),
                                  key: const Key('balance-value'),
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Cozy.ink)),
                              const Text('개',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Cozy.ink)),
                            ]),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            '누적 ${compactNumber(controller.state.lifetime)}개',
                            key: const Key('lifetime-value'),
                            style: const TextStyle(
                                fontSize: 10, color: Cozy.inkSoft)),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      );

  Widget _rate(Key key, IconData icon, String label, BigInt value) => CozyPanel(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Cozy.wood),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('$label ${compactNumber(value)}개',
                  key: key,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  Widget _stage(bool reduce, Rect? fishOnScreen) => Column(children: [
        BoostBadge(controller: controller),
        Expanded(
            child: Stack(children: [
          Positioned.fill(
              child: BakeTarget(
                  controller: controller,
                  reduceMotion: reduce,
                  fishOnScreen: fishOnScreen)),
          // The combo floats above the bungeoppang in the round Jua font.
          if (controller.currentCombo >= comboDisplayMinimum)
            Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: IgnorePointer(
                    child: Center(
                        child: _ComboLabel(
                            combo: controller.currentCombo, reduce: reduce)))),
        ])),
      ]);

  Widget _nav(double bottomInset) {
    final claimable = claimableCount(controller.state);
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 6 + bottomInset),
      child: SizedBox(
        height: navHeight - 6,
        child: Row(children: [
          for (final (id, label, icon) in const <(String, String, Widget)>[
            ('menu', '메뉴', PixelIcon('menu', size: 28)),
            ('skills', '스킬', PixelIcon('skill', size: 34)),
            ('skins', '꾸미기', PixelIcon('tab_outfit', size: 34)),
            ('shop', '상점', PixelIcon('shop', size: 28)),
          ]) ...[
            if (id != 'menu') const SizedBox(width: 6),
            Expanded(
                child: CountBadge(
                    count: id == 'menu' ? claimable : 0,
                    badgeKey: const Key('menubar-badge'),
                    child: _NavButton(
                        // The HUD's round menu button already uses menu-menu.
                        id: id == 'menu' ? 'menubar' : id,
                        label: label,
                        icon: icon,
                        onPressed: () => onOpen(id)))),
          ],
        ]),
      ),
    );
  }
}

/// The small fish that flanks titles and labels (ui/title_fish).
class _TitleFish extends StatelessWidget {
  const _TitleFish();
  @override
  Widget build(BuildContext context) =>
      PixelArt(PixelSprites.screenArt('title_fish'), width: 18, height: 14);
}

class _NavButton extends StatelessWidget {
  final String id, label;
  final Widget icon;
  final VoidCallback onPressed;
  const _NavButton(
      {required this.id,
      required this.label,
      required this.icon,
      required this.onPressed});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Material(
          color: Cozy.wood,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('menu-$id'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color: Cozy.cream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Cozy.woodLight, width: 1.5)),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    icon,
                    const SizedBox(width: 4),
                    Text(label,
                        style: const TextStyle(
                            color: Cozy.ink, fontFamily: 'Jua', fontSize: 21)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Combo counter: colour steps at 20/50 and a short pop per new tap.
class _ComboLabel extends StatelessWidget {
  final int combo;
  final bool reduce;
  const _ComboLabel({required this.combo, required this.reduce});
  @override
  Widget build(BuildContext context) {
    final color = combo >= 50
        ? const Color(0xffffc94d)
        : combo >= 20
            ? const Color(0xffff9f6b)
            : NightHome.cream;
    // A chocolate outline all round, like the concept's chunky labels.
    const outline = [
      Shadow(color: Cozy.woodDark, offset: Offset(2, 0)),
      Shadow(color: Cozy.woodDark, offset: Offset(-2, 0)),
      Shadow(color: Cozy.woodDark, offset: Offset(0, 2)),
      Shadow(color: Cozy.woodDark, offset: Offset(0, -2)),
      Shadow(color: Cozy.woodDark, offset: Offset(2, 3)),
    ];
    final label = Row(mainAxisSize: MainAxisSize.min, children: [
      PixelIcon('combo', size: combo >= 20 ? 34 : 28),
      const SizedBox(width: 4),
      Text('$combo 콤보!',
          key: const Key('combo-label'),
          style: TextStyle(
              fontFamily: 'Jua',
              color: color,
              fontSize: combo >= 50
                  ? 40
                  : combo >= 20
                      ? 34
                      : 28,
              shadows: outline)),
    ]);
    if (reduce) return label;
    return TweenAnimationBuilder<double>(
        key: ValueKey(combo),
        tween: Tween(begin: 1.3, end: 1),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: label);
  }
}
