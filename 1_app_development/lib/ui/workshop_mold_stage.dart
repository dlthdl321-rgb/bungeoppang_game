import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cosmetic_config.dart';
import '../development_balance.dart';
import '../workshop_controller.dart';
import 'boost_effects.dart';
import 'piping_bag_control.dart';
import 'cooking_session_controls.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// Presentation only. All commands still pass through WorkshopController.
///
/// With [cleanCounter] (a background without the baked mold) the stage
/// follows the 메인UI mockup: while the stall is open the bungeoppang floats
/// with no mold; before opening, and for [orderFlash] after a new order
/// arrives, it sits in the iron mold. Otherwise the baked art shows.
class WorkshopMoldStage extends StatefulWidget {
  final WorkshopController controller;
  final Rect? fishOnScreen;
  final bool cleanCounter;
  final Widget sensorControl;
  const WorkshopMoldStage(
      {super.key,
      required this.controller,
      required this.fishOnScreen,
      this.cleanCounter = false,
      required this.sensorControl});

  /// How long a new order shows the fish back in its mold.
  static const orderFlash = Duration(milliseconds: 2500);
  @override
  State<WorkshopMoldStage> createState() => _WorkshopMoldStageState();
}

class _WorkshopMoldStageState extends State<WorkshopMoldStage> {
  Offset _origin = Offset.zero;
  ScrollPosition? _scroll;
  Set<String> _seenOrders = {};
  Timer? _flash;
  void _scrolled() { if (mounted) setState(() {}); }
  @override
  void initState() {
    super.initState();
    _seenOrders = _orderIds();
    widget.controller.addListener(_ordersChanged);
  }
  @override
  void didUpdateWidget(covariant WorkshopMoldStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_ordersChanged);
      widget.controller.addListener(_ordersChanged);
      _seenOrders = _orderIds();
    }
  }
  Set<String> _orderIds() =>
      {for (final o in widget.controller.state.customers) o.id};
  void _ordersChanged() {
    final ids = _orderIds();
    final arrived = ids.difference(_seenOrders).isNotEmpty;
    _seenOrders = ids;
    if (!arrived || !widget.controller.state.business.open) return;
    _flash?.cancel();
    _flash = Timer(WorkshopMoldStage.orderFlash, () {
      if (mounted) setState(() => _flash = null);
    });
    if (mounted) setState(() {});
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scroll?.removeListener(_scrolled);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_scrolled);
  }
  @override
  void dispose() {
    _flash?.cancel();
    widget.controller.removeListener(_ordersChanged);
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
    return LayoutBuilder(builder: (context, box) {
      final fallback = Rect.fromCenter(
          center: Offset(box.maxWidth / 2, box.maxHeight * .59),
          width: math.min(box.maxWidth * .78, 330),
          height: math.min(box.maxHeight * .42, 190));
      final mapped = widget.fishOnScreen?.shift(-_origin);
      final rect = mapped ?? fallback;
      final clean = widget.cleanCounter || mapped == null;
      // Idle: float while open, sit in the mold before opening or on a new order.
      final floating = session == null && clean &&
          s.business.open && _flash == null;
      final String? idleMold = session != null || floating
          ? null
          : clean ? 'empty' : null;
      Widget mold(Widget interaction) => Positioned.fromRect(
          rect: rect,
          child: Stack(fit: StackFit.expand, clipBehavior:Clip.none, children: [
            if (floating)
              Positioned.fill(
                  top: -rect.height * .75, bottom: rect.height * .75,
                  child: const IgnorePointer(
                      key: Key('floating-fish'),
                      child: CustomPaint(painter: FloatingFishPainter()))),
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
                  ? Align(alignment: const Alignment(0, 1.25),
                      child: FittedBox(fit: BoxFit.scaleDown, child: _pill(label)))
                  : Center(child: _caption(label))));
      final Widget control;
      if (session == null) {
        control = action('큰 틀 연습 시작', c.startPractice);
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
        Positioned(
            top: 0,
            left: 8,
            right: 8,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (session == null)
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
                  TextButton(
                      onPressed: blocked ? null : c.tap,
                      child: _caption('+${c.tapRate} 붕어빵력')),
                ])
              else ...[
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
        final enabled = !c.busy &&
            c.error == null &&
            !c.gameplayPaused &&
            s.session == null &&
            s.business.permitsProducts(c.now()) &&
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
                  : '${i + 1}번 굽기 시작';
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
                                      : Colors.black26,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                  cell.cooking
                                      ? '${i + 1} ${provisionalDonenessLabels[grade!]}\n${grade == 4 ? '폐기' : '수확'}'
                                      : '${i + 1} 시작',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 10, color: Cozy.cream))))));
            })
        ]);
      });
}
