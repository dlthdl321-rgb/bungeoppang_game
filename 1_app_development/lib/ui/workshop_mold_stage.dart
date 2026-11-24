import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_paint.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cosmetic_config.dart';
import '../development_balance.dart';
import '../feedback_config.dart';
import '../workshop_controller.dart';
import '../workshop_feature_unlocks.dart';
import 'center_toast.dart';
import 'griddle_geometry.dart';
import 'cooking_result_effects.dart';
import 'lock_overlay.dart';
import 'flavor_picker.dart';
import 'flip_circle_control.dart';
import 'piping_bag_control.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'sparkle_art.dart';
import 'workshop_fairy.dart';
import 'workshop_home_layout.dart';

/// Presentation only. All commands still pass through WorkshopController.
///
/// Two places use it (4차 피드백 g11, 사용자 결정 2026-11-21):
/// - the centre stage ([bench] null): in business, with no bake, the
///   붕어빵 요정 clicker ([WorkshopClicker]) over the guests;
/// - the lower workbench ([bench] = the six-cell griddle's box): the
///   special bungeoppang mold. When a bake starts (practice before
///   opening, an order from a guest, 오늘의 주문서) the griddle slides aside
///   (NightHome.griddleAside) and the mold slides into its place with its
///   step controls, the bake's title and its buttons over it; when it ends
///   the mold slides out again. Before opening '스페셜 붕어빵 제작 시작'
///   sits on the closed griddle (the flavor choice comes first, H26).
/// The mold is drawn in one box ([moldBenchRect]); a new hearth-mold
/// picture (25번 56번) only replaces mold/*.png.
class WorkshopMoldStage extends StatefulWidget {
  final WorkshopController controller;
  final Rect? fishOnScreen;

  /// The sale counter's top on screen (NightHome.centerBuilder), or null.
  final double? counterTop;

  /// The higher of the sale counter's top and the cooking cut's top on
  /// screen (NightHome), or null: the 붕어빵 요정 hides above it.
  final double? cutTop;

  /// The griddle's box in this widget's coordinates: this is the workbench
  /// (NightHome.bench). Null: the centre stage.
  final Rect? bench;
  final bool cleanCounter, reduceMotion, vibration;

  /// The new home layout (26번 4-1단계): the clicker sits just above the
  /// counter at 0.8 (S4-1-Q5) and the order customer's words go in a
  /// bubble over the guest (WorkshopGuestLayer) instead of under the result.
  final bool lowStall;

  /// The 붕어빵 요정 holds still at its place (its short tour points at it,
  /// 4차 g12).
  final bool fairyStill;

  /// '자랑하기' on a perfect result (26번 8단계 공유 카드); null hides it.
  final void Function(ResultLook look)? onSharePerfect;

  /// 재료 타이쿤 E: '재료 준비' (PantryPrepButton) left of '스페셜 붕어빵
  /// 제작 시작' on the workbench before opening; null leaves it out.
  final Widget? prepAction;
  const WorkshopMoldStage(
      {super.key,
      required this.controller,
      required this.fishOnScreen,
      this.counterTop,
      this.cutTop,
      this.bench,
      this.cleanCounter = false,
      this.lowStall = false,
      this.fairyStill = false,
      this.onSharePerfect,
      this.prepAction,
      this.reduceMotion = false,
      this.vibration = false});

  @override
  State<WorkshopMoldStage> createState() => _WorkshopMoldStageState();
}

/// The mold's fish box on the workbench (4차 피드백 g11): the mold picture
/// (with its axle, WorkshopMoldArt) [WorkshopHomeLayout.benchMoldShare] of
/// the [griddle] box's width (at most benchMoldMaxWidth), centred on it,
/// its axle feet [WorkshopHomeLayout.benchFootGap] above [height] (the
/// menu bar's top) and its top no higher than benchTopRoom.
Rect moldBenchRect(Rect griddle, double height) {
  final line = height - WorkshopHomeLayout.benchFootGap;
  const art = WorkshopMoldArt.pictureSize, fish = WorkshopMoldArt.fishRect;
  final k = math.max(.05, math.min(
      math.min(griddle.width * WorkshopHomeLayout.benchMoldShare, WorkshopHomeLayout.benchMoldMaxWidth) / art.width,
      (line - WorkshopHomeLayout.benchTopRoom) / (WorkshopMoldArt.pictureBottom - WorkshopMoldArt.pictureTop)));
  final origin = Offset(griddle.center.dx - art.width * k / 2, line - WorkshopMoldArt.pictureBottom * k);
  return Rect.fromLTWH(origin.dx + fish.left * k, origin.dy + fish.top * k, fish.width * k, fish.height * k);
}

class _WorkshopMoldStageState extends State<WorkshopMoldStage> {
  Offset _origin = Offset.zero;

  /// '스페셜 붕어빵 제작 시작': with more than one flavor owned, asks which
  /// one first (26번 3차 피드백 H26), then starts the practice.
  Future<void> _startPractice(BuildContext context) async {
    final c = widget.controller;
    if (c.state.recipes.length > 1) {
      final flavor = await showFlavorPicker(context, c);
      if (flavor == null || !mounted) return;
    }
    await c.startPractice();
  }

  /// Cells painted by this session's finished piping steps, shown until the
  /// mold closes (G2). Memory only: after a restart the whole pictures show.
  String? _keptId;
  final Map<CookingPhase, Uint8List> _kept = {};

