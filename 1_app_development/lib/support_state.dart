import 'support_config.dart';

BigInt readNatural(Object? value) {
  final n = BigInt.tryParse('$value');
  if (n == null || n.isNegative) throw const FormatException('잘못된 보조 진행 수량');
  return n;
}

DateTime readUtc(Object? value) {
  final t = DateTime.tryParse('$value');
  if (t == null) throw const FormatException('잘못된 보조 진행 시각');
  return t.toUtc();
}

String dailyKey(DateTime utc) => utc
    .toUtc()
    .add(const Duration(minutes: dailyUtcOffsetMinutes))
    .toIso8601String()
    .substring(0, 10);
DateTime nextDailyReset(DateTime utc) {
  final local = utc.toUtc().add(const Duration(minutes: dailyUtcOffsetMinutes));
  return DateTime.utc(local.year, local.month, local.day + 1)
      .subtract(const Duration(minutes: dailyUtcOffsetMinutes));
}

class DailyState {
  String day;
  BigInt taps = BigInt.zero,
      production = BigInt.zero,
      purchases = BigInt.zero,
      peakAuto = BigInt.zero;
  Set<String> claimed = {};
  bool allClaimed = false;
  DailyState(this.day);
  void rollTo(DateTime now) {
    final key = dailyKey(now);
    if (key.compareTo(day) <= 0) return; // Never reopen an already claimed day.
    day = key;
    taps = production = purchases = peakAuto = BigInt.zero;
    claimed = {};
    allClaimed = false;
  }

  BigInt progress(DailyMetric metric) => switch (metric) {
        DailyMetric.taps => taps,
        DailyMetric.production => production,
        DailyMetric.purchases => purchases,
        DailyMetric.autoRate => peakAuto,
      };
  Map<String, dynamic> toJson() => {
        'day': day,
        'taps': '$taps',
        'production': '$production',
        'purchases': '$purchases',
        'peakAuto': '$peakAuto',
        'claimed': claimed.toList(),
        'allClaimed': allClaimed
      };
  factory DailyState.fromJson(Map<String, dynamic> m) {
    final day = '${m['day']}';
    final date = DateTime.tryParse(day);
    final ids = m['claimed'];
    if (date == null ||
        date.toIso8601String().substring(0, 10) != day ||
        ids is! List ||
        ids.any((v) => !dailyDefinitions.any((d) => d.id == v)) ||
        ids.toSet().length != ids.length ||
        m['allClaimed'] is! bool) {
      throw const FormatException('잘못된 일일 미션');
    }
    return DailyState(day)
      ..taps = readNatural(m['taps'])
      ..production = readNatural(m['production'])
      ..purchases = readNatural(m['purchases'])
      ..peakAuto = readNatural(m['peakAuto'])
      ..claimed = ids.cast<String>().toSet()
      ..allClaimed = m['allClaimed'] as bool;
  }
}

class CoinTransaction {
  final String id, reason;
  final BigInt delta;
  final DateTime atUtc;
  const CoinTransaction(this.id, this.delta, this.reason, this.atUtc);
  Map<String, dynamic> toJson() => {
        'id': id,
        'delta': '$delta',
        'reason': reason,
        'atUtc': atUtc.toIso8601String()
      };
  factory CoinTransaction.fromJson(Map<String, dynamic> m) {
    final delta = BigInt.tryParse('${m['delta']}');
    if (m['id'] is! String ||
        (m['id'] as String).isEmpty ||
        m['reason'] is! String ||
        delta == null) {
      throw const FormatException('코인 원장 손상');
    }
    return CoinTransaction(
        m['id'] as String, delta, m['reason'] as String, readUtc(m['atUtc']));
  }
}

