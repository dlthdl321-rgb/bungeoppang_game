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
import 'center_toast.dart';
import 'bake_target.dart';
import 'boost_effects.dart';
import 'cook_cut.dart';
import 'count_badge.dart';
import 'cozy_style.dart';
import 'lock_overlay.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'weather_layer.dart';
import 'workshop_home_layout.dart';

/// Home screen laid out like the concept art (3.5_completed_game_mockups/메인UI_화면): striped
/// awning and HUD on top, the big bungeoppang in the middle, the griddle and
/// the vendor's cooking cut at the bottom, and a menu bar under them.
/// What the Workshop status badge says (26번 4-1단계 F7).
enum WorkshopStatusKind { open, preparing, error }

class NightHomeHeaderData {
  final int level, progressPermille, claimable;
  final BigInt buns, lifetime, autoRate, tapRate;
  final String status;
  /// The badge's look: green dot in business, grey before opening, red for
  /// a save that needs checking.
  final WorkshopStatusKind statusKind;
  /// Whether the per-second and per-tap numbers show (26번 2단계: they open
  /// with the skill window at Lv.2).
  final bool showRates;
  /// 황금붕어빵력 beside 붕어빵력 in the HUD (26번 3차 피드백 H30), null
  /// hides it (the old clicker home).
  final BigInt? gold;
  const NightHomeHeaderData({required this.level, required this.progressPermille,
    required this.buns, required this.lifetime, required this.autoRate,
    required this.tapRate, required this.status, this.claimable = 0, this.showRates = true,
    this.statusKind = WorkshopStatusKind.open, this.gold});
}

