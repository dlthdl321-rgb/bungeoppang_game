import 'package:flutter/material.dart';
import '../feedback_config.dart';
import '../number_format.dart';

/// 32번 0단계: moved unchanged from `celebration.dart`.
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
