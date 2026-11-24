import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_flip.dart';
import '../development_balance.dart';
import '../feedback_config.dart';
import 'cozy_style.dart';
import 'workshop_mold_stage.dart' show WorkshopMoldArt, MoldAxlePainter;

/// The flipping step on the special bungeoppang mold (24번 6단계 DEC-034,
/// 4차 피드백 IC5 2026-11-20 사용자 결정: '원 그리기, 그리는 대로 틀이
/// 돌아가게'): the player draws circles round the closed mold with a finger
/// ([FlipCircle]) and the mold turns over its axle as the circle goes on —
/// [FlipCircle.moldDegrees], a half turn when the circle is done. Then
/// [onFlip] sends the command; a failed command puts it back flat. The turn
/// transforms the given [mold] picture, so it works with any mold art.
///
/// Same input rules as the piping steps (MoldPaintControl): only the first
/// pointer counts and the gesture is claimed at once (no scrolling); the
/// touch area reaches [touchOutset] past the mold's box. Lifting the finger
/// early, pointer cancel, [blocked], a new [stageToken] or leaving the app
/// drops the mold back flat, and also stops a flip that has not been sent
/// yet. A tap alone never flips. The screen reader's activation flips it
/// over in `flip_ms` (like '고르게 칠하기' of the piping steps).
/// [reduceMotion] keeps the mold still (no turning); the caption's
/// progress, the wait and the judgement stay.
class FlipCircleControl extends StatefulWidget {
  final int stageToken;
  final bool blocked, reduceMotion, vibration;
  final DevelopmentBalance config;

  /// [WorkshopMoldArt.fit] grow of the mold under this control.
  final double grow;

  /// How far the caption sits above the bottom, clear of the stage's
  /// '제작 취소' button (WorkshopMoldStage).
  final double captionLift;

  /// How far this control's box reaches past the mold's box on each side
  /// (a bigger touch area; the mold and caption keep the inner box).
  final EdgeInsets touchOutset;

  /// The closed mold picture, turned and flipped by this control.
  final Widget mold;
  final Future<bool> Function() onFlip;
  const FlipCircleControl({super.key, required this.stageToken, required this.blocked,
      required this.config, required this.mold, required this.onFlip, this.grow = 1, this.captionLift = 0,
      this.touchOutset = EdgeInsets.zero, this.reduceMotion = false, this.vibration = false});
  @override
  State<FlipCircleControl> createState() => FlipCircleControlState();
}

