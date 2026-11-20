import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../economy.dart' show compactNumber;
import '../feedback_config.dart';
import '../game_audio.dart';
import '../workshop_controller.dart';
import 'piping_bag_control.dart' show fillingPasteColor;
import 'pixel_sprites.dart';
import 'sparkle_art.dart';
import 'tap_effects.dart';
import 'workshop_mold_stage.dart' show FloatingFishPainter;

/// The 붕어빵 요정's motion (4차 피드백 IA3, MASTER 10장 '붕어빵 요정').
/// Every number of the fairy lives here.
class FairyMotion {
  FairyMotion._();

  /// Off in tests (test/flutter_test_config.dart): an endless swim would
  /// keep pumpAndSettle from settling. Off, the fairy stays at its place
  /// (or its hiding spot) like with reduced motion.
  static bool animate = true;

  /// Previews only (test/fairy_preview_test.dart): draw the fairy still at
  /// this moment (ms); [previewSwitchMs] is when guests came (or all left),
  /// to draw the run to the hiding spot (or out of it); [previewTapMs] a tap,
  /// to draw its twinkle. Null in the game.
  static int? previewMs, previewSwitchMs, previewTapMs;

  /// One slow swim: across the stage and back in [swimXMs], up and down in
  /// [swimYMs] (two periods that never line up, so the path wanders). A
  /// small bob of [bob] every [bobMs].
  static const swimXMs = 17000, swimYMs = 7300, bobMs = 1700;
  static const bob = 3.0;

  /// Redraws a second while it only swims (tap effects use every frame).
  static const swimFps = 30;

  /// How quickly it turns round at the swim's ends: about 0.7 s flat.
  static const turnSharpness = 8.0;

  /// How far the nose tilts up or down with the swim (radians).
  static const tilt = .14;

  /// The swim keeps the fish this far inside the stage's sides, and its
  /// top this far under the stage's top (the status sign and the bake
  /// title line).
  static const sideMargin = 6.0, topClearance = 56.0;

  /// Guests come: the fairy runs to its hiding spot in [hideMs] (a quick,
  /// shy dash with a little hop of [hop] × its height). They all leave: it
  /// comes out again slowly in [emergeMs].
  static const hideMs = 650, emergeMs = 1400;
  static const hop = .3;

  /// Hiding: at the stage's right edge, [hideScale] of its size (at least
  /// [hideMinWidth] wide), only [peekShare] of it on screen (at least
  /// [peekMinWidth]), its bottom [hideGap] above the counter / cooking cut.
  /// Every [peekMs] it leans [peekOut] further out for a moment.
  static const hideScale = .6, hideMinWidth = 120.0;
  static const peekShare = .5, peekMinWidth = 60.0;
  static const hideGap = 6.0;
  static const peekMs = 5200, peekOut = 12.0;

  /// A tap's twinkle is this much larger than the old always-on one, so a
  /// single tap shows.
  static const tapSparkleGrow = 2.5;

  /// The tap box is the fish's box, never smaller than [minHit] either way
  /// (a fair target, also while peeking).
  static const minHit = 56.0;

  /// A filling drip (the flavor picked with the HUD's flavor button) every
  /// [dripEveryMs] while it swims, skipping every third, none for
  /// [quietAfterTapMs] after a tap. One drip lives [dripLifeMs]: it swells
  /// at the belly for [dripHangShare] of its life, then falls [dripFall] ×
  /// the fish height, fading at the end.
  static const dripEveryMs = 3400, dripLifeMs = 1700, quietAfterTapMs = 2000;
  static const dripHangShare = .3, dripFall = .45, dripSize = .13;

  /// Where on the fish (unmirrored, as fractions of its box) a drip hangs:
  /// the belly seam under the filling.
  static const dripFrom = Offset(.47, .84);
}

/// Where the fairy is at one moment: its centre, size scale, which way it
/// faces (1 = as drawn, looking left; -1 = mirrored, looking right; values
/// between are a turn) and its tilt.
class FairyPose {
  final Offset center;
  final double scale, face, tilt;
  const FairyPose(this.center, this.scale, this.face, this.tilt);
}

