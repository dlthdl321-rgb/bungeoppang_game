import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../economy.dart' show compactNumber;
import '../feedback_config.dart';
import '../game_audio.dart';
import '../workshop_controller.dart';
import 'pixel_sprites.dart';
import 'sparkle_art.dart';
import 'tap_effects.dart';
import 'workshop_mold_stage.dart' show FloatingFishPainter;

/// The 붕어빵 요정's motion (4차 피드백 IA3·g12, MASTER 10장 '붕어빵 요정').
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

  /// The wide swim (4차 g12): one round ("tour") is [legsPerTour] swims
  /// from point to point over the stage, then out past the left or right
  /// edge. It stays out [offMinMs]–[offMaxMs], then comes back in at the
  /// left or right edge, at another height (at least [reentryGap] × the
  /// swim's height away, or from the other side). The first round starts
  /// at its place; each round is drawn by lot from [seed] and its number,
  /// so the path is never the same but a preview can draw any moment.
  static const legsPerTour = 6, seed = 2611;
  static const offMinMs = 900, offMaxMs = 2000;
  static const reentryGap = .35;

  /// Out of the stage: this far past the edge (fully out of sight).
  static const offOutside = 10.0;

  /// The kinds of swim and their share: up or down (sideways at most
  /// [verticalDrift] × the swim's width), slanting across, or across at
  /// about the same height (up or down at most [acrossDrift] × its height).
  /// A swim is at least [minHop] long. It bends to one side by up to
  /// [curve] × its length.
  static const verticalShare = .35, diagonalShare = .4;
  static const verticalDrift = .2, acrossDrift = .2;
  static const minHop = 70.0, curve = .35;

  /// Its average speed (px a second); a swim lasts at least [minLegMs].
  /// It speeds up from a stop and slows into the next point.
  static const speed = 62.0;
  static const minLegMs = 1500;

  /// Leaving the stage it heads for the nearer side this often.
  static const nearSideShare = .65;

  /// A small bob of [bob] every [bobMs].
  static const bobMs = 1700;
  static const bob = 3.0;

  /// Redraws a second while it only swims (tap effects use every frame).
  static const swimFps = 30;

  /// It turns to face the way it swims at the start of a swim, in
  /// [turnMs] (flattening as it turns). A swim with less than
  /// [turnShare] × its length sideways keeps the old facing.
  static const turnMs = 700;
  static const turnShare = .25;

  /// How far the nose tilts up or down with the swim (radians, at full
  /// speed straight up or down).
  static const tilt = .3;

  /// The swim keeps the fish this far inside the stage's sides, and its
  /// top this far under the stage's top (the status sign and the bake
  /// title line). Its lowest point is its place (above the counter).
  static const sideMargin = 6.0, topClearance = 56.0;

  /// When it must hold still (the first-run guide, its tour pointing at
  /// it) it glides back to its place in [settleMs].
  static const settleMs = 600;

  /// Guests come: the fairy runs to its hiding spot in [hideMs] (a quick,
  /// shy dash with a little hop of [hop] × its height). They all leave: it
  /// comes out again slowly in [emergeMs] and starts a new round from its
  /// place.
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
}

/// Where the fairy is at one moment: its centre, size scale, which way it
/// faces (1 = as drawn, looking left; -1 = mirrored, looking right; values
/// between are a turn) and its tilt.
class FairyPose {
  final Offset center;
  final double scale, face, tilt;
  const FairyPose(this.center, this.scale, this.face, this.tilt);
}

/// One swim of a round: along a curve from [a] by [c] to [b] (a wait out
/// of the stage when [a] == [b]), from [start] for [ms], turning from
/// [fromFace] to [face].
class _Leg {
  final Offset a, c, b;
  final int start, ms;
  final double fromFace, face;
  const _Leg(this.a, this.c, this.b, this.start, this.ms, this.fromFace, this.face);
  int get end => start + ms;
}

/// Every round of one stage, drawn as far as asked (rounds are short, a
/// long swim only adds a few a minute).
class _Rounds {
  final legs = <_Leg>[];
  double exitY = 0;
  int tours = 0;
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
  /// Whether it swims (motion on, the first-run guide over, nothing
  /// pointing at it).
  final bool wander;
  const FairyPath(this.stage, this.home, this.hideBottom, {required this.wander});

