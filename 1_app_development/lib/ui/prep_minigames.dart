import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../development_balance.dart';
import '../pantry_rules.dart';
import '../prep_minigames.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart' show PixelSprites;
import 'prep_art.dart';

/// What the make command answered once a mini-game ended.
class PrepFinish {
  /// The tubs were made.
  final bool made;
  /// The line under the result heading ('반죽 3통을 만들었어요.' or why not).
  final String text;
  const PrepFinish(this.made, this.text);
}

/// The full-screen mini-game over the 재료 준비 window (재료 타이쿤 D,
/// 설계안 3장): the bowl or pot in the middle, the time and the game's bar
/// on top, one line and '그만두기' below. When the game ends [onFinish] runs
/// the make command once and the result shows; '확인' goes back to the
/// window. '그만두기', the back button or leaving the app before the end
/// makes nothing.
///
/// With the screen reader on, the game is replaced by '보통으로 만들기'
/// (double tap; made without the bonus). [reduceMotion] keeps the flame and
/// the result still; [vibration] follows the player's setting.
class PrepGameScreen extends StatefulWidget {
  final DevelopmentBalance config;
  final PreparedKind kind;
  final bool premium, reduceMotion, vibration;
  final int tubs;
  final Future<PrepFinish> Function(bool success) onFinish;
  const PrepGameScreen({super.key, required this.config, required this.kind, required this.tubs,
      required this.onFinish, this.premium = false, this.reduceMotion = false, this.vibration = false});

  /// The mini-game's name on its screen.
  static String title(String minigame) => switch (minigame) {
        'stir' => '반죽 젓기',
        'heat' => '불 조절',
        'whisk' => '휘젓기',
        _ => minigame,
      };

  @override
  State<PrepGameScreen> createState() => PrepGameScreenState();
}

enum _Stage { playing, saving, result }

