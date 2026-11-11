import 'package:flutter/material.dart';
import '../development_balance.dart';
import '../workshop_controller.dart';
import '../workshop_tutorial.dart';
import 'celebration.dart' show CountUpText;
import 'cozy_style.dart';

/// First-run guide over the real home: a ring around the widget keyed
/// [WorkshopTutorialStep.target] inside [home], and a small card beside it.
/// Only the card takes touches; the game underneath stays playable.
class WorkshopTutorialOverlay extends StatefulWidget {
  final WorkshopTutorialStep step;
  final GlobalKey home;
  final VoidCallback? onSkip;
  const WorkshopTutorialOverlay({super.key, required this.step, required this.home, required this.onSkip});
  @override
  State<WorkshopTutorialOverlay> createState() => _WorkshopTutorialOverlayState();
}

class _WorkshopTutorialOverlayState extends State<WorkshopTutorialOverlay> {
  Rect? _target, _below, _nav;
  Rect? _find(String name) {
    final overlay = context.findRenderObject(), root = widget.home.currentContext;
    if (overlay is! RenderBox || !overlay.hasSize || root is! Element) return null;
    final key = Key(name);
    Rect? found;
    void visit(Element e) {
      if (found != null) return;
      final box = e.widget.key == key ? e.findRenderObject() : null;
      if (box is RenderBox && box.hasSize && box.attached) {
        found = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
        return;
      }
      e.visitChildren(visit);
    }
    root.visitChildren(visit);
    return found;
  }
  void _measure() {
    if (!mounted) return;
    final target = _find(widget.step.target), below = widget.step.below == null ? null : _find(widget.step.below!);
    final nav = _find('home-nav');
    if (target != _target || below != _below || nav != _nav) {
      setState(() { _target = target; _below = below; _nav = nav; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Targets move and appear with the game state: measure after each frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final target = _target;
    return LayoutBuilder(builder: (context, box) {
      final card = CozyPanel(
          key: const Key('tutorial-card'),
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('첫 영업 안내 ${widget.step.number}/$workshopTutorialSteps', key: const Key('tutorial-progress'),
                  style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
              Text(widget.step.text, key: const Key('tutorial-text'), style: const TextStyle(fontSize: 15)),
            ])),
            TextButton(key: const Key('tutorial-skip'), onPressed: widget.onSkip,
                child: const Text('건너뛰기', style: TextStyle(color: Cozy.wood))),
          ]));
      // Under the stage, or beside the target on the side with more room;
      // always between the top edge and the bottom menu, even at large text.
      final limit = (_nav?.top ?? box.maxHeight) - 6;
      final _CardPlace place;
      if (_below != null) {
        place = _CardPlace.top(_below!.bottom + 6);
      } else if (target == null) {
        place = const _CardPlace.bottom(double.infinity);
      } else if (target.center.dy > box.maxHeight / 2) {
        place = _CardPlace.bottom(target.top - 10);
      } else {
        place = _CardPlace.top(target.bottom + 10);
      }
      final placed = Positioned.fill(child: CustomSingleChildLayout(
          delegate: _CardLayout(place, limit: limit), child: card));
      return Stack(children: [
        if (target != null)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
              key: const Key('tutorial-ring'), painter: _RingPainter(target.inflate(4))))),
        placed,
      ]);
    });
  }
}

/// Where the card wants to be: its top at [y], or its bottom at [y].
class _CardPlace {
  final double y;
  final bool top;
  const _CardPlace.top(this.y) : top = true;
  const _CardPlace.bottom(this.y) : top = false;
  @override
  bool operator ==(Object other) => other is _CardPlace && other.y == y && other.top == top;
  @override
  int get hashCode => Object.hash(y, top);
}

