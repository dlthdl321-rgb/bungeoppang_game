import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_flip.dart';
import '../development_balance.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'workshop_mold_stage.dart' show WorkshopMoldArt;

/// The flipping step on the special bungeoppang mold (24번 6단계, DEC-034):
/// the player draws a circle around the mold. The mold ([mold]) turns with
/// the swept angle and a ring shows how far it is. At
/// `manual_cooking.flip_turn_degrees` the mold flips over in `flip_ms` and
/// then [onFlip] sends the command; a failed command puts the mold back.
///
/// Same input rules as the piping steps (MoldPaintControl): only the first
/// pointer counts and the gesture is claimed at once (no scrolling). Lifting
/// the finger early, pointer cancel, [blocked], a new [stageToken] or leaving
/// the app drops the circle back to 0 degrees and the mold to its place, and
/// also stops a flip that has not been sent yet. The screen reader's
/// activation flips it (like '고르게 칠하기' of the piping steps).
/// [reduceMotion] keeps the mold still (no turning, no flip-over); the ring,
/// the wait and the judgement stay the same.
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
  /// The mold picture canvas width (WorkshopMoldArt, mold/*.png): the dead
  /// zone is `flip_dead_zone_permille` of it.
  static const moldPictureWidth = 1200.0;
  late final AnimationController _flip;
  FlipCircle? _circle;
  _Turn? _turn;
  bool _sent = false;

  /// The circle being drawn, for tests.
  FlipCircle? get circle => _circle;
  bool get flipping => _flip.isAnimating || _sent;

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

  /// Back to 0 degrees and the mold in its place. A command already sent is
  /// left to the controller.
  void _reset() {
    _turn?.dead = true;
    _turn = null;
    if (_sent) return;
    final had = _circle != null || _flip.value != 0;
    _circle = null;
    _flip.stop();
    _flip.value = 0;
    if (had && mounted) setState(() {});
  }

  Drag? _start(Offset global) {
    if (widget.blocked || _turn != null || flipping || !mounted) return null;
    final box = context.findRenderObject() as RenderBox;
    final (k, _) = WorkshopMoldArt.fit(box.size, widget.grow);
    final turn = _Turn(this, widget.stageToken);
    _turn = turn;
    _circle = FlipCircle.forMold(widget.config, moldPictureWidth * k);
    _move(global);
    return turn;
  }

  void _move(Offset global) {
    final circle = _circle;
    if (circle == null || flipping) return;
    final box = context.findRenderObject() as RenderBox;
    final at = box.globalToLocal(global) - box.size.center(Offset.zero);
    circle.moveTo(at.dx, at.dy);
    if (circle.done) {
      _turn?.dead = true;
      _turn = null;
      _begin();
    }
    setState(() {});
  }

  /// The finger lifted before the circle was done: back to 0 (DEC-034).
  void _end() {
    _turn = null;
    if (!flipping) _reset();
  }

  /// The circle is done (or the screen reader flipped it): flip over in
  /// `flip_ms`, then send the command.
  void _begin() {
    if (widget.blocked || flipping) return;
    if (widget.vibration) HapticFeedback.selectionClick();
    _flip.forward(from: 0);
  }

  void _activate() {
    if (widget.blocked || _turn != null || flipping) return;
    _circle = null;
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
    final circle = _circle;
    if (circle == null || circle.degrees == 0) return '틀 둘레로 원을 한 바퀴 그려 뒤집어요';
    return '뒤집기 ${(circle.progress * 100).floor()}% · 손을 떼면 처음부터';
  }

  @override
  Widget build(BuildContext context) {
    final circle = _circle;
    final t = Curves.easeInOut.transform(_flip.value);
    final degrees = circle?.degrees ?? 0;
    final still = widget.reduceMotion;
    // While flipping a drawn turn eases on to a whole turn (looks like 0);
    // the screen reader's flip does not turn at all.
    final shown = degrees == 0 ? 0.0 : degrees + ((degrees > 0 ? 360 : -360) - degrees) * t;
    final progress = flipping ? 1.0 : circle?.progress ?? 0;
    Widget mold = widget.mold;
    if (!still) {
      mold = Transform.rotate(angle: shown * math.pi / 180, child: mold);
      if (_flip.value > 0) {
        // Over the long axis: edge-on half way, then the other side (which
        // looks the same) comes up, so the back half is drawn mirrored back.
        final m = Matrix4.identity()
          ..setEntry(3, 2, .0015)
          ..translateByDouble(0.0, -18 * math.sin(math.pi * t), 0.0, 1.0)
          ..rotateX(math.pi * t);
        if (t > .5) m.scaleByDouble(1.0, -1.0, 1.0, 1.0);
        mold = Transform(alignment: Alignment.center, transform: m, child: mold);
      }
    }
    return Semantics(
      button: true,
      enabled: !widget.blocked,
      label: '틀 뒤집기',
      hint: '틀 둘레로 원을 한 바퀴 그리거나, 화면 읽기 기능으로 두 번 활성화하면 뒤집어요.',
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
          child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
            IgnorePointer(child: KeyedSubtree(key: const Key('flip-mold'), child: mold)),
            IgnorePointer(
                child: CustomPaint(
                    key: const Key('flip-ring'),
                    painter: _RingPainter(progress, degrees < 0, widget.grow,
                        idle: circle == null && !flipping))),
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
          ]),
        ),
      ),
    );
  }
}

