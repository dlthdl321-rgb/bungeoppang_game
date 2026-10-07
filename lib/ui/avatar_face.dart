import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../avatar_motion.dart';
import '../avatar_rig_config.dart';

/// Runs an [AvatarMotion] for one vendor and hands [builder] the face frames
/// to draw (eyes blink by themselves; the mouth talks while [talking]).
/// Rebuilds only when a frame changes. Changing what the vendor wears does
/// not touch the motion, so a blink or a sentence carries on.
///
/// With [animate] off (reduced motion, tests) the face rests and no ticker
/// runs.
class AvatarFace extends StatefulWidget {
  final bool animate, talking;

  /// Played once when the vendor is tapped (null: taps pass through).
  final MotionClip? onTap;
  final Widget Function(BuildContext context, Map<String, String> face)
      builder;
  const AvatarFace(
      {super.key,
      required this.builder,
      this.animate = true,
      this.talking = false,
      this.onTap});

  @override
  State<AvatarFace> createState() => _AvatarFaceState();
}

class _AvatarFaceState extends State<AvatarFace>
    with SingleTickerProviderStateMixin {
  final _motion = AvatarMotion(seed: identityHashCode(Object()));
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;
  Map<String, String> _face = const {};

  int get _ms => _now.inMilliseconds;

  void _tick(Duration elapsed) {
    _now = elapsed;
    _show();
  }

  void _show() {
    final face = widget.animate ? _motion.frames(_ms) : const <String, String>{};
    if (!mapEquals(face, _face)) setState(() => _face = face);
  }

  void _sync() {
    if (widget.animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.animate && _ticker.isActive) {
      _ticker.stop();
    }
    if (widget.talking && !_motion.playing(talkClip.id)) {
      _motion.play(talkClip, _ms, loops: 0);
    } else if (!widget.talking && _motion.playing(talkClip.id)) {
      _motion.stop(talkClip.id);
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AvatarFace old) {
    super.didUpdateWidget(old);
    _sync();
    if (!widget.animate) _show();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder(context, _face);
    final tap = widget.onTap;
    if (tap == null || !widget.animate) return child;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _motion.play(tap, _ms);
          _show();
        },
        child: child);
  }
}
