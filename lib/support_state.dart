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

class ActiveItem {
  final String id;
  final EffectChannel channel;
  final BigInt multiplierPermille;
  final DateTime startedAtUtc, endsAtUtc;
  const ActiveItem(this.id, this.channel, this.multiplierPermille,
      this.startedAtUtc, this.endsAtUtc);
  int remainingMs(DateTime now) {
    final remaining = endsAtUtc.difference(now).inMilliseconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool activeAt(DateTime now) =>
      !now.isBefore(startedAtUtc) && now.isBefore(endsAtUtc);
  Map<String, dynamic> toJson(DateTime now) => {
        'id': id,
        'channel': channel.name,
        'multiplierPermille': '$multiplierPermille',
        'startedAtUtc': startedAtUtc.toIso8601String(),
        'endsAtUtc': endsAtUtc.toIso8601String(),
        'remainingMs': remainingMs(now)
      };
  factory ActiveItem.fromJson(Map<String, dynamic> m, DateTime now) {
    final start = readUtc(m['startedAtUtc']), end = readUtc(m['endsAtUtc']);
    final factor = readNatural(m['multiplierPermille']);
    if (!itemDefinitions.any((d) => d.id == m['id']) ||
        !EffectChannel.values.any((v) => v.name == m['channel']) ||
        end.isBefore(start) ||
        factor < BigInt.from(effectScale)) {
      throw const FormatException('아이템 효과 손상');
    }
    final result = ActiveItem(
        m['id'] as String,
        EffectChannel.values.firstWhere((v) => v.name == m['channel']),
        factor,
        start,
        end);
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
  final Map<String, BigInt> inventory, itemUses;
  final Map<String, ActiveItem> effects;
  final Map<String, CoinTransaction> ledger;
  int purchaseSequence = 0;
  SupportState._(this.observedUtc, this.daily, this.inventory, this.itemUses,
      this.effects, this.ledger);
  factory SupportState.initial(DateTime now,
      {BigInt? legacyStars, BigInt? legacyFraction}) {
    final s = SupportState._(now.toUtc(), DailyState(dailyKey(now)), {
      for (final i in itemDefinitions) i.id: BigInt.parse(i.starterQuantity)
    }, {
      for (final i in itemDefinitions) i.id: BigInt.zero
    }, {}, {});
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

  BigInt multiplier(EffectChannel channel, DateTime now) {
    var factor = BigInt.from(effectScale);
    for (final effect in effects.values) {
      if (effect.channel == channel && effect.activeAt(now)) {
        factor = factor * effect.multiplierPermille ~/ BigInt.from(effectScale);
      }
    }
    return factor;
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
        'inventory': {for (final e in inventory.entries) e.key: '${e.value}'},
        'itemUses': {for (final e in itemUses.entries) e.key: '${e.value}'},
        'effects': {
          for (final e in effects.entries) e.key: e.value.toJson(observedUtc)
        },
        'ledger': [for (final t in ledger.values) t.toJson()],
        'purchaseSequence': purchaseSequence
      };
  factory SupportState.fromJson(Map<String, dynamic> m) {
    if (m['configVersion'] != supportConfigVersion ||
        m['daily'] is! Map ||
        m['inventory'] is! Map ||
        m['itemUses'] is! Map ||
        m['effects'] is! Map ||
        m['ledger'] is! List ||
        m['purchaseSequence'] is! int ||
        (m['purchaseSequence'] as int) < 0) {
      throw const FormatException('보조 진행 저장 손상');
    }
    final at = readUtc(m['observedUtc']);
    final s = SupportState._(
        at, DailyState.fromJson(Map<String, dynamic>.from(m['daily'] as Map)), {
      for (final i in itemDefinitions)
        i.id: readNatural((m['inventory'] as Map)[i.id])
    }, {
      for (final i in itemDefinitions)
        i.id: readNatural((m['itemUses'] as Map)[i.id])
    }, {}, {});
    s.coins = readNatural(m['coins']);
    s.autoFraction = readNatural(m['autoFraction']);
    s.tapFraction = readNatural(m['tapFraction']);
    s.purchaseSequence = m['purchaseSequence'] as int;
    if (s.autoFraction >= BigInt.from(productionQuantum) ||
        s.tapFraction >= BigInt.from(effectScale) ||
        s.daily.day != dailyKey(at)) {
      throw const FormatException('진행 나머지/날짜 손상');
    }
    for (final entry in (m['effects'] as Map).entries) {
      if (entry.value is! Map) throw const FormatException('효과 저장 손상');
      final e = ActiveItem.fromJson(
          Map<String, dynamic>.from(entry.value as Map), at);
      if (entry.key != e.id) throw const FormatException('효과 ID 불일치');
      s.effects[e.id] = e;
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
