import 'achievement_config.dart';
import 'support_config.dart';
import 'support_state.dart';
import 'weekly_config.dart';

/// KST Monday (YYYY-MM-DD) of the week containing [utc].
String weekKey(DateTime utc) {
  final local = utc.toUtc().add(const Duration(minutes: dailyUtcOffsetMinutes));
  return DateTime.utc(local.year, local.month, local.day - (local.weekday - 1))
      .toIso8601String()
      .substring(0, 10);
}

DateTime weekStartUtc(String week) => DateTime.parse('${week}T00:00:00Z')
    .subtract(const Duration(minutes: dailyUtcOffsetMinutes));
DateTime weekEndUtc(String week) =>
    weekStartUtc(week).add(const Duration(days: 7));

int _readCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('잘못된 기록 수치');
  }
  return value;
}

String? _readDay(Object? value) {
  if (value == null) return null;
  final day = '$value', date = DateTime.tryParse(day);
  if (date == null || date.toIso8601String().substring(0, 10) != day) {
    throw const FormatException('잘못된 기록 날짜');
  }
  return day;
}

/// Personal records. Only this device's own play; never compared to others.
class RecordState {
  BigInt bestAutoRate, lifetimeTaps, pastBestDayProduction;
  String? pastBestDay, lastPlayDay;
  int todayBestCombo, pastBestCombo, playDays, newRecordDays;
  RecordState(
      {required this.bestAutoRate,
      required this.lifetimeTaps,
      required this.pastBestDayProduction,
      required this.pastBestDay,
      required this.lastPlayDay,
      required this.todayBestCombo,
      required this.pastBestCombo,
      required this.playDays,
      required this.newRecordDays});
  factory RecordState.initial() => RecordState(
      bestAutoRate: BigInt.zero,
      lifetimeTaps: BigInt.zero,
      pastBestDayProduction: BigInt.zero,
      pastBestDay: null,
      lastPlayDay: null,
      todayBestCombo: 0,
      pastBestCombo: 0,
      playDays: 0,
      newRecordDays: 0);

  int get bestCombo =>
      todayBestCombo > pastBestCombo ? todayBestCombo : pastBestCombo;

  /// Counts a play day once; never reopens an earlier day.
  void touchDay(String day) {
    final last = lastPlayDay;
    if (last != null && day.compareTo(last) <= 0) return;
    lastPlayDay = day;
    playDays++;
  }

  /// Folds a finished day's totals into the "before today" bests.
  void closeDay(String day, BigInt production) {
    if (production > pastBestDayProduction) {
      if (pastBestDayProduction > BigInt.zero) newRecordDays++;
      pastBestDayProduction = production;
      pastBestDay = day;
    }
    if (todayBestCombo > pastBestCombo) pastBestCombo = todayBestCombo;
    todayBestCombo = 0;
  }

  Map<String, dynamic> toJson() => {
        'bestAutoRate': '$bestAutoRate',
        'lifetimeTaps': '$lifetimeTaps',
        'pastBestDayProduction': '$pastBestDayProduction',
        'pastBestDay': pastBestDay,
        'lastPlayDay': lastPlayDay,
        'todayBestCombo': todayBestCombo,
        'pastBestCombo': pastBestCombo,
        'playDays': playDays,
        'newRecordDays': newRecordDays,
      };
  factory RecordState.fromJson(Map<String, dynamic> m) => RecordState(
      bestAutoRate: readNatural(m['bestAutoRate']),
      lifetimeTaps: readNatural(m['lifetimeTaps']),
      pastBestDayProduction: readNatural(m['pastBestDayProduction']),
      pastBestDay: _readDay(m['pastBestDay']),
      lastPlayDay: _readDay(m['lastPlayDay']),
      todayBestCombo: _readCount(m['todayBestCombo']),
      pastBestCombo: _readCount(m['pastBestCombo']),
      playDays: _readCount(m['playDays']),
      newRecordDays: _readCount(m['newRecordDays']));
}

/// The running weekly challenge. A later week replaces it automatically.
class WeeklyState {
  String week;
  BigInt taps = BigInt.zero,
      purchases = BigInt.zero,
      dailyAllClears = BigInt.zero;
  int playDays = 0;
  String? lastPlayDay;
  Set<String> claimed = {};
  WeeklyState(this.week);
  factory WeeklyState.initial(DateTime now) => WeeklyState(weekKey(now));