  static double _wave(int ms, int period, [double shift = 0]) => math.sin(2 * math.pi * ms / period + shift);

  /// The swim's box for the fish's centre.
  double get _xMin => home.width / 2 + FairyMotion.sideMargin;
  double get _xMax => math.max(_xMin, stage.width - home.width / 2 - FairyMotion.sideMargin);
  double get _yBottom => home.center.dy;
  double get _yTop => math.min(_yBottom, FairyMotion.topClearance + home.height / 2);

  /// Out of the stage at the left (or right) side, at height [y].
  Offset _outside(bool left, double y) => Offset(
      left ? -home.width / 2 - FairyMotion.offOutside : stage.width + home.width / 2 + FairyMotion.offOutside, y);

  /// Whether the fish is wholly out of the stage at [pose].
  bool offStage(FairyPose pose) {
    final w = home.width * pose.scale / 2;
    return pose.center.dx + w <= 0 || pose.center.dx - w >= stage.width;
  }

  static final _cache = <String, _Rounds>{};

  _Rounds _rounds(int ms) {
    final key = '${stage.width},${stage.height},${home.left},${home.top},${home.width},${home.height}';
    if (_cache.length > 8 && !_cache.containsKey(key)) _cache.clear();
    final r = _cache.putIfAbsent(key, _Rounds.new);
    while (r.legs.isEmpty || r.legs.last.end <= ms) {
      _addRound(r);
    }
    return r;
  }

  /// Draws round number [_Rounds.tours] by lot.
  void _addRound(_Rounds r) {
    final k = r.tours++;
    final rnd = math.Random(FairyMotion.seed + k * 7919);
    final xMin = _xMin, xMax = _xMax, yTop = _yTop, yBottom = _yBottom;
    final bw = xMax - xMin, bh = yBottom - yTop;
    double lerp(double a, double b, double t) => a + (b - a) * t;
    var t = r.legs.isEmpty ? 0 : r.legs.last.end;
    var face = r.legs.isEmpty ? 1.0 : r.legs.last.face;
    late Offset p;
    void add(Offset b, {bool bend = true}) {
      final d = (b - p).distance;
      var c = Offset.lerp(p, b, .5)!;
      if (bend && d > 0) {
        final n = Offset(-(b.dy - p.dy) / d, (b.dx - p.dx) / d);
        c += n * (d * FairyMotion.curve * (rnd.nextDouble() * 2 - 1));
        // Never bends behind the counter, under the stage's top line or
        // past a side (only the way out leaves the stage).
        c = Offset(c.dx.clamp(xMin, xMax), c.dy.clamp(yTop, yBottom));
      }
      final length = ((p - c).distance + (c - b).distance + d) / 2;
      final ms = math.max(FairyMotion.minLegMs, (length / FairyMotion.speed * 1000).round());
      final dx = b.dx - p.dx;
      final next = d > 0 && dx.abs() >= d * FairyMotion.turnShare ? (dx < 0 ? 1.0 : -1.0) : face;
      r.legs.add(_Leg(p, c, b, t, ms, face, next));
      t += ms;
      face = next;
      p = b;
    }

    if (k == 0) {
      p = home.center;
    } else {
      // Back in from a side, at another height.
      final left = rnd.nextBool();
      var y = lerp(yTop, yBottom, rnd.nextDouble());
      for (var i = 0; i < 6 && (y - r.exitY).abs() < bh * FairyMotion.reentryGap; i++) {
        y = lerp(yTop, yBottom, rnd.nextDouble());
      }
      p = _outside(left, y);
      final wait = FairyMotion.offMinMs + rnd.nextInt(FairyMotion.offMaxMs - FairyMotion.offMinMs + 1);
      face = left ? -1 : 1;
      r.legs.add(_Leg(p, p, p, t, wait, face, face));
      t += wait;
      add(Offset(lerp(xMin, xMax, left ? .15 + .35 * rnd.nextDouble() : .5 + .35 * rnd.nextDouble()),
          lerp(yTop, yBottom, rnd.nextDouble())));
    }
    for (var i = 0; i < FairyMotion.legsPerTour; i++) {
      Offset q = p;
      for (var tries = 0; tries < 8; tries++) {
        final kind = rnd.nextDouble();
        final upper = (p.dy - yTop) < bh / 2, leftHalf = (p.dx - xMin) < bw / 2;
        double other(bool firstHalf) => firstHalf ? .55 + .45 * rnd.nextDouble() : .45 * rnd.nextDouble();
        if (kind < FairyMotion.verticalShare) {
          q = Offset((p.dx + bw * FairyMotion.verticalDrift * (rnd.nextDouble() * 2 - 1)).clamp(xMin, xMax),
              lerp(yTop, yBottom, upper ? .7 + .3 * rnd.nextDouble() : .3 * rnd.nextDouble()));
        } else if (kind < FairyMotion.verticalShare + FairyMotion.diagonalShare) {
          q = Offset(lerp(xMin, xMax, other(leftHalf)), lerp(yTop, yBottom, other(upper)));
        } else {
          q = Offset(lerp(xMin, xMax, other(leftHalf)),
              (p.dy + bh * FairyMotion.acrossDrift * (rnd.nextDouble() * 2 - 1)).clamp(yTop, yBottom));
        }
        if ((q - p).distance >= FairyMotion.minHop) break;
      }
      add(q);
    }
    // Out past a side for a moment.
    final near = (p.dx - xMin) < bw / 2;
    final left = rnd.nextDouble() < FairyMotion.nearSideShare ? near : !near;
    r.exitY = (p.dy + bh * .3 * (rnd.nextDouble() * 2 - 1)).clamp(yTop, yBottom);
    add(_outside(left, r.exitY));
  }