/// The fairy's path, a pure function of time so previews can draw any
/// moment (MASTER 10장 '붕어빵 요정').
class FairyPath {
  /// The stage's size and the fairy's own place (the old clicker place:
  /// the bottom-centre of its swim).
  final Size stage;
  final Rect home;
  /// The hiding spot's bottom in the stage.
  final double hideBottom;
  /// Whether it swims (motion on, the first-run guide over).
  final bool wander;
  const FairyPath(this.stage, this.home, this.hideBottom, {required this.wander});

  static double _wave(int ms, int period, [double shift = 0]) => math.sin(2 * math.pi * ms / period + shift);
  static double _slope(int ms, int period, [double shift = 0]) => math.cos(2 * math.pi * ms / period + shift);

  /// The swim at [ms]: from the home place (bottom centre) out over the
  /// stage and back.
  FairyPose swim(int ms) {
    if (!wander) return FairyPose(home.center, 1, 1, 0);
    final w = home.width, h = home.height;
    final xMin = w / 2 + FairyMotion.sideMargin, xMax = stage.width - w / 2 - FairyMotion.sideMargin;
    final ax = math.max(0.0, (xMax - xMin) / 2), cx = stage.width / 2;
    final yBottom = home.center.dy, yTop = math.min(yBottom, FairyMotion.topClearance + h / 2);
    final ay = (yBottom - yTop) / 2, cy = yBottom - ay;
    final x = cx + ax * _wave(ms, FairyMotion.swimXMs);
    final y = cy + ay * _wave(ms, FairyMotion.swimYMs, math.pi / 2) +
        FairyMotion.bob * _wave(ms, FairyMotion.bobMs);
    // Moving right: mirrored. A quick turn where it changes direction.
    final face = (-_slope(ms, FairyMotion.swimXMs) * FairyMotion.turnSharpness).clamp(-1.0, 1.0);
    // Nose up while rising.
    final down = _slope(ms, FairyMotion.swimYMs, math.pi / 2);
    return FairyPose(Offset(x, y), 1, face, -down * FairyMotion.tilt * face);
  }

  /// The hiding spot's size scale.
  double get hideScale => math.max(home.width * FairyMotion.hideScale, FairyMotion.hideMinWidth) / home.width;

  /// Peeking from the right edge at [ms], looking into the stage.
  FairyPose hide(int ms) {
    final s = hideScale, hw = home.width * s, hh = home.height * s;
    final visible = math.max(hw * FairyMotion.peekShare, FairyMotion.peekMinWidth);
    final lean = wander ? FairyMotion.peekOut * math.pow(math.max(0.0, _wave(ms, FairyMotion.peekMs)), 3) : 0.0;
    final bob = wander ? 2 * _wave(ms, 2100) : 0.0;
    return FairyPose(Offset(stage.width - visible - lean + hw / 2, hideBottom - hh / 2 + bob), s, 1,
        wander ? .05 * _wave(ms, 2900) : 0);
  }

  /// Between the swim and the hiding spot: [amount] 0 swims, 1 hides.
  /// [hiding] is the way it is going (running away, or coming out).
  FairyPose at(int ms, double amount, {required bool hiding}) {
    if (amount <= 0) return swim(ms);
    if (amount >= 1) return hide(ms);
    final a = Curves.easeInOut.transform(amount);
    final from = swim(ms), to = hide(ms);
    final center = Offset.lerp(from.center, to.center, a)! -
        Offset(0, math.sin(math.pi * a) * home.height * FairyMotion.hop);
    // Running away it looks where it goes (right), turning back at the
    // spot to peek; coming out it looks left, into the stage.
    final double face = hiding
        ? _lerp(from.face, a < .7 ? -1.0 : -1 + 2 * (a - .7) / .3, math.min(1.0, a * 4))
        : _lerp(from.face, 1, a);
    return FairyPose(center, _lerp(from.scale, to.scale, a), face, _lerp(from.tilt, to.tilt, a));
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// The tap box for [pose]: the fish's box, at least [FairyMotion.minHit]
  /// each way.
  Rect hitBox(FairyPose pose) {
    final w = math.max(home.width * pose.scale, FairyMotion.minHit);
    final h = math.max(home.height * pose.scale, FairyMotion.minHit);
    return Rect.fromCenter(center: pose.center, width: w, height: h);
  }

  /// A point of the fish (fractions of its unmirrored box) on the stage.
  Offset point(FairyPose pose, Offset share) {
    final w = home.width * pose.scale, h = home.height * pose.scale;
    final local = Offset((share.dx - .5) * w * pose.face, (share.dy - .5) * h);
    final c = math.cos(pose.tilt), s = math.sin(pose.tilt);
    return pose.center + Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
  }
}

/// The 붕어빵 요정 (4차 피드백 IA3, was the big bungeoppang clicker DEC-036):
/// with no guests it swims slowly over the stage; when guests come it is
/// shy, runs to the right edge and peeks out from there. Wherever it is,
/// each tap goes through [WorkshopController.clickerTap] (buns +tapRate,
/// the same taps for missions) and shows the tap effects of
/// tap_effects.dart (a pop, small bungeoppang crumbs, a floating gain) and,
/// only then, a twinkle. While it swims it now and then drips a little of
/// the filling picked with the HUD's flavor button. Taps past the
/// per-second limit still pop and crumble but earn nothing, so they show no
/// gain. Reduced motion: it stays put (or jumps to the hiding spot), with
/// only a still gain.
///
/// It fills the whole stage; only the fish's own box takes taps.
class WorkshopClicker extends StatefulWidget {
  static const maxBursts = maxFloatingGains;
  final WorkshopController controller;

