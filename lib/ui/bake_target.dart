import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../economy.dart';
import '../game_controller.dart';
import 'fish_painter.dart';

class _Burst {
  final int born;
  final BigInt amount;
  final double x;
  const _Burst(this.born, this.amount, this.x);
}

/// One ticker and at most eight particles, irrespective of tap frequency.
/// Every accepted tap earns currency; only decorative effects are capped.
class BakeTarget extends StatefulWidget {
  static const maxBursts = 8;
  static const effectMilliseconds = 700;
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
      });
      if (_bursts.isEmpty) _ticker.stop();
    });
  }

  void _bake() {
    if (!_active || widget.controller.busy) return;
    final c = widget.controller;
    final amount = c.tap();
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
      _bursts.add(_Burst(_elapsed, amount, .3 + (_serial++ % 5) * .1));
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
    final pulse = widget.reduceMotion
        ? 0.0
        : (1 - (_elapsed - _lastTap) / 180).clamp(0.0, 1.0);
    final skin = widget.controller.state.equippedSkin;
    final filling = skin == 'cocoa'
        ? const Color(0xff663322)
        : skin == 'custard'
            ? const Color(0xffffef9b)
            : const Color(0xffa95738);
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
            onTap: _bake,
            onLongPressStart: widget.controller.state.settings.holdToBake
                ? (_) {
                    _stopHold();
                    _bake();
                    _hold = Timer.periodic(
                        const Duration(milliseconds: 250), (_) => _bake());
                  }
                : null,
            onLongPressEnd: (_) => _stopHold(),
            onLongPressCancel: _stopHold,
            child: LayoutBuilder(
                builder: (context, box) => Stack(
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
                        Transform.scale(
                            key: const Key('fish-scale'),
                            scale: 1 - .07 * pulse,
                            child: CustomPaint(
                                size: Size(box.maxWidth,
                                    math.min(box.maxHeight, box.maxWidth * .8)),
                                painter: FishPainter(filling, skin: skin))),
                        for (final burst in _bursts)
                          Positioned(
                              key: ValueKey(burst),
                              left: (box.maxWidth * burst.x - 40)
                                  .clamp(0.0, math.max(0, box.maxWidth - 120)),
                              top: box.maxHeight * .36 -
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
                                          Shadow(
                                              color: Colors.black,
                                              blurRadius: 4)
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
                    )),
          ),
        ),
      ),
    );
  }
}