  /// The swim [ms] after it set out from its place (or the place itself
  /// when it does not swim).
  FairyPose swim(int ms) {
    if (!wander) return FairyPose(home.center, 1, 1, 0);
    if (ms <= 0) return FairyPose(home.center, 1, 1, 0);
    final legs = _rounds(ms).legs;
    var lo = 0, hi = legs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (legs[mid].end <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final leg = legs[lo];
    final u = ((ms - leg.start) / leg.ms).clamp(0.0, 1.0);
    // Starts and stops gently: smoothstep along the curve.
    final s = u * u * (3 - 2 * u), ds = 6 * u * (1 - u);
    final pos = leg.a * ((1 - s) * (1 - s)) + leg.c * (2 * (1 - s) * s) + leg.b * (s * s);
    final dir = (leg.c - leg.a) * (2 * (1 - s)) + (leg.b - leg.c) * (2 * s);
    final vy = dir.dy * ds / leg.ms * 1000 / FairyMotion.speed;
    final turn = ((ms - leg.start) / FairyMotion.turnMs).clamp(0.0, 1.0);
    final face = leg.fromFace + (leg.face - leg.fromFace) * (turn * turn * (3 - 2 * turn));
    final y = pos.dy + FairyMotion.bob * _wave(ms, FairyMotion.bobMs);
    // Nose up while rising.
    return FairyPose(Offset(pos.dx, y), 1, face, -vy.clamp(-1.0, 1.0) * FairyMotion.tilt * face);
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

  /// Between the swim (at swim time [swimMs]) and the hiding spot (at
  /// [ms]): [amount] 0 swims, 1 hides. [hiding] is the way it is going
  /// (running away, or coming out).
  FairyPose at(int swimMs, int ms, double amount, {required bool hiding}) {
    if (amount <= 0) return swim(swimMs);
    if (amount >= 1) return hide(ms);
    final a = Curves.easeInOut.transform(amount);
    final from = swim(swimMs), to = hide(ms);
    final center = Offset.lerp(from.center, to.center, a)! -
        Offset(0, math.sin(math.pi * a) * home.height * FairyMotion.hop);
    // Running away it looks where it goes (right), turning back at the
    // spot to peek; coming out it looks left, into the stage.
    final double face = hiding
        ? lerpPose(from.face, a < .7 ? -1.0 : -1 + 2 * (a - .7) / .3, math.min(1.0, a * 4))
        : lerpPose(from.face, 1, a);
    return FairyPose(center, lerpPose(from.scale, to.scale, a), face, lerpPose(from.tilt, to.tilt, a));
  }

  static double lerpPose(double a, double b, double t) => a + (b - a) * t;

  /// The tap box for [pose]: the fish's box, at least [FairyMotion.minHit]
  /// each way.
  Rect hitBox(FairyPose pose) {
    final w = math.max(home.width * pose.scale, FairyMotion.minHit);
    final h = math.max(home.height * pose.scale, FairyMotion.minHit);
    return Rect.fromCenter(center: pose.center, width: w, height: h);
  }
}

/// The 붕어빵 요정 (4차 피드백 IA3, was the big bungeoppang clicker DEC-036):
/// with no guests it swims over the whole stage, up and down and across,
/// now and then out past a side and back in elsewhere (4차 g12); when guests
/// come it is
/// shy, runs to the right edge and peeks out from there. Wherever it is,
/// each tap goes through [WorkshopController.clickerTap] (buns +tapRate,
/// the same taps for missions) and shows the tap effects of
/// tap_effects.dart (a pop, small bungeoppang crumbs, a floating gain) and,
/// only then, a twinkle. Taps past the
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

  /// Hold still at its place (its short tour points at it): it glides
  /// back home and starts a new round when let go.
  final bool still;
  const WorkshopClicker(
      {super.key,
      required this.controller,
      required this.home,
      required this.floating,
      this.hideBottom,
      this.reduceMotion = false,
      this.vibration = false,
      this.still = false});
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

  /// Swimming: since when its round started (it sets out from its place),
  /// and when it last stopped to hold still, at which swim moment.
  bool? _swimming;
  int _epoch = 0, _settleAt = -100000, _settleSwimMs = 0;

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

  /// How long it has swum in this round at [ms] (previews: since the
  /// guests left, or from 0).
  int _swimMs(int ms) {
    if (FairyMotion.previewMs != null) {
      final switched = FairyMotion.previewSwitchMs;
      return switched != null && _hidden == false ? ms - switched : ms;
    }
    return ms - _epoch;
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
      // Coming out it starts a new round from its place.
      if (!hidden) _epoch = t;
    }
    final canSwim = widget.floating && !reduce && (FairyMotion.animate || FairyMotion.previewMs != null);
    final swimming = canSwim && !s.tutorialActive && !widget.still;
    if (_swimming == null) {
      _swimming = swimming;
    } else if (_swimming != swimming) {
      if (swimming) {
        // A new round from its place.
        _epoch = t;
      } else {
        _settleAt = t;
        _settleSwimMs = _swimMs(t);
      }
      _swimming = swimming;
    }
    final pop = reduce ? 1.0 : tapPopScale((_now - _lastTap) / tapPopMs);
    return LayoutBuilder(builder: (context, box) {
      final hideBottom = widget.hideBottom ?? widget.home.bottom;
      final path = FairyPath(box.biggest, widget.home, hideBottom, wander: swimming);
      final amount = _amount(t);
      var pose = widget.floating
          ? path.at(_swimMs(t), t, amount, hiding: _hidden!)
          : FairyPose(widget.home.center, 1, 1, 0);
      // Told to hold still: back to its place from where it swam.
      if (widget.floating && canSwim && !swimming && amount == 0 && t - _settleAt < FairyMotion.settleMs) {
        final from = FairyPath(box.biggest, widget.home, hideBottom, wander: true).swim(_settleSwimMs);
        final a = Curves.easeInOut.transform(((t - _settleAt) / FairyMotion.settleMs).clamp(0.0, 1.0));
        pose = FairyPose(Offset.lerp(from.center, pose.center, a)!, 1, FairyPath.lerpPose(from.face, pose.face, a),
            FairyPath.lerpPose(from.tilt, pose.tilt, a));
      }
      final hit = _hit = widget.floating ? path.hitBox(pose) : widget.home;
      final fishW = widget.home.width * pose.scale, fishH = widget.home.height * pose.scale;
      final sparkleAt = FairyMotion.previewTapMs ?? _sparkleAt;
      final twinkle = widget.floating && !reduce && t - sparkleAt < SparkleArt.cycleMs * 1.5;
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
