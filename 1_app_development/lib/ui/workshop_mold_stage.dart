import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cosmetic_config.dart';
import '../development_balance.dart';
import '../economy.dart' show compactNumber;
import '../feedback_config.dart';
import '../game_audio.dart';
import '../workshop_controller.dart';
import 'boost_effects.dart';
import 'piping_bag_control.dart';
import 'cooking_session_controls.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'tap_effects.dart';

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
  final bool cleanCounter, reduceMotion, vibration;
  final Widget sensorControl;
  const WorkshopMoldStage(
      {super.key,
      required this.controller,
      required this.fishOnScreen,
      this.counterTop,
      this.cleanCounter = false,
      this.reduceMotion = false,
      this.vibration = false,
      required this.sensorControl});

  @override
  State<WorkshopMoldStage> createState() => _WorkshopMoldStageState();
}

class _WorkshopMoldStageState extends State<WorkshopMoldStage> {
  Offset _origin = Offset.zero;
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
    final rule =
        c.config.mastery(c.difficulty(session?.flavor ?? s.selectedFlavor));
    // In business (and not waiting to continue a new day) the idle mold is
    // the clicker; before opening it is the practice mold.
    final inBusiness = s.business.permitsProducts(c.now());
    final clicker = session == null && inBusiness;
    final preparing = session == null && !s.business.open;
    return LayoutBuilder(builder: (context, box) {
      final fallback = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * .59),
          width: math.min(box.maxWidth * .78, 330),
          height: math.min(box.maxHeight * .42, 190));
      final mapped = widget.fishOnScreen?.shift(-_origin);
      final counterLocal =
          widget.counterTop == null ? null : widget.counterTop! - _origin.dy;
      final rect = mapped ?? fallback;
      final clean = widget.cleanCounter || mapped == null;
      // The clicker fish floats with no mold, above the mold's place.
      final floating = clicker && clean;
      final String? idleMold = session != null || floating
          ? null
          : clean ? 'empty' : null;
      Widget mold(Widget interaction) => Positioned.fromRect(
          rect: rect,
          child: Stack(key: const Key('workshop-mold'), fit: StackFit.expand, clipBehavior:Clip.none, children: [
            if (idleMold != null)
              IgnorePointer(child: CustomPaint(
                  key: const Key('idle-mold'),
                  painter: WorkshopMoldArt(idleMold, withFish: true))),
            if (session != null)
              IgnorePointer(child: CustomPaint(
                  key: const Key('active-empty-mold'),
                  painter: WorkshopMoldArt(moldFor(session),
                      withFish: session.phase == CookingPhase.result,
                      cover: !clean))),
            interaction,
          ]));
      Widget action(String label, VoidCallback command) => Semantics(
          button: true,
          label: label,
          child: InkWell(
              key: const Key('workshop-mold-action'),
              onTap: blocked ? null : command,
              child: session == null
                  ? counterLocal == null
                      ? Align(alignment: const Alignment(0, 1.25),
                          child: FittedBox(fit: BoxFit.scaleDown, child: _pill(label)))
                      // The counter's top is on the towel (DEC-038): the
                      // button's bottom stays 4 above it.
                      : Stack(clipBehavior: Clip.none, children: [
                          Positioned(left: 0, right: 0,
                              bottom: rect.bottom - (counterLocal - 4),
                              child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _pill(label)))),
                        ])
                  : Center(child: _caption(label))));
      final Widget control;
      if (session == null) {
        // Practice only before opening; waiting to continue a new day the
        // mold just sits there until the counter's '이어서 영업'.
        control = preparing
            ? action('스페셜 붕어빵 제작 시작', c.startPractice)
            : const SizedBox.shrink();
      } else {
        switch (session.phase) {
          case CookingPhase.firstBatter:
          case CookingPhase.secondBatter:
            final label = session.phase == CookingPhase.firstBatter
                ? '첫 반죽 붓기'
                : '둘째 반죽 붓기';
            control = BatterHoldButton(
                key: ValueKey('mold-batter:${session.id}'),
                stageToken: session.token,
                blocked: blocked,
                label: label,
                surfaceBuilder: (pouring) => PourAmountVisual(key:ValueKey('${session.token}:$pouring'),pouring:pouring,filling:false,capacityMs:DevelopmentBalance.integer(rule,'batter_target_ms')),
                onFinished: (ms) =>
                    c.cookingCommand(session.pour(session.token, ms)));
          case CookingPhase.closing:
            control = action(
                '뚜껑 닫기', () => c.cookingCommand(session.close(session.token)));
          case CookingPhase.flipping:
            control = action(
                '뒤집기', () => c.cookingCommand(session.flip(session.token)));
          case CookingPhase.cooking:
            control = action(
                '꺼내기 · ${(c.activePhaseElapsedMs / 1000).toStringAsFixed(1)}초',
                () => c.cookingCommand(
                    session.takeOut(session.token, c.activePhaseElapsedMs)));
          case CookingPhase.result:
            final result = evaluateCookingResult(c.config, session,
                difficulty: c.difficulty(session.flavor));
            control = Center(
                child: _caption(
                    '완성 · ${provisionalDonenessLabels[result.variant]}'));
          case CookingPhase.filling:
            control = PipingBagControl(key:ValueKey('piping:${session.id}'),onMold:true,
              stageToken:session.token,blocked:blocked,
              capacityMs:DevelopmentBalance.integer(c.config.section('manual_cooking'),'filling_capacity_ms'),
              onFinished:(ms)=>c.cookingCommand(session.squeezeFilling(session.token,ms)));
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
              rect: floating ? rect.shift(Offset(0, -rect.height * .75)) : rect,
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
              if (preparing)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  DropdownButton<String>(
                      value: s.selectedFlavor,
                      dropdownColor: Cozy.cream,
                      items: [
                        for (final flavor in s.recipes)
                          DropdownMenuItem(
                              value: flavor,
                              child: _caption(c.flavorLabel(flavor)))
                      ],
                      onChanged: blocked
                          ? null
                          : (value) {
                              if (value != null) c.selectFlavor(value);
                            }),
                ])
              else if (session != null) ...[
                _caption(
                    '${c.flavorLabel(session.flavor)} ${session.practice ? '연습' : '주문 제작'} · 반죽 목표 ${DevelopmentBalance.integer(rule, 'batter_target_ms') / 1000}초'),
                _caption('현재 단계 경과 ${(c.activePhaseElapsedMs / 1000).toStringAsFixed(1)}초${c.gameplayPaused ? ' · 일시정지' : ''}', key: const Key('workshop-phase-time')),
            if(session.phase==CookingPhase.firstBatter || session.phase==CookingPhase.secondBatter) widget.sensorControl,
              ],
            ])),
        if (session != null)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                  child: Wrap(spacing: 8, children: [
                if (session.phase == CookingPhase.result) ...[
                  FilledButton(
                      key: const Key('mold-store'),
                      onPressed: blocked ? null : () => c.storeResult(true),
                      child: Text(session.practice ? '보관' : '결과 닫기')),
                  if (session.practice)
                    TextButton(
                        onPressed: blocked ? null : () => c.storeResult(false),
                        child: _caption('버리기')),
                ] else
                  TextButton(
                      onPressed: blocked
                          ? null
                          : () => c.cookingCommand(session.cancel()),
                      child: _caption('제작 취소')),
              ]))),
      ]);
    });
  }
}

