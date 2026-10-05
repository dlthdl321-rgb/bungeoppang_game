import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/home_presentation.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'controller_test.dart' show FakeTime;

void main() {
  test('모의 이벤트 시간은 시작 전, 종료 시각과 이후를 구분한다', () {
    final clock = FakeTime();
    final event = HomeEventDefinition(
        startsAtUtc: clock.now,
        endsAtUtc: clock.now.add(const Duration(days: 1)),
        title: '예시',
        rewardNotice: '실제 지급 없음',
        exampleCapacity: 10000);
    expect(event.countdown(clock), '종료까지 1일 00:00:00');
    clock.advance(1000);
    expect(event.countdown(clock), '종료까지 0일 23:59:59');
    clock.advance(86400000 - 1000);
    expect(event.countdown(clock), '이벤트 종료');
    clock.advance(1);
    expect(event.countdown(clock), '이벤트 종료');
    clock.now = event.startsAtUtc.subtract(const Duration(seconds: 1));
    expect(event.countdown(clock), '이벤트 시작 전');
  });

  test('복합 목표 진행률은 부족한 조건을 기준으로 표시한다', () {
    final s = GameState.initial(DateTime.utc(2026))..level = 9;
    s.missions = MissionState.forLevel(9, DateTime.utc(2026));
    s.upgradeCounts['auto_13'] = 8;
    s.missions.seenInvitePlayers.addAll({'a', 'b', 'c'});
    s.missions.qualifiedInvitePlayers.addAll({'a', 'b', 'c'});
    expect(levelProgressPermille(s), 400);
    s.upgradeCounts['auto_13'] = 20;
    expect(levelProgressPermille(s), 1000);
    s.missions.qualifiedInvitePlayers.remove('c');
    expect(levelProgressPermille(s), 666);
    s.level = 10;
    s.missions = s.missions.advance(10, DateTime.utc(2026));
    expect(levelProgressPermille(s), 1000);
  });
}
