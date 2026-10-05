import 'config_values.dart';
import 'support_config.dart';

// Weekly challenge: Monday 00:00 KST for seven days, then the next week
// starts by itself. Goals and rewards are this game's own tuning.
const weeklyConfigVersion = 'weekly-v1';

enum WeeklyMetric { taps, playDays, purchases, dailyAllClears }

class WeeklyGoalDefinition {
  final String id, title, target;
  final WeeklyMetric metric;
  final RewardDefinition reward;
  const WeeklyGoalDefinition(
      this.id, this.title, this.metric, this.target, this.reward);
  BigInt get targetAmount => configBigInt(target);
}

const weeklyGoals = [
  WeeklyGoalDefinition('taps', '붕어빵 1,000번 굽기', WeeklyMetric.taps, '1000',
      RewardDefinition('3')),
  WeeklyGoalDefinition('days', '3일 동안 노점 열기', WeeklyMetric.playDays, '3',
      RewardDefinition('0', {'fairy': '1'})),
  WeeklyGoalDefinition('purchases', '스킬 20개 구매', WeeklyMetric.purchases, '20',
      RewardDefinition('3')),
  WeeklyGoalDefinition('dailyAll', '일일 미션 전체 완료 3회',
      WeeklyMetric.dailyAllClears, '3', RewardDefinition('5', {'butter': '1'})),
];

class SeasonTheme {
  final String title, description;
  const SeasonTheme(this.title, this.description);
}

/// Seasonal flavour by the KST month the week starts in. Text only.
SeasonTheme seasonThemeForMonth(int month) => switch (month) {
      3 || 4 || 5 => const SeasonTheme('벚꽃 노점 주간', '꽃잎 날리는 골목에서 따끈한 한 판'),
      6 || 7 || 8 => const SeasonTheme('여름밤 노점 주간', '시원한 밤바람과 함께 굽는 붕어빵'),
      9 || 10 || 11 => const SeasonTheme('단풍 골목 주간', '낙엽 사이로 퍼지는 고소한 냄새'),
      _ => const SeasonTheme('첫눈 붕어빵 주간', '눈 오는 밤에 더 반가운 붕어빵'),
    };