/// The mold picture for [session]'s step (PixelSprites.moldNames).
String moldFor(CookingSession session) {
  final poured = (session.firstBatterMs ?? 0) > 0;
  final filled = (session.fillingDurationMs ?? 0) > 0;
  final topped = (session.secondBatterMs ?? 0) > 0;
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

/// Draws one of the big mold pictures so its fish cavity covers the canvas
/// (the baked fish's place), with fish/redbean.png in it when [withFish].
/// [cover] grows it a little to hide a background's baked mold.
class WorkshopMoldArt extends CustomPainter {
  final String name;
  final bool withFish, cover;
  const WorkshopMoldArt(this.name, {this.withFish = false, this.cover = false});

  /// The fish body inside the mold canvas, and where fish/redbean.png sits
  /// (tools/make_home_stage_art.py).
  static const fishRect = Rect.fromLTRB(215, 174, 984, 706);
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
    if (withFish) drawAt(c, PixelSprites.fish('redbean', 'scales'), fishAt, k, origin);
  }

  @override
  bool shouldRepaint(covariant WorkshopMoldArt old) =>
      old.name != name || old.withFish != withFish || old.cover != cover;
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

/// The mockup's floating bungeoppang: no mold, a little larger, with
/// sparkles around it.
class FloatingFishPainter extends CustomPainter {
  const FloatingFishPainter();
  static const _sparkles = [
    Offset(.06, .30), Offset(.94, .20), Offset(.88, .80), Offset(.12, .88),
    Offset(.50, .00), Offset(.99, .55),
  ];

  @override
  void paint(Canvas c, Size size) {
    final (k, origin) = WorkshopMoldArt.fit(size, 1.08);
    WorkshopMoldArt.drawAt(c, PixelSprites.fish('redbean', 'scales'),
        WorkshopMoldArt.fishAt, k, origin);
    final sparkle = PixelSprites.fx('sparkle');
    if (sparkle == null) return;
    for (var i = 0; i < _sparkles.length; i++) {
      final s = size.shortestSide * (i.isEven ? .16 : .10);
      final p = Offset(_sparkles[i].dx * size.width, _sparkles[i].dy * size.height);
      PixelSprites.draw(c, sparkle, Rect.fromCenter(center: p, width: s, height: s));
    }
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
        final enabled = !c.busy &&
            c.error == null &&
            !c.gameplayPaused &&
            s.session == null &&
            s.masteryAwards.isNotEmpty;
        return Stack(children: [
          for (var i = 0; i < s.grid.cells.length; i++)
            Builder(builder: (context) {
              final cell = s.grid.cells[i], cycle = cell.cycle;
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
