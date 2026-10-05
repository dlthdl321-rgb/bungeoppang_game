import 'models.dart';
import 'missions.dart';
import 'event_config.dart';

/// The one countdown format for every event surface. Remaining time is
/// rounded up to whole seconds, so "0s" is only shown once the event ended.
String countdownLabel(DateTime start, DateTime end, DateTime now) {
  if (now.isBefore(start)) return '이벤트 시작 전';
  final remaining = end.difference(now);
  if (remaining <= Duration.zero) return '이벤트 종료';
  final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
  final days = seconds ~/ 86400;
  final hours = (seconds ~/ 3600 % 24).toString().padLeft(2, '0');
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final secs = (seconds % 60).toString().padLeft(2, '0');
  return '종료까지 $days일 $hours:$minutes:$secs';
}

String eventCountdownLabel(EventDefinition d, DateTime now) =>
    countdownLabel(d.start, d.end, now);

/// All progress arithmetic is integral. Only the bounded paint ratio is double.
int levelProgressPermille(GameState state) {
  final next = activeLevelMission(state);
  if (next == null) return 1000;
  return missionProgress(state, next)
      .fold(1000, (lowest, p) => p.permille < lowest ? p.permille : lowest);
}
