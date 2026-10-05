// Achievements: each is claimed once, for coins and/or a title. Targets and
// rewards are this game's own tuning.
enum AchievementMetric {
  lifetime,
  bestAutoRate,
  level,
  lifetimeTaps,
  bestCombo,
  itemUses,
  cosmeticsOwned,
  allCosmetics, // Target is the number of non-default cosmetics.
  playDays,
  weeklyCompletions,
  dailyAllClears,
  newRecordDays,
}

class AchievementDefinition {
  final String id, title, target, coins;
  final AchievementMetric metric;
  final String? titleReward;
  const AchievementDefinition(this.id, this.title, this.metric, this.target,
      {this.coins = '0', this.titleReward});
}

const achievementDefinitions = [
  AchievementDefinition('bake-1', '첫 붕어빵', AchievementMetric.lifetime, '1',
      coins: '1'),
  AchievementDefinition(
      'bake-100', '붕어빵 100개', AchievementMetric.lifetime, '100',
      coins: '1'),
  AchievementDefinition(
      'bake-1e4', '붕어빵 1만 개', AchievementMetric.lifetime, '10000',
      coins: '2'),
  AchievementDefinition(
      'bake-1e8', '붕어빵 1억 개', AchievementMetric.lifetime, '100000000',
      coins: '3'),
  AchievementDefinition(
      'bake-1e12', '붕어빵 1조 개', AchievementMetric.lifetime, '1000000000000',
      titleReward: '조 단위 제빵사'),
  AchievementDefinition(
      'bake-1e16', '붕어빵 1경 개', AchievementMetric.lifetime, '10000000000000000',
      coins: '5'),
  AchievementDefinition(
      'auto-100', '초당 100개', AchievementMetric.bestAutoRate, '100',
      coins: '2'),
  AchievementDefinition(
      'auto-1e8', '초당 1억 개', AchievementMetric.bestAutoRate, '100000000',
      coins: '3'),
  AchievementDefinition('level-5', 'Lv.5 도달', AchievementMetric.level, '5',
      coins: '3'),
  AchievementDefinition('level-10', 'Lv.10 완주', AchievementMetric.level, '10',
      titleReward: '골목 명장'),
  AchievementDefinition(
      'taps-1000', '1,000번 굽기', AchievementMetric.lifetimeTaps, '1000',
      coins: '2'),
  AchievementDefinition('combo-50', '50 콤보', AchievementMetric.bestCombo, '50',
      titleReward: '번개손'),
  AchievementDefinition(
      'items-10', '아이템 10회 사용', AchievementMetric.itemUses, '10',
      coins: '2'),
  AchievementDefinition(
      'cosmetics-5', '꾸미기 5개 수집', AchievementMetric.cosmeticsOwned, '5',
      coins: '3'),
  AchievementDefinition(
      'cosmetics-all', '꾸미기 전부 수집', AchievementMetric.allCosmetics, '0',
      titleReward: '수집가'),
  AchievementDefinition('days-7', '7일 노점 운영', AchievementMetric.playDays, '7',
      coins: '3'),
  AchievementDefinition(
      'days-30', '30일 노점 운영', AchievementMetric.playDays, '30',
      titleReward: '단골'),
  AchievementDefinition(
      'weekly-1', '주간 도전 첫 완주', AchievementMetric.weeklyCompletions, '1',
      coins: '3'),
  AchievementDefinition(
      'daily-all-10', '일일 미션 전체 완료 10회', AchievementMetric.dailyAllClears, '10',
      coins: '3'),
  AchievementDefinition(
      'record-1', '첫 하루 생산 신기록', AchievementMetric.newRecordDays, '1',
      coins: '3'),
];

// Direct taps no more than this far apart continue a combo. Hold-to-bake
// repeats are excluded. Combos have no production effect.
const comboWindowMilliseconds = 1000;
const comboDisplayMinimum = 5;

// Pre-v7 "final exchange" receipt; migrated to [legacyFinisherAchievement].
const legacyFinalExchangeId = 'final:prototype-v1';
const legacyFinisherAchievement = 'level-10';
