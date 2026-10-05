import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../balance.dart' show maxOfflineMs;
import '../economy.dart';
import '../feedback_config.dart';
import '../game_audio.dart';
import '../game_controller.dart';
import '../game_events.dart';
import 'fish_painter.dart';

/// Counts from 0 to [value] with integer BigInt steps (no double rounding),
/// ending exactly on [value]. Shows the final value at once when [instant].
class CountUpText extends StatefulWidget {
  final BigInt value;
  final String suffix;
  final bool instant;
  final TextStyle? style;
  const CountUpText(this.value,
      {super.key, this.suffix = '', this.instant = false, this.style});
  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: countUpMs));

  @override
  void initState() {
    super.initState();
    if (widget.instant) {
      _anim.value = 1;
    } else {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_anim.value);
        final shown = _anim.isCompleted
            ? widget.value
            : widget.value *
                BigInt.from((t * 1000).round()) ~/
                BigInt.from(1000);
        return Text('${exactNumber(shown)}${widget.suffix}',
            textAlign: TextAlign.center, style: widget.style);
      });
}

class _Confetti {
  double x = 0, vy = 0, sway = 0, size = 0;
  int color = 0;
}

/// Fixed pool of [maxConfetti] pieces, created once per celebration host.
class _ConfettiPainter extends CustomPainter {
  static const _colors = [
    Color(0xffffd36b),
    Color(0xffff8f6b),
    Color(0xff91d5c0),
    Color(0xfffff3c8)
  ];
  final List<_Confetti> pieces;
  final double t; // 0..1 of the celebration.
  _ConfettiPainter(this.pieces, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      paint.color = _colors[p.color].withValues(alpha: (1 - t).clamp(0, 1));
      final y = -20 + p.vy * t * size.height;
      final x = p.x * size.width + math.sin(t * 12 + p.sway) * 14;
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y), width: p.size, height: p.size * .6),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/// Shows queued celebrations above every route (sheets and dialogs).
class CelebrationHost extends StatefulWidget {
  final GameController controller;
  final Widget child;
  const CelebrationHost(
      {super.key, required this.controller, required this.child});
  @override
  State<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends State<CelebrationHost>
    with SingleTickerProviderStateMixin {
  final _queue = Queue<GameEvent>();
  final _confetti = List.generate(maxConfetti, (_) => _Confetti());
  final _random = math.Random(3);
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  StreamSubscription<GameEvent>? _sub;
  GameEvent? _current;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.controller.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    final audio = GameAudioScope.of(context);
    audio.play(switch (e.kind) {
      GameEventKind.purchase => Sfx.purchase,
      GameEventKind.levelUp || GameEventKind.prestige => Sfx.levelUp,
      _ => Sfx.reward,
    });
    if (e.kind == GameEventKind.purchase) return;
    _queue.add(e);
    if (_current == null) _next();
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    _reduced = widget.controller.state.settings.reduceMotion ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    for (final p in _confetti) {
      p
        ..x = _random.nextDouble()
        ..vy = .6 + _random.nextDouble() * .7
        ..sway = _random.nextDouble() * 6
        ..size = 6 + _random.nextDouble() * 6
        ..color = _random.nextInt(4);
    }
    setState(() => _current = _queue.removeFirst());
    _anim
      ..duration = Duration(
          milliseconds: _reduced ? reducedCelebrationMs : celebrationMs)
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final e = _current;
    return Stack(children: [
      widget.child,
      if (e != null)
        Positioned.fill(
            child: IgnorePointer(
                child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) {
                      final t = _anim.value;
                      final opacity = t < .1
                          ? t / .1
                          : t > .85
                              ? (1 - t) / .15
                              : 1.0;
                      return Stack(children: [
                        if (!_reduced)
                          Positioned.fill(
                              child: CustomPaint(
                                  key: const Key('confetti'),
                                  painter: _ConfettiPainter(_confetti, t))),
                        SafeArea(
                            child: Align(
                                alignment: const Alignment(0, -.55),
                                child: Opacity(
                                    opacity: opacity.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                        scale: _reduced
                                            ? 1
                                            : .85 +
                                                .15 *
                                                    Curves.elasticOut.transform(
                                                        (t * 2.5).clamp(0, 1)),
                                        child: _banner(context, e))))),
                      ]);
                    }))),
    ]);
  }

  Widget _banner(BuildContext context, GameEvent e) => Material(
      key: const Key('celebration'),
      color: Colors.transparent,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xff3b2a1f), Color(0xff1d2c3d)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffffd36b), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88000000), blurRadius: 18)
                  ]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    switch (e.kind) {
                      GameEventKind.levelUp => Icons.emoji_events,
                      GameEventKind.achievement => Icons.military_tech,
                      GameEventKind.itemUsed => Icons.auto_awesome,
                      GameEventKind.prestige => Icons.storefront,
                      _ => Icons.celebration,
                    },
                    color: const Color(0xffffd36b),
                    size: 34),
                const SizedBox(height: 6),
                Text(e.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                if (e.amount != null) ...[
                  const SizedBox(height: 4),
                  CountUpText(e.amount!,
                      key: const Key('celebration-amount'),
                      suffix: ' ${e.unit ?? ''}'.trimRight(),
                      instant: _reduced,
                      style: const TextStyle(
                          color: Color(0xffffe7ac),
                          fontSize: 26,
                          fontWeight: FontWeight.w900)),
                ],
              ]))));
}

/// The "welcome back" screen for offline production.
class OfflineRewardDialog extends StatelessWidget {
  final BigInt amount;
  final Duration away;
  final bool reduceMotion;
  const OfflineRewardDialog(
      {super.key,
      required this.amount,
      required this.away,
      required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final hours = away.inHours, minutes = away.inMinutes % 60;
    return Dialog(
        key: const Key('offline-reward'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xff16243a), Color(0xff3b2a1f)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xffffd36b), width: 2)),
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('다시 오셨네요!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                      '자리를 비운 ${hours > 0 ? '$hours시간 ' : ''}$minutes분 동안 노점이 쉬지 않고 구웠어요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xffc4d0d7))),
                  const SizedBox(
                      height: 110,
                      width: 150,
                      child: CustomPaint(painter: FishPainter())),
                  CountUpText(amount,
                      key: const Key('offline-reward-amount'),
                      suffix: '개',
                      instant: reduceMotion,
                      style: const TextStyle(
                          color: Color(0xffffe7ac),
                          fontSize: 30,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(
                      '자리를 비운 동안은 자동 생산의 50%를 최대 ${maxOfflineMs ~/ 3600000}시간까지 받아요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xffc4d0d7), fontSize: 12)),
                  const SizedBox(height: 12),
                  FilledButton(
                      key: const Key('offline-reward-close'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('받기')),
                ]))));
  }
}