class PrepGameScreenState extends State<PrepGameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  PrepGame? _game;
  Duration _last = Duration.zero;
  _Stage _stage = _Stage.playing;
  bool _normal = false, _quitting = false;
  PrepFinish? _finish;
  int? _pointer;
  Offset? _finger;
  bool _wasGreen = false;
  int _lastBuzz = -1000;

  /// The running game, for tests.
  PrepGame? get game => _game;
  bool get finished => _stage == _Stage.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    PrepArt.loaded.addListener(_artIn);
    PrepArt.load();
  }

  void _artIn() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PrepArt.loaded.removeListener(_artIn);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-game is quitting (nothing is used).
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.hidden) && _stage == _Stage.playing) _quit();
  }

  void _quit() {
    if (_stage != _Stage.playing || _quitting || !mounted) return;
    _quitting = true;
    _ticker.stop();
    Navigator.of(context).pop(false);
  }

  /// Made on the bowl's first layout (the bowl's width sets the distances).
  void _ensureGame(double bowlWidth) {
    if (_game != null) return;
    _game = PrepGameConfig.of(widget.config).create(widget.kind.minigame, bowlWidth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stage != _Stage.playing) return;
      // The bars and the line come in with the game.
      setState(() {});
      if (!_ticker.isActive) _ticker.start();
    });
  }

  void _onTick(Duration elapsed) {
    final game = _game;
    if (game == null) return;
    final ms = (elapsed - _last).inMilliseconds;
    if (ms <= 0) return;
    _last = elapsed;
    game.advance(ms);
    _afterChange();
  }

  void _afterChange() {
    final game = _game!;
    if (widget.vibration && game.playing) {
      final green = game.inGreen;
      if (green && !_wasGreen) HapticFeedback.lightImpact();
      _wasGreen = green;
    }
    if (!game.playing) {
      _end(game.phase == PrepPhase.success);
    } else {
      setState(() {});
    }
  }

  Future<void> _end(bool success) async {
    if (_stage != _Stage.playing) return;
    _ticker.stop();
    setState(() => _stage = _Stage.saving);
    if (widget.vibration) success ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    final finish = await widget.onFinish(success);
    if (!mounted) return;
    setState(() {
      _finish = finish;
      _stage = _Stage.result;
    });
  }

  /// The screen reader's '보통으로 만들기': no game, no bonus.
  void _makeNormal() {
    if (_stage != _Stage.playing) return;
    _normal = true;
    _end(false);
  }

  // ---- 손가락 ----

  (Offset, double) _bowl(Size area) {
    final k = math.min(area.width / PrepArt.sceneSize.width, area.height / PrepArt.sceneSize.height);
    final origin = Offset((area.width - PrepArt.sceneSize.width * k) / 2, (area.height - PrepArt.sceneSize.height * k) / 2);
    // The bowls' centre (600, 440) and outer width (720) on the canvas.
    return (origin + const Offset(600, 440) * k, 720 * k);
  }

  void _down(PointerDownEvent e, Size area) {
    final game = _game;
    if (game == null || !game.playing || _pointer != null) return;
    _pointer = e.pointer;
    _finger = e.localPosition;
    switch (game) {
      case HeatGame g:
        g.hold(true);
      case StirGame g:
        final at = e.localPosition - _bowl(area).$1;
        g.move(at.dx, at.dy);
      case WhiskGame g:
        g.move(e.localPosition.dx);
    }
    _afterChange();
  }

  void _move(PointerMoveEvent e, Size area) {
    final game = _game;
    if (game == null || e.pointer != _pointer) return;
    _finger = e.localPosition;
    switch (game) {
      case StirGame g:
        final at = e.localPosition - _bowl(area).$1;
        g.move(at.dx, at.dy);
      case WhiskGame g:
        final before = g.strokes;
        g.move(e.localPosition.dx);
        if (widget.vibration && g.strokes > before && game.elapsedMs - _lastBuzz >= 80) {
          _lastBuzz = game.elapsedMs;
          HapticFeedback.selectionClick();
        }
      case HeatGame _:
        break;
    }
    _afterChange();
  }

  void _up(int pointer) {
    final game = _game;
    if (game == null || pointer != _pointer) return;
    _pointer = null;
    _finger = null;
    switch (game) {
      case HeatGame g:
        g.hold(false);
      case StirGame g:
        g.release();
      case WhiskGame g:
        g.release();
    }
    _afterChange();
  }

  // ---- 화면 ----

  @override
  Widget build(BuildContext context) {
    final reader = MediaQuery.accessibleNavigationOf(context);
    final title = PrepGameScreen.title(widget.kind.minigame);
    final what = '${widget.premium ? widget.kind.premiumLabel : widget.kind.label} ${widget.tubs}통';
    return PopScope(
      canPop: _stage != _Stage.saving,
      child: Material(
        key: const Key('prep-game'),
        color: Cozy.cream,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(children: [
              Text(title, key: const Key('prep-game-title'),
                  style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 28, color: Cozy.ink)),
              Text(what, style: const TextStyle(fontSize: 14, color: Cozy.inkSoft)),
              const SizedBox(height: 10),
              if (_stage == _Stage.result) Expanded(child: _result()) else ...[
                _bars(reader),
                const SizedBox(height: 8),
                Expanded(child: reader ? _readerPlay() : _play()),
                const SizedBox(height: 8),
                if (!reader) Text(_game?.caption ?? '', key: const Key('prep-game-caption'), textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Cozy.ink)),
                const SizedBox(height: 10),
                SizedBox(width: 180, child: CozyButton(key: const Key('prep-game-quit'), minHeight: 44, fontSize: 17,
                    onPressed: _stage == _Stage.playing ? _quit : null, label: '그만두기')),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bars(bool reader) {
    final game = _game;
    if (game == null || reader) return const SizedBox(height: 52);
    final label = switch (game) {
      StirGame _ => '매끈함',
      HeatGame _ => '맞춘 시간',
      WhiskGame _ => '거품',
      _ => '',
    };
    final (value, green, mark) = switch (game) {
      HeatGame g => (g.greenShare, null, g.needShare),
      _ => (game.bar, game.green, null),
    };
    return Column(children: [
      _Meter(key: const Key('prep-time'), label: '남은 시간', value: game.timeLeft, colour: Cozy.orangeDeep, height: 10),
      const SizedBox(height: 8),
      _Meter(key: const Key('prep-bar'), label: label, value: value, green: green, mark: mark,
          colour: game.inGreen || (game is HeatGame && value >= (mark ?? 1)) ? CozyTone.success.text : Cozy.amber, height: 18),
    ]);
  }

  Widget _readerPlay() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('화면 읽기를 켜 두면 덤 없이 보통으로 만들어요.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Cozy.ink)),
          const SizedBox(height: 14),
          SizedBox(width: 240, child: CozyPrimaryButton(key: const Key('prep-game-normal'),
              onPressed: _stage == _Stage.playing ? _makeNormal : null, label: '보통으로 만들기')),
        ]),
      );

  Widget _play() => LayoutBuilder(builder: (context, box) {
        final area = box.biggest;
        final (centre, width) = _bowl(area);
        _ensureGame(width);
        final game = _game!;
        return Semantics(
          button: true,
          label: '보통으로 만들기',
          hint: '화면 읽기 기능으로 두 번 누르면 덤 없이 보통으로 만들어요.',
          onTap: _stage == _Stage.playing ? _makeNormal : null,
          child: ExcludeSemantics(
            child: Listener(
              key: const Key('prep-game-area'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _down(e, area),
              onPointerMove: (e) => _move(e, area),
              onPointerUp: (e) => _up(e.pointer),
              onPointerCancel: (e) => _up(e.pointer),
              child: CustomPaint(
                size: area,
                painter: _ScenePainter(game: game, kind: widget.kind, centre: centre, bowlWidth: width,
                    finger: _finger, still: widget.reduceMotion),
              ),
            ),
          ),
        );
      });

  Widget _result() {
    final game = _game;
    final finish = _finish!;
    final success = game?.phase == PrepPhase.success && !_normal;
    final heading = !finish.made ? '만들지 못했어요'
        : _normal ? '보통으로 만들었어요'
        : success ? '딱 좋아요!'
        : game?.failText ?? '보통으로 만들었어요';
    final tone = !finish.made ? CozyTone.warning : success ? CozyTone.success : CozyTone.neutral;
    final tub = PrepArt.icon('tub_${widget.kind.id}');
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (tub != null) SizedBox.square(dimension: 96, child: CustomPaint(painter: _ImagePainter(tub))),
        const SizedBox(height: 10),
        Text(heading, key: const Key('prep-result-heading'), textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 30,
                color: tone == CozyTone.neutral ? Cozy.ink : tone.text)),
        const SizedBox(height: 10),
        CozyPanel(tone: tone, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(finish.text, key: const Key('prep-result-text'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.35))),
        const SizedBox(height: 18),
        SizedBox(width: 200, child: CozyPrimaryButton(key: const Key('prep-result-ok'),
            onPressed: () => Navigator.of(context).pop(finish.made), label: '확인')),
      ]),
    );
  }
}

