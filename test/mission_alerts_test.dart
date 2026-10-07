import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_alerts.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/music_config.dart';
import 'level_missions_widget_test.dart' show tapVisible;
import 'widget_test.dart' show mountGame;

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
    for (final mood in musicMoods) {
      expect(musicAsset(mood), 'audio/bgm_$mood.wav');
    }
  });

  testWidgets('미션을 달성하면 알림이 뜨고 메뉴에 받을 보상 수가 붙는다',
      (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    // Goals already claimable at start are counted but not announced.
    final before = claimableCount(c.state);
    expect(find.byKey(const Key('mission-notice')), findsNothing);
    c.state.support.daily.taps = BigInt.from(50);
    c.tick();
    await tester.pump();
    expect(find.byKey(const Key('mission-notice')), findsOneWidget);
    expect(find.textContaining('일일 미션'), findsWidgets);
    expect(claimableCount(c.state), before + 1);
    expect(find.byKey(const Key('menu-badge')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mission-notice')), findsNothing);
    await tapVisible(tester, const Key('menu-menu'));
    expect(find.byKey(const Key('badge-daily')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
