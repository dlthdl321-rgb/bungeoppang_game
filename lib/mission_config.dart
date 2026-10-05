import 'config_values.dart';

// Versioned level mission seasons. Keep existing season IDs immutable when
// introducing a different season: old saves name the season they were made in.
enum MissionKind {
  tutorial,
  lifetime,
  autoRate,
  newPlayerInvites, // Legacy season only; needs the debug invite system.
  goldenButterUses,
  cosmeticsOwned, // Non-default cosmetics owned, all slots.
  itemUses, // Lifetime item uses, all items.
  skillLevel, // Owned count of [MissionDefinition.skillId].
  achievements, // Achievements whose condition is met.
}

class MissionDefinition {
  final String id, title, targetValue, evidence;
  final MissionKind kind;
  final String? source, skillId;
  const MissionDefinition(
      this.id, this.kind, this.title, this.targetValue, this.evidence,
      [this.source])
      : skillId = null;
  const MissionDefinition.skill(
      this.id, this.title, String this.skillId, this.targetValue)
      : kind = MissionKind.skillLevel,
        evidence = 'estimated',
        source = null;
  BigInt get target => configBigInt(targetValue);
}

class LevelDefinition {
  final int level;
  final List<MissionDefinition> missions;
  final String rewardValue, rewardEvidence;
  const LevelDefinition(this.level, this.missions,
      {this.rewardValue = '3', this.rewardEvidence = 'estimated'});
  BigInt get reward => BigInt.parse(rewardValue);
  // Read-only projections for existing production target consumers.
  BigInt get total => _target(MissionKind.lifetime);
  BigInt get autoPerSecond => _target(MissionKind.autoRate);
  BigInt _target(MissionKind kind) {
    for (final m in missions) {
      if (m.kind == kind) return m.target;
    }
    return BigInt.zero;
  }
}

// Stage 8 offline season: invite goals replaced by goals playable offline.
const currentMissionSeason = 'offline-v1';
// Pre-v7 season with friend-invite goals. Kept so old saves load and the
// debug-only invite system can still be exercised against it.
const legacyInviteMissionSeason = 'public-reviews-2025-12-v1';
const missionSource =
    'https://dailysejong.tistory.com/entry/당근마켓-붕어빵게임-공략-총정리레벨-10-달성';
const earlyMissionSource = 'https://citynetc.tistory.com/290';
// Technical prototype limit, not a source-game rule.
const mockInviteHistoryLimit = 1000;
const publicReviewLevels = <LevelDefinition>[
  LevelDefinition(1, [], rewardValue: '0'), // Starting level, no claim.
  LevelDefinition(2, [
    MissionDefinition(
        'tutorial', MissionKind.tutorial, '굽기 안내 확인', '1', 'estimated'),
    MissionDefinition('lifetime', MissionKind.lifetime, '누적 붕어빵 생산', '10',
        'public-review', earlyMissionSource),
  ]),
  LevelDefinition(3, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '1',
        'public-review', earlyMissionSource),
  ]),
  LevelDefinition(4, [
    MissionDefinition('butter', MissionKind.goldenButterUses, '황금버터 사용', '1',
        'public-review', earlyMissionSource),
  ]),
  LevelDefinition(5, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '5000',
        'public-review', earlyMissionSource),
    MissionDefinition('invite', MissionKind.newPlayerInvites, '신규 플레이어 초대 성공',
        '1', 'public-review', missionSource),
  ]),
  LevelDefinition(6, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '15000000',
        'public-review', missionSource),
  ]),
  LevelDefinition(7, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '500000000',
        'public-review', missionSource),
    MissionDefinition('invite', MissionKind.newPlayerInvites, '신규 플레이어 초대 성공',
        '1', 'public-review', missionSource),
  ]),
  LevelDefinition(8, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '20000000000',
        'public-review', missionSource),
  ]),
  LevelDefinition(9, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '500000000000',
        'public-review', missionSource),
    MissionDefinition('invite', MissionKind.newPlayerInvites, '신규 플레이어 초대 성공',
        '1', 'public-review', missionSource),
  ]),
  LevelDefinition(10, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '20000000000000',
        'public-review', missionSource),
    MissionDefinition('invite', MissionKind.newPlayerInvites, '신규 플레이어 초대 성공',
        '3', 'public-review', missionSource),
  ]),
];

// Invite goals (Lv.5/7/9/10) replaced by offline goals. Stage 11 raised the
// Lv.6-9 per-second targets and set Lv.10 to 15조/s so a casual player
// reaches Lv.10 in weeks 3-4 (see docs/stage11_balance_endgame.md).
const offlineLevels = <LevelDefinition>[
  LevelDefinition(1, [], rewardValue: '0'), // Starting level, no claim.
  LevelDefinition(2, [
    MissionDefinition(
        'tutorial', MissionKind.tutorial, '굽기 안내 확인', '1', 'estimated'),
    MissionDefinition(
        'lifetime', MissionKind.lifetime, '누적 붕어빵 생산', '10', 'estimated'),
  ]),
  LevelDefinition(3, [
    MissionDefinition('auto', MissionKind.autoRate, '초당 생산량', '1', 'estimated'),
  ]),
  LevelDefinition(4, [
    MissionDefinition(
        'butter', MissionKind.goldenButterUses, '황금버터 사용', '1', 'estimated'),
  ]),
  LevelDefinition(5, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '5000', 'estimated'),
    MissionDefinition('cosmetics', MissionKind.cosmeticsOwned, '기본 외 꾸미기 보유',
        '1', 'estimated'),
  ]),
  LevelDefinition(6, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '60000000', 'estimated'),
  ]),
  LevelDefinition(7, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '16000000000', 'estimated'),
    MissionDefinition(
        'items', MissionKind.itemUses, '아이템 누적 사용', '5', 'estimated'),
  ]),
  LevelDefinition(8, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '500000000000', 'estimated'),
  ]),
  LevelDefinition(9, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '4000000000000', 'estimated'),
    MissionDefinition.skill('skill', '은하 공방 보유', 'auto_11', '1'),
  ]),
  LevelDefinition(10, [
    MissionDefinition(
        'auto', MissionKind.autoRate, '초당 생산량', '15000000000000', 'estimated'),
    MissionDefinition(
        'achievements', MissionKind.achievements, '업적 달성', '12', 'estimated'),
  ]),
];

const missionSeasons = {
  currentMissionSeason: offlineLevels,
  legacyInviteMissionSeason: publicReviewLevels,
};

List<LevelDefinition> levelsForSeason(String id) {
  final result = missionSeasons[id];
  if (result == null) throw const FormatException('지원하지 않는 미션 시즌');
  return result;
}
