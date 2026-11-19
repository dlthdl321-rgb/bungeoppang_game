import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../cooking_paint.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cosmetic_config.dart';
import '../development_balance.dart';
import '../economy.dart' show compactNumber;
import '../feedback_config.dart';
import '../game_audio.dart';
import '../workshop_controller.dart';
import '../workshop_feature_unlocks.dart';
import 'center_toast.dart';
import 'boost_effects.dart';
import 'cooking_result_effects.dart';
import 'lock_overlay.dart';
import 'flavor_picker.dart';
import 'flip_circle_control.dart';
import 'piping_bag_control.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'sparkle_art.dart';
import 'tap_effects.dart';
import 'workshop_home_layout.dart';

/// Presentation only. All commands still pass through WorkshopController.
///
/// The two molds follow the business state (DEC-035, 24번 3단계):
/// - before opening the special bungeoppang mold sits empty with
///   '스페셜 붕어빵 제작 시작' and the flavor choice (practice only);
/// - in business, with nothing in the mold, the big bungeoppang floats with
///   no mold and is a clicker ([WorkshopClicker]);
/// - while a session runs (practice before opening, or an order started
///   from the customer window) the mold and its step controls show.
/// Without [cleanCounter] (a background with the mold baked in) the baked
/// art shows instead of the drawn mold and floating fish.
class WorkshopMoldStage extends StatefulWidget {
  final WorkshopController controller;
  final Rect? fishOnScreen;

  /// The sale counter's top on screen (NightHome.centerBuilder), or null.
  /// The practice start button sits 4 above it (24번 4단계).
  final double? counterTop;

  /// The highest of the sale counter's top and the cooking cut's top on
  /// screen (NightHome), or null. The special bungeoppang mold (practice,
  /// a bake) keeps its whole picture [WorkshopHomeLayout.moldGap] above it,
  /// so it never covers the owner's cooking cut or the six-cell griddle
  /// (26번 3차 피드백 H18).
  final double? moldLimit;
  final bool cleanCounter, reduceMotion, vibration;

  /// The new home layout (26번 4-1단계): the clicker sits just above the
  /// counter at 0.8 (S4-1-Q5) and the order customer's words go in a
  /// bubble over the guest (WorkshopGuestLayer) instead of under the result.
  final bool lowStall;

  /// '자랑하기' on a perfect result (26번 8단계 공유 카드); null hides it.
  final void Function(ResultLook look)? onSharePerfect;
  const WorkshopMoldStage(
      {super.key,
      required this.controller,
      required this.fishOnScreen,
      this.counterTop,
      this.moldLimit,
      this.cleanCounter = false,
      this.lowStall = false,
      this.onSharePerfect,
      this.reduceMotion = false,
      this.vibration = false});

  @override
  State<WorkshopMoldStage> createState() => _WorkshopMoldStageState();
}