  /// The paste each finished step spilled past the fish (mask points, IC4).
  final Map<CookingPhase, List<(double, double)>> _spills = {};
  ScrollPosition? _scroll;
  void _scrolled() { if (mounted) setState(() {}); }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.removeListener(_scrolled);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_scrolled);
  }
  @override
  void dispose() {
    _scroll?.removeListener(_scrolled);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bench = widget.bench;
    if (bench != null) return _bench(context, bench);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final next = box.localToGlobal(Offset.zero);
      if (next != _origin) setState(() => _origin = next);
    });
    final c = widget.controller, s = c.state;
    // In business (and not waiting to continue a new day) with no bake the
    // stage is the clicker.
    final clicker = s.session == null && s.business.permitsProducts(c.now());
    return LayoutBuilder(builder: (context, box) {
      final fallback = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * .59),
          width: math.min(box.maxWidth * .78, 330),
          height: math.min(box.maxHeight * .42, 190));
      final mapped = widget.fishOnScreen?.shift(-_origin);
      final counterLocal =
          widget.counterTop == null ? null : widget.counterTop! - _origin.dy;
      final clean = widget.cleanCounter || mapped == null;
      final rect = mapped ?? fallback;
      // The clicker fish floats with no mold, above the mold's place.
      final floating = clicker && clean;
      final cutLocal = widget.cutTop == null ? null : widget.cutTop! - _origin.dy;
      final hideAbove = cutLocal ?? counterLocal;
      return Stack(key: const Key('workshop-center-stage'), children: [
        // In the stage itself: the floating fish must be hit-testable there.
        if (clicker)
          Positioned.fill(
              child: WorkshopClicker(
                  controller: c,
                  home: !floating
                      ? rect
                      : widget.lowStall && counterLocal != null
                          // Just above the counter's button row, 0.8 of the
                          // mold's place, the guests behind it (S4-1-Q5).
                          ? Rect.fromCenter(
                              center: Offset(box.maxWidth / 2,
                                  counterLocal - WorkshopHomeLayout.clickerLift - rect.height * WorkshopHomeLayout.clickerScale / 2),
                              width: rect.width * WorkshopHomeLayout.clickerScale,
                              height: rect.height * WorkshopHomeLayout.clickerScale)
                          : rect.shift(Offset(0, -rect.height * .75)),
                  // 붕어빵 요정 (4차 IA3): hides from guests at the right
                  // edge, clear of the cooking cut and the counter.
                  hideBottom: hideAbove == null ? null : hideAbove - FairyMotion.hideGap,
                  floating: floating,
                  still: widget.fairyStill,
                  reduceMotion: widget.reduceMotion,
                  vibration: widget.vibration)),
      ]);
    });
  }

  /// The workbench: the special mold in the griddle's place (g11).
  Widget _bench(BuildContext context, Rect griddle) {
    final c = widget.controller, s = c.state, session = s.session;
    final blocked = c.cookingInputBlocked;
    final reduce = widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (session?.id != _keptId) {
      _keptId = session?.id;
      _kept.clear();
      _spills.clear();
    }
    final manual = c.config.section('manual_cooking');
    // Before opening '스페셜 붕어빵 제작 시작' sits on the closed griddle;
    // waiting to continue a new day nothing does (the counter's '이어서 영업').
    final preparing = session == null && !s.business.open;
    // The finished bake's grade and look (26번 4단계), presentation only.
    final ResultLook? look = session?.phase == CookingPhase.result
        ? ResultLook.of(c.config, session!, difficulty: c.difficulty(session.flavor))
        : null;
    return LayoutBuilder(builder: (context, box) {
      final rect = moldBenchRect(griddle, box.maxHeight);
      final (moldTop, _) = moldPictureSpan(rect, 1);
      Widget activeMold(CookingSession session) => IgnorePointer(child: CustomPaint(
          key: const Key('active-empty-mold'),
          painter: paintedMoldFor(session, _kept, c.config, clean: true, look: look, spills: _spills)));
      // 4차 피드백 IC3·IC4: the hand steps take touches on the whole mold
      // picture (its rim and handles reach past the fish's box) and a
      // little past it, so a stroke may start on the edge or outside.
      final touch = session != null && session.phase.index <= CookingPhase.flipping.index &&
              session.phase != CookingPhase.closing
          ? WorkshopHomeLayout.moldTouchOutset : EdgeInsets.zero;
      Widget mold(Widget interaction) => Positioned.fromRect(
          rect: touch.inflateRect(rect),
          child: Stack(key: session == null ? null : const Key('workshop-mold'), fit: StackFit.expand,
              clipBehavior: Clip.none, children: [
           Padding(padding: touch, child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
            // The axle the mold turns on (H21), behind it, its feet on the bench.
            const IgnorePointer(child: CustomPaint(key: Key('mold-axle'), painter: MoldAxlePainter())),
            if (session == null)
              // Sliding out after the bake: the mold empty again.
              const IgnorePointer(child: CustomPaint(key: Key('idle-mold'), painter: WorkshopMoldArt('empty'))),
            // While flipping the control turns the mold itself.
            if (session != null && session.phase != CookingPhase.flipping) activeMold(session),
            // The pin heads in front (the flip control draws its own).
            if (session?.phase != CookingPhase.flipping)
              const IgnorePointer(child: CustomPaint(painter: MoldAxlePainter(front: true))),
           ])),
            interaction,
          ]));
      Widget action(String label, VoidCallback command) => Semantics(
          button: true,
          label: label,
          child: InkWell(
              key: const Key('workshop-mold-action'),
              onTap: blocked ? null : command,
              child: session == null
                  ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: _pill(label)))
                  : Center(child: _caption(label))));
      Widget control = const SizedBox.shrink();
      if (session != null) {
        switch (session.phase) {
          case CookingPhase.firstBatter:
          case CookingPhase.secondBatter:
          case CookingPhase.filling:
            final phase = session.phase;
            control = MoldPaintControl(
                key: ValueKey('mold-paint:${session.id}'),
                stageToken: session.token,
                blocked: blocked,
                filling: phase == CookingPhase.filling,
                flavor: session.flavor,
                config: c.config,
                touchOutset: touch,
                before: phase == CookingPhase.secondBatter ? session.firstBatter : null,
                reduceMotion: widget.reduceMotion,
                vibration: widget.vibration,
                onFinished: (paint, cells, spill) {
                  _spills[phase] = spill;
                  _kept[phase] = cells;
                  c.cookingCommand(phase == CookingPhase.filling
                      ? session.squeezeFilling(session.token, paint)
                      : session.pour(session.token, paint));
                });
          case CookingPhase.closing:
            control = action(
                '뚜껑 닫기', () => c.cookingCommand(session.close(session.token)));
          case CookingPhase.flipping:
            // Draw a circle around the mold (24번 6단계, DEC-034). The flip
            // shows for flip_ms before the command, so the controller's
            // flip_ms check always passes; a margin covers clock drift.
            control = FlipCircleControl(
                key: ValueKey('mold-flip:${session.id}'),
                stageToken: session.token,
                blocked: blocked,
                config: c.config,
                touchOutset: touch,
                reduceMotion: widget.reduceMotion,
                vibration: widget.vibration,
                mold: activeMold(session),
                onFlip: () async {
                  final wait = DevelopmentBalance.integer(manual, 'flip_ms') - c.activePhaseElapsedMs;
                  if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
                  return c.cookingCommand(session.flip(session.token));
                });
          case CookingPhase.cooking:
            control = action(
                '꺼내기 · ${(c.activePhaseElapsedMs / 1000).toStringAsFixed(1)}초',
                () => c.cookingCommand(
                    session.takeOut(session.token, c.activePhaseElapsedMs)));
          case CookingPhase.result:
            // Grade, praise or reason, the order customer's reaction, and
            // once a sound, vibration and effect (MASTER 10장 결과 등급·연출).
            control = CookingResultView(
                key: ValueKey('mold-result:${session.id}'),
                sessionId: session.id,
                grade: look!.grade,
                line: cookingGradeLine(c.config, session, look.grade, variant: look.variant),
                reaction: widget.lowStall ? null : c.resultReaction(look.grade),
                burnt: look.variant == provisionalDonenessLabels.length - 1,
                reduceMotion: widget.reduceMotion,
                vibration: widget.vibration);
          case CookingPhase.canceled:
            break;
        }
      }
      // Over the mold picture: the bake's title, then its buttons (H19·H25),
      // higher on the result, over the grade band.
      final dockBottom = math.min(moldTop, touch.inflateRect(rect).top) - WorkshopHomeLayout.moldButtonGap -
          (session?.phase == CookingPhase.result ? WorkshopHomeLayout.benchResultRoom : 0);
      final dock = session == null
          ? null
          : Positioned(
              left: 8,
              right: 8,
              bottom: box.maxHeight - dockBottom,
              child: Column(key: const Key('mold-dock'), mainAxisSize: MainAxisSize.min, children: [
                // H19: only which bungeoppang is being made, and a pause.
                _sessionTitle(
                    '${c.flavorLabel(session.flavor)} 붕어빵 ${session.practice ? '연습' : '주문'}${c.gameplayPaused ? ' · 일시정지' : ''}'),
                const SizedBox(height: WorkshopHomeLayout.moldButtonGap),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (session.phase == CookingPhase.result) ...[
                        // H25: two real buttons of one size: keep (honey) and,
                        // for practice, throw away (light). An order bake goes to
                        // its customer, so it only closes.
                        StageButton(
                            key: const Key('mold-store'),
                            label: session.practice ? '보관하기' : '결과 닫기',
                            primary: true,
                            onPressed: blocked ? null : () => c.storeResult(true)),
                        if (session.practice) ...[
                          const SizedBox(width: 8),
                          StageButton(
                              key: const Key('mold-discard'),
                              label: '버리기',
                              onPressed: blocked ? null : () => c.storeResult(false)),
                        ],
                        if (look!.grade == CookingGrade.perfect && widget.onSharePerfect != null) ...[
                          const SizedBox(width: 8),
                          StageButton(
                              key: const Key('mold-share'),
                              label: '자랑하기',
                              onPressed: () => widget.onSharePerfect!(look)),
                        ],
                      ] else
                        StageButton(
                            key: const Key('mold-cancel'),
                            label: '제작 취소',
                            quiet: true,
                            onPressed: blocked
                                ? null
                                : () => c.cookingCommand(session.cancel())),
                    ])),
              ]));
      final onBench = session != null;
      return Stack(key: const Key('workshop-bench'), clipBehavior: Clip.none, children: [
        // The mold slides in from the right while the griddle slides out to
        // the left, and back (WorkshopHomeLayout.benchSlideMs).
        Positioned.fill(
            child: TweenAnimationBuilder<double>(
                tween: Tween(end: onBench ? 0 : 1),
                duration: reduce ? Duration.zero : const Duration(milliseconds: WorkshopHomeLayout.benchSlideMs),
                curve: Curves.easeInOutCubic,
                builder: (context, t, child) => t >= 1
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        ignoring: !onBench || t > 0,
                        child: FractionalTranslation(translation: Offset(t, 0), child: child)),
                child: Stack(clipBehavior: Clip.none, children: [
                  mold(control),
                  if (dock != null) dock,
                ]))),
        if (preparing)
          Positioned.fromRect(
              rect: Rect.fromCenter(
                  center: Offset(griddle.center.dx, griddle.top + griddle.height * WorkshopHomeLayout.benchPillAt),
                  width: griddle.width,
                  height: 48),
              child: widget.prepAction == null
                  ? action('스페셜 붕어빵 제작 시작', () => _startPractice(context))
                  // 재료 타이쿤 E: '재료 준비' left of it, both shrinking together.
                  : Center(child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                      widget.prepAction!,
                      const SizedBox(width: 8),
                      action('스페셜 붕어빵 제작 시작', () => _startPractice(context)),
                    ])))),
      ]);
    });
  }
}

