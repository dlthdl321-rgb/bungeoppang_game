// All values in this file are ESTIMATED prototype rules, not verified effects.
const supportEvidence = 'estimated';
const dailyUtcOffsetMinutes = 540; // Fixed Korea midnight, not device timezone.
const supportConfigVersion = 'support-v1';
const effectScale = 1000;
// Includes milliseconds, permille effects and the existing 50% offline rate.
const productionQuantum = 2000000;

enum EffectChannel { tap, automatic }

enum DailyMetric { taps, production, purchases, autoRate }

class RewardDefinition {
  final String coins;
  final Map<String, String> items;
  const RewardDefinition(this.coins, [this.items = const {}]);
}

class DailyDefinition {
  final String id, title, target;
  final DailyMetric metric;
  final RewardDefinition reward;
  const DailyDefinition(
      this.id, this.title, this.metric, this.target, this.reward);
}

const dailyDefinitions = [
  DailyDefinition(
      'taps', '붕어빵 탭', DailyMetric.taps, '50', RewardDefinition('2')),
  DailyDefinition('production', '오늘 붕어빵 생산', DailyMetric.production, '1000',
      RewardDefinition('3')),
  DailyDefinition('purchases', '스킬 구매 수량', DailyMetric.purchases, '3',
      RewardDefinition('2')),
  DailyDefinition(
      'auto', '기본 초당 생산', DailyMetric.autoRate, '10', RewardDefinition('3')),
];
const dailyAllReward = RewardDefinition('5', {'fairy': '1', 'butter': '1'});
// Active production only; purchased quantity (not button presses); base skill
// rate peak (temporary boosts cannot satisfy this goal). Explicit estimates.
const dailyOfflineCounts = false;
const itemRepeatPolicy = 'rejectWhileActive';

class ItemDefinition {
  final String id, name, multiplierPermille, coinPrice, starterQuantity;
  final EffectChannel channel;
  final int durationSeconds;
  const ItemDefinition(
      this.id,
      this.name,
      this.channel,
      this.multiplierPermille,
      this.durationSeconds,
      this.coinPrice,
      this.starterQuantity);
}

const itemDefinitions = [
  ItemDefinition('fairy', '요정', EffectChannel.automatic, '2000', 300, '3', '1'),
  ItemDefinition('butter', '황금버터', EffectChannel.tap, '2000', 60, '2', '1'),
];
