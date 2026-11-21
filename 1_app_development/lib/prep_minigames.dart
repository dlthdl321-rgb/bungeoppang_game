import 'cooking_flip.dart';
import 'development_balance.dart';

/// 재료 준비 미니게임 3종 (재료 타이쿤 D, 2026-11-21): rules only, no
/// screen. The screen (`ui/prep_minigames.dart`) feeds time and touches and
/// reads the bars; the result goes to `PantryState.make(success:)` once.
///
/// * 반죽 젓기 (`stir`, 반죽): circles round the bowl ([FlipCircle], the
///   special mold's '원 그려 뒤집기' angle) raise the 매끈함 bar to
///   `full_degrees` = 100%. Lifting the finger while the bar is in the green
///   zone (`green_min`~`green_max` ‰) succeeds; lifting below it just stops
///   stirring (keep going), past the green zone is '조금 묽어요' at once, and
///   time up below it is '덜 저었어요'.
/// * 불 조절 (`heat`, 팥소·초코 크림): the needle falls by itself and rises
///   while the screen is held; success when it stayed in the green zone for
///   at least `success_time_permille` of the time.
/// * 휘젓기 (`whisk`, 슈크림): rubbing left and right; each turn back after
///   at least `stroke_min_permille` of the bowl's width adds
///   `fill_per_stroke_permille` to the foam bar, which sinks by
///   `decay_permille_per_second`. Full before the time is up succeeds.
///
/// Failing loses nothing (the tubs are made without the bonus); quitting
/// makes nothing. All numbers are in config `prep_minigames`.
enum PrepPhase { playing, success, fail }

/// The `prep_minigames` section, checked once per [DevelopmentBalance]
/// (same checks as tools/development_balance.py).
class PrepGameConfig {
  final Map<String, dynamic> stir, heat, whisk;
  PrepGameConfig._(this.stir, this.heat, this.whisk);

  static final _cache = Expando<PrepGameConfig>();
  factory PrepGameConfig.of(DevelopmentBalance config) => _cache[config] ??= PrepGameConfig.parse(config.section('prep_minigames'));

  factory PrepGameConfig.parse(Map<String, dynamic> s) {
    Map<String, dynamic> game(String id) {
      final v = s[id];
      if (v is! Map<String, dynamic>) throw FormatException('재료 준비 미니게임 설정 오류: $id');
      final ms = DevelopmentBalance.integer(v, 'duration_ms');
      if (ms < 6000 || ms > 10000) throw FormatException('재료 준비 미니게임 설정 오류: $id.duration_ms(6~10초)');
      return v;
    }
    int i(Map<String, dynamic> row, String key) => DevelopmentBalance.integer(row, key);
    final stir = game('stir'), heat = game('heat'), whisk = game('whisk');
    if (i(stir, 'full_degrees') < 360 || i(stir, 'dead_zone_permille') < 0 || i(stir, 'dead_zone_permille') >= 500 ||
        !(0 < i(stir, 'green_min_permille') && i(stir, 'green_min_permille') < i(stir, 'green_max_permille') &&
            i(stir, 'green_max_permille') < 1000)) {
      throw const FormatException('재료 준비 미니게임 설정 오류: stir');
    }
    if (!(0 < i(heat, 'green_min_permille') && i(heat, 'green_min_permille') <= i(heat, 'start_permille') &&
            i(heat, 'start_permille') <= i(heat, 'green_max_permille') && i(heat, 'green_max_permille') < 1000) ||
        i(heat, 'fall_permille_per_second') < 1 || i(heat, 'rise_permille_per_second') < 1 ||
        i(heat, 'success_time_permille') < 1 || i(heat, 'success_time_permille') > 1000) {
      throw const FormatException('재료 준비 미니게임 설정 오류: heat');
    }
    if (i(whisk, 'stroke_min_permille') < 1 || i(whisk, 'stroke_min_permille') >= 1000 ||
        i(whisk, 'fill_per_stroke_permille') < 1 || i(whisk, 'decay_permille_per_second') < 0) {
      throw const FormatException('재료 준비 미니게임 설정 오류: whisk');
    }
    return PrepGameConfig._(stir, heat, whisk);
  }

  /// A new game of [minigame] (`PreparedKind.minigame`); [width] is the
  /// bowl's width on screen (the stir dead zone, the whisk stroke).
  PrepGame create(String minigame, double width) => switch (minigame) {
        'stir' => StirGame(this, width),
        'heat' => HeatGame(this),
        'whisk' => WhiskGame(this, width),
        _ => throw FormatException('모르는 미니게임: $minigame'),
      };
}

/// One running mini-game. [advance] moves its clock; when the phase leaves
/// [PrepPhase.playing] it stays there.
abstract class PrepGame {
  final int durationMs;
  int elapsedMs = 0;
  PrepPhase phase = PrepPhase.playing;
  /// Why it failed (shown on the result), null while playing or on success.
  String? failText;
  PrepGame(this.durationMs);

  String get id;
  bool get playing => phase == PrepPhase.playing;
  /// 1 → 0 as the time runs out.
  double get timeLeft => 1 - (elapsedMs / durationMs).clamp(0, 1);
  /// The main bar, 0..1.
  double get bar;
  /// The green zone of [bar] (null: the whole bar is the goal, 휘젓기).
  (double, double)? get green;
  bool get inGreen {
    final g = green;
    return g != null && bar >= g.$1 && bar <= g.$2;
  }

  /// The one line under the game.
  String get caption;

  void advance(int ms) {
    if (!playing || ms <= 0) return;
    final step = ms > durationMs - elapsedMs ? durationMs - elapsedMs : ms;
    elapsedMs += step;
    tick(step);
    if (playing && elapsedMs >= durationMs) timeUp();
  }

