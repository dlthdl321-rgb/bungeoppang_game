import 'mission_config.dart';

class LevelRewardRecord {
  final int level;
  final String seasonId, source;
  final BigInt? amount;
  final DateTime? claimedAtUtc;
  const LevelRewardRecord(
      {required this.level,
      required this.seasonId,
      required this.source,
      this.amount,
      this.claimedAtUtc});
  Map<String, dynamic> toJson() => {
        'level': level,
        'seasonId': seasonId,
        'source': source,
        'amount': amount?.toString(),
        'claimedAtUtc': claimedAtUtc?.toIso8601String(),
      };
  factory LevelRewardRecord.fromJson(Map<String, dynamic> m) {
    final level = m['level'];
    final amount =
        m['amount'] == null ? null : BigInt.tryParse('${m['amount']}');
    final at = m['claimedAtUtc'] == null
        ? null
        : DateTime.tryParse('${m['claimedAtUtc']}');
    final source = m['source'];
    if (level is! int ||
        level < 2 ||
        level > publicReviewLevels.last.level ||
        m['seasonId'] is! String ||
        (source != 'claim' && source != 'legacy') ||
        (m['amount'] != null && (amount == null || amount.isNegative)) ||
        (m['claimedAtUtc'] != null && at == null) ||
        (source == 'claim' && (amount == null || at == null))) {
      throw const FormatException('잘못된 레벨 보상 기록');
    }
    return LevelRewardRecord(
        level: level,
        seasonId: m['seasonId'] as String,
        source: source as String,
        amount: amount,
        claimedAtUtc: at?.toUtc());
  }
}

class MissionState {
  final String seasonId;
  final int? targetLevel;
  final int generation;
  DateTime? activatedAtUtc;
  final Set<String> seenInvitePlayers, qualifiedInvitePlayers;
  // Goal IDs of the active level counted as complete because the save had
  // already met the friend-invite goal they replaced (v7 migration).
  final Set<String> waivedGoals;
  // Saved under the stage-12 key 'butterUses' (it counted golden butter).
  BigInt goldenCatches;
  MissionState(
      {required this.seasonId,
      required this.targetLevel,
      required this.generation,
      required this.activatedAtUtc,
      required this.seenInvitePlayers,
      required this.qualifiedInvitePlayers,
      required this.goldenCatches,
      Set<String>? waivedGoals})
      : waivedGoals = waivedGoals ?? {};

  factory MissionState.forLevel(int level, DateTime? now,
          {String seasonId = currentMissionSeason}) =>
      MissionState(
        seasonId: seasonId,
        targetLevel:
            level < levelsForSeason(seasonId).last.level ? level + 1 : null,
        generation: 1,
        activatedAtUtc: now?.toUtc(),
        seenInvitePlayers: {},
        qualifiedInvitePlayers: {},
        goldenCatches: BigInt.zero,
      );
  String get token => '$seasonId/$generation/$targetLevel';
  MissionState advance(int level, DateTime now) => MissionState(
        seasonId: seasonId,
        targetLevel:
            level < levelsForSeason(seasonId).last.level ? level + 1 : null,
        generation: generation + 1,
        activatedAtUtc: now.toUtc(),
        seenInvitePlayers: Set.of(seenInvitePlayers),
        qualifiedInvitePlayers: {},
        goldenCatches: BigInt.zero,
      );

