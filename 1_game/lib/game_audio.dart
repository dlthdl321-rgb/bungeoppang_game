import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'feedback_config.dart';
import 'models.dart';
import 'music_config.dart';

enum Sfx { tap, purchase, reward, levelUp }

/// Sound port. Audio is optional: every failure is swallowed so the game
/// never stops because a device cannot play sound.
abstract class GameAudio {
  Future<void> init();
  void play(Sfx sfx);
  void configure(GameSettings settings);

  /// Plays the music of [background]'s mood ([musicMoodFor]).
  void setScene(String background);
  void pauseMusic();
  void resumeMusic();
  Future<void> dispose();
}

/// Tests and platforms without audio.
class SilentAudio implements GameAudio {
  const SilentAudio();
  @override
  Future<void> init() async {}
  @override
  void play(Sfx sfx) {}
  @override
  void configure(GameSettings settings) {}
  @override
  void setScene(String background) {}
  @override
  void pauseMusic() {}
  @override
  void resumeMusic() {}
  @override
  Future<void> dispose() async {}
}

/// Decides what should sound from settings and app state; [AudioplayersAudio]
/// and test fakes only implement the raw output.
abstract class SoundPolicy implements GameAudio {
  bool sfxOn = true, musicOn = true, foreground = true;
  int sfxVolume = defaultSfxVolume, musicVolume = defaultMusicVolume;
  int? _lastTapMs;
  bool _configured = false;
  final Stopwatch _clock = Stopwatch()..start();

  /// The mood whose loop is (or will be) playing.
  String mood = musicMoodFor('clear');

  void output(Sfx sfx, double volume);
  void musicOutput({required bool playing, required double volume});

  /// Switches the music loop to [mood]'s; a no-op until a backend does it.
  void moodOutput(String mood) {}

  @override
  void setScene(String background) {
    final next = musicMoodFor(background);
    if (next == mood) return;
    mood = next;
    moodOutput(next);
  }

  @override
  void play(Sfx sfx) {
    if (!sfxOn || sfxVolume == 0) return;
    if (sfx == Sfx.tap) {
      final now = _clock.elapsedMilliseconds, last = _lastTapMs;
      if (last != null && now - last < tapSoundMinIntervalMs) return;
      _lastTapMs = now;
    }
    output(sfx, sfxVolume / 100);
  }

  void _syncMusic() => musicOutput(
      playing: musicOn && foreground && musicVolume > 0,
      volume: musicVolume / 100);

  @override
  void configure(GameSettings s) {
    if (sfxOn == s.soundEffects &&
        sfxVolume == s.sfxVolume &&
        musicOn == s.music &&
        musicVolume == s.musicVolume &&
        _configured) {
      return;
    }
    _configured = true;
    sfxOn = s.soundEffects;
    sfxVolume = s.sfxVolume;
    musicOn = s.music;
    musicVolume = s.musicVolume;
    _syncMusic();
  }

  @override
  void pauseMusic() {
    foreground = false;
    _syncMusic();
  }

  @override
  void resumeMusic() {
    foreground = true;
    _syncMusic();
  }
}

class AudioplayersAudio extends SoundPolicy {
  static const _files = {
    Sfx.tap: 'audio/tap.wav',
    Sfx.purchase: 'audio/purchase.wav',
    Sfx.reward: 'audio/reward.wav',
    Sfx.levelUp: 'audio/levelup.wav',
  };
  final _pools = <Sfx, AudioPool>{};
  final _music = AudioPlayer();
  bool _musicPlaying = false, _ready = false;

  @override
  Future<void> init() async {
    try {
      // Mix with the player's own music instead of stealing audio focus.
      await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
      for (final e in _files.entries) {
        _pools[e.key] = await AudioPool.createFromAsset(
            path: e.value, maxPlayers: e.key == Sfx.tap ? 4 : 2);
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setSource(AssetSource(musicAsset(mood)));
      _ready = true;
      _syncMusic();
    } catch (_) {
      _ready = false;
    }
  }

  @override
  void output(Sfx sfx, double volume) {
    _pools[sfx]?.start(volume: volume).catchError((_) => () async {});
  }

  @override
  void musicOutput({required bool playing, required double volume}) {
    if (!_ready) return;
    _music.setVolume(volume).catchError((_) {});
    if (playing && !_musicPlaying) {
      _musicPlaying = true;
      _music.resume().catchError((_) {});
    } else if (!playing && _musicPlaying) {
      _musicPlaying = false;
      _music.pause().catchError((_) {});
    }
  }

  /// Swaps the loop; keeps playing if music was playing.
  @override
  void moodOutput(String mood) {
    if (!_ready) return;
    () async {
      await _music.setSource(AssetSource(musicAsset(mood)));
      if (_musicPlaying) await _music.resume();
    }()
        .catchError((_) {});
  }

  @override
  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    await _music.dispose();
  }
}

/// Makes the app's [GameAudio] reachable from deep widgets (tap target).
class GameAudioScope extends InheritedWidget {
  final GameAudio audio;
  const GameAudioScope({super.key, required this.audio, required super.child});
  static GameAudio of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameAudioScope>()?.audio ??
      const SilentAudio();
  @override
  bool updateShouldNotify(GameAudioScope old) => old.audio != audio;
}