/// A running boost (see [BoostKind]). It multiplies tap and automatic
/// production alike.
class ActiveBoost {
  final BoostKind kind;
  final BigInt multiplierPermille;
  final DateTime startedAtUtc, endsAtUtc;
  const ActiveBoost(
      this.kind, this.multiplierPermille, this.startedAtUtc, this.endsAtUtc);
  String get id => kind.name;
  int remainingMs(DateTime now) {
    final remaining = endsAtUtc.difference(now).inMilliseconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool activeAt(DateTime now) =>
      !now.isBefore(startedAtUtc) && now.isBefore(endsAtUtc);
  Map<String, dynamic> toJson(DateTime now) => {
        'id': id,
        'multiplierPermille': '$multiplierPermille',
        'startedAtUtc': startedAtUtc.toIso8601String(),
        'endsAtUtc': endsAtUtc.toIso8601String(),
        'remainingMs': remainingMs(now)
      };
  factory ActiveBoost.fromJson(Map<String, dynamic> m, DateTime now) {
    final start = readUtc(m['startedAtUtc']), end = readUtc(m['endsAtUtc']);
    final factor = readNatural(m['multiplierPermille']);
    final kind = BoostKind.values.where((k) => k.name == m['id']);
    if (kind.isEmpty ||
        end.isBefore(start) ||
        factor < BigInt.from(effectScale)) {
      throw const FormatException('부스트 효과 손상');
    }
    final result = ActiveBoost(kind.first, factor, start, end);
    if (m['remainingMs'] != result.remainingMs(now)) {
      throw const FormatException('남은 효과 시간 불일치');
    }
    return result;
  }
}

class SupportState {
  BigInt coins = BigInt.zero,
      autoFraction = BigInt.zero,
      tapFraction = BigInt.zero;
  DateTime observedUtc;
  DailyState daily;

  /// Boosts started so far, all kinds (missions and achievements count it).
  BigInt boostUses = BigInt.zero;

  /// Running boosts by [ActiveBoost.id].
  final Map<String, ActiveBoost> effects;

  /// Visits (friend or invite guest) already turned into a boost, so a
  /// visit the server delivers again is never applied twice.
  final Set<String> appliedVisits;
  final Map<String, CoinTransaction> ledger;
  int purchaseSequence = 0;
  SupportState._(this.observedUtc, this.daily, this.effects,
      this.appliedVisits, this.ledger);

  /// Oldest applied visits are forgotten past this; the server never
  /// redelivers a visit that old.
  static const appliedVisitLimit = 500;
  factory SupportState.initial(DateTime now,
      {BigInt? legacyStars, BigInt? legacyFraction}) {
    final s =
        SupportState._(now.toUtc(), DailyState(dailyKey(now)), {}, {}, {});
    if (legacyStars != null) {
      s.transact('migration:v4', legacyStars, '기존 별사탕 1:1 이전', now);
    }
    s.autoFraction = (legacyFraction ?? BigInt.zero) * BigInt.from(2000);
    return s;
  }
  DateTime now(DateTime clockNow) =>
      clockNow.isAfter(observedUtc) ? clockNow.toUtc() : observedUtc;
  void observe(DateTime value) {
    if (value.isAfter(observedUtc)) observedUtc = value.toUtc();
    daily.rollTo(observedUtc);
  }

  /// Production factor (permille) at [now]: the strongest running boost.
  BigInt multiplier(DateTime now) {
    var factor = BigInt.from(effectScale);
    for (final effect in effects.values) {
      if (effect.activeAt(now) && effect.multiplierPermille > factor) {
        factor = effect.multiplierPermille;
      }
    }
    return factor;
  }

  /// Starts [boost] at [now], or adds its duration if it is still running.
  void startBoost(BoostDefinition boost, DateTime now) {
    final running = effects[boost.id];
    final duration = Duration(seconds: boost.durationSeconds);
    effects[boost.id] = running != null && running.activeAt(now)
        ? ActiveBoost(boost.kind, running.multiplierPermille,
            running.startedAtUtc, running.endsAtUtc.add(duration))
        : ActiveBoost(boost.kind, BigInt.from(boost.multiplierPermille),
            now.toUtc(), now.toUtc().add(duration));
    boostUses += BigInt.one;
  }

  /// Records that [visitId] was applied; false if it already was.
  bool markVisit(String visitId) {
    if (!appliedVisits.add(visitId)) return false;
    while (appliedVisits.length > appliedVisitLimit) {
      appliedVisits.remove(appliedVisits.first);
    }
    return true;
  }

