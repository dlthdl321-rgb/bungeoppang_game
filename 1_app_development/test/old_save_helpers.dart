import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/support_config.dart';

/// Old account saves for the migration tests (moved from
/// stage8_progress_test.dart when that old-clicker test went, 32번).
final now = DateTime.utc(2026, 10, 5, 3); // Monday 12:00 KST.

Map<String, dynamic> plainJson(GameState s) =>
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

GameState progressed() {
  final s = GameState.initial(now)
    ..buns = BigInt.parse('123456789012345678901234567890')
    ..lifetime = BigInt.parse('999999999999999999999')
    ..stars = BigInt.from(42)
    ..level = 3
    ..tutorialDone = true;
  s.missions = MissionState.forLevel(3, now);
  s.upgradeCounts['tap_1'] = 7;
  s.support.transact('test:fund', BigInt.from(42), 'test', now);
  s.support.startBoost(boostOf(BoostKind.bought), now);
  s.wardrobe.owned.add('dusk');
  s.wardrobe.equipped[CosmeticSlot.background] = 'dusk';
  return s;
}

/// Rebuilds the JSON shape an older app version wrote for [s].
Map<String, dynamic> asVersion(GameState s, int version) {
  final json = plainJson(s)..['formatVersion'] = version;
  for (final key in ['records', 'weekly', 'achievements']) {
    json.remove(key);
  }
  final missions = json['missions'] as Map
    ..['seasonId'] = legacyInviteMissionSeason
    ..remove('waivedGoals');
  if (version == 6) json['events'] = <String, Object?>{};
  if (version <= 5) json.remove('wardrobe');
  if (version <= 4) json.remove('invites');
  if (version <= 3) json.remove('support');
  if (version <= 2) {
    json
      ..remove('missions')
      ..remove('levelRewards')
      ..['rewardedLevels'] = [for (var l = 2; l <= s.level; l++) l];
  }
  expect(missions, isNotEmpty);
  return json;
}
