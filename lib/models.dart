import 'balance.dart' show balanceVersion, upgrades, levels;
import 'economy_config.dart';
import 'mission_state.dart';
import 'support_state.dart';
import 'invite_models.dart';
import 'menu_state.dart';
import 'event_config.dart';
import 'cosmetic_config.dart';

enum UpgradeKind { tap, auto }

class UpgradeDefinition {
  final String id, name;
  final UpgradeKind kind;
  final BigInt baseCost, effect, unlockTotal;
  final int ratioNumerator, ratioDenominator;
  UpgradeDefinition(this.id, this.name, this.kind, int baseCost, int effect,
      this.ratioNumerator, this.ratioDenominator, int unlockTotal)
      : baseCost = BigInt.from(baseCost),
        effect = BigInt.from(effect),
        unlockTotal = BigInt.from(unlockTotal);
  UpgradeDefinition.decimal(
      this.id,
      this.name,
      this.kind,
      String baseCost,
      String effect,
      this.ratioNumerator,
      this.ratioDenominator,
      String unlockTotal)
      : baseCost = BigInt.parse(baseCost),
        effect = BigInt.parse(effect),
        unlockTotal = BigInt.parse(unlockTotal);
}

class SkinDefinition {
  final String id, name;
  final int unlockLevel;
  final BigInt cost;
  SkinDefinition(this.id, this.name, this.unlockLevel, int cost)
      : cost = BigInt.from(cost);
  SkinDefinition.decimal(this.id, this.name, this.unlockLevel, String cost)
      : cost = BigInt.parse(cost);
}

class GameSettings {
  bool vibration, holdToBake, reduceMotion;
  GameSettings(
      {this.vibration = true,
      this.holdToBake = false,
      this.reduceMotion = false});
  Map<String, dynamic> toJson() => {
        'vibration': vibration,
        'holdToBake': holdToBake,
        'reduceMotion': reduceMotion
      };
  factory GameSettings.fromJson(Object? raw) {
    final m = raw is Map ? raw : const {};
    return GameSettings(
        vibration: m['vibration'] is bool ? m['vibration'] as bool : true,
        holdToBake: m['holdToBake'] == true,
        reduceMotion: m['reduceMotion'] == true);
  }
}

