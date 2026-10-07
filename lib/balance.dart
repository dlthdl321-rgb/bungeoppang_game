import 'models.dart';
import 'economy_config.dart';
import 'mission_config.dart';
import 'cosmetic_config.dart';

const balanceVersion = economyBalanceVersion;
const maxUpgradeCount = skillCountLimit;
const maxOfflineMs = 8 * 60 * 60 * 1000;

List<UpgradeDefinition> _skills(
        UpgradeKind kind, List<SkillRow> early, List<LateSkillRow> late) =>
    [
      for (final r in early)
        UpgradeDefinition.decimal(
            r.$1, r.$2, kind, r.$3, r.$4, r.$6, r.$7, r.$5),
      for (var i = 0; i < late.length; i++)
        UpgradeDefinition.decimal(
            '${kind == UpgradeKind.tap ? 'tap' : 'auto'}_${i + 4}',
            late[i].$1,
            kind,
            late[i].$2,
            late[i].$3,
            lateSkillRatioNumerator,
            lateSkillRatioDenominator,
            late[i].$4),
    ];

final upgrades = List<UpgradeDefinition>.unmodifiable([
  ..._skills(UpgradeKind.tap, tapSkillConfig, lateTapSkillConfig),
  ..._skills(UpgradeKind.auto, autoSkillConfig, lateAutoSkillConfig),
]);
final levels = levelsForSeason(currentMissionSeason);
