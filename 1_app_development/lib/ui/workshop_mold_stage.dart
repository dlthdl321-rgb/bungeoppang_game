import 'dart:math' as math;
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
import 'fish_painter.dart';
import 'cooking_mold_painter.dart';
import 'pixel_sprites.dart';

/// Presentation only. All commands still pass through WorkshopController.
class WorkshopMoldStage extends StatefulWidget {
  final WorkshopController controller;
  final Rect? fishOnScreen;
  final Widget sensorControl;
  const WorkshopMoldStage(
      {super.key,
      required this.controller,
      required this.fishOnScreen,
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
  void dispose() { _scroll?.removeListener(_scrolled); super.dispose(); }
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
      Widget mold(Widget interaction) => Positioned.fromRect(
          rect: rect,
          child: Stack(fit: StackFit.expand, clipBehavior:Clip.none, children: [
            if (session == null && mapped == null) const IgnorePointer(child: CustomPaint(painter: FishPainter())),
            if (session != null) Positioned.fill(left:-rect.height*.2,right:-rect.height*.2,top:-rect.height*.2,bottom:-rect.height*.2,
              child:IgnorePointer(child:CustomPaint(key:const Key('active-empty-mold'),painter:CookingMoldPainter(
                phase:session.phase,hasBatter:session.firstBatterMs!=null && session.firstBatterMs!>0,
                hasFilling:session.fillingDurationMs!=null && session.fillingDurationMs!>0 && session.secondBatterMs==null)))),
            if(session?.phase==CookingPhase.result) const IgnorePointer(child:CustomPaint(painter:FishPainter())),
            interaction,
          ]));
      Widget action(String label, VoidCallback command) => Semantics(
          button: true,
          label: label,
          child: InkWell(
              key: const Key('workshop-mold-action'),
              onTap: blocked ? null : command,
              child: Center(child: _caption(label))));
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
