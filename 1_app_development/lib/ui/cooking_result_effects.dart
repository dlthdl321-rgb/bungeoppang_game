import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_result_rules.dart';
import '../game_audio.dart';
import '../feedback_config.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'sparkle_art.dart';

/// The bake result's grade on the mold (26번 4단계, MASTER 10장 결과 등급·연출):
/// a big word, a short praise or reason (`mold-result-caption`), the order
/// customer's reaction, and once per result a sound, a vibration and a
/// short effect (sparkles, steam, a shine or smoke).
///
/// With [reduceMotion] (or the system's 'remove animations') nothing moves:
/// the words, sound and vibration stay. The sound and vibration follow the
/// settings (SoundPolicy, [vibration]).
class CookingResultView extends StatefulWidget {
  final String sessionId;
  final CookingGrade grade;
  final String line;
  /// '도윤: 와, …' for an order production, else null.
  final String? reaction;
  /// Burnt (not underdone) for [CookingGrade.fail]: smoke instead of nothing.
  final bool burnt;
  final bool reduceMotion, vibration;
  const CookingResultView(
      {super.key,
      required this.sessionId,
      required this.grade,
      required this.line,
      this.reaction,
      this.burnt = false,
      this.reduceMotion = false,
      this.vibration = false});

  /// Effect length; the big word pops in the first [popMs].
  static const effectMs = 1400, popMs = 300;

  /// The result band (H22): dark wood at 70% so the stall shows through.
  static const bandColor = Color(0xb3221410);
  static const bandMaxWidth = 280.0;

  /// At most this many particles at once (sparkles + steam + smoke).
  static const maxParticles = 12;

  /// The result whose sound and vibration already played: rebuilding the
  /// screen (or coming back to it) does not play them again. Memory only.
  static String? celebrated;

  static Sfx sound(CookingGrade grade) => switch (grade) {
        CookingGrade.perfect => Sfx.resultPerfect,
        CookingGrade.good => Sfx.resultGood,
        CookingGrade.near => Sfx.resultNear,
        CookingGrade.fail => Sfx.resultFail,
      };

  /// (sparkles, steam lines, smoke puffs) of each grade.
  static (int, int, int) particles(CookingGrade grade, {bool burnt = false}) => switch (grade) {
        CookingGrade.perfect => (8, 3, 0),
        CookingGrade.good => (4, 2, 0),
        CookingGrade.near => (0, 1, 0),
        CookingGrade.fail => (0, 0, burnt ? 2 : 0),
      };

  @override
  State<CookingResultView> createState() => _CookingResultViewState();
}

class _CookingResultViewState extends State<CookingResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effect = AnimationController(
      vsync: this, duration: const Duration(milliseconds: CookingResultView.effectMs));
  bool _still = true, _begun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    _start();
  }

  @override
  void didUpdateWidget(CookingResultView old) {
    super.didUpdateWidget(old);
    if (old.sessionId != widget.sessionId) _start();
  }

  void _start() {
    _still = widget.reduceMotion || MediaQuery.disableAnimationsOf(context);
    if (CookingResultView.celebrated == widget.sessionId) {
      // Shown already: the end of the effect, no new sound.
      _effect.value = 1;
      return;
    }
    CookingResultView.celebrated = widget.sessionId;
    GameAudioScope.of(context).play(CookingResultView.sound(widget.grade));
    if (widget.vibration) {
      switch (widget.grade) {
        case CookingGrade.perfect:
          HapticFeedback.heavyImpact();
        case CookingGrade.good:
          HapticFeedback.mediumImpact();
        case CookingGrade.near:
          HapticFeedback.lightImpact();
        case CookingGrade.fail:
          break;
      }
    }
    if (_still) {
      _effect.value = 1;
    } else {
      _effect.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;
    final stars = cookingStars(grade);
    final title = Text(cookingGradeTitle(grade),
        key: const Key('mold-result-grade'),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontFamily: 'Jua',
            fontFamilyFallback: Cozy.fontFallback,
            color: switch (grade) {
              CookingGrade.perfect => const Color(0xffffd36b),
              CookingGrade.good => Cozy.cream,
              CookingGrade.near => const Color(0xfff3dcc0),
              CookingGrade.fail => const Color(0xffe7d6c8),
            },
            fontSize: grade == CookingGrade.fail ? 19 : 23,
            height: 1.15));
    // 26번 3차 피드백 H22·H24: the grade, its stars and the reason in one
    // translucent band over the mold's top (not loose words on the fish).
    final band = Container(
      key: const Key('mold-result-band'),
      constraints: const BoxConstraints(maxWidth: CookingResultView.bandMaxWidth),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
      decoration: BoxDecoration(
          color: CookingResultView.bandColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Cozy.cream.withValues(alpha: .22))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          label: '별 $cookingStarsMax개 중 $stars개',
          excludeSemantics: true,
          child: Row(key: const Key('mold-result-stars'), mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < cookingStarsMax; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: i < stars
                    ? const PixelIcon('star', key: Key('mold-result-star-on'), size: 22)
                    : const Opacity(
                        opacity: .4,
                        child: ColorFiltered(
                            colorFilter: ColorFilter.mode(Color(0xffd9cfc4), BlendMode.srcIn),
                            child: PixelIcon('star', size: 22))),
              ),
          ]),
        ),
        const SizedBox(height: 2),
        AnimatedBuilder(
            animation: _effect,
            builder: (context, child) => Transform.scale(
                scale: _still ? 1 : popScale(grade, _effect.value),
                child: child),
            child: title),
        Text(widget.line,
            key: const Key('mold-result-caption'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Cozy.cream, fontWeight: FontWeight.w600, fontSize: 13, height: 1.3)),
      ]),
    );
    return Stack(clipBehavior: Clip.none, children: [
      if (!_still)
        Positioned.fill(
            child: IgnorePointer(
                child: CustomPaint(
                    key: const Key('mold-result-effects'),
                    painter: CookingResultEffectPainter(
                        grade, _effect, burnt: widget.burnt)))),
      Align(
          alignment: const Alignment(0, -1),
          child: FractionalTranslation(
              translation: const Offset(0, -.6),
              child: IgnorePointer(child: band))),
      if (widget.reaction != null)
        Align(
            alignment: const Alignment(0, 1),
            child: FractionalTranslation(
                translation: const Offset(0, .2),
                child: Container(
                    key: const Key('mold-result-reaction'),
                    constraints: const BoxConstraints(maxWidth: 260),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Cozy.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Cozy.woodLight, width: 2)),
                    child: Text(widget.reaction!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Cozy.ink, fontWeight: FontWeight.bold, fontSize: 13))))),
    ]);
  }

  /// The big word's size at [t] of the effect: a 300 ms hop for perfect,
  /// a smaller one for good, none below.
  static double popScale(CookingGrade grade, double t) {
    final hop = switch (grade) {
      CookingGrade.perfect => .35,
      CookingGrade.good => .15,
      _ => 0.0,
    };
    final p = (t * CookingResultView.effectMs / CookingResultView.popMs).clamp(0.0, 1.0);
    return 1 + hop * math.sin(p * math.pi) - (1 - p) * .2 * (hop > 0 ? 1 : 0);
  }
}