class GameState {
  static const formatVersion = 6;
  BigInt buns, lifetime, stars, activeRemainder, savedAutoRate;
  int level, snapshotSequence;
  Map<String, int> upgradeCounts;
  Map<int, LevelRewardRecord> levelRewards;
  MissionState missions;
  SupportState support;
  InviteState invites;
  WardrobeState wardrobe;
  Map<String, LocalEventState> events;
  Set<String> ownedSkins;
  String equippedSkin;
  bool tutorialDone;
  GameSettings settings;
  DateTime lastSettledUtc;
  GameState(
      {required this.buns,
      required this.lifetime,
      required this.stars,
      required this.level,
      required this.snapshotSequence,
      required this.upgradeCounts,
      required this.levelRewards,
      required this.missions,
      required this.support,
      required this.invites,
      required this.wardrobe,
      required this.events,
      required this.ownedSkins,
      required this.equippedSkin,
      required this.tutorialDone,
      required this.settings,
      required this.lastSettledUtc,
      required this.savedAutoRate,
      required this.activeRemainder});
  factory GameState.initial([DateTime? now]) => GameState(
      buns: BigInt.zero,
      lifetime: BigInt.zero,
      stars: BigInt.zero,
      level: 1,
      snapshotSequence: 0,
      upgradeCounts: {for (final u in upgrades) u.id: 0},
      levelRewards: {},
      missions: MissionState.forLevel(1, now ?? DateTime.now().toUtc()),
      support: SupportState.initial(now ?? DateTime.now().toUtc()),
      invites: InviteState(),
      wardrobe: WardrobeState.initial(),
      events: {
        for (final e in eventDefinitions) e.id: LocalEventState.initial(e)
      },
      ownedSkins: {'redbean'},
      equippedSkin: 'redbean',
      tutorialDone: false,
      settings: GameSettings(),
      lastSettledUtc: (now ?? DateTime.now().toUtc()).toUtc(),
      savedAutoRate: BigInt.zero,
      activeRemainder: BigInt.zero);
  GameState copy() => GameState.fromJson(toJson());
  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'balanceVersion': balanceVersion,
        'snapshotSequence': snapshotSequence,
        'buns': '$buns',
        'lifetime': '$lifetime',
        'stars': '$stars',
        'upgradeCounts': Map<String, int>.of(upgradeCounts),
        'level': level,
        'levelRewards': {
          for (final r in levelRewards.entries) '${r.key}': r.value.toJson()
        },
        'missions': missions.toJson(),
        'support': support.toJson(),
        'invites': invites.toJson(),
        'wardrobe': wardrobe.toJson(),
        'events': {for (final e in events.entries) e.key: e.value.toJson()},
        'ownedSkins': ownedSkins.toList(),
        'equippedSkin': equippedSkin,
        'tutorialDone': tutorialDone,
        'settings': settings.toJson(),
        'lastSettledUtc': lastSettledUtc.toUtc().toIso8601String(),
        'savedAutoRate': '$savedAutoRate',
        'activeRemainder': '$activeRemainder'
      };
  // [cosmetics] lets catalog-evolution tests load saves against a future catalog.
  factory GameState.fromJson(Map<String, dynamic> m,
      {Iterable<CosmeticDefinition> cosmetics = cosmeticDefinitions}) {
    BigInt natural(String key) {
      final v = BigInt.tryParse('${m[key]}');
      if (v == null || v.isNegative) {
        throw FormatException('잘못된 $key');
      }
      return v;
    }

    final version = m['formatVersion'];
    if (version != 1 &&
        version != 2 &&
        version != 3 &&
        version != 4 &&
        version != 5 &&
        version != formatVersion) {
      throw const FormatException('지원하지 않는 저장 버전');
    }
    final countsRaw = m['upgradeCounts'];
    if (countsRaw is! Map) {
      throw const FormatException('업그레이드 데이터 손상');
    }
    final counts = <String, int>{};
    for (final u in upgrades) {
      final legacyId = {'tap_1', 'tap_2', 'tap_3', 'auto_1', 'auto_2', 'auto_3'}
          .contains(u.id);
      final n = version == 1 && !legacyId ? 0 : countsRaw[u.id];
      final limit = version == 1 ? legacySkillCountLimit : skillCountLimit;
      if (n is! int || n < 0 || n > limit) {
        throw FormatException('잘못된 업그레이드 ${u.id}');
      }
      counts[u.id] = n;
    }
    final lvl = m['level'];
    if (lvl is! int || lvl < 1 || lvl > levels.last.level) {
      throw const FormatException('잘못된 레벨');
    }
    final equipped = '${m['equippedSkin']}';
    final fishIds = {
      for (final d in cosmetics)
        if (d.slot == CosmeticSlot.fish) d.id
    };
    final owned = (m['ownedSkins'] as List?)
            ?.whereType<String>()
            .where(fishIds.contains)
            .toSet() ??
        {'redbean'};
    if (!owned.contains(equipped)) {
      throw const FormatException('장착 외형을 보유하지 않음');
    }
    final last = DateTime.tryParse('${m['lastSettledUtc']}');
    if (last == null) {
      throw const FormatException('잘못된 저장 시각');
    }
    // Events added after a v6 save simply start fresh; only a non-map is damage.
    final rawEvents =
        version == formatVersion ? m['events'] ?? const {} : const {};
    if (rawEvents is! Map) throw const FormatException('이벤트 저장 손상');
    final rewards = <int, LevelRewardRecord>{};
    late final MissionState missions;
    if (version == 3 ||
        version == 4 ||
        version == 5 ||
        version == formatVersion) {
      final rawRewards = m['levelRewards'], rawMissions = m['missions'];
      if (rawRewards is! Map || rawMissions is! Map) {
        throw const FormatException('레벨 미션 저장 누락');
      }
      for (final entry in rawRewards.entries) {
        if (entry.value is! Map) throw const FormatException('보상 기록 손상');
        final record = LevelRewardRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map));
        if (entry.key != '${record.level}') {
          throw const FormatException('보상 ID 불일치');
        }
        rewards[record.level] = record;
      }
      missions =
          MissionState.fromJson(Map<String, dynamic>.from(rawMissions), lvl);
    } else {
      for (final level
          in (m['rewardedLevels'] as List? ?? []).whereType<int>()) {
        if (level >= 2 && level <= levels.last.level) {
          rewards[level] = LevelRewardRecord(
              level: level, seasonId: 'legacy-v$version', source: 'legacy');
        }
      }
      missions = MissionState.forLevel(lvl, null);
    }
    final result = GameState(
        buns: natural('buns'),
        lifetime: natural('lifetime'),
        stars: natural('stars'),
        level: lvl,
        snapshotSequence:
            m['snapshotSequence'] is int ? m['snapshotSequence'] as int : 0,
        upgradeCounts: counts,
        levelRewards: rewards,
        missions: missions,
        wardrobe: version == formatVersion
            ? WardrobeState.fromJson(inviteMap(m['wardrobe']))
            : WardrobeState.initial(),
        events: {
          for (final e in eventDefinitions)
            e.id: rawEvents[e.id] == null
                ? LocalEventState.initial(e)
                : LocalEventState.fromJson(inviteMap(rawEvents[e.id]), e)
        },
        invites: version == 5 || version == formatVersion
            ? InviteState.fromJson(inviteMap(m['invites']))
            : InviteState.migrate(missions.seenInvitePlayers),
        support: version == 4 || version == 5 || version == formatVersion
            ? SupportState.fromJson(m['support'] is Map
                ? Map<String, dynamic>.from(m['support'] as Map)
                : throw const FormatException('보조 진행 저장 누락'))
            : SupportState.initial(last.toUtc(),
                legacyStars: natural('stars'),
                legacyFraction: natural('activeRemainder')),
        ownedSkins: owned,
        equippedSkin: equipped,
        tutorialDone: m['tutorialDone'] == true,
        settings: GameSettings.fromJson(m['settings']),
        lastSettledUtc: last.toUtc(),
        savedAutoRate: natural('savedAutoRate'),
        activeRemainder: natural('activeRemainder') % BigInt.from(1000));
    for (final e in result.events.entries) {
      for (final id in e.value.receipts.keys) {
        if (!result.support.ledger.containsKey('event:${e.key}:$id')) {
          throw const FormatException('이벤트 보상 원장 누락');
        }
      }
    }
    return result;
  }

  String equippedCosmetic(CosmeticSlot slot) =>
      slot == CosmeticSlot.fish ? equippedSkin : wardrobe.equipped[slot]!;
  bool ownsCosmetic(CosmeticDefinition item) => item.slot == CosmeticSlot.fish
      ? ownedSkins.contains(item.id)
      : wardrobe.owned.contains(item.id);
}