/// The '제작 취소' TextButton's height (Material minimum tap target).
const _cancelHeight = 48.0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final next = box.localToGlobal(Offset.zero);
      if (next != _origin) setState(() => _origin = next);
    });
    final c = widget.controller, s = c.state, session = s.session;
    final blocked = c.cookingInputBlocked;
    if (session?.id != _keptId) {
      _keptId = session?.id;
      _kept.clear();
    }
    final manual = c.config.section('manual_cooking');
    // In business (and not waiting to continue a new day) the idle mold is
    // the clicker; before opening it is the practice mold.
    final inBusiness = s.business.permitsProducts(c.now());
    final clicker = session == null && inBusiness;
    final preparing = session == null && !s.business.open;
    // The finished bake's grade and look (26번 4단계), presentation only.
    final ResultLook? look = session?.phase == CookingPhase.result
        ? ResultLook.of(c.config, session!, difficulty: c.difficulty(session.flavor))
        : null;
    return LayoutBuilder(builder: (context, box) {
      final fallback = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * .59),
          width: math.min(box.maxWidth * .78, 330),
          height: math.min(box.maxHeight * .42, 190));
      final mapped = widget.fishOnScreen?.shift(-_origin);
      final counterLocal =
          widget.counterTop == null ? null : widget.counterTop! - _origin.dy;
      final clean = widget.cleanCounter || mapped == null;
      var rect = mapped ?? fallback;
      // H18: the mold (not the floating clicker) rises until its whole
      // picture is clear of the cooking cut and the counter, but not into
      // the caption line under the HUD.
      final limitLocal = widget.moldLimit == null ? null : widget.moldLimit! - _origin.dy;
      if (limitLocal != null && !(clicker && clean)) {
        final (top, bottom) = moldPictureSpan(rect, clean ? 1 : 1.12);
        final over = bottom - (limitLocal - WorkshopHomeLayout.moldGap);
        final room = top - WorkshopHomeLayout.moldTopRoom;
        final lift = math.min(over, room);
        if (lift > 0) rect = rect.shift(Offset(0, -lift));
      }
      final moldBottom = moldPictureSpan(rect, clean ? 1 : 1.12).$2;
      // The step caption at the mold's bottom stays clear of the
      // '제작 취소' button (48 tall at the stage's bottom) and 4 above it.
      final captionLift = math.max(0.0, rect.bottom - (box.maxHeight - _cancelHeight) + 4);
      // The clicker fish floats with no mold, above the mold's place.
      final floating = clicker && clean;
      final String? idleMold = session != null || floating
          ? null
          : clean ? 'empty' : null;
      Widget activeMold(CookingSession session) => IgnorePointer(child: CustomPaint(
          key: const Key('active-empty-mold'),
          painter: paintedMoldFor(session, _kept, c.config, clean: clean, look: look)));
      Widget mold(Widget interaction) => Positioned.fromRect(
          rect: rect,
          child: Stack(key: const Key('workshop-mold'), fit: StackFit.expand, clipBehavior:Clip.none, children: [
            // The axle the mold hangs on (H21), behind it.
            if (idleMold != null || session != null)
              IgnorePointer(child: CustomPaint(key: const Key('mold-axle'),
                  painter: MoldAxlePainter(grow: clean ? 1 : 1.12))),
            if (idleMold != null)
              IgnorePointer(child: CustomPaint(
                  key: const Key('idle-mold'),
                  // H20: the mold waits empty; batter goes in first.
                  painter: WorkshopMoldArt(idleMold))),
            // While flipping the control turns the mold itself.
            if (session != null && session.phase != CookingPhase.flipping) activeMold(session),
            // The pin heads in front (the flip control draws its own).
            if ((idleMold != null || session != null) && session?.phase != CookingPhase.flipping)
              IgnorePointer(child: CustomPaint(painter: MoldAxlePainter(grow: clean ? 1 : 1.12, front: true))),
            interaction,
          ]));
      Widget action(String label, VoidCallback command) => Semantics(
          button: true,
          label: label,
          child: InkWell(
              key: const Key('workshop-mold-action'),
              onTap: blocked ? null : command,
              child: session == null
                  // On the empty mold's middle (H18·H20: the mold stands
                  // clear of the counter now).
                  ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: _pill(label)))
                  : Center(child: _caption(label))));
      final Widget control;
      if (session == null) {
        // Practice only before opening; waiting to continue a new day the
        // mold just sits there until the counter's '이어서 영업'.
        control = preparing
            ? action('스페셜 붕어빵 제작 시작', () => _startPractice(context))
            : const SizedBox.shrink();
      } else {
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
                grow: clean ? 1 : 1.12,
                captionLift: captionLift,
                reduceMotion: widget.reduceMotion,
                vibration: widget.vibration,
                onFinished: (paint, cells) {
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
                grow: clean ? 1 : 1.12,
                captionLift: captionLift,
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
            control = const SizedBox.shrink();
        }
      }
      return Stack(key: const Key('workshop-center-stage'), children: [
        mold(control),
        // In the stage itself, not the mold: the floating fish sits above the
        // mold's place and must still be hit-testable there.
        if (clicker)
          Positioned.fromRect(
              rect: !floating
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
              child: WorkshopClicker(
                  controller: c,
                  floating: floating,
                  reduceMotion: widget.reduceMotion,
                  vibration: widget.vibration)),
        Positioned(
            top: 0,
            left: 8,
            right: 8,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // H19: only which bungeoppang is being made (the flavor is
              // chosen with the HUD's flavor button, H26), and a pause.
              if (session != null)
                _sessionTitle(
                    '${c.flavorLabel(session.flavor)} 붕어빵 ${session.practice ? '연습' : '주문'}${c.gameplayPaused ? ' · 일시정지' : ''}'),
            ])),
        // Under the mold, left of the cooking cut when the mold keeps clear
        // of it (H18·H25), else centred.
        if (session != null)
          Positioned(
              // Right under the mold picture, never past the stage's bottom.
              top: math.min(moldBottom + WorkshopHomeLayout.moldButtonGap,
                  box.maxHeight - StageButton.height - 4),
              left: 0,
              right: limitLocal == null ? 0 : box.maxWidth * WorkshopHomeLayout.cookCutShare + 8,
              child: Center(
                  child: FittedBox(
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
              ])))),
      ]);
    });
  }
}

