import 'dart:math' as math;
import 'avatar_rig_config.dart';

/// Plays [MotionClip]s on the vendor's face channels against one clock in
/// milliseconds. Each channel plays one clip at a time, so the eyes can
/// blink while the mouth talks; a clip with several tracks moves them
/// together. Nothing here draws: [frames] says which picture each channel
/// shows now, and a channel not listed rests (the art as drawn).
class AvatarMotion {
  AvatarMotion({this.autoBlink = true, int seed = 0})
      : _random = math.Random(seed);

  /// Blink by itself every [blinkGapMs] while no other clip holds the eyes.
  bool autoBlink;
  final math.Random _random;
  final _playing = <String, _Play>{};
  int? _nextBlinkAt;

  /// Starts [clip] at [nowMs] on each of its channels, replacing whatever
  /// those channels played; other channels go on. [loops] 0 repeats until
  /// [stop].
  void play(MotionClip clip, int nowMs, {int loops = 1}) {
    for (final channel in clip.tracks.keys) {
      _playing[channel] = _Play(clip, clip.tracks[channel]!, nowMs, loops);
    }
  }

  /// Stops [clipId] on every channel it plays; they go back to rest.
  void stop(String clipId) =>
      _playing.removeWhere((_, play) => play.clip.id == clipId);

  bool playing(String clipId) =>
      _playing.values.any((play) => play.clip.id == clipId);

  int _gap() =>
      blinkGapMs.$1 + _random.nextInt(blinkGapMs.$2 - blinkGapMs.$1 + 1);

  /// The frame each busy channel shows at [nowMs] (time only goes forward).
  Map<String, String> frames(int nowMs) {
    if (autoBlink) {
      final due = _nextBlinkAt ??= nowMs + _gap();
      if (nowMs >= due) {
        if (!_playing.containsKey(eyesChannel.id)) play(blinkClip, due);
        _nextBlinkAt = nowMs + _gap();
      }
    }
    final shown = <String, String>{};
    _playing.removeWhere((channel, play) {
      final frame = play.frameAt(nowMs);
      if (frame != null) shown[channel] = frame;
      return frame == null;
    });
    return shown;
  }
}

class _Play {
  final MotionClip clip;
  final List<(String, int)> keys;
  final int start, loops;
  final int length;
  _Play(this.clip, this.keys, this.start, this.loops)
      : length = keys.fold(0, (sum, k) => sum + k.$2);

  /// The key's frame at [now], or null once the clip has finished.
  String? frameAt(int now) {
    final t = now - start;
    if (length <= 0 || t < 0 || (loops > 0 && t >= length * loops)) {
      return null;
    }
    var at = t % length;
    for (final (frame, ms) in keys) {
      if (at < ms) return frame;
      at -= ms;
    }
    return null;
  }
}
