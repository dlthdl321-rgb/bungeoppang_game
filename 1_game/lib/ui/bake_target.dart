import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../economy.dart';
import '../feedback_config.dart';
import '../game_audio.dart';
import '../game_controller.dart';
import '../cosmetic_config.dart';
import 'boost_effects.dart';
import 'fish_painter.dart';
import 'pixel_sprites.dart';
import 'tap_effects.dart';

class _Burst {
  final int born;
  final BigInt amount;
  final Offset at;
  const _Burst(this.born, this.amount, this.at);
}

/// One ticker, at most [maxBursts] floating gains and a fixed crumb pool,
/// irrespective of tap frequency. Every accepted tap earns currency; only the
/// decorative effects are capped. Reduced motion shows a static gain only.
class BakeTarget extends StatefulWidget {
  static const maxBursts = maxFloatingGains;
  static const effectMilliseconds = floatingGainMs;
  final GameController controller;
  final bool reduceMotion;

  /// Where the bungeoppang should sit, in global (screen) coordinates: over
  /// the one baked into a concept background. Null centres it in the box.
  final Rect? fishOnScreen;
  const BakeTarget(
      {super.key,
      required this.controller,
      required this.reduceMotion,
      this.fishOnScreen});
  @override
  State<BakeTarget> createState() => _BakeTargetState();
}

class _BakeTargetState extends State<BakeTarget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _bursts = <_Burst>[];
  final crumbs = CrumbPool(maxCrumbParticles, crumbLifeMs);
  Offset? _tapDown;
  Size _box = Size.zero;
  Timer? _hold;
  int _elapsed = 0, _lastTap = -1000, _serial = 0;
  int? _lastHaptic;
  bool _active = true;
  BigInt? _staticGain;

  /// This box's top-left on screen, to place [BakeTarget.fishOnScreen].
  Offset _origin = Offset.zero;

  void _trackOrigin() {
    if (widget.fishOnScreen == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      if (origin != _origin) setState(() => _origin = origin);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((duration) {
      setState(() {
        _elapsed = duration.inMilliseconds;
        _bursts.removeWhere(
            (b) => _elapsed - b.born >= BakeTarget.effectMilliseconds);
        crumbs.update(_elapsed);
      });
      if (_bursts.isEmpty &&
          crumbs.activeCount == 0 &&
          _elapsed - _lastTap > tapPopMs) {
        _ticker.stop();
      }
    });
  }

  void _bake({bool direct = true}) {
    if (!_active || widget.controller.busy) return;
    final c = widget.controller;
    final amount = c.tap(direct: direct);
    GameAudioScope.of(context).play(Sfx.tap);
    // Pointer taps start where the finger landed; keyboard, semantics and
    // hold repeats start from the fish's centre.
    final at = _tapDown ?? _box.center(Offset.zero);
    _tapDown = null;
    final now = c.clock.monotonicMilliseconds;
    if (c.state.settings.vibration &&
        (_lastHaptic == null || now - _lastHaptic! >= 80)) {
      _lastHaptic = now;
      HapticFeedback.selectionClick();
    }
    setState(() {
      _staticGain = amount;
      if (widget.reduceMotion) return;
      if (!_ticker.isActive) {
        _elapsed = 0;
        _ticker.start();
      }
      _lastTap = _elapsed;
      if (_bursts.length == BakeTarget.maxBursts) _bursts.removeAt(0);
      // Small horizontal stagger so rapid taps on one spot stay readable.
      _bursts.add(_Burst(
          _elapsed, amount, at.translate(((_serial++ % 5) - 2) * 6.0, 0)));
      crumbs.spawn(at, _elapsed, crumbsPerTap);
    });
  }

  void _stopHold() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      _stopHold();
      _ticker.stop();
      setState(() {
        _bursts.clear();
        crumbs.clear();
        _lastTap = -1000;
      });
    }
  }

  @override
  void didUpdateWidget(covariant BakeTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.controller.state.settings.holdToBake) _stopHold();
    if (widget.reduceMotion) {
      _ticker.stop();
      _bursts.clear();
      crumbs.clear();
      _lastTap = -1000;
    }
  }

  @override
  void dispose() {
    _stopHold();
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = widget.reduceMotion;
    final pop = reduce ? 1.0 : tapPopScale((_elapsed - _lastTap) / tapPopMs);
    final look = widget.controller.state.equippedCosmetic;
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '붕어빵 굽기',
        onTap: _bake,
        child: FocusableActionDetector(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent()
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              _bake();
              return null;
            })
          },
          child: GestureDetector(
            key: const Key('fish-button'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (d) => _tapDown = d.localPosition,
            onTapCancel: () => _tapDown = null,
            onTap: _bake,
            onLongPressStart: widget.controller.state.settings.holdToBake
                ? (_) {
                    _stopHold();
                    _bake();
                    _hold = Timer.periodic(const Duration(milliseconds: 250),
                        (_) => _bake(direct: false));
                  }
                : null,
            onLongPressEnd: (_) => _stopHold(),
            onLongPressCancel: _stopHold,
            child: LayoutBuilder(builder: (context, box) {
              _box = box.biggest;
              _trackOrigin();
              // The fish canvas: over the baked-in fish when there is one
              // (its art fills ~77% of the canvas width), else centred.
              final onScreen = widget.fishOnScreen;
              final canvasWidth = onScreen == null ? 0.0 : onScreen.width / .77;
              final fishRect = onScreen == null
                  ? null
                  : Rect.fromCenter(
                      center: onScreen.center - _origin,
                      width: canvasWidth,
                      height: canvasWidth * .75);
              final fish = Transform.scale(
                  key: const Key('fish-scale'),
                  scale: pop,
                  child: _goldenWhileBoosted(CustomPaint(
                      key: const Key('center-fish'),
                      size: fishRect?.size ??
                          Size(
                              math.min(
                                  box.maxWidth * .82, box.maxHeight * 1.25),
                              math.min(box.maxHeight, box.maxWidth * .62)),
                      painter: FishPainter(
                          skin: look(CosmeticSlot.fish),
                          pattern: look(CosmeticSlot.pattern),
                          topping: look(CosmeticSlot.topping)))));
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                      child: IgnorePointer(
                          child: CustomPaint(
                              key: const Key('fish-sparkles'),
                              painter: const SparklePainter()))),
                  if (fishRect == null)
                    fish
                  else
                    Positioned.fromRect(rect: fishRect, child: fish),
                  if (!reduce)
                    Positioned.fill(
                        child: IgnorePointer(
                            child: CustomPaint(
                                key: const Key('crumbs'),
                                painter: CrumbPainter(crumbs, _elapsed,
                                    fish: PixelSprites.fx('minifish') ??
                                        PixelSprites.fish(
                                            look(CosmeticSlot.fish),
                                            look(CosmeticSlot.pattern)))))),
                  for (final burst in _bursts)
                    Positioned(
                        key: ValueKey(burst),
                        left: (burst.at.dx - 40)
                            .clamp(0.0, math.max(0, box.maxWidth - 120)),
                        top: (burst.at.dy - 34)
                                .clamp(0.0, math.max(0.0, box.maxHeight - 40)) -
                            (_elapsed - burst.born) /
                                BakeTarget.effectMilliseconds *
                                65,
                        child: IgnorePointer(
                            child: ExcludeSemantics(
                                child: Opacity(
                          opacity: (1 -
                                  (_elapsed - burst.born) /
                                      BakeTarget.effectMilliseconds)
                              .clamp(0.0, 1.0),
                          child: Text('+${compactNumber(burst.amount)}',
                              key: const Key('tap-burst'),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xffffedab),
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4)
                                  ])),
                        )))),
                  if (widget.reduceMotion && _staticGain != null)
                    Align(
                        alignment: Alignment.topCenter,
                        child: Text('+${compactNumber(_staticGain!)}',
                            key: const Key('static-gain'),
                            style: const TextStyle(
                                color: Color(0xffffedab), fontSize: 22))),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// The centre bungeoppang turns gold while any boost runs.
