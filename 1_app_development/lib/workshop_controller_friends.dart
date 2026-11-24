part of 'workshop_controller.dart';

/// 친구 가게 방문 (DEC-154, 29번 8절): visits the server delivered become a
/// production boost ([FriendBoost], rules in `workshop_friend_visits.dart`).
extension WorkshopFriendVisits on WorkshopController {
  FriendVisitRules get friendVisitRules => FriendVisitRules.fromConfig(config);

  /// The boost's time left, or 0.
  int get friendBoostRemainingMs => state.friendBoost.remainingMs(_nowMs);

  /// The visits seen, for the server to leave out.
  Set<String> get seenFriendVisits => state.friendBoost.applied.keys.toSet();

  /// Saves [visits] once each; those within the day's limit add boost time
  /// and say who came. Returns the visits that gave time.
  Future<List<FriendVisitArrival>> applyFriendVisits(List<FriendVisitArrival> visits) async {
    if (visits.isEmpty || disposed) return const [];
    var gave = const <FriendVisitArrival>[];
    final saved = await command(() {
      final (next, arrived) = state.friendBoost.apply(visits, friendVisitRules,
          nowMs: _nowMs, today: businessDayKst(now()));
      state.friendBoost = next;
      gave = arrived;
      if (arrived.isNotEmpty) {
        final rules = friendVisitRules, names = arrived.map((v) => '${v.name}님').join(', ');
        notice = '$names이 놀러 왔어요 · ${(state.friendBoost.remainingMs(_nowMs) / 60000).ceil()}분 동안 '
            '생산 ${rules.multiplierPermille ~/ 1000}배';
      }
    }, keepNotice: true);
    return saved ? gave : const [];
  }

  /// [amount] with the boost applied when it runs now.
  BigInt _friendBoosted(BigInt amount) => state.friendBoost.activeAt(_nowMs)
      ? amount * BigInt.from(friendVisitRules.multiplierPermille) ~/ BigInt.from(1000)
      : amount;

  /// Auto production's ms × permille ([_runAutoPantry]) over the last
  /// [elapsedMs]: the part the boost covered counts [FriendVisitRules.multiplierPermille].
  int? _friendBoostedPermilleMs(int? permilleMs, int elapsedMs) {
    if (permilleMs == null || permilleMs == 0 || elapsedMs <= 0) return permilleMs;
    final end = _nowMs, boosted = state.friendBoost.boostedMs(end - elapsedMs, end);
    if (boosted == 0) return permilleMs;
    // The pantry covered permilleMs/1000 ms; the boost adds on its share.
    final covered = permilleMs ~/ 1000, extra = (covered < boosted ? covered : boosted) *
        (friendVisitRules.multiplierPermille - 1000);
    return permilleMs + extra;
  }
}