/// The top and bottom of the mold picture's opaque part (mold/*.png rows
/// 89~847 of 880) drawn over [rect] with [grow] (WorkshopMoldArt.fit).
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
    DevelopmentBalance config, {required bool clean, ResultLook? look}) {
  if (session.phase.index > CookingPhase.closing.index) {
    final result = session.phase == CookingPhase.result;
    return WorkshopMoldArt(moldFor(session),
        withFish: result, cover: !clean, look: result ? look : null);
  }
  MoldPaintLayer layer(CookingPhase step, String picture, PaintAmount? paint,
      {String? image, Color? color}) {
    final cells = kept[step];
    return cells == null
        ? MoldPaintLayer(image: picture)
        : MoldPaintLayer(image: image, color: color, cells: cells,
            drip: step == CookingPhase.filling ? session.flavor : 'batter',
            overflow: paint != null && paintOverflowed(config, paint));
  }
  return _PaintedMoldArt([
    if (session.firstBatterDone)
      layer(CookingPhase.firstBatter, 'batter', session.firstBatter, image: 'batter'),
    if (session.fillingSqueezed)
      layer(CookingPhase.filling, 'filling_${session.flavor}', session.filling,
          color: fillingPasteColor(session.flavor)),
    if (session.secondBatterDone)
      layer(CookingPhase.secondBatter, 'batter_top', session.secondBatter, image: 'batter_top'),
  ], '${session.id}:${session.token}:${kept.length}', clean: clean);
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
        overflow: batterFailureLabel(config, session) == '반죽 넘침');
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

  /// The first and last rows of the mold pictures' opaque part.
  static const pictureTop = 89.0, pictureBottom = 847.0;
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
/// mold), and while flipping the push's [progress] as a honey ring round
/// the right pin and, before a push, a small curved arrow ([hint]). Drawn
/// in the mold picture's coordinates (WorkshopMoldArt.fit), so it follows
/// the mold's place and size. A stand-in until the new mold art with its
/// own axle (25번 36번 주문) is in.
class MoldAxlePainter extends CustomPainter {
  final double grow, progress;
  final bool front, hint;
  const MoldAxlePainter({this.grow = 1, this.front = false, this.progress = 0, this.hint = false});

  static const iron = Color(0xff2f2a27), ironLight = Color(0xff6d635c), brass = Color(0xffc9a25a);

