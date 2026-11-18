import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/feedback_config.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/music_config.dart';

/// 26번 4-6단계: the new song, the seamless griddle loop and one family of
/// effect sounds.

class _Wav {
  final int rate;
  final Float64List samples;
  _Wav(this.rate, this.samples);

  factory _Wav.read(String path) {
    final bytes = File(path).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(data.getUint16(34, Endian.little), 16);
    final rate = data.getUint32(24, Endian.little);
    final length = data.getUint32(40, Endian.little) ~/ 2;
    final samples = Float64List(length);
    for (var i = 0; i < length; i++) {
      samples[i] = data.getInt16(44 + i * 2, Endian.little) / 32768;
    }
    return _Wav(rate, samples);
  }

  double get seconds => samples.length / rate;
}

double _db(Iterable<double> x) {
  var sum = 0.0, n = 0;
  for (final v in x) {
    sum += v * v;
    n++;
  }
  final rms = math.sqrt(sum / math.max(1, n));
  return rms == 0 ? -240 : 20 * math.log(rms) / math.ln10;
}

/// Problems a looping [wav] has at its loop point (the checks of
/// tools/make_seamless_loop.py --check).
List<String> _seamProblems(_Wav wav) {
  final s = wav.samples, problems = <String>[];
  final jump = (s.last - s.first).abs();
  if (jump > 0.02) problems.add('끝·처음 샘플 차 $jump');
  final edge = (wav.rate * .05).round();
  final gap = (_db(s.sublist(s.length - edge)) - _db(s.sublist(0, edge))).abs();
  if (gap > 3) problems.add('앞뒤 50ms 크기 차 ${gap.toStringAsFixed(1)}dB');
  final window = (wav.rate * .01).round();
  final levels = [
    for (var i = 0; i + window <= s.length; i += window)
      _db(s.sublist(i, i + window))
  ];
  final sorted = [...levels]..sort();
  final median = sorted[sorted.length ~/ 2];
  final quiet = levels.where((l) => l < median - 10).length;
  if (quiet > 0) problems.add('중앙값보다 10dB 넘게 작은 10ms 구간 $quiet개');
  return problems;
}

void main() {
  test('배경음: 모든 분위기가 있는 OGG 곡 하나를 가리킨다', () {
    final assets = {for (final mood in musicMoods) musicAsset(mood)};
    expect(assets, {'audio/bgm_warm_stall.ogg'});
    final file = File('assets/${assets.single}');
    expect(file.existsSync(), isTrue);
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'OggS');
    // 171 s Vorbis q4 stereo is about 2.3 MB; a stray WAV/MP3 would be far off.
    expect(bytes.length, inInclusiveRange(1500000, 3200000));
    // The old synthesized mood loops are gone.
    expect(Directory('assets/audio').listSync().map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('bgm_') && n.endsWith('.wav')), isEmpty);
  });

  test('효과음 매핑: Sfx 전부에 파일이 있고 모두 한 계열(44.1kHz, 1.5초 이하, 최고 -3dBFS, 크기 차 2dB 안)', () {
    expect(AudioplayersAudio.sfxFiles.keys.toSet(), Sfx.values.toSet());
    final loudness = <String, double>{};
    for (final path in AudioplayersAudio.sfxFiles.values) {
      final wav = _Wav.read('assets/$path');
      expect(wav.rate, 44100, reason: path);
      expect(wav.seconds, lessThanOrEqualTo(1.5), reason: path);
      final peak = wav.samples.map((v) => v.abs()).reduce(math.max);
      expect(20 * math.log(peak) / math.ln10, lessThanOrEqualTo(-2.9), reason: path);
      final lead = wav.samples.indexWhere((v) => v.abs() > 1e-3);
      expect(lead / wav.rate, lessThanOrEqualTo(.01), reason: '$path 앞 무음');
      final floor = math.pow(10, -3 / 20) * math.pow(10, -40 / 20);
      loudness[path] = _db(wav.samples.where((v) => v.abs() > floor));
    }
    final spread = loudness.values.reduce(math.max) - loudness.values.reduce(math.min);
    expect(spread, lessThanOrEqualTo(2.0), reason: '$loudness');
    expect(tapSoundMinIntervalMs, 60);
  });

  test('굽는 소리: 20초 44.1kHz, 반복 이음매에 틈·뚝 끊김이 없다', () {
    expect(cookingLoopAsset, 'audio/sizzle_loop.wav');
    final wav = _Wav.read('assets/$cookingLoopAsset');
    expect(wav.rate, 44100);
    expect(wav.seconds, closeTo(20, .01));
    expect(_seamProblems(wav), isEmpty);
  });

  test('이음매 검사는 예전 4초 굽는 소리(양 끝 25ms를 0으로 줄임)를 잡아낸다', () {
    // Rebuilds the old loop's seam: a steady hiss faded to 0 over 25 ms at
    // both ends, as tools/generate_cooking_sound.py did before 4-6단계.
    const rate = 22050, n = rate * 4;
    final random = math.Random(20261016);
    final s = Float64List(n);
    for (var i = 0; i < n; i++) {
      final edge = math.min(i, n - 1 - i);
      s[i] = (random.nextDouble() * 2 - 1) * .1 * math.min(1.0, edge / (rate * .025));
    }
    expect(_seamProblems(_Wav(rate, s)), isNotEmpty);
  });
}
