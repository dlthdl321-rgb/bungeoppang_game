import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_alerts.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/music_config.dart';

void main() {
  test('달성했지만 안 받은 일일 미션만 받을 보상으로 센다', () {
    final s = GameState.initial(DateTime.utc(2026, 10, 7));
    expect(claimableCount(s, 'daily'), 0);
    s.support.daily.taps = BigInt.from(50);
    expect(claimableCount(s, 'daily'), 1);
    expect(claimableGoals(s).first.label, contains('일일 미션'));
    s.support.daily.claimed.add('taps');
    expect(claimableCount(s, 'daily'), 0);
  });

  test('배경마다 분위기 음악이 정해진다', () {
    expect(musicMoodFor('clear'), 'day');
    expect(musicMoodFor('rain'), 'rain');
    expect(musicMoodFor('snowday'), musicMoodFor('snow'));
    expect(musicMoodFor('seaside'), 'night');
    expect(musicMoodFor('unknown'), 'day');
    // 26번 4-6단계: every mood plays the one song.
    for (final mood in musicMoods) {
      expect(musicAsset(mood), 'audio/bgm_warm_stall.ogg');
    }
  });

}
