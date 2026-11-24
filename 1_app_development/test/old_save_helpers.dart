import 'dart:convert';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/models.dart';

/// Old account saves for the migration tests (moved from
/// stage8_progress_test.dart when that old-clicker test went, 32번). Since
/// format 15 the account save keeps only settings, gold, the old wardrobe
/// and fish skins; older saves' other keys are ignored when read.
final now = DateTime.utc(2026, 10, 5, 3); // Monday 12:00 KST.

Map<String, dynamic> plainJson(GameState s) =>
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

GameState progressed() {
  final s = GameState.initial(now);
  s.premium.gold = 42;
  s.wardrobe.owned.add('dusk');
  s.wardrobe.equipped[CosmeticSlot.background] = 'dusk';
  return s;
}

/// The JSON shape an older app version wrote for [s] (the keys this format
/// still reads; the old clicker's progress keys an old save also had are
/// ignored and so left out, except a few to show they are ignored).
Map<String, dynamic> asVersion(GameState s, int version) {
  final json = plainJson(s)..['formatVersion'] = version;
  json
    ..['buns'] = '123456789012345678901234567890'
    ..['lifetime'] = '999999999999999999999'
    ..['level'] = 3
    ..['upgradeCounts'] = {'tap_1': 7};
  if (version == 6) json['events'] = <String, Object?>{};
  if (version <= 5) json.remove('wardrobe');
  return json;
}
