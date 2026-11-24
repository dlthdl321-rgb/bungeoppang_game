import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_support.dart';
import 'package:todays_bungeoppang/feedback_config.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'fake_time.dart' show FakeTime;
import 'old_save_helpers.dart' show asVersion, progressed, plainJson;

const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];

void main() {
  group('저장 v8: 소리 설정', () {
    final now = DateTime.utc(2026, 10, 5, 3);
    test('v1~v7 저장은 기본 소리 설정으로 v8이 되고 진행도를 잃지 않는다', () {
      final original = progressed();
      for (var version = 2; version <= 7; version++) {
        final json = version == 7
            ? (plainJson(original)..['formatVersion'] = 7)
            : asVersion(original, version);
        final settings = json['settings'] as Map
          ..remove('soundEffects')
          ..remove('music')
          ..remove('sfxVolume')
          ..remove('musicVolume');
        expect(settings, isNotEmpty);
        final restored = GameState.fromJson(json);
        expect(restored.buns, original.buns, reason: 'v$version');
        expect(restored.level, original.level, reason: 'v$version');
        expect(restored.support.coins, BigInt.from(42), reason: 'v$version');
        expect(restored.ownedSkins, original.ownedSkins, reason: 'v$version');
        if (version >= 4) {
          expect(restored.support.boostUses, original.support.boostUses);
        }
        if (version >= 6) {
          expect(restored.wardrobe.toJson(), original.wardrobe.toJson());
        }
        final s = restored.settings;
        expect([
          s.soundEffects,
          s.music,
          s.sfxVolume,
          s.musicVolume
        ], [
          true,
          true,
          defaultSfxVolume,
          defaultMusicVolume
        ], reason: 'v$version');
        expect(plainJson(GameState.fromJson(plainJson(restored))),
            plainJson(restored));
      }
    });

    test('26번 3차 H7: 배경음은 처음부터 켜져 있고, 표시 없는 예전 저장의 꺼진 배경음은 한 번 켠다', () {
      expect(GameState.initial(now).settings.music, isTrue, reason: '새 설치');
      final off = GameState.initial(now)..settings.music = false;
      final json = plainJson(off);
      final settings = json['settings'] as Map;
      expect(settings[GameSettings.musicDefaultKey], isTrue);
      // The player's own 'off' after this change is kept.
      expect(GameState.fromJson(json).settings.music, isFalse);
      // A save from before the change (no key): 배경음 on once, then kept.
      settings.remove(GameSettings.musicDefaultKey);
      final migrated = GameState.fromJson(json);
      expect(migrated.settings.music, isTrue);
      expect(migrated.settings.musicVolume, off.settings.musicVolume);
      migrated.settings.music = false;
      expect(GameState.fromJson(plainJson(migrated)).settings.music, isFalse);
    });

    test('v8 소리 설정 왕복과 손상값 거부', () {
      final s = GameState.initial(now)
        ..settings.soundEffects = false
        ..settings.musicVolume = 0
        ..settings.sfxVolume = 100;
      final restored = GameState.fromJson(plainJson(s));
      expect(restored.settings.toJson(), s.settings.toJson());
      for (final bad in <String, Object>{
        'sfxVolume': 101,
        'musicVolume': -1,
        'music': 'yes',
      }.entries) {
        final json = plainJson(s);
        (json['settings'] as Map)[bad.key] = bad.value;
        expect(() => GameState.fromJson(json), throwsFormatException,
            reason: bad.key);
      }
    });

    test('설정 변경은 호출당 한 번만 저장한다', () async {
      final repo = CountingRepository();
      final c = GameController(repo, FakeTime()..now = now);
      await c.initialize();
      final saves = repo.saves;
      await c.updateSettings(music: false, musicVolume: 150);
      expect(repo.saves, saves + 1);
      expect((await repo.load())!.settings.music, isFalse);
      expect(c.state.settings.musicVolume, 100);
      c.dispose();
    });
  });

  group('소리 정책', () {
    test('효과음 끄기·볼륨 0·탭 소리 간격', () {
      final audio = FakeAudio()..configure(GameSettings());
      audio
        ..play(Sfx.tap)
        ..play(Sfx.tap);
      expect(audio.sounds, [Sfx.tap]); // Second tap inside the interval.
      audio.play(Sfx.reward);
      expect(audio.sounds, [Sfx.tap, Sfx.reward]);
      audio.configure(GameSettings(soundEffects: false));
      audio.play(Sfx.reward);
      audio.configure(GameSettings(sfxVolume: 0));
      audio.play(Sfx.reward);
      expect(audio.sounds.length, 2);
    });
    test('배경 음악은 설정과 앱 전경 여부를 따른다', () {
      final audio = FakeAudio()..configure(GameSettings());
      expect(audio.musicPlaying, isTrue);
      audio.pauseMusic();
      expect(audio.musicPlaying, isFalse);
      audio.resumeMusic();
      expect(audio.musicPlaying, isTrue);
      audio.configure(GameSettings(music: false));
      expect(audio.musicPlaying, isFalse);
      audio.configure(GameSettings(musicVolume: 0));
      expect(audio.musicPlaying, isFalse);
    });
  });






  test('합성 효과음 자산: WAV 44.1kHz 모노 16비트, 길이 범위', () {
    // 26번 4-6단계: one 44.1 kHz family; the music is the OGG song.
    final limits = {
      'tap': (0.05, 0.2),
      'purchase': (0.3, 1.0),
      'reward': (0.5, 1.2),
      'levelup': (1.0, 1.5),
      'sizzle_loop': (15.0, 25.0),
    };
    for (final e in limits.entries) {
      final bytes = File('assets/audio/${e.key}.wav').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint16(34, Endian.little), 16);
      final seconds = data.getUint32(40, Endian.little) / 2 / 44100;
      expect(seconds, inInclusiveRange(e.value.$1, e.value.$2), reason: e.key);
    }
  });
}