extension on _BakeTargetState {
  Widget _goldenWhileBoosted(Widget fish) {
    if (widget.controller.activeBoost == null) return fish;
    final glow = PixelSprites.fx('butter_glow');
    return Stack(alignment: Alignment.center, children: [
      ColorFiltered(
          key: const Key('center-fish-golden'),
          colorFilter: goldTint,
          child: fish),
      // The shine drawn for the 96x72 fish canvas, laid over it.
      if (glow != null)
        Positioned.fill(child: IgnorePointer(child: PixelArt(glow))),
    ]);
  }
}

/// Fixed four-point pixel sparkles around the bungeoppang (concept art).
class SparklePainter extends CustomPainter {
  const SparklePainter();

  /// Centre (fraction of the box) and size in sparkle pixels.
  static const _sparkles = [
    (.12, .22, 3),
    (.86, .18, 2),
    (.2, .78, 2),
    (.9, .7, 3),
    (.08, .52, 1),
    (.78, .9, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sprite = PixelSprites.fx('sparkle');
    if (sprite != null) {
      for (final (fx, fy, n) in _sparkles) {
        // Logical 7x7 sparkle; the art may be exported at finer dots.
        final side = 7 * (1.0 + n) * (size.width / 360);
        PixelSprites.draw(
            canvas,
            sprite,
            Rect.fromCenter(
                center: Offset(size.width * fx, size.height * fy),
                width: side,
                height: side));
      }
      return;
    }
    final px = math.max(2.0, (size.width / 120).roundToDouble());
    final core = Paint()..color = const Color(0xfffff3c4);
    final ray = Paint()..color = const Color(0xccfed794);
    for (final (fx, fy, n) in _sparkles) {
      final c = Offset((size.width * fx / px).roundToDouble() * px,
          (size.height * fy / px).roundToDouble() * px);
      canvas.drawRect(Rect.fromCenter(center: c, width: px, height: px), core);
      for (var i = 1; i <= n; i++) {
        for (final d in const [
          Offset(1, 0),
          Offset(-1, 0),
          Offset(0, 1),
          Offset(0, -1)
        ]) {
          canvas.drawRect(
              Rect.fromCenter(
                  center: c + d * px * i.toDouble(), width: px, height: px),
              ray);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) => false;
}