/// The top and bottom of the mold picture's opaque part with its axle
/// (mold/*.png rows 102~833 of 880) drawn over [rect] with [grow]
/// (WorkshopMoldArt.fit).
(double, double) moldPictureSpan(Rect rect, double grow) {
  final (k, origin) = WorkshopMoldArt.fit(rect.size, grow);
  return (rect.top + origin.dy + WorkshopMoldArt.pictureTop * k,
      rect.top + origin.dy + WorkshopMoldArt.pictureBottom * k);
}

/// The open mold of [session] with each finished piping step on it: the
/// cells painted in this run of the app ([kept], G2), or the whole step
/// picture when the cells are gone (a restart, or an older hold-time save).
/// Once the lid closes the step pictures take over (moldFor).
CustomPainter paintedMoldFor(CookingSession session, Map<CookingPhase, Uint8List> kept,
    DevelopmentBalance config, {required bool clean, ResultLook? look,
    Map<CookingPhase, List<(double, double)>> spills = const {}}) {
  if (session.phase.index > CookingPhase.closing.index) {
    final result = session.phase == CookingPhase.result;
    return WorkshopMoldArt(moldFor(session),
        withFish: result, cover: !clean, look: result ? look : null);
  }
  MoldPaintLayer layer(CookingPhase step, String picture, PaintAmount? paint,
      {String? image, Color? color}) {
    final cells = kept[step];
    // The batter is judged on both strokes together (IC6): the drips show
    // once the poured total is past the line.
    final overflow = paint != null && (step == CookingPhase.filling
        ? paintOverflowed(config, paint)
        : batterOverflowed(config, paint,
            before: step == CookingPhase.secondBatter ? session.firstBatter : null));
    return cells == null
        ? MoldPaintLayer(image: picture)
        : MoldPaintLayer(image: image, color: color, cells: cells,
            drip: step == CookingPhase.filling ? session.flavor : 'batter',
            overflow: overflow, spill: spills[step] ?? const []);
  }
  return _PaintedMoldArt([
    if (session.firstBatterDone)
      layer(CookingPhase.firstBatter, 'batter', session.firstBatter, image: 'batter'),
    if (session.fillingSqueezed)
      layer(CookingPhase.filling, 'filling_${session.flavor}', session.filling,
          color: fillingPasteColor(session.flavor)),
    if (session.secondBatterDone)
      layer(CookingPhase.secondBatter, 'batter_top', session.secondBatter, image: 'batter_top'),
  ], '${session.id}:${session.token}:${kept.length}:${spills.length}', clean: clean);
}