class NightHome extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;

  /// Workshop supplies authoritative content while retaining the original stall.
  final Widget? header, griddleContent, vendor;
  final NightHomeHeaderData? headerData;
  /// Workshop's own centre stage. [cleanCounter] tells whether the
  /// background shows without its baked mold, so the stage draws the mold.
  /// [counterTop] is the sale counter's top on screen (null when the
  /// background has no measured towel), so the stage keeps clear of it.
  /// [moldLimit] is the higher of the counter's and the cooking cut's tops
  /// (26번 3차 피드백 H18): the special mold stays above it.
  final Widget Function(Rect? fishOnScreen, bool cleanCounter, double? counterTop, double? moldLimit)?
      centerBuilder;
  /// Workshop's sale counter: left of the cooking cut, its top on the red
  /// check towel of the background (DEC-038).
  final Widget? counter;

  /// The counter's one action button (sell, bake, open…), floating centred
  /// on the screen just above the counter (26번 4-1단계 F6, S4-1-Q6).
  final Widget? counterAction;

  /// A small slip just under the HUD's settings button, right edges lined
  /// up (26번 7단계: the '오늘' slip for 오늘의 주문서·출석; moved there from
  /// above the cooking cut by the 2nd mockup check, 2026-11-19).
  final Widget? counterSlip;

  /// A small button beside the business-state sign in the HUD (26번 시안
  /// 확인 2차: '영업 시작'·'이어서 영업'·'영업 종료' moved up there from the
  /// floating counter button). Null leaves the sign alone.
  final Widget? statusAction;

  /// The HUD's top-left round slot. The old clicker home keeps the menu
  /// button there; the Workshop home has its menu only in the bottom bar
  /// (26번 3차 피드백 H28) and puts the special bungeoppang's flavor here
  /// (H26, WorkshopFlavorButton). Null leaves the slot empty.
  final Widget? hudLeading;

  /// The stall lowered to the towel with guests behind it (26번 4-1단계,
  /// [WorkshopHomeLayout.active]): the lowered background, and [guests]
  /// laid out over the street down to the counter's top.
  final bool lowStall;
  /// Called twice: the pictures (taps false) under the stage, and their tap
  /// targets (taps true) over it. [clicker] is the lowered clicker's place
  /// in the same coordinates (null without a baked-fish place), so the tap
  /// targets keep off it.
  final Widget Function(Rect? clicker, bool taps)? guests;

  /// Null draws the stove art as it is. Otherwise the empty griddle with a
  /// bungeoppang only in these cavities (Workshop: the cooking cells; empty
  /// before opening). See GriddlePainter.filled.
  final Set<int>? griddleFilled;

  /// Null draws the griddle as before. False: closed and cold (the lid
  /// over the plate, no flames); true: open with the flames on and the lid
  /// standing above the griddle box, behind the counter (26번 4-2단계 F8,
  /// [workshopGriddleOpen]). The griddle box and its cells do not move.
  final bool? griddleOpen;
  final String Function(CosmeticSlot)? equipped;
  /// Bottom-menu buttons still locked, by destination id, with the reason
  /// ('Lv.2에 열려요'). They show the common hatched lock (26번 2단계) and
  /// a tap tells the reason instead of opening.
  final Map<String, String> navLocks;
  const NightHome(
      {super.key,
      required this.controller,
      required this.onOpen,
      this.headerData,
    this.header,
      this.griddleContent,
      this.vendor,
      this.centerBuilder,
      this.counter,
      this.counterAction,
      this.counterSlip,
      this.statusAction,
      this.hudLeading,
      this.lowStall = false,
      this.guests,
      this.griddleFilled,
      this.griddleOpen,
      this.equipped,
      this.navLocks = const {}});

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
    final e = equipped ?? state.equippedCosmetic;
    // The '오늘' slip follows the HUD's settings button wherever the HUD
    // lays it out (text size, scrolling stage).
    final settingsLink = LayerLink();
    return Scaffold(
      backgroundColor: Cozy.woodDark,
      body: RepaintBoundary(
        key: const Key('home-capture'),
        child: LayoutBuilder(builder: (context, box) {
          final w = math.min(box.maxWidth, maxWidth);
          final side = (box.maxWidth - w) / 2;
          final workshop = centerBuilder != null;
          final stove = PixelSprites.cosmetic(
              CosmeticSlot.stove, e(CosmeticSlot.stove));
          // Workshop: the griddle art spans the screen less 8 at each side
          // (DEC-038); its box has the art's own shape, so the art fills it.
          final griddleW = workshop ? w - 16 : w * .94;
          final griddleH = workshop
              ? griddleW * (stove?.height ?? 40) / (stove?.width ?? 80)
              : griddleW * 40 / 88;
          final cookW = w * WorkshopHomeLayout.cookCutShare, cookH = w * .27;
          final navBottom = navHeight + padding.bottom;
          final griddleBottom = navBottom - 10;
          final cookBottom = griddleBottom + griddleH * .7;
          // Space under the bungeoppang: the griddle and part of the cooking cut.
          final reserved = centerBuilder == null ? cookBottom + cookH * .35 : griddleBottom + griddleH * .85;
          final fishArea = box.maxHeight - padding.top - reserved;
          final scroll = largeText || fishArea < 360;
          // Large text scrolls the stage, so the fish keeps its own place.
          final night = isNightTime(e(CosmeticSlot.time), DateTime.now());
          final low = lowStall && centerBuilder != null;
          final cleanCounter = centerBuilder != null &&
              (low || PixelSprites.hasCleanBackground(e(CosmeticSlot.background), night));
          // The sale counter's top sits on the background's towel (DEC-038).
          final towelTop = counter == null
              ? null
              : NightStallPainter.towelTopOnScreen(
                  box.biggest, e(CosmeticSlot.background), night,
                  clean: cleanCounter, low: low);
          // Without a measured towel the counter sits above the griddle's
          // first row; the floating action keeps above it the same way.
          final counterBottom = griddleBottom + griddleH * .66;
          final actionBottom = towelTop == null
              ? counterBottom + 52 + WorkshopHomeLayout.actionGap
              : box.maxHeight - towelTop + WorkshopHomeLayout.actionGap;
          final fishRect = scroll && centerBuilder == null
              ? null
              : NightStallPainter.bakedFishOnScreen(
                  box.biggest, e(CosmeticSlot.background));
          // The lowered clicker (WorkshopMoldStage, S4-1-Q5) in the guest
          // layer's coordinates.
          final clicker = towelTop == null || fishRect == null ? null
              : Rect.fromLTRB(
                  (w - fishRect.width * WorkshopHomeLayout.clickerScale) / 2,
                  towelTop - WorkshopHomeLayout.clickerLift - fishRect.height * WorkshopHomeLayout.clickerScale - padding.top,
                  (w + fishRect.width * WorkshopHomeLayout.clickerScale) / 2,
                  towelTop - WorkshopHomeLayout.clickerLift - padding.top);
          // The cooking cut's top on screen (H18).
          final cookTop = box.maxHeight - cookBottom - cookH;
          final moldLimit = towelTop == null || scroll ? null : math.min(towelTop, cookTop);
          final stage = centerBuilder != null
              ? centerBuilder!(fishRect, cleanCounter, towelTop, moldLimit)
              : _stage(reduce, fishRect);
          return Stack(children: [
            Positioned.fill(
                child: RepaintBoundary(
                    child: CustomPaint(
                        key: const Key('stall-scene'),
                        painter: NightStallPainter(
                            background: e(CosmeticSlot.background),
                            night: night,
                            stove: null,
                            decoration: e(CosmeticSlot.decoration),
                            cleanCounter: cleanCounter,
                            lowStall: low)))),
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
            if (centerBuilder == null)
              Positioned(
                  left: side,
                  width: w,
                  top: padding.top,
                  bottom: griddleBottom,
                  child: IgnorePointer(
                      child: GuestArrivalLayer(
                          controller: controller, reduceMotion: reduce))),
            // Guests stand on the street, their feet hidden behind the
            // counter: under the HUD, the stage and the counter.
            if (low && guests != null && towelTop != null)
              Positioned(
                  left: side,
                  width: w,
                  top: padding.top,
                  height: math.max(0.0, towelTop - padding.top),
                  child: guests!(clicker, false)),
            // The open lid stands above the griddle box: over the guests,
            // under the stage and the counter (26번 4-2단계 F8).
            if (griddleOpen == true && stove != null)
              Positioned(
                  left: side + (w - griddleW) / 2,
                  width: griddleW,
                  bottom: griddleBottom + griddleH,
                  height: GriddleLidPainter.heightFor(griddleW, stove.width.toDouble()),
                  child: IgnorePointer(
                      child: CustomPaint(
                          key: const Key('griddle-lid'),
                          painter: GriddleLidPainter(e(CosmeticSlot.stove))))),
            Positioned(
                left: side + (w - griddleW) / 2,
                width: griddleW,
                bottom: griddleBottom,
                height: griddleH,
                child: IgnorePointer(
                    child: CustomPaint(
                        key: const Key('griddle'),
                        painter: GriddlePainter(e(CosmeticSlot.stove),
                            filled: griddleFilled,
                            closed: griddleOpen == false)))),
            Positioned(
                left: side + (w - griddleW) / 2,
                width: griddleW,
                bottom: griddleBottom,
                height: griddleH,
                child: griddleContent ??
                    GoldenGriddleLayer(
                        controller: controller, reduceMotion: reduce)),
            if (vendor != null) Positioned(
                right: side + 8, width: cookW, bottom: cookBottom, height: cookH,
                child: IgnorePointer(child: vendor!)),
            Positioned(
                left: side,
                width: w,
                top: padding.top,
                bottom: reserved,
                child: scroll
                    ? SingleChildScrollView(
                        key: const Key('home-scroll'),
                        child: Column(children: [
                          header ?? _hud(settingsLink),
                          SizedBox(
                              height: centerBuilder != null
                                  ? 460
                                  : largeText
                                      ? 300
                                      : 260,
                              child: stage),
                        ]))
                    : Column(children: [
                        header ?? _hud(settingsLink),
                        Expanded(child: stage),
                      ])),
            if (low && guests != null && towelTop != null)
              Positioned(
                  left: side,
                  width: w,
                  top: padding.top,
                  height: math.max(0.0, towelTop - padding.top),
                  child: guests!(clicker, true)),
            if (counter != null) Positioned(
                left: side + 8,
                width: w - 16 - (vendor == null ? 0 : cookW + 8),
                top: towelTop,
                // A background without a measured towel: just above the
                // griddle's first row of cells, as before.
                bottom: towelTop == null ? counterBottom : null,
                child: counter!),
            if (counterAction != null) Positioned(
                left: side,
                width: w,
                bottom: actionBottom,
                child: Center(child: counterAction!)),
            // Under the settings button, over the stage and the guests' tap
            // targets (2nd mockup check).
            if (counterSlip != null && header == null) Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                    link: settingsLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomRight,
                    followerAnchor: Alignment.topRight,
                    offset: const Offset(0, WorkshopHomeLayout.slipGap),
                    child: counterSlip!)),
            if (vendor == null) Positioned(
                right: side + 8,
                width: cookW,
                bottom: cookBottom,
                height: cookH,
                child: vendor ??
                    CookCut(
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

  Widget _hud(LayerLink settingsLink) {
    final s = controller.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _levelBadge(),
            const SizedBox(width: 6),
            Expanded(flex: 44, child: _balance()),
            if (headerData?.showRates ?? true) ...[
            const SizedBox(width: 6),
            Expanded(
                flex: 30,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _rate(const Key('auto-rate'), Icons.timer_outlined, '초당',
                          headerData?.autoRate ?? controller.currentAutoRate),
                      const SizedBox(height: 4),
                      _rate(const Key('tap-rate'), Icons.touch_app_outlined,
                          '클릭당', headerData?.tapRate ?? controller.currentTapRate),
                    ])),
            ],
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          // Claimable mission rewards wait in the menu. The Workshop home
          // has its menu only in the bottom bar (H28).
          if (centerBuilder == null)
            CountBadge(
                count: headerData?.claimable ?? claimableCount(s),
                badgeKey: const Key('menu-badge'),
                child: CozyRoundButton(
                    key: const Key('menu-menu'),
                    tooltip: '메뉴',
                    icon: const PixelIcon('menu', size: 28),
                    onPressed: () => onOpen('menu')))
          else
            SizedBox(width: 48, child: hudLeading),
          Expanded(
              child: Column(children: [
            if (headerData != null)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: WorkshopStatusBadge(text: headerData!.status, kind: headerData!.statusKind)),
                if (statusAction != null) statusAction!,
              ]),
            if (headerData == null && s.prestige.stars > 0)
              _note(const Key('home-prestige'),
                  '명성 별 ${s.prestige.stars} · 생산 +${(prestigePermille(s) - 1000) ~/ 10}%'),
            if (headerData == null) if (s.achievements.equippedTitle case final title?)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const PixelIcon('title', size: 16),
                const SizedBox(width: 3),
                Flexible(child: _note(const Key('home-title'), '칭호 · $title')),
              ]),
          ])),
          CompositedTransformTarget(
            link: settingsLink,
            child: CozyRoundButton(
                key: const Key('home-settings'),
                tooltip: '설정',
                icon: const PixelIcon('settings', size: 28),
                onPressed: () => onOpen('settings')),
          ),
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

  /// The level as a round emblem (26번 3차 피드백 H29 '레벨 표시가 낡아
  /// 보임'): a cream disc with 'Lv' and the number, the level-mission
  /// progress as a honey ring around it.
  static const levelSize = 62.0;
  Widget _levelBadge() {
    final s = controller.state;
    final next = activeLevelMission(s);
    final progress = headerData?.progressPermille ?? levelProgressPermille(s);
    final level = headerData?.level ?? s.level;
    return Semantics(
      button: true,
      label:
          'Lv.$level 레벨 미션 ${(headerData == null ? next == null : level >= 50) ? '최고 레벨 달성' : '진행 ${progress ~/ 10}%'}',
      excludeSemantics: true,
      onTap: () => onOpen('missions'),
      child: GestureDetector(
        key: const Key('level-mission-entry'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpen('missions'),
        child: Center(
          child: SizedBox.square(
            dimension: levelSize,
            child: CustomPaint(
              key: const Key('level-progress'),
              painter: _LevelRingPainter(progress / 1000),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Lv',
                      style: TextStyle(
                          fontSize: 11, height: 1, fontWeight: FontWeight.w800, color: Cozy.woodLight)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$level',
                        key: const Key('current-level'),
                        style: const TextStyle(
                            fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                            color: Cozy.ink, fontSize: 24, height: 1.05)),
                  ),
                ]),
              )),
            ),
          ),
        ),
      ),
    );
  }

  /// 붕어빵력 with a big icon and, in the Workshop, 황금붕어빵력 beside it
  /// (on one line when the card is wide, under it when the rates take the
  /// room) (26번 3차 피드백 H29·H30). A tap on the gold opens the gold packs.
  Widget _balance() {
    final gold = headerData?.gold;
    final buns = headerData?.buns ?? controller.state.buns;
    Widget bunRow(double icon, double font) => Semantics(
          label: '보유 붕어빵력 ${exactNumber(buns)}개',
          onTap: () => onOpen('balance'),
          excludeSemantics: true,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpen('balance'),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PixelIcon('bun', size: icon),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(compactNumber(buns),
                            key: const Key('balance-value'),
                            style: TextStyle(fontSize: font, fontWeight: FontWeight.w900, color: Cozy.ink)),
                        const Text('개',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Cozy.ink)),
                      ]),
                ),
              ),
            ]),
          ),
        );
    Widget goldRow(BigInt gold, double icon) => Semantics(
          label: '황금붕어빵력 ${exactNumber(gold)}개, 충전',
          onTap: () => onOpen('gold'),
          excludeSemantics: true,
          button: true,
          child: GestureDetector(
            key: const Key('hud-gold'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpen('gold'),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PixelIcon('gold_bun', size: icon),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(compactNumber(gold),
                      key: const Key('hud-gold-value'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xffa8700c))),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Cozy.honey),
                child: const Icon(Icons.add, size: 14, color: Cozy.ink),
              ),
            ]),
          ),
        );
    return CozyPanel(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      child: Builder(builder: (context) {
        if (gold == null) {
          return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            bunRow(36, 26),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                  '누적 ${compactNumber(headerData?.lifetime ?? controller.state.lifetime)}개',
                  key: const Key('lifetime-value'),
                  style: const TextStyle(fontSize: 10, color: Cozy.inkSoft)),
            ),
          ]);
        }
        // Wide (no rates column): both on one line, gold at the right.
        if (!(headerData?.showRates ?? true)) {
          return Row(children: [
            Expanded(child: bunRow(42, 28)),
            Container(width: 1, height: 30, color: Cozy.tan, margin: const EdgeInsets.symmetric(horizontal: 8)),
            Flexible(child: goldRow(gold, 28)),
          ]);
        }
        return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          bunRow(36, 24),
          Padding(padding: const EdgeInsets.only(left: 6), child: goldRow(gold, 22)),
        ]);
      }),
    );
  }

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

  /// The bottom menu's icon size and label size before any shrinking
  /// (26번 4-2단계 F10): the icon above its label. Every button uses the
  /// same pair, shrunk by the one factor the longest (or, with large text,
  /// tallest) label needs, so the four icons look the same size.
  static const navIconSize = 32.0, navLabelSize = 15.0;

  /// A locked bottom-menu button's padlock (26번 3차 피드백 H27: small, in
  /// the corner, never over the name).
  static const navLockSize = 18.0;
  static const _navItems = <(String, String, String)>[
    ('menu', '메뉴', 'nav_menu'),
    ('skills', '스킬', 'nav_skill'),
    ('skins', '꾸미기', 'nav_skins'),
    ('shop', '상점', 'nav_shop'),
  ];

  /// The shrink factor (at most 1) that fits the longest label in a button
  /// [inner] wide and the icon over the tallest label in [innerHeight].
  static double navScale(BuildContext context, double inner, double innerHeight) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0, tallest = 0.0;
    for (final (_, label, _) in _navItems) {
      final painter = TextPainter(
          text: TextSpan(text: label, style: _navLabelStyle(navLabelSize)),
          textDirection: TextDirection.ltr,
          textScaler: scaler)
        ..layout();
      widest = math.max(widest, painter.width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return math.min(1.0,
        math.min(inner / widest, innerHeight / (navIconSize + tallest)));
  }

  static TextStyle _navLabelStyle(double size) => TextStyle(
      color: Cozy.ink,
      fontFamily: 'Jua',
      fontFamilyFallback: Cozy.fontFallback,
      fontSize: size,
      height: 1.15);

  Widget _nav(double bottomInset) {
    // The Workshop home's only menu button carries the reward count (H28).
    final claimable = centerBuilder == null
        ? claimableCount(controller.state)
        : headerData?.claimable ?? 0;
    return Padding(
      key: const Key('home-nav'),
      padding: EdgeInsets.fromLTRB(8, 0, 8, 6 + bottomInset),
      child: SizedBox(
        height: navHeight - 6,
        child: LayoutBuilder(builder: (context, box) {
          // Button width less its 2 margin, 1.5 border and 4 breathing room
          // at each side.
          final inner = (box.maxWidth - 6 * (_navItems.length - 1)) / _navItems.length - 15;
          // Height less the 2 margin and 1.5 border at top and bottom.
          final k = navScale(context, inner, box.maxHeight - 7);
          return Row(children: [
          for (final (id, label, iconName) in _navItems) ...[
            if (id != 'menu') const SizedBox(width: 6),
            Builder(builder: (context) {
              final icon = PixelIcon(iconName, size: navIconSize * k);
              return Expanded(
                child: CountBadge(
                    count: id == 'menu' ? claimable : 0,
                    badgeKey: const Key('menubar-badge'),
                    child: navLocks[id] != null
                        ? Builder(
                            builder: (context) => LockedOverlay(
                                key: Key('menu-$id-locked'),
                                caption: '$label: ${navLocks[id]}',
                                showCaption: false,
                                // Small, in the top-right corner: the icon
                                // and the name stay readable (H27).
                                maxLock: navLockSize,
                                lockAlignment: const Alignment(.82, -.78),
                                onTap: () => showCenterToast(context, '$label: ${navLocks[id]}'),
                                child: _NavButton(
                                    id: id,
                                    label: label,
                                    icon: icon,
                                    labelSize: navLabelSize * k,
                                    onPressed: () {})))
                        : _NavButton(
                            // The HUD's round menu button already uses menu-menu.
                            id: id == 'menu' ? 'menubar' : id,
                            label: label,
                            icon: icon,
                            labelSize: navLabelSize * k,
                            onPressed: () => onOpen(id))));
            }),
          ],
        ]);
        }),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String id, label;
  final Widget icon;
  final double labelSize;
  final VoidCallback onPressed;
  const _NavButton(
      {required this.id,
      required this.label,
      required this.icon,
      required this.labelSize,
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    icon,
                    Text(label, style: NightHome._navLabelStyle(labelSize)),
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
              fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
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

/// The level emblem's ring: a dark rim with the level-mission progress in
/// honey from 12 o'clock, around a cream disc.
class _LevelRingPainter extends CustomPainter {
  final double progress;
  _LevelRingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c.translate(0, 2), r, Paint()..color = const Color(0x40000000));
    canvas.drawCircle(c, r, Paint()..color = Cozy.woodDark);
    canvas.drawCircle(c, r - 7, Paint()..color = Cozy.cream);
    final ring = Rect.fromCircle(center: c, radius: r - 3.5);
    canvas.drawArc(ring, 0, 2 * math.pi, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x33fef1d6));
    if (progress > 0) {
      canvas.drawArc(ring, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Cozy.honey);
    }
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) => old.progress != progress;
}

/// The business state over the stall (26번 4-1단계 F7 → 3차 피드백 H17): a
/// sign, not a button. Unlike the HUD's wooden round buttons and the honey
/// '영업 시작' it is a dark glass plate with a thin light edge, and its lamp
/// lights up green and glows slowly while open (grey and still before
/// opening, a red plate for a save to check). Key workshop-status is the text.
class WorkshopStatusBadge extends StatefulWidget {
  final String text;
  final WorkshopStatusKind kind;
  const WorkshopStatusBadge({super.key, required this.text, required this.kind});

  /// False in tests: the lamp shows one still frame (pumpAndSettle).
  static bool animate = true;

  /// One slow breath of the lamp's glow while open.
  static const glowMs = 1600;
  static const lampOn = Color(0xff7ed957);

  @override
  State<WorkshopStatusBadge> createState() => _WorkshopStatusBadgeState();
}

class _WorkshopStatusBadgeState extends State<WorkshopStatusBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: WorkshopStatusBadge.glowMs), value: 1);

  void _sync() {
    final on = widget.kind == WorkshopStatusKind.open && WorkshopStatusBadge.animate &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on) {
      if (!_glow.isAnimating) _glow.repeat(reverse: true);
    } else {
      _glow.stop();
      _glow.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WorkshopStatusBadge old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final error = kind == WorkshopStatusKind.error;
    final open = kind == WorkshopStatusKind.open;
    final dot = switch (kind) {
      WorkshopStatusKind.open => WorkshopStatusBadge.lampOn,
      WorkshopStatusKind.preparing => const Color(0xff9c938a),
      WorkshopStatusKind.error => Cozy.cream,
    };
    return Semantics(
      label: '가게 상태 ${widget.text}',
      excludeSemantics: true,
      child: Container(
        key: const Key('workshop-status-badge'),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
        decoration: BoxDecoration(
            color: error ? Cozy.brick : const Color(0xb3221410),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Cozy.cream.withValues(alpha: error ? .8 : .28), width: 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) => Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [
                  if (open)
                    BoxShadow(
                        color: WorkshopStatusBadge.lampOn.withValues(alpha: .35 + .45 * _glow.value),
                        blurRadius: 4 + 6 * _glow.value,
                        spreadRadius: 1 + 1.5 * _glow.value),
                ])),
          ),
          const SizedBox(width: 7),
          Flexible(child: Text(widget.text, key: const Key('workshop-status'), maxLines: 1, softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                  fontSize: 15, letterSpacing: .5, color: open || error ? Cozy.cream : const Color(0xffd9cfc4)))),
        ]),
      ),
    );
  }
}
