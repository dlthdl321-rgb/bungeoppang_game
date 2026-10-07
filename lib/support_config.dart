// All values in this file are ESTIMATED prototype rules, not verified effects.
const supportEvidence = 'estimated';
const dailyUtcOffsetMinutes = 540; // Fixed Korea midnight, not device timezone.
const supportConfigVersion = 'support-v2';

/// Saves before stage 14 (items instead of boosts); still loadable.
const legacySupportConfigVersion = 'support-v1';
const effectScale = 1000;
// Includes milliseconds, permille effects and the existing 50% offline rate.
const productionQuantum = 2000000;

enum DailyMetric { taps, production, purchases, autoRate }

/// Coins paid out by a daily goal or an invitation (items were removed in
/// stage 14; their rewards became coins).
class RewardDefinition {
  final String coins;
  const RewardDefinition(this.coins);
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
const dailyAllReward = RewardDefinition('10');
// Active production only; purchased quantity (not button presses); base skill
// rate peak (temporary boosts cannot satisfy this goal). Explicit estimates.
const dailyOfflineCounts = false;

/// Timed production boosts (stage 14). Each one multiplies both tap and
/// automatic production; when several run at once only the strongest counts.
enum BoostKind {
  /// The invited player reached Lv.1: the inviter visits as a guest.
  invite,

  /// A friend visited (once per friend per day).
  visit,

  /// Caught a golden bungeoppang on the griddle.
  golden,

  /// Bought with 황금 붕어빵.
  bought,
}

class BoostDefinition {
  final BoostKind kind;
  final String name;
  final int multiplierPermille, durationSeconds;
  const BoostDefinition(
      this.kind, this.name, this.multiplierPermille, this.durationSeconds);
  String get id => kind.name;
}

const boostDefinitions = [
  BoostDefinition(BoostKind.invite, '초대 손님', 5000, 600),
  BoostDefinition(BoostKind.visit, '친구 방문', 3000, 300),
  BoostDefinition(BoostKind.golden, '황금 찬스', 3000, 60),
  BoostDefinition(BoostKind.bought, '황금 부스트', 3000, 600),
];

BoostDefinition boostOf(BoostKind kind) =>
    boostDefinitions.firstWhere((b) => b.kind == kind);

/// A golden bungeoppang appears on the griddle every 3-7 minutes of play
/// and can be caught for this long.
const goldenChanceMinSeconds = 180;
const goldenChanceMaxSeconds = 420;
const goldenChanceVisibleSeconds = 8;