  /// The fairy's place in the stage (the old clicker place).
  final Rect home;

  /// The hiding spot's bottom in the stage (null: the place's bottom).
  final double? hideBottom;

  /// Draws the fairy (a clean counter); otherwise the background's baked
  /// fish is the target at [home] and only the effects are drawn.
  final bool floating, reduceMotion, vibration;
  const WorkshopClicker(
      {super.key,
      required this.controller,
      required this.home,
      required this.floating,
      this.hideBottom,
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
  /// Time on the ticker, carried on when it stops and starts again.
  int _now = 0, _base = 0, _lastTap = -100000, _sparkleAt = -100000, _serial = 0;
  int? _lastHaptic;
  Offset? _down;
  Rect _hit = Rect.zero;
  BigInt? _staticGain;

  /// Hiding (guests there): since when, and how far it was then.
  bool? _hidden;
  int _switchAt = -100000;
  double _from = 0;

  WorkshopController get c => widget.controller;
  bool get _moving => widget.floating && FairyMotion.animate && !widget.reduceMotion && FairyMotion.previewMs == null;
  int get _time => FairyMotion.previewMs ?? _now;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final now = _base + elapsed.inMilliseconds;
      // Just swimming (no tap effects): FairyMotion.swimFps is enough.
      final effects = _bursts.isNotEmpty || _crumbs.activeCount > 0 || now - _lastTap <= tapPopMs ||
          now - _sparkleAt <= SparkleArt.cycleMs * 1.5;
      if (!effects && now - _now < 1000 ~/ FairyMotion.swimFps) return;
      setState(() {
        _now = now;
        _bursts.removeWhere((b) => _now - b.$1 >= floatingGainMs);
        _crumbs.update(_now);
      });
      if (!_moving && _bursts.isEmpty && _crumbs.activeCount == 0 && _now - _lastTap > tapPopMs &&
          _now - _sparkleAt > SparkleArt.cycleMs) {
        _stop();
      }
    });
    if (_moving) _start();
  }

