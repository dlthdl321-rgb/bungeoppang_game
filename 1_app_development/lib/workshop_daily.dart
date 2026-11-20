import 'dart:convert';
import 'development_balance.dart';
import 'workshop_arrivals.dart' show arrivalSeed;

/// 26번 7단계 — 매일 돌아올 이유 (DEC-047, S7-Q1~Q3).
///
/// Four small things bring the player back each day, all on the KST day of
/// the settled business time (`businessDayKst(business.settledUtc)`), which
/// only moves forward: turning the device clock back never reopens a day.
///
/// * 오늘의 주문서: one order a day (flavor, doneness, 1~2), handed over from
///   stock while the business is open. Buns and the requester's affinity,
///   never gold.
/// * 출석: seven stamps; the first stamp of a KST day takes the next box, a
///   missed day does not reset it, after the seventh it starts again at 1.
///   Days 1~6 give buns, day 7 one gold through the server wallet.
/// * 이야기 하루 한 조각: see [WorkshopController] (`story_daily_limit`).
/// * 겨울 행사: dates only in `daily_return.seasonal_events`.

/// A dated event from `daily_return.seasonal_events`.
class SeasonalEvent {
  final String id, kind, label, start, end, decoration, greeting, orderNote;
  const SeasonalEvent({required this.id, required this.kind, required this.label, required this.start,
      required this.end, required this.decoration, required this.greeting, required this.orderNote});
  /// Whether the KST [day] ('yyyy-mm-dd') is inside the event, both ends included.
  bool covers(String day) => start.compareTo(day) <= 0 && day.compareTo(end) <= 0;
}

List<SeasonalEvent> seasonalEvents(DevelopmentBalance config) => [
      for (final raw in (config.section('daily_return')['seasonal_events'] as List).cast<Map<String, dynamic>>())
        SeasonalEvent(id: raw['id'] as String, kind: raw['kind'] as String, label: raw['label'] as String,
            start: raw['start'] as String, end: raw['end'] as String, decoration: raw['decoration'] as String,
            greeting: raw['greeting'] as String, orderNote: raw['order_note'] as String),
    ];

/// The event on [day], or null. The first listed wins when two overlap.
SeasonalEvent? activeSeasonalEvent(DevelopmentBalance config, String day) {
  for (final event in seasonalEvents(config)) {
    if (event.covers(day)) return event;
  }
  return null;
}

bool _isDay(Object? value) => value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse('${value}T00:00:00Z')?.toIso8601String().substring(0, 10) == value;

/// The day's order. [npc] is the named neighbor who asks (null: '동네 손님').
/// When [done], [reward] is the buns paid and [businessIndex] the business
/// day it was handed over on.
class DailyOrder {
  final String day, flavor;
  final String? npc, event, reward;
  final int variant, quantity;
  final int? businessIndex;
  const DailyOrder({required this.day, required this.flavor, required this.variant, required this.quantity,
      this.npc, this.event, this.reward, this.businessIndex});
  bool get done => reward != null;
  DailyOrder delivered(BigInt buns, int businessIndex) => DailyOrder(day: day, flavor: flavor, variant: variant,
      quantity: quantity, npc: npc, event: event, reward: buns.toString(), businessIndex: businessIndex);
  Map<String, dynamic> toJson() => {'day': day, 'npc': npc, 'flavor': flavor, 'variant': variant,
      'quantity': quantity, 'event': event, 'reward': reward, 'businessIndex': businessIndex};
  factory DailyOrder.fromJson(Map<String, dynamic> row) {
    const keys = {'day', 'npc', 'flavor', 'variant', 'quantity', 'event', 'reward', 'businessIndex'};
    if (row.length != keys.length || !keys.every(row.containsKey) || !_isDay(row['day']) ||
        row['flavor'] is! String || (row['npc'] != null && row['npc'] is! String) ||
        (row['event'] != null && row['event'] is! String) ||
        (row['reward'] == null) != (row['businessIndex'] == null)) {
      throw const FormatException('오늘의 주문서 저장 오류');
    }
    final variant = DevelopmentBalance.integer(row, 'variant'), quantity = DevelopmentBalance.integer(row, 'quantity');
    if (variant < 1 || variant > 3 || quantity < 1) throw const FormatException('오늘의 주문서 내용 오류');
    String? reward;
    int? index;
    if (row['reward'] != null) {
      final buns = DevelopmentBalance.decimal(row, 'reward');
      index = DevelopmentBalance.integer(row, 'businessIndex');
      if (buns <= BigInt.zero || index < 1) throw const FormatException('오늘의 주문서 보상 오류');
      reward = buns.toString();
    }
    return DailyOrder(day: row['day'] as String, flavor: row['flavor'] as String, variant: variant,
        quantity: quantity, npc: row['npc'] as String?, event: row['event'] as String?, reward: reward,
        businessIndex: index);
  }
}