class _PaintedMoldArt extends CustomPainter {
  final List<MoldPaintLayer> layers;
  final String signature;
  final bool clean;
  _PaintedMoldArt(this.layers, this.signature, {required this.clean});
  @override
  void paint(Canvas canvas, Size size) {
    WorkshopMoldArt('empty', cover: !clean).paint(canvas, size);
    for (final layer in layers) {
      paintMoldLayer(canvas, size, clean ? 1 : 1.12, layer);
    }
  }

  @override
  bool shouldRepaint(covariant _PaintedMoldArt old) =>
      old.signature != signature || old.clean != clean;
}

/// The mold picture for [session]'s step (PixelSprites.moldNames).
String moldFor(CookingSession session) {
  final poured = session.firstBatterDone;
  final filled = session.fillingSqueezed;
  final topped = session.secondBatterDone;
  switch (session.phase) {
    case CookingPhase.flipping:
    case CookingPhase.cooking:
      return 'closed';
    case CookingPhase.result:
      return 'empty';
    default:
      if (topped || session.phase == CookingPhase.closing) return 'batter_top';
      if (filled) return 'filling_${session.flavor}';
      return poured ? 'batter' : 'empty';
  }
}

/// How a finished bake looks (26번 4단계, MASTER 10장): its grade, its
/// doneness color, the spilled batter drips and a perfect bake's shine.
class ResultLook {
  final CookingGrade grade;
  final int variant;
  final bool overflow;
  const ResultLook(this.grade, this.variant, {this.overflow = false});