  void _start() {
    if (_ticker.isActive) return;
    _base = _now;
    _ticker.start();
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  @override
  void didUpdateWidget(WorkshopClicker old) {
    super.didUpdateWidget(old);
    if (_moving) _start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// How far into hiding (0 out, 1 hidden) at [ms].
  double _amount(int ms) {
    final switched = FairyMotion.previewSwitchMs;
    if (FairyMotion.previewMs != null && switched != null) {
      final t = ms - switched;
      return _hidden! ? (t / FairyMotion.hideMs).clamp(0.0, 1.0) : (1 - t / FairyMotion.emergeMs).clamp(0.0, 1.0);
    }
    if (!_moving) return _hidden! ? 1 : 0;
    final t = ms - _switchAt;
    return _hidden!
        ? (_from + t / FairyMotion.hideMs).clamp(0.0, 1.0)
        : (_from - t / FairyMotion.emergeMs).clamp(0.0, 1.0);
  }

  void _tap() {
    if (c.gameplayPaused || c.error != null) return;
    final amount = c.clickerTap();
    GameAudioScope.of(context).play(Sfx.tap);
    final at = _down ?? _hit.center;
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
        _bursts.clear();
        _crumbs.clear();
        _start();
      }
      _lastTap = _now;
      // A twinkle only when tapped; a new one once the last has mostly shown.
      if (_now - _sparkleAt > SparkleArt.cycleMs * .6) _sparkleAt = _now;
      if (amount != null) {
        if (_bursts.length == WorkshopClicker.maxBursts) _bursts.removeAt(0);
        _bursts.add((_now, amount, at.translate(((_serial++ % 5) - 2) * 6.0, 0)));
      }
      _crumbs.spawn(at, _now, crumbsPerTap);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = widget.reduceMotion;
    final s = c.state;
    // Shy: hides while any guest waits (presentation only, never saved).
    final hidden = widget.floating && s.customers.isNotEmpty;
    final t = _time;
    if (_hidden == null) {
      _hidden = hidden;
    } else if (_hidden != hidden) {
      _from = _amount(t);
      _switchAt = t;
      _hidden = hidden;
    }
    final pop = reduce ? 1.0 : tapPopScale((_now - _lastTap) / tapPopMs);
    return LayoutBuilder(builder: (context, box) {
      final path = FairyPath(box.biggest, widget.home, widget.hideBottom ?? widget.home.bottom,
          wander: widget.floating && !reduce && (FairyMotion.animate || FairyMotion.previewMs != null) && !s.tutorialActive);
      final amount = _amount(t);
      final pose = widget.floating
          ? path.at(t, amount, hiding: _hidden!)
          : FairyPose(widget.home.center, 1, 1, 0);
      final hit = _hit = widget.floating ? path.hitBox(pose) : widget.home;
      final fishW = widget.home.width * pose.scale, fishH = widget.home.height * pose.scale;
      final sparkleAt = FairyMotion.previewTapMs ?? _sparkleAt;
      final twinkle = widget.floating && !reduce && t - sparkleAt < SparkleArt.cycleMs * 1.5;
      // Drips: only while swimming, quiet for a while after a tap.
      final dripping = widget.floating && path.wander && amount == 0 && !_hidden! && t - _lastTap > FairyMotion.quietAfterTapMs;
      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fromRect(
            rect: hit,
            child: Semantics(
                button: true,
                label: '${hidden ? '숨어 있는 ' : ''}붕어빵 요정 누르기, 붕어빵력 +${compactNumber(c.tapRate)}',
                onTap: _tap,
                child: GestureDetector(
                    key: const Key('workshop-clicker'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapDown: (d) => _down = hit.topLeft + d.localPosition,
                    onTapCancel: () => _down = null,
                    onTap: _tap,
                    child: widget.floating
                        ? Center(
                            child: SizedBox(
                                width: fishW,
                                height: fishH,
                                child: Transform(
                                    key: Key(hidden ? 'fairy-hiding' : 'fairy-swimming'),
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationZ(pose.tilt)
                                      ..multiply(Matrix4.diagonal3Values(
                                          pop * (pose.face.abs() < .06 ? .06 * pose.face.sign : pose.face), pop, 1)),
                                    child: const CustomPaint(
                                        key: Key('floating-fish'), painter: FloatingFishPainter()))))
                        : const SizedBox.expand()))),
        // In front of the fish: the drop hangs at its belly's edge.
        if (dripping)
          Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(
                      key: const Key('fairy-drips'),
                      painter: _DripPainter(path, t, fillingPasteColor(s.selectedFlavor), fishH)))),
        // A twinkle around the fairy, only after a tap (IA3).
        if (twinkle)
          Positioned.fromRect(
              rect: Rect.fromCenter(center: pose.center, width: fishW, height: fishH),
              child: IgnorePointer(
                  child: CustomPaint(
                      key: const Key('fairy-twinkle'),
                      painter: _TapTwinklePainter((t - sparkleAt) / SparkleArt.cycleMs)))),
        if (!reduce)
          Positioned.fill(
              child: IgnorePointer(
                  child: CustomPaint(
                      painter: CrumbPainter(_crumbs, _now,
                          fish: PixelSprites.fx('minifish') ?? PixelSprites.fish('redbean', 'scales'))))),
        for (final burst in _bursts)
          Positioned(
              key: ValueKey(burst),
              left: (burst.$3.dx - 40).clamp(0.0, math.max(0, box.maxWidth - 120)),
              top: (burst.$3.dy - 34).clamp(0.0, math.max(0.0, box.maxHeight - 40)) -
                  (_now - burst.$1) / floatingGainMs * 65,
              child: IgnorePointer(
                  child: ExcludeSemantics(
                      child: Opacity(
                          opacity: (1 - (_now - burst.$1) / floatingGainMs).clamp(0.0, 1.0),
                          child: _gain(burst.$2, const Key('clicker-burst')))))),
        if (reduce && _staticGain != null)
          Positioned(
              left: 0,
              right: 0,
              top: math.max(0.0, hit.top - 34),
              child: IgnorePointer(
                  child: Center(child: _gain(_staticGain!, const Key('clicker-static-gain'))))),
      ]);
    });
  }

  static Widget _gain(BigInt amount, Key key) => Text('+${compactNumber(amount)}',
      key: key,
      style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xffffedab),
          shadows: [Shadow(color: Colors.black, blurRadius: 4)]));
}

