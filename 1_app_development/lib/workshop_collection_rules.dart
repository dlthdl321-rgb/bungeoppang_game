import 'dart:convert';
import 'development_balance.dart';
import 'development_rules.dart';

/// 도감 칸 채우기 (4차 피드백 g6, DEC-TBD-i4g6-1).
///
/// A cell (flavor × doneness) counts the special-mold bakes (practice and
/// orders) with that doneness, read from the per-bake ledger
/// [FlavorMasteryProgress.results]; the six-cell griddle never records
/// there. A cell is '발견' after one bake and '완성' after
/// [collectionRequired] bakes. A flavor is collected when all five are
/// complete: that opens the six-cell griddle for it, its title and gold.

/// Bakes each of the five cells of [flavor] needs:
/// `collection_counts.required_by_flavor[flavor]`, else the row of its
/// difficulty in `required_by_difficulty`.
List<int> collectionRequired(DevelopmentBalance config, String flavor) {
  final counts = config.section('collection_counts');
  final byFlavor = counts['required_by_flavor'];
  final List raw;
  if (byFlavor is Map && byFlavor[flavor] is List) {
    raw = byFlavor[flavor] as List;
  } else {
    final recipe = config.section('active_recipes')[flavor];
    if (recipe is! Map<String, dynamic>) throw const FormatException('도감 맛 오류');
    final rows = counts['required_by_difficulty'];
    final difficulty = DevelopmentBalance.integer(recipe, 'difficulty');
    if (rows is! List || difficulty < 0 || difficulty >= rows.length || rows[difficulty] is! List) {
      throw const FormatException('도감 칸 횟수 설정 오류');
    }
    raw = rows[difficulty] as List;
  }
  if (raw.length != 5 || raw.any((v) => v is! int || v < 1)) throw const FormatException('도감 칸 횟수 설정 오류');
  return List<int>.unmodifiable(raw.cast<int>());
}

/// How many special-mold bakes of each doneness (0~4) [progress] recorded.
List<int> collectionCounts(FlavorMasteryProgress? progress) {
  final counts = List<int>.filled(5, 0);
  if (progress == null) return counts;
  for (final fingerprint in progress.results.values) {
    final raw = jsonDecode(fingerprint);
    if (raw is List && raw.length > 1 && raw[1] is int && (raw[1] as int) >= 0 && (raw[1] as int) < 5) {
      counts[raw[1] as int]++;
    }
  }
  return counts;
}

/// One flavor's 도감 page in numbers.
class CollectionProgress {
  final String flavor;
  final List<int> counts, required;
  const CollectionProgress(this.flavor, this.counts, this.required);
  bool found(int i) => counts[i] > 0;
  bool complete(int i) => counts[i] >= required[i];
  int get completedCells => [for (var i = 0; i < 5; i++) if (complete(i)) i].length;
  bool get collected => completedCells == 5;
}

CollectionProgress collectionProgress(DevelopmentBalance config, String flavor, FlavorMasteryProgress? progress) =>
    CollectionProgress(flavor, collectionCounts(progress), collectionRequired(config, flavor));

Map<String, dynamic> _rewards(DevelopmentBalance config) => config.section('collection_rewards');

/// The title a collected [flavor] gives ('팥 장인'): `collection_rewards.titles`,
/// else the label + `title_default_suffix`.
String collectionTitle(DevelopmentBalance config, String flavor) {
  final rewards = _rewards(config), titles = rewards['titles'];
  if (titles is Map && titles[flavor] is String) return titles[flavor] as String;
  final label = (config.section('active_recipes')[flavor] as Map)['label'] as String;
  return '$label ${rewards['title_default_suffix']}';
}

/// Seconds of auto production a completed cell pays, and its floor.
int collectionCellSeconds(DevelopmentBalance config) => DevelopmentBalance.integer(_rewards(config), 'cell_buns_seconds');
BigInt collectionCellMinimum(DevelopmentBalance config) => DevelopmentBalance.decimal(_rewards(config), 'cell_min_buns');
int collectionFlavorGold(DevelopmentBalance config) => DevelopmentBalance.integer(_rewards(config), 'flavor_gold');

/// The gold claim of a collected flavor (`pendingGold['collection:<flavor>']`),
/// verified by the server like a mission claim: exactly these four keys.
String collectionGoldClaim(DevelopmentBalance config, String flavor) => jsonEncode({
      'scope': 'collection', 'goal': flavor, 'gold': collectionFlavorGold(config), 'revision': config.revision});