  factory ResultLook.of(DevelopmentBalance config, CookingSession session, {required int difficulty}) {
    final variant = evaluateCookingResult(config, session, difficulty: difficulty).variant;
    return ResultLook(cookingGrade(config, session, difficulty: difficulty), variant,
        overflow: const ['반죽 넘침', '반죽 흘림'].contains(batterFailureLabel(config, session)));
  }

  /// The fish's color by doneness: 덜 익음 pale (60% color, 15% lighter),
  /// 부드러움 6% lighter, 미디엄 as drawn, 바삭함 deeper gold, 타버림 dark
  /// brown (x0.55). Null for 미디엄.
  static ColorFilter? filter(int variant) => switch (variant) {
        0 => const ColorFilter.matrix([
            .6 + .4 * .2126, .4 * .7152, .4 * .0722, 0, 38,
            .4 * .2126, .6 + .4 * .7152, .4 * .0722, 0, 38,
            .4 * .2126, .4 * .7152, .6 + .4 * .0722, 0, 38,
            0, 0, 0, 1, 0,
          ]),
        1 => const ColorFilter.matrix([
            1, 0, 0, 0, 15,
            0, 1, 0, 0, 15,
            0, 0, 1, 0, 15,
            0, 0, 0, 1, 0,
          ]),
        3 => const ColorFilter.matrix([
            1.02, 0, 0, 0, 0,
            0, .88, 0, 0, 0,
            0, 0, .66, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        4 => const ColorFilter.matrix([
            .55, 0, 0, 0, 0,
            0, .45, 0, 0, 0,
            0, 0, .38, 0, 0,
            0, 0, 0, 1, 0,
          ]),
        _ => null,
      };

  @override
  bool operator ==(Object other) =>
      other is ResultLook && other.grade == grade && other.variant == variant && other.overflow == overflow;
  @override
  int get hashCode => Object.hash(grade, variant, overflow);
}

/// Draws one of the big mold pictures so its fish cavity covers the canvas
/// (the baked fish's place), with fish/redbean.png in it when [withFish].
/// [cover] grows it a little to hide a background's baked mold. A result's
/// [look] colors the fish by doneness, hangs batter drips on a spilled one
/// and puts a shine on a perfect one.
class WorkshopMoldArt extends CustomPainter {
  final String name;
  final bool withFish, cover;
  final ResultLook? look;
  const WorkshopMoldArt(this.name, {this.withFish = false, this.cover = false, this.look});

  /// The fish body inside the mold canvas, and where fish/redbean.png sits
  /// (tools/make_home_stage_art.py).
  static const fishRect = Rect.fromLTRB(215, 174, 984, 706);

  /// The first row of the mold pictures' opaque part and the last row of
  /// the axle's feet under it (mold/axle_back.png), which stand lower.
  static const pictureTop = 102.0, pictureBottom = 833.0;

  /// The mold pictures' own size (mold/*.png).
  static const pictureSize = Size(1200, 880);
  static const fishAt = Offset(100, 66);
  static final _smooth = Paint()..filterQuality = FilterQuality.medium;

  /// Scale and origin that put [fishRect] centred in [size].
  static (double, Offset) fit(Size size, double grow) {
    final k = math.min(size.width / fishRect.width, size.height / fishRect.height) * grow;
    return (k, size.center(Offset.zero) - fishRect.center * k);
  }

  static void drawAt(Canvas c, ui.Image? image, Offset at, double k, Offset origin) {
    if (image == null) return;
    c.drawImageRect(image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(origin.dx + at.dx * k, origin.dy + at.dy * k,
            image.width * k, image.height * k),
        _smooth);
  }

  @override
  void paint(Canvas c, Size size) {
    final (k, origin) = fit(size, cover ? 1.12 : 1);
    drawAt(c, PixelSprites.mold(name), Offset.zero, k, origin);
    if (!withFish) return;
    final look = this.look;
    final filter = look == null ? null : ResultLook.filter(look.variant);
    if (filter != null) c.saveLayer(null, Paint()..colorFilter = filter);
    drawAt(c, PixelSprites.fish('redbean', 'scales'), fishAt, k, origin);
    if (filter != null) c.restore();
    if (look == null) return;
    final fish = Rect.fromLTRB(origin.dx + fishRect.left * k, origin.dy + fishRect.top * k,
        origin.dx + fishRect.right * k, origin.dy + fishRect.bottom * k);
    if (look.overflow) {
      // Three drips on the lower edge (fx/overflow_batter.png).
      final art = PixelSprites.fx('overflow_batter');
      for (final (x, y) in const [(.32, .8), (.5, .86), (.68, .8)]) {
        final w = fish.width * .1;
        final at = Offset(fish.left + fish.width * x, fish.top + fish.height * y);
        if (art != null) {
          PixelSprites.draw(c, art, Rect.fromLTWH(at.dx - w / 2, at.dy, w, w * art.height / art.width));
        } else {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - w / 4, at.dy, w / 2, w),
              Radius.circular(w / 4)), Paint()..color = const Color(0xfff2d49b));
        }
      }
    }
    if (look.grade == CookingGrade.perfect) {
      // A soft shine on the upper body.
      final shine = Rect.fromCenter(
          center: Offset(fish.left + fish.width * .42, fish.top + fish.height * .3),
          width: fish.width * .4, height: fish.height * .16);
      c.drawOval(shine, Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)])
            .createShader(shine));
    }
  }

  @override
  bool shouldRepaint(covariant WorkshopMoldArt old) =>
      old.name != name || old.withFish != withFish || old.cover != cover || old.look != look;
}

