import 'economy.dart';
import 'mission_config.dart';
import 'models.dart';
import 'progress_rules.dart';

LevelDefinition? activeLevelMission(GameState state) {
  final target = state.missions.targetLevel;
  if (target == null || target != state.level + 1) return null;
  return levelsForSeason(state.missions.seasonId)[target - 1];
}

class MissionProgress {
  final MissionDefinition definition;
  final BigInt current;
  final bool active;
  const MissionProgress(this.definition, this.current, this.active);
  bool get complete => active && current >= definition.target;
  int get permille => !active
      ? 0
      : complete
          ? 1000
          : (current * BigInt.from(1000) ~/ definition.target).toInt();
}

List<MissionProgress> missionProgress(GameState state, LevelDefinition level) {
  final active = activeLevelMission(state)?.level == level.level &&
      state.missions.activatedAtUtc != null;
  return [
    for (final m in level.missions)
      MissionProgress(
          m,
          !active
              ? BigInt.zero
              : state.missions.waivedGoals.contains(m.id)
                  ? m.target
                  : switch (m.kind) {
                      MissionKind.tutorial =>
                        state.tutorialDone ? BigInt.one : BigInt.zero,
                      MissionKind.lifetime => state.lifetime,
                      MissionKind.autoRate => autoRate(state),
                      MissionKind.newPlayerInvites => BigInt.from(
                          state.missions.qualifiedInvitePlayers.length),
                      MissionKind.goldenCatches => state.missions.goldenCatches,
                      MissionKind.cosmeticsOwned =>
                        BigInt.from(cosmeticsOwnedCount(state)),
                      MissionKind.boostUses => state.support.boostUses,
                      MissionKind.skillLevel =>
                        BigInt.from(state.upgradeCounts[m.skillId] ?? 0),
                      MissionKind.achievements =>
                        BigInt.from(achievementsMetCount(state)),
                    },
          active)
  ];
}

bool canClaimLevel(GameState state) {
  final target = activeLevelMission(state);
  return target != null &&
      target.missions.isNotEmpty &&
      missionProgress(state, target).every((m) => m.complete);
}
