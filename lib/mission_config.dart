// A selectable, versioned interpretation of PUBLIC REVIEWS, not official rules.
// Keep existing season IDs immutable when introducing a different season.
enum MissionKind {
  tutorial,
  lifetime,
  autoRate,
  newPlayerInvites,
  goldenButterUses
}

class MissionDefinition {
  final String id, title, targetValue, evidence;
  final MissionKind kind;
  final String? source;
  const MissionDefinition(
      this.id, this.kind, this.title, this.targetValue, this.evidence,
      [this.source]);
  BigInt get target => BigInt.parse(targetValue);
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

const currentMissionSeason = 'public-reviews-2025-12-v1';
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

const missionSeasons = {currentMissionSeason: publicReviewLevels};

List<LevelDefinition> levelsForSeason(String id) {
  final result = missionSeasons[id];
  if (result == null) throw const FormatException('지원하지 않는 미션 시즌');
  return result;
}
