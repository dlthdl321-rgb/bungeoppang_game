import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;

class PolicyAudio extends SoundPolicy {
  final moods = <String>[];
  final playing = <bool>[];
  final cooking = <bool>[];
  @override
  Future<void> init() async {}
  @override
  void output(Sfx sfx, double volume) {}
  @override
  void moodOutput(String mood) => moods.add(mood);
  @override
  void musicOutput({required bool playing, required double volume}) =>
      this.playing.add(playing);
  @override
  void cookingOutput({required bool playing, required double volume}) => cooking.add(playing);
  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> encoded(GameState state) =>
    jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;

void main() {
  test('v12 자산과 기존 배경 연동은 보존하고 v13으로 저장한다', () {
    final state = GameState.initial(DateTime.utc(2026, 10, 16));
    state.buns = BigInt.from(1234);
    state.lifetime = BigInt.from(5678);
    final old = encoded(state)..['formatVersion'] = 12;
    (old['settings'] as Map)
      ..remove('musicSelection')
      ..remove('cookingSound')
      ..remove('cookingVolume');
    final restored = GameState.fromJson(old);
    expect(restored.buns, state.buns);
    expect(restored.lifetime, state.lifetime);
    expect(restored.settings.musicSelection, 'auto');
    expect(restored.toJson()['formatVersion'], 13);
  });

  test('v13 명시 선택은 왕복 보존하고 누락/잘못된 값은 거부한다', () {
    final state = GameState.initial(DateTime.utc(2026, 10, 16));
    state.settings.musicSelection = 'rain';
    expect(GameState.fromJson(encoded(state)).settings.musicSelection, 'rain');
    for (final value in <Object?>[null, 'invalid', 1]) {
      final raw = encoded(state);
      (raw['settings'] as Map)['musicSelection'] = value;
      expect(() => GameState.fromJson(raw), throwsFormatException);
    }
  });

  test('v13 굽기 설정의 손상 타입과 범위는 조용히 초기화하지 않는다', () {
    final state = GameState.initial(DateTime.utc(2026, 10, 16));
    for (final value in <String, Object>{
      'cookingSound': 'yes', 'cookingVolume': 101,
    }.entries) {
      final raw = encoded(state);
      (raw['settings'] as Map)[value.key] = value.value;
      expect(() => GameState.fromJson(raw), throwsFormatException);
    }
  });

  test('명시 음악은 배경 변경과 pause/resume 후에도 유지된다', () {
    final audio = PolicyAudio();
    audio.setScene('night');
    audio.configure(GameSettings(musicSelection: 'rain'));
    audio.setScene('cherry');
    expect(audio.mood, 'rain');
    audio.pauseMusic();
    expect(audio.playing.last, isFalse);
    audio.resumeMusic();
    expect(audio.playing.last, isTrue);
    expect(audio.mood, 'rain');
    audio.configure(GameSettings(musicSelection: 'auto'));
    expect(audio.mood, 'spring');
  });

  test('굽기 루프는 실제 소스·전경·독립 설정에 따르며 소스가 없으면 멈춘다', () {
    final audio = PolicyAudio()..configure(GameSettings(cookingSound: true));
    expect(audio.cooking.last, isFalse);
    audio.setCookingSources({'manual', 'slot-1'});
    expect(audio.cooking.last, isTrue);
    audio.setCookingSources({'slot-1'});
    expect(audio.cooking.last, isTrue);
    audio.pauseMusic();
    expect(audio.cooking.last, isFalse);
    audio.resumeMusic();
    expect(audio.cooking.last, isTrue);
    audio.setCookingSources({});
    expect(audio.cooking.last, isFalse);
    audio.configure(GameSettings(cookingSound: false));
    audio.setCookingSources({'slot-1'});
    expect(audio.cooking.last, isFalse);
  });

  test('겹친 설정 저장은 직렬 처리하고 앞선 실패 뒤에도 다음 선택을 저장한다', () async {
    final repository = MemoryGameRepository();
    final controller = GameController(repository, FakeTime());
    await controller.initialize();
    addTearDown(controller.dispose);
    repository.failNextSave = true;
    await Future.wait([
      controller.updateSettings(musicSelection: 'rain'),
      controller.updateSettings(musicSelection: 'snow'),
    ]);
    expect(controller.state.settings.musicSelection, 'snow');
    expect((await repository.load())!.settings.musicSelection, 'snow');
  });

  test('음악 선택 저장 실패는 선택과 음량을 함께 복원한다', () async {
    final repository = MemoryGameRepository();
    final controller = GameController(repository, FakeTime());
    await controller.initialize();
    addTearDown(controller.dispose);
    final originalVolume = controller.state.settings.musicVolume;
    repository.failNextSave = true;
    await controller.updateSettings(musicSelection: 'rain', musicVolume: 90);
    expect(controller.state.settings.musicSelection, 'auto');
    expect(controller.state.settings.musicVolume, originalVolume);
    expect(controller.error, isNotNull);
    await controller.updateSettings(musicSelection: 'rain');
    expect((await repository.load())!.settings.musicSelection, 'rain');
  });
}
