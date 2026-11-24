import 'development_balance.dart';

/// 친구 가게 방문 (DEC-154, 29번 8절): a friend who drops by (or the
/// inviter, once the invited player reached the goal) doubles this shop's
/// production for a while. Rules here are pure; [WorkshopController] calls them.
///
/// * Each visit adds `visit_duration_ms` (an invite visit
///   `invite_duration_ms`) of `multiplier_permille` production, after any
///   boost still running (boosts queue, they never stack the multiplier).
/// * At most `daily_limit` visits a KST day give time; more are still marked
///   seen so the server never sends them again.
/// * Taps and auto production in the foreground are boosted; the away
///   settlement is not.
class FriendVisitRules {
  final int multiplierPermille, visitMs, inviteMs, dailyLimit;
  const FriendVisitRules({required this.multiplierPermille, required this.visitMs,
      required this.inviteMs, required this.dailyLimit});
  factory FriendVisitRules.fromConfig(DevelopmentBalance config) {
    final row = config.section('friend_visits');
    return FriendVisitRules(
        multiplierPermille: DevelopmentBalance.integer(row, 'multiplier_permille'),
        visitMs: DevelopmentBalance.integer(row, 'visit_duration_ms'),
        inviteMs: DevelopmentBalance.integer(row, 'invite_duration_ms'),
        dailyLimit: DevelopmentBalance.integer(row, 'daily_limit'));
  }
}

/// A visit the server delivered.
class FriendVisitArrival {
  final String id, name;
  final bool invite;
  const FriendVisitArrival({required this.id, required this.name, required this.invite});
}

/// The saved boost: when it ends (UTC epoch ms), how many visits gave time
/// on [day] (KST `yyyy-mm-dd`) and the visits already seen (ID → when seen,
/// kept [appliedKeepMs]: the server stops sending a visit after 7 days).
class FriendBoost {
  final int untilMs;
  final String day;
  final int dayCount;
  final Map<String, int> applied;
  const FriendBoost({this.untilMs = 0, this.day = '', this.dayCount = 0, this.applied = const {}});

  static const appliedKeepMs = 8 * 24 * 60 * 60 * 1000;

  bool activeAt(int nowMs) => nowMs < untilMs;
  int remainingMs(int nowMs) => untilMs > nowMs ? untilMs - nowMs : 0;

  /// The part of [fromMs]..[toMs] the boost covers.
  int boostedMs(int fromMs, int toMs) {
    if (toMs <= fromMs || untilMs <= fromMs) return 0;
    return (toMs < untilMs ? toMs : untilMs) - fromMs;
  }

  /// [visits] seen at [nowMs] on KST [today]: the new state and the visits
  /// that gave time (the rest were over the day's limit or already seen).
  (FriendBoost, List<FriendVisitArrival>) apply(List<FriendVisitArrival> visits, FriendVisitRules rules,
      {required int nowMs, required String today}) {
    var until = untilMs, count = day == today ? dayCount : 0;
    final seen = {for (final e in applied.entries) if (nowMs - e.value < appliedKeepMs) e.key: e.value};
    final gave = <FriendVisitArrival>[];
    for (final v in visits) {
      if (v.id.isEmpty || seen.containsKey(v.id)) continue;
      seen[v.id] = nowMs;
      if (count >= rules.dailyLimit) continue;
      count++;
      until = (until > nowMs ? until : nowMs) + (v.invite ? rules.inviteMs : rules.visitMs);
      gave.add(v);
    }
    return (FriendBoost(untilMs: until, day: today, dayCount: count, applied: seen), gave);
  }

  Map<String, dynamic> toJson() => {'untilMs': untilMs, 'day': day, 'dayCount': dayCount,
    'applied': Map<String, int>.fromEntries(applied.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))};

  /// Checks a saved boost against [rules]: no more time than a day's
  /// visits could give after the last one seen.
  factory FriendBoost.fromJson(Object? row, FriendVisitRules rules) {
    if (row is! Map<String, dynamic> || row['day'] is! String || row['applied'] is! Map<String, dynamic>) {
      throw const FormatException('친구 방문 저장 형식 오류');
    }
    final until = DevelopmentBalance.integer(row, 'untilMs'), count = DevelopmentBalance.integer(row, 'dayCount');
    final applied = <String, int>{};
    for (final e in (row['applied'] as Map<String, dynamic>).entries) {
      if (e.key.isEmpty || e.value is! int || (e.value as int) < 0) throw const FormatException('친구 방문 기록 오류');
      applied[e.key] = e.value as int;
    }
    // A save written later than this device's clock is fine (clock moved
    // back); only time no visits could give is rejected.
    final latest = applied.values.fold(0, (a, b) => a > b ? a : b);
    if (count > rules.dailyLimit || (until > 0 && applied.isEmpty) ||
        until > latest + rules.dailyLimit * rules.inviteMs) {
      throw const FormatException('친구 방문 부스트 근거 오류');
    }
    return FriendBoost(untilMs: until, day: row['day'] as String, dayCount: count, applied: applied);
  }
}