/// The special mold's axle (26번 3차 피드백 H21: '양옆 고리에 실제 장치'):
/// an iron rod through each side ring out to a small bracket standing on
/// the counter. [front] = false draws the rods and brackets (behind the
/// mold); true draws the pin heads on the rings (in front of a turning
/// mold) and, before the flip's circle is drawn, a round arrow round the
/// mold's middle showing it ([hint], 4차 피드백 IC5; the progress ring
/// round the right pin is gone, IC8). Drawn
/// in the mold picture's coordinates (WorkshopMoldArt.fit), so it follows
/// the mold's place and size. The rods, posts and pins are 25번 36번 art
/// (mold/axle_back.png, axle_front.png, 1200x880 like the mold); without
/// them they are drawn in code.
class MoldAxlePainter extends CustomPainter {
  final double grow;
  final bool front, hint;
  const MoldAxlePainter({this.grow = 1, this.front = false, this.hint = false});

  static const iron = Color(0xff2f2a27), ironLight = Color(0xff6d635c), brass = Color(0xffc9a25a);

  @override
  void paint(Canvas canvas, Size size) {
    final (k, origin) = WorkshopMoldArt.fit(size, grow);
    Offset at(double x, double y) => origin + Offset(x, y) * k;
    final rings = [flipAxleLeftRing, flipAxleRightRing];
    final art = PixelSprites.mold(front ? 'axle_front' : 'axle_back');
    if (art != null) {
      WorkshopMoldArt.drawAt(canvas, art, Offset.zero, k, origin);
      if (!front) return;
    } else if (!front) {
      for (final (i, (x, y)) in rings.indexed) {
        final out = i == 0 ? x - 66 : x + 66;
        // The rod from the ring out to the bracket.
        canvas.drawLine(at(x, y), at(out, y), Paint()
          ..color = iron
          ..strokeWidth = 22 * k
          ..strokeCap = StrokeCap.round);
        canvas.drawLine(at(x, y - 5), at(out, y - 5), Paint()
          ..color = ironLight
          ..strokeWidth = 5 * k
          ..strokeCap = StrokeCap.round);
        // The bracket: a post down to a foot on the counter.
        final post = RRect.fromRectAndRadius(
            Rect.fromPoints(at(out - 14, y - 30), at(out + 14, 860)), Radius.circular(8 * k));
        canvas.drawRRect(post, Paint()..color = iron);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromPoints(at(out - 14, y - 30), at(out - 6, 860)), Radius.circular(6 * k)),
            Paint()..color = ironLight.withValues(alpha: .7));
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromPoints(at(out - 34, 846), at(out + 34, 872)), Radius.circular(8 * k)),
            Paint()..color = iron);
        // The rod's bearing on the post.
        canvas.drawCircle(at(out, y), 26 * k, Paint()..color = iron);
        canvas.drawCircle(at(out, y), 12 * k, Paint()..color = brass);
      }
      return;
    }
    for (final (x, y) in art == null ? rings : const <(double, double)>[]) {
      canvas.drawCircle(at(x, y), 21 * k, Paint()..color = iron);
      canvas.drawCircle(at(x, y), 13 * k, Paint()..color = brass);
      canvas.drawCircle(at(x - 4, y - 4), 5 * k, Paint()..color = const Color(0xfff3dca0));
    }
    if (!hint) return;
    // A round arrow (clockwise, most of a turn) round the mold's middle:
    // draw a circle like this to flip it.
    final m = at(600, 440);
    final r = 150 * k;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Cozy.cream.withValues(alpha: .9);
    const from = -math.pi * .5, sweep = math.pi * 1.6;
    canvas.drawArc(Rect.fromCircle(center: m, radius: r), from, sweep, false, paint);
    // Arrowhead at the arc's end, pointing along it (clockwise).
    const end = from + sweep;
    final tip = m + Offset(math.cos(end), math.sin(end)) * r;
    final along = Offset(-math.sin(end), math.cos(end));
    final across = Offset(math.cos(end), math.sin(end));
    final head = Path()
      ..moveTo(tip.dx + along.dx * 9, tip.dy + along.dy * 9)
      ..lineTo(tip.dx - along.dx * 4 + across.dx * 8, tip.dy - along.dy * 4 + across.dy * 8)
      ..lineTo(tip.dx - along.dx * 4 - across.dx * 8, tip.dy - along.dy * 4 - across.dy * 8)
      ..close();
    canvas.drawPath(head, Paint()..color = Cozy.cream.withValues(alpha: .9));
  }

  @override
  bool shouldRepaint(covariant MoldAxlePainter old) =>
      old.grow != grow || old.front != front || old.hint != hint;
}

