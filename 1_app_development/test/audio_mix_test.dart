import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_audio.dart';

/// 4차 피드백: 폰에서 굽기를 시작하면 배경음악이 멈추고 지글 소리만 났다.
/// 원인: 배경음악·지글 플레이어가 전역 설정(mixWithOthers)보다 먼저 만들어져
/// Android 기본값(AUDIOFOCUS_GAIN)을 가진 채 서로 오디오 포커스를 빼앗음.
/// 이제 모든 플레이어(배경음악·지글·효과음 풀)가 포커스를 요청하지 않는 같은
/// 섞기 설정을 받는지 플랫폼 채널 수준에서 확인한다(실제 소리는 폰에서 확인).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('섞기 설정: Android 포커스 요청 없음(none), 미디어 용도', () {
    final android = mixedAudioContext().android;
    expect(android.audioFocus, AndroidAudioFocus.none);
    expect(android.usageType, AndroidUsageType.media);
  });

  test('배경음악·지글·효과음 플레이어 모두 섞기 설정을 받는다', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final created = <String>{};
    final contexts = <String, Map<Object?, Object?>>{};
    Map<Object?, Object?>? global;
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final id = args['playerId'] as String?;
      if (call.method == 'create' && id != null) created.add(id);
      if (call.method == 'setAudioContext' && id != null) contexts[id] = args;
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async {
      if (call.method == 'setAudioContext') global = call.arguments as Map<Object?, Object?>;
      return null;
    });
    // Asset files are copied by AudioCache through path_provider: give it a
    // temp folder so the effect pools can be made.
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => '.dart_tool/audio_mix_test');
    addTearDown(() {
      messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    });

    final audio = AudioplayersAudio();
    // The effect pools then wait for the platform's 'prepared' event, which
    // this fake never sends: look once the players are made and set up.
    unawaited(audio.init());
    for (var i = 0; i < 100 && created.length < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(global, isNotNull);
    expect(global!['audioFocus'], AndroidAudioFocus.none.value);
    // The music and the sizzle players (made before the global setting)
    // and every effect pool player got the mixed context themselves.
    // Music + sizzle + the first effect pool's player.
    expect(created.length, greaterThanOrEqualTo(3));
    for (final id in created) {
      expect(contexts[id], isNotNull, reason: '플레이어 $id 에 섞기 설정이 없음');
      expect(contexts[id]!['audioFocus'], AndroidAudioFocus.none.value, reason: id);
    }
  });
}