  bool transact(String id, BigInt delta, String reason, DateTime at) {
    if (ledger.containsKey(id) || coins + delta < BigInt.zero) return false;
    coins += delta;
    ledger[id] = CoinTransaction(id, delta, reason, at.toUtc());
    return true;
  }

  Map<String, dynamic> toJson() => {
        'configVersion': supportConfigVersion,
        'coins': '$coins',
        'autoFraction': '$autoFraction',
        'tapFraction': '$tapFraction',
        'observedUtc': observedUtc.toIso8601String(),
        'daily': daily.toJson(),
        'boostUses': '$boostUses',
        'appliedVisits': appliedVisits.toList(),
        'effects': {
          for (final e in effects.entries) e.key: e.value.toJson(observedUtc)
        },
        'ledger': [for (final t in ledger.values) t.toJson()],
        'purchaseSequence': purchaseSequence
      };
  factory SupportState.fromJson(Map<String, dynamic> m) {
    // support-v1 (before stage 14) kept items: their counts and running
    // item effects are dropped (unreleased, nothing refunded) and past item
    // uses carry over as boost uses.
    final legacy = m['configVersion'] == legacySupportConfigVersion;
    if ((!legacy && m['configVersion'] != supportConfigVersion) ||
        m['daily'] is! Map ||
        (legacy ? m['itemUses'] is! Map : m['appliedVisits'] is! List) ||
        m['effects'] is! Map ||
        m['ledger'] is! List ||
        m['purchaseSequence'] is! int ||
        (m['purchaseSequence'] as int) < 0) {
      throw const FormatException('보조 진행 저장 손상');
    }
    final at = readUtc(m['observedUtc']);
    final visits = legacy ? const <Object?>[] : m['appliedVisits'] as List;
    if (visits.any((v) => v is! String) ||
        visits.length > appliedVisitLimit ||
        visits.toSet().length != visits.length) {
      throw const FormatException('방문 기록 손상');
    }
    final s = SupportState._(
        at,
        DailyState.fromJson(Map<String, dynamic>.from(m['daily'] as Map)),
        {},
        visits.cast<String>().toSet(),
        {});
    s.boostUses = legacy
        ? (m['itemUses'] as Map)
            .values
            .map(readNatural)
            .fold(BigInt.zero, (a, b) => a + b)
        : readNatural(m['boostUses']);
    s.coins = readNatural(m['coins']);
    s.autoFraction = readNatural(m['autoFraction']);
    s.tapFraction = readNatural(m['tapFraction']);
    s.purchaseSequence = m['purchaseSequence'] as int;
    if (s.autoFraction >= BigInt.from(productionQuantum) ||
        s.tapFraction >= BigInt.from(effectScale) ||
        s.daily.day != dailyKey(at)) {
      throw const FormatException('진행 나머지/날짜 손상');
    }
    if (!legacy) {
      for (final entry in (m['effects'] as Map).entries) {
        if (entry.value is! Map) throw const FormatException('효과 저장 손상');
        final e = ActiveBoost.fromJson(
            Map<String, dynamic>.from(entry.value as Map), at);
        if (entry.key != e.id) throw const FormatException('효과 ID 불일치');
        s.effects[e.id] = e;
      }
    }
    var sum = BigInt.zero;
    for (final raw in m['ledger'] as List) {
      if (raw is! Map) throw const FormatException('원장 저장 손상');
      final t = CoinTransaction.fromJson(Map<String, dynamic>.from(raw));
      if (s.ledger.containsKey(t.id)) throw const FormatException('중복 코인 거래');
      s.ledger[t.id] = t;
      sum += t.delta;
      if (sum.isNegative) throw const FormatException('음수 코인 잔액');
    }
    if (sum != s.coins) throw const FormatException('코인 원장 잔액 불일치');
    for (final id in s.daily.claimed) {
      if (!s.ledger.containsKey('daily:${s.daily.day}:$id')) {
        throw const FormatException('일일 수령 원장 누락');
      }
    }
    if (s.daily.allClaimed &&
        !s.ledger.containsKey('daily:${s.daily.day}:all')) {
      throw const FormatException('전체 수령 원장 누락');
    }
    return s;
  }
}