  void rollTo(DateTime now) {
    final key = weekKey(now);
    if (key.compareTo(week) <= 0) return; // Never reopen a finished week.
    week = key;
    taps = purchases = dailyAllClears = BigInt.zero;
    playDays = 0;
    lastPlayDay = null;
    claimed = {};
  }

  void touchDay(String day) {
    final last = lastPlayDay;
    if (last != null && day.compareTo(last) <= 0) return;
    lastPlayDay = day;
    playDays++;
  }

  BigInt progress(WeeklyMetric metric) => switch (metric) {
        WeeklyMetric.taps => taps,
        WeeklyMetric.playDays => BigInt.from(playDays),
        WeeklyMetric.purchases => purchases,
        WeeklyMetric.dailyAllClears => dailyAllClears,
      };

  Map<String, dynamic> toJson() => {
        'configVersion': weeklyConfigVersion,
        'week': week,
        'taps': '$taps',
        'purchases': '$purchases',
        'dailyAllClears': '$dailyAllClears',
        'playDays': playDays,
        'lastPlayDay': lastPlayDay,
        'claimed': claimed.toList(),
      };
  factory WeeklyState.fromJson(Map<String, dynamic> m) {
    final week = _readDay(m['week']);
    final ids = m['claimed'];
    if (m['configVersion'] != weeklyConfigVersion ||
        week == null ||
        DateTime.parse(week).weekday != DateTime.monday ||
        ids is! List ||
        ids.any((v) => !weeklyGoals.any((g) => g.id == v)) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('잘못된 주간 도전');
    }
    final s = WeeklyState(week)
      ..taps = readNatural(m['taps'])
      ..purchases = readNatural(m['purchases'])
      ..dailyAllClears = readNatural(m['dailyAllClears'])
      ..playDays = _readCount(m['playDays'])
      ..lastPlayDay = _readDay(m['lastPlayDay'])
      ..claimed = ids.cast<String>().toSet();
    if (s.playDays > 7) throw const FormatException('잘못된 주간 접속일');
    return s;
  }
}

class AchievementState {
  final Set<String> claimed;
  String? equippedTitle;
  AchievementState([Set<String>? claimed, this.equippedTitle])
      : claimed = claimed ?? {};

  Set<String> get titles => {
        for (final d in achievementDefinitions)
          if (claimed.contains(d.id) && d.titleReward != null) d.titleReward!
      };

  Map<String, dynamic> toJson() =>
      {'claimed': claimed.toList(), 'equippedTitle': equippedTitle};
  factory AchievementState.fromJson(Map<String, dynamic> m) {
    final ids = m['claimed'], title = m['equippedTitle'];
    if (ids is! List ||
        ids.any((v) => !achievementDefinitions.any((d) => d.id == v)) ||
        ids.toSet().length != ids.length ||
        (title != null && title is! String)) {
      throw const FormatException('잘못된 업적 기록');
    }
    final s = AchievementState(ids.cast<String>().toSet(), title as String?);
    if (title != null && !s.titles.contains(title)) {
      throw const FormatException('보유하지 않은 칭호');
    }
    return s;
  }
}

/// Prestige ("새 노점 열기") progress. Survives every reset.
class PrestigeState {
  int stars, count;
  DateTime? lastAtUtc;
  PrestigeState({this.stars = 0, this.count = 0, this.lastAtUtc});
  Map<String, dynamic> toJson() => {
        'stars': stars,
        'count': count,
        'lastAtUtc': lastAtUtc?.toIso8601String(),
      };
  factory PrestigeState.fromJson(Map<String, dynamic> m) {
    final stars = _readCount(m['stars']), count = _readCount(m['count']);
    final at = m['lastAtUtc'] == null ? null : readUtc(m['lastAtUtc']);
    if ((count == 0) != (at == null) || (count == 0 && stars != 0)) {
      throw const FormatException('잘못된 새 노점 기록');
    }
    return PrestigeState(stars: stars, count: count, lastAtUtc: at);
  }
}
