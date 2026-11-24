import 'development_balance.dart';
import 'development_business.dart';

/// 26번 5-1단계: customers come in real time, the app on or off.
///
/// Two clocks run apart: regular (anonymous) guests every
/// `customer_arrivals.regular_min_ms`..`regular_max_ms` and named neighbors
/// every `named_min_ms`..`named_max_ms`. Each interval is fixed in advance by
/// the clock's seed and draw count, so the time a notification is scheduled
/// for is the time the guest really arrives. A clock stops (`nextAt` null)
/// while its places (`regular_slots`/`named_slots`) are full and starts again,
/// counting from that moment, once a place frees up.
class ArrivalClock {
  /// UTC milliseconds of the next arrival, or null while stopped.
  final int? nextAt;
  final int seed, draws;
  const ArrivalClock({required this.seed, this.nextAt, this.draws = 0});
  ArrivalClock withNext(int? next) => ArrivalClock(seed: seed, nextAt: next, draws: draws);
  /// The interval of the current draw, between [min] and [max] inclusive.
  int interval(int min, int max) => min + arrivalHash(seed, draws, 0) % (max - min + 1);
  /// The named-neighbor pick for the current draw.
  int get pick => arrivalHash(seed, draws, 1);
  Map<String, dynamic> toJson() => {'nextAt': nextAt, 'seed': seed, 'draws': draws};
  factory ArrivalClock.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) throw const FormatException('손님 시계 저장 오류');
    final next = raw['nextAt'], seed = raw['seed'], draws = raw['draws'];
    if (seed is! int || seed < 0 || seed > 0x7FFFFFFF || draws is! int || draws < 0 ||
        (next != null && (next is! int || next < 0)) || raw.length != 3) {
      throw const FormatException('손님 시계 저장 오류');
    }
    return ArrivalClock(seed: seed, nextAt: next as int?, draws: draws);
  }
  @override
  bool operator ==(Object other) => other is ArrivalClock && other.nextAt == nextAt && other.seed == seed && other.draws == draws;
  @override
  int get hashCode => Object.hash(nextAt, seed, draws);
}

int _mix32(int h) {
  h &= 0xFFFFFFFF;
  h ^= h >> 16;
  h = (h * 0x7FEB352D) & 0xFFFFFFFF;
  h ^= h >> 15;
  h = (h * 0x846CA68B) & 0xFFFFFFFF;
  h ^= h >> 16;
  return h;
}

/// A fixed 31-bit hash of (seed, draw, salt). The same save always draws the
/// same intervals and picks, on every device.
int arrivalHash(int seed, int draw, int salt) =>
    _mix32(_mix32(_mix32(seed ^ 0x9E3779B9) ^ (draw & 0xFFFFFFFF)) ^ (salt * 0x85EBCA6B)) & 0x7FFFFFFF;

/// A seed made from a text such as the save's run id.
int arrivalSeed(String text, int salt) {
  var h = 0x811C9DC5 ^ salt;
  for (final unit in text.codeUnits) { h = _mix32(h ^ unit); }
  return h & 0x7FFFFFFF;
}

/// The UTC moment the KST business [day] ('yyyy-mm-dd') ends.
DateTime kstMidnightAfter(String day) {
  final start = DateTime.parse('${day}T00:00:00Z');
  return DateTime.utc(start.year, start.month, start.day + 1).subtract(const Duration(hours: 9));
}

enum ArrivalKind { regular, named, newDay }

class ArrivalEvent {
  final ArrivalKind kind;
  /// UTC milliseconds.
  final int at;
  const ArrivalEvent(this.kind, this.at);
  @override
  String toString() => '$kind@$at';
}

/// One guest the clocks will bring if nobody leaves before then.
class PlannedArrival {
  final ArrivalKind kind;
  final DateTime at;
  /// The named neighbor's id; null for a regular guest.
  final String? npc;
  const PlannedArrival(this.kind, this.at, [this.npc]);
}

