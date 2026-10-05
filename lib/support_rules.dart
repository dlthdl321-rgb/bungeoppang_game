import 'economy.dart';
import 'models.dart';
import 'prestige_rules.dart';
import 'support_config.dart';
import 'support_state.dart';

bool dailyComplete(GameState s, DailyDefinition d) =>
    s.support.daily.progress(d.metric) >= BigInt.parse(d.target);
bool dailyAllComplete(GameState s) =>
    dailyDefinitions.every((d) => dailyComplete(s, d));
// Single funnel for time passing: daily/weekly rollover and record peaks.
void observeSupport(GameState s, DateTime now) {
  final day = s.support.daily.day, production = s.support.daily.production;
  s.support.observe(now);
  if (s.support.daily.day != day) s.records.closeDay(day, production);
  s.weekly.rollTo(s.support.observedUtc);
  final rate = autoRate(s);
  if (rate > s.support.daily.peakAuto) s.support.daily.peakAuto = rate;
  if (rate > s.records.bestAutoRate) s.records.bestAutoRate = rate;
}

// Split at effect boundaries and midnight. Never round each segment separately:
// the persistent fractional numerator also survives offline/active transitions.
BigInt settleProduction(
    GameState s, DateTime start, DateTime end, BigInt baseRate,
    {bool offline = false}) {
  if (!end.isAfter(start)) {
    observeSupport(s, end);
    return BigInt.zero;
  }
  // Prestige stars scale the base rate once per settlement (per rate, not
  // per time slice), so splitting a period never changes the result.
  final rate = baseRate * BigInt.from(prestigePermille(s)) ~/ BigInt.from(1000);
  var cursor = start, total = BigInt.zero;
  while (cursor.isBefore(end)) {
    var boundary = end;
    final midnight = nextDailyReset(cursor);
    if (midnight.isBefore(boundary)) boundary = midnight;
    for (final effect in s.support.effects.values) {
      for (final edge in [effect.startedAtUtc, effect.endsAtUtc]) {
        if (edge.isAfter(cursor) && edge.isBefore(boundary)) boundary = edge;
      }
    }
    observeSupport(s, cursor);
    final numerator = rate *
            BigInt.from(boundary.difference(cursor).inMilliseconds) *
            s.support.multiplier(EffectChannel.automatic, cursor) *
            BigInt.from(offline ? 1 : 2) +
        s.support.autoFraction;
    final gain = numerator ~/ BigInt.from(productionQuantum);
    s.support.autoFraction = numerator % BigInt.from(productionQuantum);
    s.activeRemainder = s.support.autoFraction ~/ BigInt.from(2000);
    s.buns += gain;
    s.lifetime += gain;
    total += gain;
    if (!offline || dailyOfflineCounts) s.support.daily.production += gain;
    cursor = boundary;
  }
  observeSupport(s, end);
  return total;
}

bool grantReward(GameState s, String transactionId, RewardDefinition reward,
    DateTime now, String reason) {
  if (!s.support
      .transact(transactionId, BigInt.parse(reward.coins), reason, now)) {
    return false;
  }
  for (final item in reward.items.entries) {
    s.support.inventory[item.key] =
        s.support.inventory[item.key]! + BigInt.parse(item.value);
  }
  return true;
}