/// The mockup's floating bungeoppang: no mold, a little larger. Its
/// sparkles are a separate twinkling layer ([TwinklingSparkles] at
/// [sparkles]) so the fish itself never repaints.
class FloatingFishPainter extends CustomPainter {
  const FloatingFishPainter();

  /// Around the fish: (x, y, size) as fractions of the box (the shortest
  /// side for the size). The 32x32 art is mostly glow, so it is drawn a
  /// little larger than the old 21x21 sparkle.
  static const sparkles = [
    (.06, .30, .24), (.94, .20, .16), (.88, .80, .24), (.12, .88, .16),
    (.50, .00, .24), (.99, .55, .16),
  ];

  @override
  void paint(Canvas c, Size size) {
    final (k, origin) = WorkshopMoldArt.fit(size, 1.08);
    WorkshopMoldArt.drawAt(c, PixelSprites.fish('redbean', 'scales'),
        WorkshopMoldArt.fishAt, k, origin);
  }

  @override
  bool shouldRepaint(covariant FloatingFishPainter old) => false;
}

/// The mockup's cream "터치해서 굽기" pill under the fish.
Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
        color: Cozy.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Cozy.woodLight, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))]),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const PixelIcon('bun', size: 26),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Cozy.ink, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(width: 6),
      const PixelIcon('bun', size: 26),
    ]));

/// The bake's title over the mold: a small translucent plate (H19).
Widget _sessionTitle(String text) => Container(
    key: const Key('workshop-session-title'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
        color: const Color(0x99221410), borderRadius: BorderRadius.circular(12)),
    child: Text(text,
        key: const Key('workshop-phase-time'),
        style: const TextStyle(
            fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, color: Cozy.cream, fontSize: 15)));

/// A button under the special bungeoppang mold (26번 3차 피드백 H25): the
/// same rounded size for keep, throw away, show off and cancel. [primary]
/// is honey, the others cream; [quiet] is a light outline only.
class StageButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary, quiet;
  const StageButton({super.key, required this.label, required this.onPressed,
      this.primary = false, this.quiet = false});
  static const height = 40.0, minWidth = 92.0;
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = quiet
        ? const Color(0x88221410)
        : primary
            ? Cozy.honey
            : Cozy.cream;
    final ink = quiet ? Cozy.cream : Cozy.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Material(
          color: fill,
          shape: StadiumBorder(
              side: BorderSide(
                  color: quiet ? Cozy.cream.withValues(alpha: .5) : primary ? Cozy.honeyDeep : Cozy.tan,
                  width: 1.5)),
          elevation: quiet ? 0 : 2,
          shadowColor: const Color(0x66000000),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: minWidth, minHeight: height),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: ink)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _caption(String text, {Key? key}) => Text(text, key: key,
    textAlign: TextAlign.center,
    style: const TextStyle(
        color: Cozy.cream,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        shadows: [
          Shadow(color: Cozy.woodDark, blurRadius: 5),
          Shadow(color: Cozy.woodDark, offset: Offset(1, 1))
        ]));

/// The griddle cavities that show a bungeoppang in the art: the cooking
/// cells while open, none before opening (the empty griddle, DEC-035).
Set<int> workshopGriddleFilled(WorkshopController c) {
  final s = c.state;
  if (!s.business.permitsProducts(c.now())) return const {};
  return {
    // 4차 피드백 g6: the bungeoppang shows once the automatic batter and
    // filling steps are done.
    for (var i = 0; i < s.grid.cells.length; i++)
      if (s.grid.cells[i].cooking && s.grid.prepStep(i, c.config) == null) i
  };
}

/// The six-cell griddle's automatic steps (4차 피드백 g6), shown in a
/// cell while they run.
const griddlePrepLabels = ['반죽 붓기', '속 넣기', '반죽 덮기'];

/// A cooking cell's timing cue (4차 피드백 g6): the five doneness zones
/// along a thin bar (`doneness.boundary_permille` of the target) with a
/// light marker where the cell is now, so a tap can be timed.
class GriddleCuePainter extends CustomPainter {
  final int permille;
  final List<int> boundaries;
  const GriddleCuePainter({required this.permille, required this.boundaries});
  static const zoneColors = [
    Color(0xfff3e3a6), Color(0xffe8bb62), Color(0xffd28a2a), Color(0xff8a5222), Color(0xff2a1a10)];
  /// Where the bar ends: a quarter past the last boundary.
  int get span => boundaries.last * 5 ~/ 4;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.save();
    canvas.clipRRect(r);
    var from = 0;
    for (var z = 0; z < 5; z++) {
      final to = z < boundaries.length ? boundaries[z] : span;
      canvas.drawRect(Rect.fromLTRB(size.width * from / span, 0, size.width * to / span, size.height),
          Paint()..color = zoneColors[z]);
      from = to;
    }
    canvas.restore();
    final x = size.width * permille.clamp(0, span) / span;
    canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: 2.5, height: size.height + 4),
        Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(GriddleCuePainter old) => old.permille != permille || old.boundaries != boundaries;
}

/// Whether the griddle shows open with its flames on (26번 4-2단계 F8,
/// S4-2-Q1 '닫힌 판·불 꺼짐', DEC-099): only while the stall is open
/// and the griddle can be used (a flavor mastered, S2-Q2's one rule in
/// [WorkshopController.featureIsOpen]), or a cell is still cooking (old
/// saves may take it out). Before opening, and while it is locked, it is
/// closed and cold.
bool workshopGriddleOpen(WorkshopController c) {
  final s = c.state;
  if (!s.business.permitsProducts(c.now())) return false;
  return c.featureIsOpen(WorkshopFeature.griddle) ||
      s.grid.cells.any((cell) => cell.cooking);
}