  void tick(int ms);
  void timeUp();
  void succeed() => phase = PrepPhase.success;
  void fail(String why) {
    phase = PrepPhase.fail;
    failText = why;
  }
}

/// 반죽 젓기.
class StirGame extends PrepGame {
  final FlipCircle circle;
  final double _min, _max;
  StirGame(PrepGameConfig c, double width)
      : circle = FlipCircle(
            deadRadius: width * DevelopmentBalance.integer(c.stir, 'dead_zone_permille') / 1000,
            targetDegrees: DevelopmentBalance.integer(c.stir, 'full_degrees')),
        _min = DevelopmentBalance.integer(c.stir, 'green_min_permille') / 1000,
        _max = DevelopmentBalance.integer(c.stir, 'green_max_permille') / 1000,
        super(DevelopmentBalance.integer(c.stir, 'duration_ms'));

  static const overText = '조금 묽어요', underText = '덜 저었어요';
  @override
  String get id => 'stir';
  @override
  double get bar => circle.progress;
  @override
  (double, double) get green => (_min, _max);
  @override
  String get caption => inGreen ? '지금 손을 떼요!' : '그릇 위에 원을 그려 저어요. 초록 칸에서 손을 떼요';

  /// The finger at ([dx], [dy]) from the bowl's centre.
  void move(double dx, double dy) {
    if (!playing) return;
    circle.moveTo(dx, dy);
    if (bar > _max) fail(overText);
  }

  /// The finger lifted: in the green zone it is done, below it the next
  /// stroke goes on from here.
  void release() {
    if (!playing) return;
    circle.lift();
    if (inGreen) succeed();
  }

  @override
  void tick(int ms) {}
  @override
  void timeUp() => inGreen ? succeed() : fail(bar > _max ? overText : underText);
}

/// 불 조절.
class HeatGame extends PrepGame {
  final double _min, _max, _fall, _rise, _need;
  double level;
  bool holding = false;
  int greenMs = 0;
  HeatGame(PrepGameConfig c)
      : _min = DevelopmentBalance.integer(c.heat, 'green_min_permille') / 1000,
        _max = DevelopmentBalance.integer(c.heat, 'green_max_permille') / 1000,
        _fall = DevelopmentBalance.integer(c.heat, 'fall_permille_per_second') / 1000,
        _rise = DevelopmentBalance.integer(c.heat, 'rise_permille_per_second') / 1000,
        _need = DevelopmentBalance.integer(c.heat, 'success_time_permille') / 1000,
        level = DevelopmentBalance.integer(c.heat, 'start_permille') / 1000,
        super(DevelopmentBalance.integer(c.heat, 'duration_ms'));

  static const failWords = '불이 고르지 않았어요';
  @override
  String get id => 'heat';
  @override
  double get bar => level;
  @override
  (double, double) get green => (_min, _max);
  /// Share of the whole time spent in the green zone so far, 0..1.
  double get greenShare => greenMs / durationMs;
  /// The share needed to succeed.
  double get needShare => _need;
  @override
  String get caption => '누르고 있으면 불이 세져요. 바늘을 초록 칸에 두세요';

  void hold(bool on) {
    if (playing) holding = on;
  }

  @override
  void tick(int ms) {
    // In small steps, so a long frame does not jump over the green zone.
    var left = ms;
    while (left > 0) {
      final step = left > 16 ? 16 : left;
      left -= step;
      level = (level + (holding ? _rise : -_fall) * step / 1000).clamp(0.0, 1.0);
      if (inGreen) greenMs += step;
    }
  }

  @override
  void timeUp() => greenMs >= (_need * durationMs).ceil() ? succeed() : fail(failWords);
}

/// 휘젓기.
class WhiskGame extends PrepGame {
  final double _stroke, _fill, _decay;
  double foam = 0;
  int strokes = 0;
  double? _lastX, _turnX;
  int _direction = 0;
  WhiskGame(PrepGameConfig c, double width)
      : _stroke = width * DevelopmentBalance.integer(c.whisk, 'stroke_min_permille') / 1000,
        _fill = DevelopmentBalance.integer(c.whisk, 'fill_per_stroke_permille') / 1000,
        _decay = DevelopmentBalance.integer(c.whisk, 'decay_permille_per_second') / 1000,
        super(DevelopmentBalance.integer(c.whisk, 'duration_ms'));

  static const failWords = '거품이 덜 올랐어요';
  @override
  String get id => 'whisk';
  @override
  double get bar => foam;
  @override
  (double, double)? get green => null;
  @override
  String get caption => '좌우로 빠르게 문질러 거품을 올려요';

  /// The finger at [x] (any origin, the same units as the bowl's width).
  void move(double x) {
    if (!playing) return;
    final last = _lastX;
    _lastX = x;
    if (last == null) {
      _turnX = x;
      return;
    }
    final d = x - last;
    if (d == 0) return;
    final dir = d > 0 ? 1 : -1;
    if (_direction != 0 && dir != _direction) {
      // Turned back: one stroke if it went far enough.
      if ((last - _turnX!).abs() >= _stroke) {
        strokes++;
        foam = (foam + _fill).clamp(0.0, 1.0);
        if (foam >= 1) succeed();
      }
      _turnX = last;
    }
    _direction = dir;
  }

  void release() {
    _lastX = null;
    _turnX = null;
    _direction = 0;
  }

  @override
  void tick(int ms) => foam = (foam - _decay * ms / 1000).clamp(0.0, 1.0);
  @override
  void timeUp() => fail(failWords);
}