  /// Moves a legacy invite-season save to the current season. An invite goal
  /// already met for the active level waives the goals that replaced it.
  MissionState migrateToCurrentSeason() {
    if (seasonId == currentMissionSeason) return this;
    final waived = <String>{};
    final target = targetLevel;
    if (target != null && activatedAtUtc != null) {
      final old = levelsForSeason(seasonId)[target - 1].missions;
      final fresh = levelsForSeason(currentMissionSeason)[target - 1].missions;
      final invite = old.where((m) => m.kind == MissionKind.newPlayerInvites);
      if (invite.isNotEmpty &&
          BigInt.from(qualifiedInvitePlayers.length) >= invite.first.target) {
        waived.addAll(
            fresh.map((m) => m.id).where((id) => !old.any((o) => o.id == id)));
      }
    }
    return MissionState(
        seasonId: currentMissionSeason,
        targetLevel: targetLevel,
        generation: generation,
        activatedAtUtc: activatedAtUtc,
        seenInvitePlayers: Set.of(seenInvitePlayers),
        qualifiedInvitePlayers: Set.of(qualifiedInvitePlayers),
        goldenCatches: goldenCatches,
        waivedGoals: waived);
  }

  Map<String, dynamic> toJson() => {
        'seasonId': seasonId,
        'targetLevel': targetLevel,
        'generation': generation,
        'activatedAtUtc': activatedAtUtc?.toIso8601String(),
        'seenInvitePlayers': seenInvitePlayers.toList(),
        'qualifiedInvitePlayers': qualifiedInvitePlayers.toList(),
        'butterUses': goldenCatches.toString(),
        'waivedGoals': waivedGoals.toList(),
      };
  factory MissionState.fromJson(Map<String, dynamic> m, int level) {
    final seasonId = m['seasonId'];
    if (seasonId is! String) throw const FormatException('미션 시즌 누락');
    final maxLevel = levelsForSeason(seasonId).last.level;
    final target = level < maxLevel ? level + 1 : null;
    final generation = m['generation'];
    final at = m['activatedAtUtc'] == null
        ? null
        : DateTime.tryParse('${m['activatedAtUtc']}');
    final uses = BigInt.tryParse('${m['butterUses']}');
    Set<String> players(String key) {
      final values = m[key];
      if (values is! List ||
          values.length > mockInviteHistoryLimit ||
          values.any((v) => v is! String || v.isEmpty || v.length > 128) ||
          values.toSet().length != values.length) {
        throw const FormatException('잘못된 모의 초대 기록');
      }
      return values.cast<String>().toSet();
    }

    final seen = players('seenInvitePlayers'),
        qualified = players('qualifiedInvitePlayers');
    final rawWaived = m['waivedGoals'] ?? const [];
    final targetIds = target == null
        ? const <String>{}
        : levelsForSeason(seasonId)[target - 1]
            .missions
            .map((d) => d.id)
            .toSet();
    if (rawWaived is! List ||
        rawWaived.any((id) => !targetIds.contains(id)) ||
        rawWaived.toSet().length != rawWaived.length) {
      throw const FormatException('잘못된 대체 조건 기록');
    }
    if (m['targetLevel'] != target ||
        generation is! int ||
        generation < 1 ||
        (m['activatedAtUtc'] != null && at == null) ||
        uses == null ||
        uses.isNegative ||
        !seen.containsAll(qualified) ||
        ((at == null || target == null) &&
            (qualified.isNotEmpty || uses != BigInt.zero))) {
      throw const FormatException('잘못된 활성 미션 기록');
    }
    return MissionState(
        seasonId: seasonId,
        targetLevel: target,
        generation: generation,
        activatedAtUtc: at?.toUtc(),
        seenInvitePlayers: seen,
        qualifiedInvitePlayers: qualified,
        goldenCatches: uses,
        waivedGoals: rawWaived.cast<String>().toSet());
  }
}

// Local test receipt, not proof issued by a server. Both invitation and
// completion time matter: a pre-activation invitation cannot qualify later.
class MockInviteSuccess {
  final String playerId, activationToken;
  final DateTime invitedAtUtc, completedAtUtc;
  final bool isNewPlayer, reachedLevelOne;
  const MockInviteSuccess(
      {required this.playerId,
      required this.activationToken,
      required this.invitedAtUtc,
      required this.completedAtUtc,
      this.isNewPlayer = true,
      this.reachedLevelOne = true});
}