/// The saved daily state (Workshop schema 10, `daily`).
class WorkshopDaily {
  /// The last KST day seen after the first-run guide.
  final String? day;
  final DailyOrder? order;
  /// Stamps in the current seven-day card (0~7) and the day of the last one.
  final int stamps;
  final String? stampDay;
  /// Seasonal events the player has been in (for `event_join`, once each).
  final Set<String> events;
  const WorkshopDaily({this.day, this.order, this.stamps = 0, this.stampDay, this.events = const {}});
  static const empty = WorkshopDaily();
  WorkshopDaily copyWith({String? day, DailyOrder? order, int? stamps, String? stampDay, Set<String>? events}) =>
      WorkshopDaily(day: day ?? this.day, order: order ?? this.order, stamps: stamps ?? this.stamps,
          stampDay: stampDay ?? this.stampDay, events: events ?? this.events);
  Map<String, dynamic> toJson() => {'day': day, 'order': order?.toJson(), 'stamps': stamps,
      'stampDay': stampDay, 'events': events.toList()..sort()};
  /// [today] is the newest KST day the save may know (its settled time).
  factory WorkshopDaily.fromJson(Object? raw, DevelopmentBalance config, {required String today}) {
    const keys = {'day', 'order', 'stamps', 'stampDay', 'events'};
    if (raw is! Map<String, dynamic> || raw.length != keys.length || !keys.every(raw.containsKey)) {
      throw const FormatException('매일 기록 저장 오류');
    }
    final day = raw['day'], stampDay = raw['stampDay'], events = raw['events'];
    final stamps = DevelopmentBalance.integer(raw, 'stamps');
    final cycle = DevelopmentBalance.integer(config.section('daily_return')['attendance'] as Map<String, dynamic>, 'cycle_days');
    final known = {for (final e in seasonalEvents(config)) e.id};
    if ((day != null && (!_isDay(day) || (day as String).compareTo(today) > 0)) ||
        (stampDay != null && (!_isDay(stampDay) || (stampDay as String).compareTo(today) > 0)) ||
        stamps > cycle || (stamps == 0) != (stampDay == null) ||
        events is! List || events.any((e) => e is! String || !known.contains(e)) || events.toSet().length != events.length) {
      throw const FormatException('매일 기록 내용 오류');
    }
    final order = raw['order'] == null ? null
        : raw['order'] is Map<String, dynamic> ? DailyOrder.fromJson(raw['order'] as Map<String, dynamic>)
        : throw const FormatException('오늘의 주문서 저장 오류');
    if (order != null && (order.day.compareTo(today) > 0 || (order.event != null && !known.contains(order.event)))) {
      throw const FormatException('오늘의 주문서 날짜 오류');
    }
    return WorkshopDaily(day: day as String?, order: order, stamps: stamps, stampDay: stampDay as String?,
        events: events.cast<String>().toSet());
  }
}

/// Today's order, fixed by the day and the install ([runId]): the same day
/// always asks for the same thing, whenever it is first seen.
/// [flavors] are the owned recipes, [neighbors] the named guests met, both
/// in a stable order.
DailyOrder makeDailyOrder(DevelopmentBalance config, {required String day, required String runId,
    required List<String> flavors, required List<String> neighbors, SeasonalEvent? event}) {
  if (flavors.isEmpty) throw const FormatException('주문서에 쓸 레시피가 없어요.');
  final rule = config.section('daily_return')['special_order'] as Map<String, dynamic>;
  final h = arrivalSeed('$runId:$day', 47);
  return DailyOrder(day: day, flavor: flavors[h % flavors.length], variant: 1 + (h >> 7) % 3,
      quantity: 1 + (h >> 11) % DevelopmentBalance.integer(rule, 'quantity_max'),
      npc: neighbors.isEmpty ? null : neighbors[(h >> 15) % neighbors.length], event: event?.id);
}

/// The income per second daily rewards use (4차 피드백 g7, 경제 재조정):
/// R = tap power × `daily_return.rate_taps_per_second` + auto production.
/// Auto production alone fell to about a quarter of income after the skill
/// rebalance, so rewards follow both. The server bound uses the same R
/// (`plausibility_validator.ts`).
BigInt dailyIncomeRate(DevelopmentBalance config, {required BigInt tapRate, required BigInt autoRate}) =>
    tapRate * BigInt.from(DevelopmentBalance.integer(config.section('daily_return'), 'rate_taps_per_second')) + autoRate;

/// Buns for a job: [seconds] of the income [rate], at least [minimum].
BigInt dailyBuns(BigInt rate, int seconds, BigInt minimum) {
  final buns = rate * BigInt.from(seconds);
  return buns > minimum ? buns : minimum;
}

/// The attendance gold claim (`pendingGold['attendance:<day>']`), verified by
/// the server like a mission claim.
String attendanceClaim(DevelopmentBalance config, String day) => jsonEncode({'scope': 'attendance', 'period': day,
    'goal': 'day7', 'gold': DevelopmentBalance.integer(config.section('daily_return')['attendance'] as Map<String, dynamic>, 'gold'),
    'revision': config.revision});