class WorkshopGriddleLayer extends StatelessWidget {
  final WorkshopController controller;
  final String stove;
  const WorkshopGriddleLayer(
      {super.key, required this.controller, required this.stove});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final c = controller, s = c.state;
        final image = PixelSprites.cosmetic(CosmeticSlot.stove, stove);
        final sprite = griddleSpriteRect(
            box.biggest,
            image == null
                ? const Size(80, 40)
                : Size(image.width.toDouble(), image.height.toDouble()));
        // Before opening (or before continuing a new day) the griddle is an
        // empty picture: no cell faces, words or touches (DEC-035).
        if (!s.business.permitsProducts(c.now())) {
          return const SizedBox.shrink(key: Key('griddle-idle'));
        }
        // 26번 2단계 (S2-Q2): the griddle opens once a flavor is mastered;
        // until then it is hatched with the common lock and the mastery
        // still to go. A cell already cooking (old saves) can still be
        // taken out.
        final lock = c.featureLock(WorkshopFeature.griddle);
        final idle = !c.inputBusy &&
            c.error == null &&
            !c.gameplayPaused &&
            s.session == null;
        return Stack(children: [
          if (lock != null)
            Positioned.fromRect(
                rect: sprite,
                child: LockedOverlay(
                    key: const Key('griddle-locked'),
                    caption: lock,
                    // On the griddle's top rim, not over its cells (4차 IB2).
                    maxLock: 20,
                    edgeBadgeAt: griddleRimTop,
                    onTap: () => showCenterToast(context, '숙련된 붕어빵 틀: $lock'),
                    child: const SizedBox.expand())),
          for (var i = 0; i < s.grid.cells.length; i++)
            if (lock == null || s.grid.cells[i].cooking)
            Builder(builder: (context) {
              final cell = s.grid.cells[i], cycle = cell.cycle;
              final enabled = idle && (lock == null || cell.cooking);
              final center = sprite.topLeft +
                  Offset(griddleCavities[i].dx * sprite.width,
                      griddleCavities[i].dy * sprite.height);
              final prep = s.grid.prepStep(i, c.config);
              final grade = cell.cooking && prep == null ? s.grid.doneness(i, c.config) : null;
              final enabledCell = enabled && prep == null;
              final label = prep != null
                  ? '${i + 1}번 ${c.flavorLabel(cell.flavor!)} ${griddlePrepLabels[prep]} 중'
                  : cell.cooking
                  ? '${i + 1}번 ${c.flavorLabel(cell.flavor!)} ${provisionalDonenessLabels[grade!]} · ${grade == 4 ? '폐기' : '수확'}'
                  : '숙련된 붕어빵 틀 ${i + 1}번 칸 굽기 시작';
              return Positioned.fromRect(
                  rect: Rect.fromCenter(
                      center: center,
                      width: sprite.width * .215,
                      height: math.max(44, sprite.width * .15)),
                  child: Semantics(
                      button: true,
                      label: label,
                      enabled: enabledCell,
                      child: InkWell(
                          key: Key('workshop-cell-$i'),
                          onTap: !enabledCell
                              ? null
                              : () => cell.cooking
                                  ? c.harvestCell(i, expectedCycle: cycle)
                                  : c.startCell(i),
                          child: Container(
                              // 4차 g6: the rows overlap (the lower row covers the
                              // upper row's bottom), so a cooking cell's bar and
                              // words start at its top.
                              alignment: grade != null ? Alignment.topCenter : Alignment.center,
                              padding: grade != null ? const EdgeInsets.only(top: 4) : null,
                              decoration: BoxDecoration(
                                  color: prep != null
                                      ? const Color(0xccf3e3b8)
                                      : cell.cooking
                                      ? (grade == 4
                                          ? Colors.black87
                                          : Colors.brown.withValues(alpha: .75))
                                      : enabled
                                          ? Cozy.cream.withValues(alpha: .18)
                                          : Colors.black26,
                                  // An empty cell has no words: a soft cream rim marks it as tappable.
                                  border: !cell.cooking && enabled
                                      ? Border.all(color: Cozy.cream.withValues(alpha: .7), width: 1.5)
                                      : null,
                                  borderRadius: BorderRadius.circular(12)),
                              child: prep != null
                                  ? Text('${i + 1} ${griddlePrepLabels[prep]}',
                                      key: Key('griddle-prep-$i'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700, color: Cozy.woodDark))
                                  : cell.cooking
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        SizedBox(
                                            height: 5,
                                            width: double.infinity,
                                            child: CustomPaint(
                                                key: Key('griddle-cue-$i'),
                                                painter: GriddleCuePainter(
                                                    permille: s.grid.cookPermille(i, c.config),
                                                    boundaries: c.config.integers('doneness', 'boundary_permille')))),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${i + 1} ${provisionalDonenessLabels[grade!]}\n${grade == 4 ? '폐기' : '수확'}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 10, height: 1.1, color: Cozy.cream)),
                                      ]))
                                  : null))));
            })
        ]);
      });
}