/// One twinkle round the fairy after a tap: the six places of
/// [FloatingFishPainter.sparkles], one after another, once.
class _TapTwinklePainter extends CustomPainter {
  final double progress;
  const _TapTwinklePainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    const points = FloatingFishPainter.sparkles;
    for (var i = 0; i < points.length; i++) {
      final (x, y, s) = points[i];
      final phase = progress - i * .08;
      if (phase < 0 || phase >= .7) continue;
      SparkleArt.paint(canvas, Offset(x * size.width, y * size.height), size.shortestSide * s * FairyMotion.tapSparkleGrow, phase);
    }
  }

  @override
  bool shouldRepaint(covariant _TapTwinklePainter old) => old.progress != progress;
}

/// The filling drips: a drop swells at the fish's belly, then falls and
/// fades (drawn in code; 25번 그림이 오면 바꿈).
class _DripPainter extends CustomPainter {
  final FairyPath path;
  final int ms;
  final Color color;
  final double fishHeight;
  const _DripPainter(this.path, this.ms, this.color, this.fishHeight);

  @override
  void paint(Canvas canvas, Size size) {
    const every = FairyMotion.dripEveryMs, life = FairyMotion.dripLifeMs;
    final first = ((ms - life) / every).floor();
    for (var k = math.max(1, first); k * every <= ms; k++) {
      if (k % 3 == 2) continue;
      final born = k * every, p = (ms - born) / life;
      if (p < 0 || p >= 1) continue;
      final hang = FairyMotion.dripHangShare;
      // Hanging, the drop follows the fish; then it falls from where it let go.
      final from = path.point(path.swim(p < hang ? ms : born + (life * hang).round()), FairyMotion.dripFrom);
      final r = fishHeight * FairyMotion.dripSize / 2;
      final double radius, fall, alpha;
      if (p < hang) {
        radius = r * (.4 + .6 * p / hang);
        fall = radius * .6;
        alpha = 1;
      } else {
        final q = (p - hang) / (1 - hang);
        radius = r;
        fall = r * .6 + fishHeight * FairyMotion.dripFall * q * q;
        alpha = q < .6 ? 1 : 1 - (q - .6) / .4;
      }
      _drop(canvas, from + Offset(0, fall), radius, alpha.clamp(0.0, 1.0));
    }
  }

  /// A small teardrop (point up) with a light spot.
  void _drop(Canvas canvas, Offset c, double r, double alpha) {
    final body = Path()
      ..moveTo(c.dx, c.dy - r * 2.1)
      ..quadraticBezierTo(c.dx + r * .35, c.dy - r * 1.1, c.dx + r, c.dy)
      ..arcToPoint(Offset(c.dx - r, c.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(c.dx - r * .35, c.dy - r * 1.1, c.dx, c.dy - r * 2.1)
      ..close();
    canvas.drawPath(body, Paint()..color = color.withValues(alpha: alpha));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xff2a1710).withValues(alpha: alpha * .6));
    canvas.drawCircle(c.translate(-r * .35, -r * .3), r * .28,
        Paint()..color = Colors.white.withValues(alpha: alpha * .55));
  }

  @override
  bool shouldRepaint(covariant _DripPainter old) => old.ms != ms || old.color != color;
}