  @override
  void paint(Canvas canvas, Size size) {
    final (k, origin) = WorkshopMoldArt.fit(size, grow);
    Offset at(double x, double y) => origin + Offset(x, y) * k;
    final rings = [flipAxleLeftRing, flipAxleRightRing];
    if (!front) {
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
    for (final (x, y) in rings) {
      canvas.drawCircle(at(x, y), 21 * k, Paint()..color = iron);
      canvas.drawCircle(at(x, y), 13 * k, Paint()..color = brass);
      canvas.drawCircle(at(x - 4, y - 4), 5 * k, Paint()..color = const Color(0xfff3dca0));
    }
    final (rx, ry) = flipAxleRightRing;
    final c = at(rx, ry);
    final r = 46 * k + 6;
    if (progress > 0) {
      canvas.drawCircle(c, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0x55000000));
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0),
          false, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = Cozy.honey);
    }
    if (hint) {
      // An arrow turning up and over the axle, at the mold's middle.
      final m = at(600, 440);
      final h = 150 * k;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Cozy.cream.withValues(alpha: .9);
      final arc = Rect.fromCenter(center: m, width: h * .9, height: h * 1.6);
      canvas.drawArc(arc, math.pi * .62, -math.pi * 1.2, false, paint);
      // Arrowhead at the arc's end (upper left, pointing down).
      final end = arc.center + Offset(math.cos(-math.pi * .58) * arc.width / 2, math.sin(-math.pi * .58) * arc.height / 2);
      final head = Path()
        ..moveTo(end.dx - 9, end.dy - 3)
        ..lineTo(end.dx + 3, end.dy - 9)
        ..lineTo(end.dx + 1, end.dy + 6)
        ..close();
      canvas.drawPath(head, Paint()..color = Cozy.cream.withValues(alpha: .9));
    }
  }

  @override
  bool shouldRepaint(covariant MoldAxlePainter old) =>
      old.grow != grow || old.front != front || old.progress != progress || old.hint != hint;
}

/// The big bungeoppang clicker in business (DEC-036): each tap goes through
/// [WorkshopController.clickerTap] (buns +tapRate) and shows the tap effects
/// of tap_effects.dart: a pop, small bungeoppang crumbs and a floating gain.
/// Taps past the per-second limit still pop and crumble but earn nothing,
/// so they show no gain. Reduced motion shows only a still gain.
class WorkshopClicker extends StatefulWidget {
  static const maxBursts = maxFloatingGains;
  final WorkshopController controller;
  /// Draws the floating fish (a clean counter); otherwise the background's
  /// baked fish is the target and only the effects are drawn.
  final bool floating, reduceMotion, vibration;
  const WorkshopClicker(
      {super.key,
      required this.controller,
      required this.floating,
      this.reduceMotion = false,
      this.vibration = false});
  @override
  State<WorkshopClicker> createState() => _WorkshopClickerState();
}