/// A labelled bar, with a green zone or a goal mark.
class _Meter extends StatelessWidget {
  final String label;
  final double value, height;
  final (double, double)? green;
  final double? mark;
  final Color colour;
  const _Meter({super.key, required this.label, required this.value, required this.colour, required this.height,
      this.green, this.mark});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 92, child: Text(label, maxLines: 2,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Cozy.inkSoft))),
        Expanded(child: SizedBox(height: height, child: CustomPaint(
            painter: _MeterPainter(value.clamp(0, 1), green, mark, colour)))),
        SizedBox(width: 40, child: Text('${(value.clamp(0, 1) * 100).round()}%', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Cozy.ink))),
      ]);
}

class _MeterPainter extends CustomPainter {
  final double value;
  final (double, double)? green;
  final double? mark;
  final Color colour;
  _MeterPainter(this.value, this.green, this.mark, this.colour);

  static const greenZone = Color(0xff9fd8ad);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final whole = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(whole, Paint()..color = Cozy.creamDeep);
    canvas.save();
    canvas.clipRRect(whole);
    if (green case (final a, final b)) {
      canvas.drawRect(Rect.fromLTRB(size.width * a, 0, size.width * b, size.height), Paint()..color = greenZone);
    }
    canvas.drawRect(Rect.fromLTWH(0, size.height * .2, size.width * value, size.height * .6), Paint()..color = colour);
    canvas.restore();
    if (mark case final m?) {
      final x = size.width * m;
      canvas.drawLine(Offset(x, -2), Offset(x, size.height + 2), Paint()..color = CozyTone.success.text..strokeWidth = 2);
    }
    canvas.drawRRect(whole, Paint()..color = Cozy.woodLight..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _MeterPainter old) =>
      old.value != value || old.green != green || old.mark != mark || old.colour != colour;
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  _ImagePainter(this.image);
  @override
  void paint(Canvas canvas, Size size) => PixelSprites.draw(canvas, image, Offset.zero & size);
  @override
  bool shouldRepaint(covariant _ImagePainter old) => old.image != image;
}