/// The arrival rules from `customer_arrivals`. Pure: the controller applies
/// each event (a guest, or the business day turning over at KST midnight).
class WorkshopArrivals {
  final int regularMin, regularMax, namedMin, namedMax, regularSlots, namedSlots;
  const WorkshopArrivals({required this.regularMin, required this.regularMax, required this.namedMin,
      required this.namedMax, required this.regularSlots, required this.namedSlots});
  factory WorkshopArrivals.of(DevelopmentBalance config) {
    final rules = config.section('customer_arrivals');
    int v(String key) => DevelopmentBalance.integer(rules, key);
    return WorkshopArrivals(regularMin: v('regular_min_ms'), regularMax: v('regular_max_ms'),
        namedMin: v('named_min_ms'), namedMax: v('named_max_ms'),
        regularSlots: v('regular_slots'), namedSlots: v('named_slots'));
  }
  int slots(ArrivalKind kind) => kind == ArrivalKind.named ? namedSlots : regularSlots;
  int maxInterval(ArrivalKind kind) => kind == ArrivalKind.named ? namedMax : regularMax;
  int intervalOf(ArrivalClock clock, ArrivalKind kind) => kind == ArrivalKind.named
      ? clock.interval(namedMin, namedMax) : clock.interval(regularMin, regularMax);

  /// Starts a stopped clock that has a free place, counting from [at]
  /// (a sale, a guest leaving, opening, or the end of the first-run guide).
  ArrivalClock resume(ArrivalClock clock, ArrivalKind kind, {required int waiting, required int at}) =>
      clock.nextAt == null && waiting < slots(kind) ? clock.withNext(at + intervalOf(clock, kind)) : clock;

  /// The clock after its guest came at [at] (or was skipped); [waiting]
  /// already counts that guest. Full places stop the clock.
  ArrivalClock arrived(ArrivalClock clock, ArrivalKind kind, {required int waiting, required int at}) {
    final next = ArrivalClock(seed: clock.seed, draws: clock.draws + 1);
    return waiting < slots(kind) ? next.withNext(at + intervalOf(next, kind)) : next;
  }

  /// The earliest event at or before [until]: a regular or named guest, or,
  /// for an open business, the KST midnight after [acceptedDay]. However many
  /// midnights passed, the business day turns over once (S5-1-Q3); the
  /// midnight comes first when times tie.
  ArrivalEvent? next({required ArrivalClock regular, required ArrivalClock named,
      required bool open, required String? acceptedDay, required int until}) {
    ArrivalEvent? best;
    void consider(ArrivalKind kind, int? at) {
      if (at == null || at > until) return;
      if (best == null || at < best!.at) best = ArrivalEvent(kind, at);
    }
    if (open && acceptedDay != null &&
        businessDayKst(DateTime.fromMillisecondsSinceEpoch(until, isUtc: true)) != acceptedDay) {
      consider(ArrivalKind.newDay, kstMidnightAfter(acceptedDay).millisecondsSinceEpoch);
    }
    consider(ArrivalKind.regular, regular.nextAt);
    consider(ArrivalKind.named, named.nextAt);
    return best;
  }

  /// The guests the clocks bring from [from] for [horizonMs] if nobody is
  /// served: at most the free places of each kind. [nameAt] picks the named
  /// neighbor exactly as the arrival will (null skips that draw).
  List<PlannedArrival> preview({required ArrivalClock regular, required ArrivalClock named,
      required int regularWaiting, required int namedWaiting, required int from, required int horizonMs,
      required String? Function(ArrivalClock clock, int at) nameAt}) {
    final end = from + horizonMs, result = <PlannedArrival>[];
    for (final kind in [ArrivalKind.regular, ArrivalKind.named]) {
      var clock = resume(kind == ArrivalKind.named ? named : regular, kind,
          waiting: kind == ArrivalKind.named ? namedWaiting : regularWaiting, at: from);
      var waiting = kind == ArrivalKind.named ? namedWaiting : regularWaiting;
      // Each turn either fills a place or skips one draw; a guard keeps a
      // clock whose every draw is skipped from looping for ever.
      for (var guard = 0; guard < 1000; guard++) {
        final at = clock.nextAt;
        if (at == null || at > end) break;
        String? npc;
        if (kind == ArrivalKind.named) {
          npc = nameAt(clock, at);
          if (npc != null) waiting++;
        } else {
          waiting++;
        }
        if (kind == ArrivalKind.regular || npc != null) {
          result.add(PlannedArrival(kind, DateTime.fromMillisecondsSinceEpoch(at, isUtc: true), npc));
        }
        clock = arrived(clock, kind, waiting: waiting, at: at);
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }
}
