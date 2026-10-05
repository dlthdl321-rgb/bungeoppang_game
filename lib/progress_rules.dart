import 'achievement_config.dart';
import 'cosmetic_config.dart';
import 'config_values.dart';
import 'models.dart';
import 'weekly_config.dart';

/// Non-default cosmetics owned across every slot.
int cosmeticsOwnedCount(GameState s) => cosmeticDefinitions
    .where((d) => defaultCosmetics[d.slot] != d.id && s.ownsCosmetic(d))
    .length;
final collectibleCosmeticCount =
    cosmeticDefinitions.where((d) => defaultCosmetics[d.slot] != d.id).length;

BigInt totalItemUses(GameState s) =>
    s.support.itemUses.values.fold(BigInt.zero, (a, b) => a + b);

// Ledger-derived counts are cached per ledger size: the ledger only grows,
// and these are read on every home rebuild through the Lv.10 goal.
Object? _ledgerOwner;
int _ledgerSize = -1, _dailyAll = 0, _weeklyDone = 0;
void _scanLedger(GameState s) {
  final ledger = s.support.ledger;
  if (identical(ledger, _ledgerOwner) && ledger.length == _ledgerSize) return;
  final weeks = <String, int>{};
  var daily = 0;
  for (final id in ledger.keys) {
    if (id.startsWith('daily:') && id.endsWith(':all')) daily++;
    if (id.startsWith('weekly:')) {
      final week = id.split(':')[1];
      weeks[week] = (weeks[week] ?? 0) + 1;
    }
  }
  _ledgerOwner = ledger;
  _ledgerSize = ledger.length;
  _dailyAll = daily;
  _weeklyDone = weeks.values.where((n) => n >= weeklyGoals.length).length;
}

int dailyAllClearCount(GameState s) {
  _scanLedger(s);
  return _dailyAll;
}

int weeklyCompletionCount(GameState s) {
  _scanLedger(s);
  return _weeklyDone;
}

BigInt achievementTarget(AchievementDefinition d) =>
    d.metric == AchievementMetric.allCosmetics
        ? BigInt.from(collectibleCosmeticCount)
        : configBigInt(d.target);

BigInt achievementProgress(GameState s, AchievementDefinition d) =>
    switch (d.metric) {
      AchievementMetric.lifetime => s.lifetime,
      AchievementMetric.bestAutoRate => s.records.bestAutoRate,
      AchievementMetric.level => BigInt.from(s.level),
      AchievementMetric.lifetimeTaps => s.records.lifetimeTaps,
      AchievementMetric.bestCombo => BigInt.from(s.records.bestCombo),
      AchievementMetric.itemUses => totalItemUses(s),
      AchievementMetric.cosmeticsOwned ||
      AchievementMetric.allCosmetics =>
        BigInt.from(cosmeticsOwnedCount(s)),
      AchievementMetric.playDays => BigInt.from(s.records.playDays),
      AchievementMetric.weeklyCompletions =>
        BigInt.from(weeklyCompletionCount(s)),
      AchievementMetric.dailyAllClears => BigInt.from(dailyAllClearCount(s)),
      AchievementMetric.newRecordDays => BigInt.from(s.records.newRecordDays),
      AchievementMetric.prestiges => BigInt.from(s.prestige.count),
      AchievementMetric.prestigeStars => BigInt.from(s.prestige.stars),
    };

bool achievementMet(GameState s, AchievementDefinition d) =>
    s.achievements.claimed.contains(d.id) ||
    achievementProgress(s, d) >= achievementTarget(d);

int achievementsMetCount(GameState s) =>
    achievementDefinitions.where((d) => achievementMet(s, d)).length;

bool weeklyGoalComplete(GameState s, WeeklyGoalDefinition g) =>
    s.weekly.progress(g.metric) >= g.targetAmount;
