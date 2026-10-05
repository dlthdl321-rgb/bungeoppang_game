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
import 'fish_painter.dart';
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
  const BakeTarget(
      {super.key, required this.controller, required this.reduceMotion});
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
          _elapsed - _lastTap > squashMs) {
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
    final pulse =
        reduce ? 0.0 : (1 - (_elapsed - _lastTap) / 180).clamp(0.0, 1.0);
    // Overall press shrink times a squash (wide/short) then stretch rebound.
    final squash =
        reduce ? 0.0 : squashAmount((_elapsed - _lastTap) / squashMs);
    final base = 1 - .07 * pulse;
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
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                      key: const Key('fish-glow'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color.lerp(const Color(0x35ffe59b),
                                const Color(0x99ffe59b), pulse)!,
                            const Color(0x00ffe59b)
                          ],
                        ),
                      )),
                  Transform(
                      key: const Key('fish-scale'),
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                          base * (1 + .06 * squash),
                          base * (1 - .08 * squash),
                          1),
                      child: CustomPaint(
                          size: Size(box.maxWidth,
                              math.min(box.maxHeight, box.maxWidth * .8)),
                          painter: FishPainter(
                              skin: look(CosmeticSlot.fish),
                              pattern: look(CosmeticSlot.pattern),
                              topping: look(CosmeticSlot.topping)))),
                  if (!reduce)
                    Positioned.fill(
                        child: IgnorePointer(
                            child: CustomPaint(
                                key: const Key('crumbs'),
                                painter: CrumbPainter(crumbs, _elapsed)))),
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