/// Lays the card out 72px from the left (clear of the customer queue) and
/// slides it up or down to stay above [limit], the bottom menu's top.
class _CardLayout extends SingleChildLayoutDelegate {
  static const left = 72.0, right = 12.0, edge = 8.0;
  final _CardPlace place;
  final double limit;
  const _CardLayout(this.place, {required this.limit});
  double _limit(Size size) => limit.clamp(edge * 2, size.height - edge);
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
      maxWidth: (constraints.maxWidth - left - right).clamp(0.0, double.infinity),
      maxHeight: (_limit(constraints.biggest) - edge).clamp(0.0, double.infinity));
  @override
  Offset getPositionForChild(Size size, Size child) {
    final bottom = _limit(size);
    final wanted = place.top ? place.y : place.y.clamp(0.0, bottom) - child.height;
    return Offset(left, wanted.clamp(edge, (bottom - child.height).clamp(edge, double.infinity)));
  }
  @override
  bool shouldRelayout(_CardLayout old) => old.place != place || old.limit != limit;
}

class _RingPainter extends CustomPainter {
  final Rect target;
  const _RingPainter(this.target);
  @override
  void paint(Canvas canvas, Size size) {
    final ring = RRect.fromRectAndRadius(target, const Radius.circular(14));
    canvas.drawRRect(ring, Paint()
      ..color = Cozy.honeyLight.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(ring, Paint()
      ..color = Cozy.honeyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }
  @override
  bool shouldRepaint(_RingPainter old) => old.target != target;
}

/// The welcome-back card (복귀 안내): time away and what the stall made.
class WorkshopWelcomeBackCard extends StatelessWidget {
  final WorkshopAwayReport report;
  final DevelopmentBalance config;
  final bool reduceMotion;
  const WorkshopWelcomeBackCard({super.key, required this.report, required this.config, this.reduceMotion = false});

  @override
  Widget build(BuildContext context) {
    final fixed = config.section('fixed_requirements');
    final capHours = DevelopmentBalance.integer(fixed, 'offline_cap_ms') ~/ 3600000;
    final percent = DevelopmentBalance.integer(fixed, 'offline_efficiency_permille') ~/ 10;
    final hours = report.away.inHours, minutes = report.away.inMinutes % 60;
    const small = TextStyle(fontSize: 13, color: Cozy.inkSoft);
    return Dialog(
        key: const Key('welcome-back'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: CozyPanel(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            radius: 16,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('다시 오셨네요!', style: TextStyle(fontSize: 22, color: Cozy.wood)),
              const SizedBox(height: 4),
              Text('${hours > 0 ? '$hours시간 ' : ''}$minutes분 동안 자리를 비웠어요',
                  key: const Key('welcome-back-away'), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              if (report.open && report.buns > BigInt.zero) ...[
                const Text('그동안 구운 붕어빵력'),
                CountUpText(report.buns, key: const Key('welcome-back-buns'), instant: reduceMotion,
                    style: const TextStyle(fontSize: 28, color: Cozy.amber)),
                Text('자동 생산의 $percent%로, 최대 $capHours시간까지 쌓여요.', textAlign: TextAlign.center, style: small),
              ] else if (report.open)
                const Text('자동 생산 스킬을 배우면 자리 비운 동안에도 붕어빵력이 쌓여요.',
                    key: Key('welcome-back-none'), textAlign: TextAlign.center)
              else
                const Text('가게 문이 닫혀 있어서 쌓인 붕어빵력은 없어요. 영업 중일 때만 자동 생산이 쌓여요.',
                    key: Key('welcome-back-closed'), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(report.waiting > 0
                  ? '판매는 가게에 계실 때만 해요. 기다리던 손님 ${report.waiting}명은 그대로 있어요.'
                  : '판매는 가게에 계실 때만 해요. 손님도 그때 찾아와요.',
                  key: const Key('welcome-back-sales'), textAlign: TextAlign.center, style: small),
              const SizedBox(height: 12),
              CozyPrimaryButton(key: const Key('welcome-back-close'), minHeight: 44,
                  onPressed: () => Navigator.pop(context), label: '확인'),
            ]))));
  }
}
