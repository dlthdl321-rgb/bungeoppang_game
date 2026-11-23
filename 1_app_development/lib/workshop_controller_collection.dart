part of 'workshop_controller.dart';

/// 도감 칸 채우기 보상 (4차 피드백 g6).
/// [WorkshopController]에서 옮긴 그대로다(2026-11-23 안정화, 동작 변경 없음).
extension WorkshopCollection on WorkshopController {
  /// Takes [collectionNews] (the page shows them once).
  List<String> takeCollectionNews() { final news = collectionNews.toList(); collectionNews.clear(); return news; }
  /// The buns one completed 도감 cell pays now: `cell_buns_seconds` of auto
  /// production, at least `cell_min_buns` (like the attendance stamp).
  BigInt get collectionCellReward => dailyBuns(autoRate, collectionCellSeconds(config), collectionCellMinimum(config));
  /// Titles of the collected flavors, in recipe order ('팥 장인').
  List<String> get collectionTitles => [for (final f in config.section('active_recipes').keys)
    if (state.recipes.contains(f) && state.collection(config, f).collected) collectionTitle(config, f)];
  /// Runs after every command: pays each newly completed cell once
  /// ([WorkshopState.collectionClaims]) and asks the server for a collected
  /// flavor's gold once (`pendingGold['collection:<flavor>']`, pending until
  /// verified like level gold). The title needs nothing saved.
  void _settleCollection() {
    for (final flavor in state.recipes.toList()..sort()) {
      final progress = state.collection(config, flavor);
      final paid = state.collectionClaims[flavor] ?? <int>{};
      final label = flavorLabel(flavor);
      for (var i = 0; i < 5; i++) {
        if (!progress.complete(i) || paid.contains(i)) continue;
        final buns = collectionCellReward;
        state.buns += buns; state.lifetime += buns;
        state.collectionClaims[flavor] = {...paid, i};
        paid.add(i);
        collectionNews.add('$label · ${provisionalDonenessLabels[i]} 칸 완성! 붕어빵력 +${compactNumber(buns)}');
      }
      if (progress.collected && !state.pendingGold.containsKey('collection:$flavor')) {
        state.pendingGold['collection:$flavor'] = collectionGoldClaim(config, flavor);
        collectionNews..add('$label 도감 완성! 칭호 「${collectionTitle(config, flavor)}」')
          ..add('황금붕어빵력 ${collectionFlavorGold(config)}개는 보상 확인 뒤 받아요');
      }
    }
  }
}
