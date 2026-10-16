import 'achievement_config.dart';
import 'missions.dart';
import 'models.dart';
import 'progress_rules.dart';
import 'support_config.dart';
import 'support_rules.dart';
import 'weekly_config.dart';

/// A goal that is reached but not claimed yet: what the home menu badge
/// counts and what the "미션 달성" notice announces.
class ClaimableGoal {
  /// Stable id for spotting newly reached goals, e.g. `daily:2026-10-07:taps`.
  final String id;

  /// The menu destination that claims it: daily, event, missions or
  /// achievements.
  final String destination;

  /// What the notice shows, e.g. '일일 미션 · 붕어빵 탭'.
  final String label;
  const ClaimableGoal(this.id, this.destination, this.label);
}

/// Destinations that have claimable goals, in menu order.
const claimDestinations = ['daily', 'event', 'missions', 'achievements'];

/// Every goal [s] can claim right now.
List<ClaimableGoal> claimableGoals(GameState s) {
  final daily = s.support.daily, weekly = s.weekly;
  final level = activeLevelMission(s);
  return [
    for (final d in dailyDefinitions)
      if (!daily.claimed.contains(d.id) && dailyComplete(s, d))
        ClaimableGoal(
            'daily:${daily.day}:${d.id}', 'daily', '일일 미션 · ${d.title}'),
    if (!daily.allClaimed && dailyAllComplete(s))
      ClaimableGoal('daily:${daily.day}:all', 'daily', '일일 미션 · 전체 완료'),
    for (final g in weeklyGoals)
      if (!weekly.claimed.contains(g.id) && weeklyGoalComplete(s, g))
        ClaimableGoal(
            'weekly:${weekly.week}:${g.id}', 'event', '주간 도전 · ${g.title}'),
    if (level != null && canClaimLevel(s))
      ClaimableGoal(
          'level:${level.level}', 'missions', '레벨 미션 · Lv.${level.level} 달성'),
    for (final d in achievementDefinitions)
      if (!s.achievements.claimed.contains(d.id) && achievementMet(s, d))
        ClaimableGoal('achievement:${d.id}', 'achievements', '업적 · ${d.title}'),
  ];
}

/// How many goals [destination] can claim; all of them for null.
int claimableCount(GameState s, [String? destination]) => claimableGoals(s)
    .where((g) => destination == null || g.destination == destination)
    .length;
