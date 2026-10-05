import 'models.dart';
import 'time_service.dart';
import 'missions.dart';
import 'event_config.dart';

/// Presentation-only event fixture, NOT a verified live event or reward rule.
/// Fixed dates prevent reopening the app from restarting a countdown.
class HomeEventDefinition {
  final DateTime startsAtUtc, endsAtUtc;
  final String title, rewardNotice;
  final int exampleCapacity;
  const HomeEventDefinition({
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.title,
    required this.rewardNotice,
    required this.exampleCapacity,
  });

  String countdown(TimeService clock) {
    return countdownAt(clock.utcNow);
  }

  String countdownAt(DateTime now) {
    if (now.isBefore(startsAtUtc)) return '이벤트 시작 전';
    final remaining = endsAtUtc.difference(now);
    if (remaining <= Duration.zero) return '이벤트 종료';
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    final days = seconds ~/ 86400;
    final hours = (seconds ~/ 3600 % 24).toString().padLeft(2, '0');
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '종료까지 $days일 $hours:$minutes:$secs';
  }
}

final homeEvent = HomeEventDefinition(
  startsAtUtc: eventDefinitions.first.start,
  endsAtUtc: eventDefinitions.first.end,
  title: eventDefinitions.first.title,
  rewardNotice: '최종 보상 안내 · 실제 지급 없음',
  exampleCapacity: int.parse(eventDefinitions.first.rewards.last.capacity),
);

/// All progress arithmetic is integral. Only the bounded paint ratio is double.
int levelProgressPermille(GameState state) {
  final next = activeLevelMission(state);
  if (next == null) return 1000;
  return missionProgress(state, next)
      .fold(1000, (lowest, p) => p.permille < lowest ? p.permille : lowest);
}