/// The bowl or pot, its state, the tool under the finger and (불 조절) the
/// thermometer. Uses 25번 62번 pictures when in, else plain shapes.
class _ScenePainter extends CustomPainter {
  final PrepGame game;
  final PreparedKind kind;
  final Offset centre;
  final double bowlWidth;
  final Offset? finger;
  final bool still;
  // Repaints follow the game's numbers.
  final double _bar;
  final bool _holding;
  final int _elapsed;
  _ScenePainter({required this.game, required this.kind, required this.centre, required this.bowlWidth,
      required this.finger, required this.still})
      : _bar = game.bar,
        _holding = game is HeatGame && game.holding,
        _elapsed = game.elapsedMs;

  static const batter = Color(0xffd9b775), batterLumpy = Color(0xffe8d2a0), custardLow = Color(0xfff7dc95),
      custardHigh = Color(0xffe8b84a), bowlRim = Color(0xfffff4dc), outline = Color(0xff4a2c1d);
  static const fillings = {'redbean': Color(0xff642b27), 'cocoa': Color(0xff4a2c1d), 'custard': Color(0xffe8b84a)};

  Rect _sceneRect(Size size) {
    final k = math.min(size.width / PrepArt.sceneSize.width, size.height / PrepArt.sceneSize.height);
    final w = PrepArt.sceneSize.width * k, h = PrepArt.sceneSize.height * k;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  void _art(Canvas canvas, ui.Image image, Rect rect, [double opacity = 1]) {
    if (opacity <= 0) return;
    if (opacity >= 1) {
      PixelSprites.draw(canvas, image, rect);
      return;
    }
    canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    PixelSprites.draw(canvas, image, rect);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scene = _sceneRect(size);
    switch (game) {
      case StirGame _:
        _bowl(canvas, scene, 'bowl_batter_lumpy', 'bowl_batter_smooth', batterLumpy, batter, _bar / (game.green?.$2 ?? 1));
        _tool(canvas, 'tool_spatula');
      case WhiskGame _:
        _bowl(canvas, scene, 'bowl_custard_low', 'bowl_custard_high', custardLow, custardHigh, _bar);
        _tool(canvas, 'tool_whisk');
      case HeatGame g:
        _pot(canvas, scene, g);
    }
  }

  void _bowl(Canvas canvas, Rect scene, String from, String to, Color a, Color b, double t) {
    final low = PrepArt.scene(from), high = PrepArt.scene(to);
    final mix = t.clamp(0.0, 1.0);
    if (low != null && high != null) {
      _art(canvas, low, scene);
      _art(canvas, high, scene, mix);
      return;
    }
    // Stand-in: a cream bowl seen from above.
    final r = bowlWidth / 2;
    canvas.drawCircle(centre, r, Paint()..color = bowlRim);
    canvas.drawCircle(centre, r, Paint()..color = outline..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawCircle(centre, r * .8, Paint()..color = Color.lerp(a, b, mix)!);
  }

  void _tool(Canvas canvas, String name) {
    final at = finger ?? centre + Offset(bowlWidth * .42, bowlWidth * .1);
    final image = PrepArt.scene(name);
    final side = bowlWidth * .55, k = side / PrepArt.toolSize.width;
    final grip = PrepArt.toolGrip[name]!;
    if (image != null) {
      PixelSprites.draw(canvas, image, Rect.fromLTWH(at.dx - grip.dx * k, at.dy - grip.dy * k, side, side));
      return;
    }
    canvas.drawCircle(at, 10, Paint()..color = Cozy.wood);
  }

  void _pot(Canvas canvas, Rect scene, HeatGame g) {
    final pot = PrepArt.scene('pot_${kind.id}') ?? PrepArt.scene('pot_redbean');
    final fire = PrepArt.scene('fire_high');
    final k = scene.width / PrepArt.sceneSize.width;
    if (pot != null) {
      _art(canvas, pot, scene);
    } else {
      // Stand-in: a pot on a small stove.
      final body = Rect.fromCenter(center: scene.topLeft + const Offset(560, 400) * k, width: 520 * k, height: 300 * k);
      canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(40 * k)), Paint()..color = const Color(0xff5a504a));
      canvas.drawOval(Rect.fromCenter(center: body.topCenter, width: body.width * .9, height: 90 * k),
          Paint()..color = fillings[kind.id] ?? batter);
    }
    if (_holding) {
      // Flickers a little unless motion is reduced.
      final flicker = still ? 1.0 : 1 + .04 * math.sin(_elapsed / 60);
      if (fire != null) {
        canvas.save();
        final base = scene.topLeft + const Offset(470, 720) * k;
        canvas.translate(base.dx, base.dy);
        canvas.scale(1, flicker);
        canvas.translate(-base.dx, -base.dy);
        _art(canvas, fire, scene);
        canvas.restore();
      } else {
        final base = scene.topLeft + const Offset(560, 640) * k;
        canvas.drawOval(Rect.fromCenter(center: base, width: 160 * k, height: 120 * k * flicker),
            Paint()..color = const Color(0xffff8a2a));
      }
    }
    _thermometer(canvas, Rect.fromLTWH(scene.left + 1040 * k, scene.top + 140 * k, 80 * k, 600 * k), g);
  }

  void _thermometer(Canvas canvas, Rect r, HeatGame g) {
    final (lo, hi) = g.green;
    final w = math.max(r.width, 18.0);
    final rect = Rect.fromCenter(center: r.center, width: w, height: r.height);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(w / 2));
    canvas.drawRRect(rr, Paint()..color = Cozy.creamDeep);
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Rect.fromLTRB(rect.left, rect.bottom - rect.height * hi, rect.right, rect.bottom - rect.height * lo),
        Paint()..color = _MeterPainter.greenZone);
    canvas.restore();
    canvas.drawRRect(rr, Paint()..color = Cozy.wood..style = PaintingStyle.stroke..strokeWidth = 2);
    // The needle: a red line with a knob on the left.
    final y = rect.bottom - rect.height * g.level;
    final needle = Paint()..color = Cozy.brick..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(rect.left - 10, y), Offset(rect.right + 4, y), needle);
    canvas.drawCircle(Offset(rect.left - 12, y), 6, Paint()..color = Cozy.brick);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old._bar != _bar || old._holding != _holding || old.finger != finger || old.centre != centre ||
      old.bowlWidth != bowlWidth || (!still && _holding && old._elapsed != _elapsed) || old.game != game;
}