class FlipCircleControlState extends State<FlipCircleControl>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flip;
  FlipCircle? _circle;
  _Push? _push;
  bool _sent = false;

  /// The command went through: the mold stays over until the stage moves on.
  bool _flipped = false;

  /// Where the mold was when it started its last fall over (degrees): a
  /// whole half turn after a finished circle, 0 for the screen reader.
  double _from = 0;

  /// The circle being drawn, for tests.
  FlipCircle? get circle => _circle;
  bool get flipping => _flip.isAnimating || _sent || _flipped;

  /// The mold's turn now, in degrees (sign = direction): following the
  /// circle, or falling to a whole half turn while flipping.
  double get turn {
    if (_flip.value > 0 || _sent || _flipped) {
      final end = _from < 0 ? -180.0 : 180.0;
      return _from + (end - _from) * Curves.easeIn.transform(_flip.value);
    }
    return _circle?.moldDegrees ?? 0;
  }

  Map<String, dynamic> get _manual => widget.config.section('manual_cooking');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flip = AnimationController(vsync: this,
        duration: Duration(milliseconds: DevelopmentBalance.integer(_manual, 'flip_ms')))
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _send();
      });
  }

  @override
  void didUpdateWidget(covariant FlipCircleControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageToken != widget.stageToken) _flipped = false;
    if (oldWidget.stageToken != widget.stageToken || widget.blocked) _reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flip.dispose();
    super.dispose();
  }

  /// Back flat. A command already sent is left to the controller.
  void _reset() {
    _push?.dead = true;
    _push = null;
    if (_sent || _flipped) return;
    final had = _circle != null || _flip.value != 0;
    _circle = null;
    _from = 0;
    _flip.stop();
    _flip.value = 0;
    if (had && mounted) setState(() {});
  }

  /// The mold picture's size on screen (the circle's dead zone is a share
  /// of its width) and the mold's centre on screen.
  (Size, Offset) get _mold {
    final box = context.findRenderObject() as RenderBox;
    final size = widget.touchOutset.deflateSize(box.size);
    final (k, origin) = WorkshopMoldArt.fit(size, widget.grow);
    final centre = origin + WorkshopMoldArt.fishRect.center * k +
        Offset(widget.touchOutset.left, widget.touchOutset.top);
    return (WorkshopMoldArt.pictureSize * k, box.localToGlobal(centre));
  }

  Drag? _start(Offset global) {
    if (widget.blocked || _push != null || flipping || !mounted) return null;
    final push = _Push(this, widget.stageToken);
    _push = push;
    _circle = FlipCircle.forMold(widget.config, _mold.$1.width);
    _move(global);
    return push;
  }

  void _move(Offset global) {
    final circle = _circle;
    if (circle == null || flipping) return;
    final at = global - _mold.$2;
    circle.moveTo(at.dx, at.dy);
    if (circle.done) {
      _push?.dead = true;
      _push = null;
      _finish();
    }
    setState(() {});
  }

  /// The finger lifted before the circle was done: back flat (DEC-034).
  void _end() {
    _push = null;
    if (!flipping) _reset();
  }

  /// The circle is done: the mold has turned over with it, so the command
  /// goes now (the stage waits out the rest of `flip_ms`, if any).
  void _finish() {
    if (widget.blocked || flipping) return;
    if (widget.vibration) HapticFeedback.selectionClick();
    _from = (_circle?.degrees ?? 0) < 0 ? -180 : 180;
    // Completing the controller sends the command (its status listener).
    _flip.value = 1;
  }

  /// The screen reader flipped it: fall over in `flip_ms`, then send.
  void _activate() {
    if (widget.blocked || _push != null || flipping) return;
    _circle = null;
    setState(() {
      if (widget.vibration) HapticFeedback.selectionClick();
      _from = 0;
      _flip.forward(from: 0);
    });
  }

  Future<void> _send() async {
    if (_sent || widget.blocked || !mounted) {
      _reset();
      return;
    }
    _sent = true;
    final ok = await widget.onFlip();
    if (!mounted) return;
    _sent = false;
    if (ok) {
      _flipped = true;
    } else {
      _reset();
    }
  }

  String get caption {
    if (flipping) return '뒤집는 중…';
    final circle = _circle;
    if (circle == null || circle.degrees == 0) return '틀 둘레에 원을 그려 뒤집어요';
    return '뒤집기 ${(circle.progress * 100).floor()}% · 손을 떼면 처음부터';
  }

  @override
  Widget build(BuildContext context) {
    final degrees = turn;
    final still = widget.reduceMotion;
    return Semantics(
      button: true,
      enabled: !widget.blocked,
      label: '틀 뒤집기',
      hint: '틀 둘레에 원을 그리거나, 화면 읽기 기능으로 두 번 활성화하면 뒤집어요.',
      onTap: widget.blocked ? null : _activate,
      child: ExcludeSemantics(
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImmediateMultiDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                    ImmediateMultiDragGestureRecognizer.new,
                    (r) => r.onStart = _start),
          },
          child: Padding(
            padding: widget.touchOutset,
            child: LayoutBuilder(builder: (context, box) {
            final size = box.biggest;
            final (k, origin) = WorkshopMoldArt.fit(size, widget.grow);
            // The axle line: through the two side rings.
            final axleY = origin.dy + flipAxleLeftRing.$2 * k;
            Widget mold = widget.mold;
            if (!still && degrees != 0) {
              final a = degrees * math.pi / 180;
              // Over the axle (x axis): edge-on at 90°, then the back
              // (which looks the same) comes up, drawn mirrored back.
              final m = Matrix4.identity()
                ..setEntry(3, 2, .0018)
                ..rotateX(-a);
              if (degrees.abs() > 90) m.scaleByDouble(1.0, -1.0, 1.0, 1.0);
              mold = Transform(
                  key: const Key('flip-turn'),
                  origin: Offset(size.width / 2, axleY),
                  transform: m,
                  child: mold);
            }
            return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
              IgnorePointer(child: KeyedSubtree(key: const Key('flip-mold'), child: mold)),
              // The pins stay on the axle in front of the turning mold
              // (no progress ring, 4차 피드백 IC8), and before a circle a
              // round arrow shows how to draw it.
              IgnorePointer(
                  child: CustomPaint(
                      key: const Key('flip-pins'),
                      painter: MoldAxlePainter(grow: widget.grow, front: true,
                          hint: _circle == null && !flipping))),
              Padding(
                  padding: EdgeInsets.only(bottom: widget.captionLift),
                  child: Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Cozy.woodDark.withValues(alpha: .9),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(caption,
                              key: const Key('flip-caption'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Cozy.cream, fontWeight: FontWeight.bold, fontSize: 13)))))),
            ]);
          }),
          ),
        ),
      ),
    );
  }
}

class _Push extends Drag {
  final FlipCircleControlState owner;
  final int token;
  bool dead = false;
  _Push(this.owner, this.token);
  bool get _live => !dead && owner.mounted && owner._push == this &&
      owner.widget.stageToken == token;
  @override
  void update(DragUpdateDetails details) {
    if (_live) owner._move(details.globalPosition);
  }

  @override
  void end(DragEndDetails details) {
    if (_live) owner._end();
  }

  @override
  void cancel() {
    if (_live) owner._reset();
  }
}
