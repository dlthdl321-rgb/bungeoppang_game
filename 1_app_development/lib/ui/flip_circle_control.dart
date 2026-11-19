import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_flip.dart';
import '../development_balance.dart';
import '../feedback_config.dart';
import 'cozy_style.dart';
import 'workshop_mold_stage.dart' show WorkshopMoldArt, MoldAxlePainter;

/// The flipping step on the special bungeoppang mold (24번 6단계 DEC-034 →
/// 26번 3차 피드백 H21 '고리에 걸려 실제로 돌아가듯이'): the closed mold
/// hangs on an axle through its two side rings ([MoldAxlePainter] draws the
/// pins and brackets), and the player pushes it up (or down) with a finger.
/// The mold turns over that axle with the push ([FlipAxle]); past
/// [flipAxleDoneDegrees] it falls the rest of the way over in `flip_ms`
/// and then [onFlip] sends the command; a failed command puts it back.
///
/// Same input rules as the piping steps (MoldPaintControl): only the first
/// pointer counts and the gesture is claimed at once (no scrolling). Lifting
/// the finger early, pointer cancel, [blocked], a new [stageToken] or leaving
/// the app drops the mold back flat, and also stops a flip that has not been
/// sent yet. A tap alone never flips. The screen reader's activation flips
/// it (like '고르게 칠하기' of the piping steps). [reduceMotion] keeps the
/// mold still (no turning); the progress, the wait and the judgement stay.
class FlipCircleControl extends StatefulWidget {
  final int stageToken;
  final bool blocked, reduceMotion, vibration;
  final DevelopmentBalance config;

  /// [WorkshopMoldArt.fit] grow of the mold under this control.
  final double grow;

  /// How far the caption sits above the bottom, clear of the stage's
  /// '제작 취소' button (WorkshopMoldStage).
  final double captionLift;

  /// The closed mold picture, turned and flipped by this control.
  final Widget mold;
  final Future<bool> Function() onFlip;
  const FlipCircleControl({super.key, required this.stageToken, required this.blocked,
      required this.config, required this.mold, required this.onFlip, this.grow = 1, this.captionLift = 0,
      this.reduceMotion = false, this.vibration = false});
  @override
  State<FlipCircleControl> createState() => FlipCircleControlState();
}

class FlipCircleControlState extends State<FlipCircleControl>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flip;
  FlipAxle? _axle;
  _Push? _push;
  bool _sent = false;

  /// Where the push was when the mold started falling over (degrees).
  double _from = 0;

  /// The push being made, for tests.
  FlipAxle? get axle => _axle;
  bool get flipping => _flip.isAnimating || _sent;

  /// The mold's turn now, in degrees (sign = direction): the push, or the
  /// fall to a whole half turn while flipping.
  double get turn {
    if (_flip.value > 0 || _sent) {
      final end = _from < 0 ? -180.0 : 180.0;
      return _from + (end - _from) * Curves.easeIn.transform(_flip.value);
    }
    return _axle?.degrees ?? 0;
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
    if (_sent) return;
    final had = _axle != null || _flip.value != 0;
    _axle = null;
    _from = 0;
    _flip.stop();
    _flip.value = 0;
    if (had && mounted) setState(() {});
  }

  /// The mold's height on screen: one of it turns [flipAxleDegreesPerHeight].
  double get _moldHeight {
    final box = context.findRenderObject() as RenderBox;
    final (k, _) = WorkshopMoldArt.fit(box.size, widget.grow);
    return WorkshopMoldArt.fishRect.height * k;
  }

  Drag? _start(Offset global) {
    if (widget.blocked || _push != null || flipping || !mounted) return null;
    final push = _Push(this, widget.stageToken);
    _push = push;
    _axle = FlipAxle(height: _moldHeight, startY: global.dy);
    return push;
  }

  void _move(Offset global) {
    final axle = _axle;
    if (axle == null || flipping) return;
    axle.moveTo(global.dy);
    if (axle.done) {
      _push?.dead = true;
      _push = null;
      _begin();
    }
    setState(() {});
  }

  /// The finger lifted before the mold went over: back flat (DEC-034).
  void _end() {
    _push = null;
    if (!flipping) _reset();
  }

  /// Pushed past the top (or the screen reader flipped it): fall over in
  /// `flip_ms`, then send the command.
  void _begin() {
    if (widget.blocked || flipping) return;
    if (widget.vibration) HapticFeedback.selectionClick();
    _from = _axle?.degrees ?? 0;
    _flip.forward(from: 0);
  }

  void _activate() {
    if (widget.blocked || _push != null || flipping) return;
    _axle = null;
    setState(_begin);
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
    if (!ok) _reset();
  }

  String get caption {
    if (flipping) return '뒤집는 중…';
    final axle = _axle;
    if (axle == null || axle.degrees == 0) return '틀을 위로 밀어 올려 뒤집어요';
    return '뒤집기 ${(axle.progress * 100).floor()}% · 손을 떼면 처음부터';
  }

  @override
  Widget build(BuildContext context) {
    final degrees = turn;
    final still = widget.reduceMotion;
    final progress = flipping ? 1.0 : _axle?.progress ?? 0;
    return Semantics(
      button: true,
      enabled: !widget.blocked,
      label: '틀 뒤집기',
      hint: '틀을 위로 밀어 올리거나, 화면 읽기 기능으로 두 번 활성화하면 뒤집어요.',
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
              // The pins stay on the axle in front of the turning mold, the
              // progress ring round the right one.
              IgnorePointer(
                  child: CustomPaint(
                      key: const Key('flip-ring'),
                      painter: MoldAxlePainter(grow: widget.grow, front: true, progress: progress,
                          hint: _axle == null && !flipping))),
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