/// The result effect over the mold: sparkles around the fish, steam lines
/// rising, one shine sweeping a perfect fish, grey smoke over a burnt one.
class CookingResultEffectPainter extends CustomPainter {
  final CookingGrade grade;
  final Animation<double> t;
  final bool burnt;
  CookingResultEffectPainter(this.grade, this.t, {this.burnt = false}) : super(repaint: t);

  static const _sparkleAt = [
    (.08, .25), (.92, .2), (.86, .82), (.14, .86), (.5, .02), (.98, .52), (.3, .05), (.7, .96),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v >= 1) return;
    final (sparkles, steam, smoke) =
        CookingResultView.particles(grade, burnt: burnt);
    final side = size.shortestSide * .26;
    for (var i = 0; i < sparkles; i++) {
      final (x, y) = _sparkleAt[i];
      // Staggered: each twinkles once while the effect runs.
      final phase = (v * 1.6 - i * .08).clamp(0.0, .7);
      if (phase <= 0 || phase >= .7) continue;
      SparkleArt.paint(canvas, Offset(x * size.width, y * size.height), side, phase);
    }
    final fade = math.sin(v * math.pi);
    for (var i = 0; i < steam; i++) {
      final x = size.width * (.35 + .15 * i);
      final rise = size.height * .5 * v;
      final path = Path()..moveTo(x, size.height * .25 - rise);
      for (var k = 1; k <= 5; k++) {
        path.lineTo(x + math.sin(v * 7 + k + i) * size.width * .025,
            size.height * (.25 - k * .07) - rise);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: .5 * fade));
    }
    for (var i = 0; i < smoke; i++) {
      final c = Offset(size.width * (.42 + .16 * i), size.height * (.35 - .4 * v));
      canvas.drawCircle(c, size.shortestSide * (.12 + .1 * v),
          Paint()..color = const Color(0xff6b625c).withValues(alpha: .45 * fade));
    }
    if (grade == CookingGrade.perfect) {
      // One shine across the fish, in the first half.
      final s = (v * 2).clamp(0.0, 1.0);
      if (s < 1) {
        final x = size.width * (-.2 + 1.4 * s);
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * .12, size.height * .15, size.width * .76, size.height * .7),
            Radius.circular(size.height * .35)));
        canvas.drawPath(
            Path()
              ..moveTo(x, 0)
              ..lineTo(x + size.width * .08, 0)
              ..lineTo(x - size.width * .04, size.height)
              ..lineTo(x - size.width * .12, size.height)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: .35 * math.sin(s * math.pi)));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CookingResultEffectPainter old) =>
      old.grade != grade || old.burnt != burnt || old.t != t;
}