class _WorkshopClickerState extends State<WorkshopClicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _crumbs = CrumbPool(maxCrumbParticles, crumbLifeMs);
  final _bursts = <(int, BigInt, Offset)>[];
  final _haptics = Stopwatch()..start();
  int _elapsed = 0, _lastTap = -100000, _serial = 0;
  int? _lastHaptic;
  Offset? _down;
  Size _box = Size.zero;
  BigInt? _staticGain;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((duration) {
      setState(() {
        _elapsed = duration.inMilliseconds;
        _bursts.removeWhere((b) => _elapsed - b.$1 >= floatingGainMs);
        _crumbs.update(_elapsed);
      });
      if (_bursts.isEmpty && _crumbs.activeCount == 0 && _elapsed - _lastTap > tapPopMs) {
        _ticker.stop();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tap() {
    final c = widget.controller;
    if (c.gameplayPaused || c.error != null) return;
    final amount = c.clickerTap();
    GameAudioScope.of(context).play(Sfx.tap);
    final at = _down ?? _box.center(Offset.zero);
    _down = null;
    final now = _haptics.elapsedMilliseconds;
    if (widget.vibration && (_lastHaptic == null || now - _lastHaptic! >= 80)) {
      _lastHaptic = now;
      HapticFeedback.selectionClick();
    }
    setState(() {
      if (amount != null) _staticGain = amount;
      if (widget.reduceMotion) return;
      if (!_ticker.isActive) {
        _elapsed = 0;
        _bursts.clear();
        _crumbs.clear();
        _ticker.start();
      }
      _lastTap = _elapsed;
      if (amount != null) {
        if (_bursts.length == WorkshopClicker.maxBursts) _bursts.removeAt(0);
        _bursts.add((_elapsed, amount, at.translate(((_serial++ % 5) - 2) * 6.0, 0)));
      }
      _crumbs.spawn(at, _elapsed, crumbsPerTap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = widget.reduceMotion;
    final pop = reduce ? 1.0 : tapPopScale((_elapsed - _lastTap) / tapPopMs);
    return Semantics(
        button: true,
        label: '큰 붕어빵 누르기, 붕어빵력 +${compactNumber(widget.controller.tapRate)}',
        onTap: _tap,
        child: GestureDetector(
            key: const Key('workshop-clicker'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (d) => _down = d.localPosition,
            onTapCancel: () => _down = null,
            onTap: _tap,
            child: LayoutBuilder(builder: (context, box) {
              _box = box.biggest;
              return Stack(clipBehavior: Clip.none, children: [
                if (widget.floating)
                  Positioned.fill(
                      child: Transform.scale(
                          key: const Key('clicker-scale'),
                          scale: pop,
                          child: const CustomPaint(
                              key: Key('floating-fish'),
                              painter: FloatingFishPainter()))),
                // Twinkling one after another (26번 4단계 F11), still with
                // reduced motion.
                if (widget.floating)
                  Positioned.fill(
                      child: TwinklingSparkles(
                          points: FloatingFishPainter.sparkles, reduceMotion: reduce)),
                if (!reduce)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: CustomPaint(
                              painter: CrumbPainter(_crumbs, _elapsed,
                                  fish: PixelSprites.fx('minifish') ??
                                      PixelSprites.fish('redbean', 'scales'))))),
                for (final burst in _bursts)
                  Positioned(
                      key: ValueKey(burst),
                      left: (burst.$3.dx - 40).clamp(0.0, math.max(0, box.maxWidth - 120)),
                      top: (burst.$3.dy - 34).clamp(0.0, math.max(0.0, box.maxHeight - 40)) -
                          (_elapsed - burst.$1) / floatingGainMs * 65,
                      child: IgnorePointer(
                          child: ExcludeSemantics(
                              child: Opacity(
                                  opacity: (1 - (_elapsed - burst.$1) / floatingGainMs).clamp(0.0, 1.0),
                                  child: _gain(burst.$2, const Key('clicker-burst')))))),
                if (reduce && _staticGain != null)
                  Align(
                      alignment: Alignment.topCenter,
                      child: IgnorePointer(child: _gain(_staticGain!, const Key('clicker-static-gain')))),
              ]);
            })));
  }

  static Widget _gain(BigInt amount, Key key) => Text('+${compactNumber(amount)}',
      key: key,
      style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xffffedab),
          shadows: [Shadow(color: Colors.black, blurRadius: 4)]));
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
      const PixelIcon('bun', size: 18),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Cozy.ink, fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(width: 6),
      const PixelIcon('bun', size: 18),
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
    for (var i = 0; i < s.grid.cells.length; i++)
      if (s.grid.cells[i].cooking) i
  };
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
                    maxLock: 48,
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
              final grade = cell.cooking ? s.grid.doneness(i, c.config) : null;
              final label = cell.cooking
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
                      enabled: enabled,
                      child: InkWell(
                          key: Key('workshop-cell-$i'),
                          onTap: !enabled
                              ? null
                              : () => cell.cooking
                                  ? c.harvestCell(i, expectedCycle: cycle)
                                  : c.startCell(i),
                          child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: cell.cooking
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
                              child: cell.cooking
                                  ? Text(
                                      '${i + 1} ${provisionalDonenessLabels[grade!]}\n${grade == 4 ? '폐기' : '수확'}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 10, color: Cozy.cream))
                                  : null))));
            })
        ]);
      });
}
