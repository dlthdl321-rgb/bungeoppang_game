import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'feedback_config.dart';
import 'models.dart';
import 'music_config.dart';
import 'development_audio_defaults.dart';

enum Sfx { tap, purchase, reward, levelUp }

/// Sound port. Audio is optional: every failure is swallowed so the game
/// never stops because a device cannot play sound.
abstract class GameAudio {
  Future<void> init();
  void play(Sfx sfx);
  void configure(GameSettings settings);

  /// Plays the music of [background]'s mood ([musicMoodFor]).
  void setScene(String background);
  /// IDs of actual cooking activities. Empty stops the loop; multiple IDs
  /// still use one player. The background or legacy tap is not a cooking source.
  void setCookingSources(Set<String> sources);
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
  void setCookingSources(Set<String> sources) {}
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
  int sfxVolume = provisionalDefaultSfxVolume, musicVolume = provisionalDefaultBgmVolume;
  bool cookingOn = provisionalDefaultCookingEnabled;
  int cookingVolume = provisionalDefaultCookingVolume;
  bool _hasCookingSource = false;
  int? _lastTapMs;
  bool _configured = false;
  final Stopwatch _clock = Stopwatch()..start();

  /// The mood whose loop is (or will be) playing.
  String mood = musicMoodFor('clear');
  String _sceneMood = musicMoodFor('clear');
  String _selection = defaultMusicSelection;

  void output(Sfx sfx, double volume);
  void musicOutput({required bool playing, required double volume});

  /// Switches the music loop to [mood]'s; a no-op until a backend does it.
  void moodOutput(String mood) {}

  void cookingOutput({required bool playing, required double volume}) {}

  @override
  void setCookingSources(Set<String> sources) {
    _hasCookingSource = sources.isNotEmpty;
    _syncCooking();
  }

  void _syncCooking() => cookingOutput(
      playing: cookingOn && foreground && _hasCookingSource && cookingVolume > 0,
      volume: cookingVolume / 100);

  @override
  void setScene(String background) {
    _sceneMood = musicMoodFor(background);
    _syncMood();
  }

  void _syncMood() {
    final next = selectedMusicMood(_selection, _sceneMood);
    if (next == mood) return;
    mood = next;
    moodOutput(next);
  }

  @override
  void play(Sfx sfx) {
    if (!foreground || !sfxOn || sfxVolume == 0) return;
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
        _selection == s.musicSelection &&
        cookingOn == s.cookingSound && cookingVolume == s.cookingVolume &&
        _configured) {
      return;
    }
    _configured = true;
    sfxOn = s.soundEffects;
    sfxVolume = s.sfxVolume;
    musicOn = s.music;
    musicVolume = s.musicVolume;
    _selection = s.musicSelection;
    cookingOn = s.cookingSound;
    cookingVolume = s.cookingVolume;
    _syncMood();
    _syncMusic();
    _syncCooking();
  }

  @override
  void pauseMusic() {
    foreground = false;
    _syncMusic();
    _syncCooking();
  }

  @override
  void resumeMusic() {
    foreground = true;
    _syncMusic();
    _syncCooking();
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
  final _cooking = AudioPlayer();
  bool _cookingLoaded = false;
  int _cookingRevision = 0;
  Future<void> _cookingWork = Future<void>.value();
  bool _ready = false, _disposed = false;
  String? _loadedMood;
  int _musicRevision = 0;
  Future<void> _musicWork = Future<void>.value();
  Future<void>? _initializing;

  @override
  Future<void> init() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
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
      final initialMood = mood;
      await _music.setSource(AssetSource(musicAsset(initialMood)));
      _loadedMood = initialMood;
      if (_disposed) return;
      _ready = true;
      _syncMusic();
      _syncCooking();
    } catch (_) {
      _ready = false;
    }
  }

  @override
  void output(Sfx sfx, double volume) {
    if (!_ready || _disposed) return;
    _pools[sfx]?.start(volume: volume).catchError((_) => () async {});
  }

  @override
  void musicOutput({required bool playing, required double volume}) => _queueMusic();

  @override
  void moodOutput(String mood) => _queueMusic();

  // All source/resume/pause commands share one queue. A stale source load may
  // finish, but it cannot resume after a newer selection or app pause.
  void _queueMusic() {
    if (!_ready || _disposed) return;
    final revision = ++_musicRevision;
    _musicWork = _musicWork.catchError((_) {}).then((_) async {
      if (_disposed || revision != _musicRevision) return;
      if (_loadedMood != mood) {
        final requested = mood;
        await _music.setSource(AssetSource(musicAsset(requested)));
        _loadedMood = requested;
      }
      if (_disposed || revision != _musicRevision) return;
      await _music.setVolume(musicVolume / 100);
      if (_disposed || revision != _musicRevision) return;
      if (musicOn && foreground && musicVolume > 0) {
        await _music.resume();
      } else {
        await _music.pause();
      }
    }).catchError((_) {});
  }

  @override
  void cookingOutput({required bool playing, required double volume}) {
    if (!_ready || _disposed) return;
    final revision = ++_cookingRevision;
    _cookingWork = _cookingWork.catchError((_) {}).then((_) async {
      if (_disposed || revision != _cookingRevision) return;
      if (!playing && !_cookingLoaded) return;
      if (!_cookingLoaded) {
        await _cooking.setReleaseMode(ReleaseMode.loop);
        await _cooking.setSource(AssetSource('audio/sizzle_loop.wav'));
        _cookingLoaded = true;
      }
      if (_disposed || revision != _cookingRevision) return;
      await _cooking.setVolume(volume);
      if (_disposed || revision != _cookingRevision) return;
      if (playing) {
        await _cooking.resume();
      } else {
        await _cooking.pause();
      }
    }).catchError((_) {});
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    _musicRevision++;
    _cookingRevision++;
    await (_initializing ?? Future<void>.value());
    await _musicWork;
    await _cookingWork;
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    await _music.dispose();
    await _cooking.dispose();
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