class _Turn extends Drag {
  final FlipCircleControlState owner;
  final int token;
  bool dead = false;
  _Turn(this.owner, this.token);
  bool get _live => !dead && owner.mounted && owner._turn == this &&
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

/// The guide ring around the mold and the honey arc of the swept turn
/// (25번 필요한 그림 5번: fx/flip_ring.png with its two clockwise arrowheads,
/// and fx/flip_ring_fill.png cut to the swept angle from 12 o'clock). When
/// those pictures are missing it draws them (arrowheads only while idle).
class _RingPainter extends CustomPainter {
  /// Ring radius in the 512x512 ring pictures (centre at the middle).
  static const pictureRadius = 236.0;
  static final _smooth = Paint()..filterQuality = FilterQuality.medium;
  final double progress, grow;
  final bool counter, idle;
  _RingPainter(this.progress, this.counter, this.grow, {required this.idle});
  @override
  void paint(Canvas canvas, Size size) {
    final (k, _) = WorkshopMoldArt.fit(size, grow);
    final centre = size.center(Offset.zero);
    // Around the mold body, within the stage's height on small screens.
    final r = 400 * k;
    final ring = PixelSprites.fx('flip_ring'), fill = PixelSprites.fx('flip_ring_fill');
    if (ring != null && fill != null) {
      void draw(ui.Image image) {
        final s = r / pictureRadius;
        canvas.drawImageRect(
            image,
            Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
            Rect.fromCenter(center: centre, width: image.width * s, height: image.height * s),
            _smooth);
      }
      draw(ring);
      if (progress <= 0) return;
      canvas.save();
      if (progress < 1) {
        final sweep = progress * 2 * math.pi * (counter ? -1 : 1);
        canvas.clipPath(Path()
          ..moveTo(centre.dx, centre.dy)
          ..arcTo(Rect.fromCircle(center: centre, radius: r * 1.3), -math.pi / 2, sweep, false)
          ..close());
      }
      draw(fill);
      canvas.restore();
      return;
    }
    final guide = Paint()
      ..color = Cozy.cream.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(centre, r, guide);
    if (idle) {
      final arrow = Paint()..color = Cozy.cream.withValues(alpha: .85);
      for (final a in [-math.pi / 4, math.pi * 3 / 4]) {
        final p = centre + Offset(math.cos(a), math.sin(a)) * r;
        // Clockwise tangent at angle a (y down).
        final tangent = Offset(-math.sin(a), math.cos(a));
        final normal = Offset(math.cos(a), math.sin(a));
        canvas.drawPath(
            Path()
              ..moveTo(p.dx + tangent.dx * 9, p.dy + tangent.dy * 9)
              ..lineTo(p.dx - tangent.dx * 5 + normal.dx * 7, p.dy - tangent.dy * 5 + normal.dy * 7)
              ..lineTo(p.dx - tangent.dx * 5 - normal.dx * 7, p.dy - tangent.dy * 5 - normal.dy * 7)
              ..close(),
            arrow);
      }
    }
    if (progress <= 0) return;
    final sweep = progress * 2 * math.pi * (counter ? -1 : 1);
    canvas.drawArc(Rect.fromCircle(center: centre, radius: r), -math.pi / 2, sweep, false,
        Paint()
          ..color = Cozy.honey
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress ||
      old.counter != counter || old.idle != idle || old.grow != grow;
}
