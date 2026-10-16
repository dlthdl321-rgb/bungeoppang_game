import 'dart:convert';

/// Development-only numeric contract. Existing purchases must not silently use
/// this catalog: the server quote/recovery protocol is a separate integration.
class DevelopmentBalance {
  final Map<String, dynamic> _data;
  DevelopmentBalance._(this._data);

  factory DevelopmentBalance.fromJson(Map<String, dynamic> json) {
    // Copy caller-owned structures so later edits cannot change an active quote.
    final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    final result = DevelopmentBalance._(copy);
    if (result.section('metadata')['schema_version'] != 1) {
      throw const FormatException('지원하지 않는 수치 설정 버전');
    }
    final fixed = result.section('fixed_requirements');
    const requirements = {
      'max_level': 50, 'griddle_slots': 6, 'doneness_stages': 5,
      'mastery_discoveries_required': 5, 'inventory_expiry_business_days': 5,
      'offline_cap_ms': 28800000, 'offline_efficiency_permille': 500,
      'rewarded_ads_per_account_day': 2, 'ad_timezone_offset_minutes': 540,
      'pause_customer_timer_during_ad': true,
      'pause_manual_cooking_timer_during_ad': true,
      'pause_griddle_timer_during_ad': true,
    };
    for (final entry in requirements.entries) {
      if (fixed[entry.key] != entry.value ||
          fixed[entry.key].runtimeType != entry.value.runtimeType) {
        throw FormatException('확정 수치 변경: ${entry.key}');
      }
    }
    if (result.revision.isEmpty) throw const FormatException('가격 버전 누락');
    final purchase = result.section('skill_purchase');
    if (integer(purchase, 'max_owned_per_skill') <= 0 ||
        integer(purchase, 'gold_step_purchase_count') <= 0) {
      throw const FormatException('잘못된 구매 회차');
    }
    final entries = _map(purchase['entries']);
    if (entries.length != 32) throw const FormatException('스킬 가격 개수 오류');
    for (final kind in ['tap', 'auto']) {
      for (var i = 1; i <= 16; i++) {
        final row = _map(entries['${kind}_$i']);
        if (decimal(row, 'buns') <= BigInt.zero || integer(row, 'gold') <= 0 ||
            integer(row, 'ratio_denominator') <= 0 ||
            integer(row, 'ratio_numerator') < integer(row, 'ratio_denominator')) {
          throw const FormatException('잘못된 스킬 가격');
        }
      }
    }
    for (final name in ['cosmetic_purchase', 'boost_purchase']) {
      for (final value in result.section(name).values) {
        final row = _map(value);
        if (decimal(row, 'buns') <= BigInt.zero || integer(row, 'gold') <= 0) {
          throw const FormatException('두 재화 가격 누락');
        }
      }
    }
    final boundaries = result.integers('doneness', 'boundary_permille');
    if (boundaries.length != 4 || boundaries.first <= 0 ||
        List.generate(3, (i) => boundaries[i] >= boundaries[i + 1]).any((v) => v)) {
      throw const FormatException('익힘 경계 오류');
    }
    for (final item in result.rows('mastery_difficulties')) {
      if (integer(item, 'practice_required') < integer(item, 'technique_passes_required') ||
          integer(item, 'technique_passes_required') <= 0 ||
          integer(item, 'doneness_target_ms') <= 0) {
        throw const FormatException('숙련 수치 오류');
      }
    }
    final levels = result.rows('level_progression');
    if (levels.length != 50) throw const FormatException('레벨 표 누락');
    var last = BigInt.from(-1);
    for (var i = 0; i < levels.length; i++) {
      final total = decimal(levels[i], 'season_total_buns');
      if (integer(levels[i], 'level') != i + 1 || total <= last) {
        throw const FormatException('레벨 목표 순서 오류');
      }
      last = total;
    }
    return result;
  }

  String get revision {
    final value = section('metadata')['revision'];
    if (value is! String) throw const FormatException('수치 버전 오류');
    return value;
  }

  // Return copies: consumers must not mutate the validated source.
  Map<String, dynamic> section(String key) =>
      _map(jsonDecode(jsonEncode(_data[key])));
  List<Map<String, dynamic>> rows(String key) {
    final list = _data[key];
    if (list is! List) throw FormatException('목록 누락: $key');
    return [for (final row in list) _map(jsonDecode(jsonEncode(row)))];
  }

  List<int> integers(String sectionKey, String key) {
    final value = section(sectionKey)[key];
    if (value is! List || value.any((v) => v is! int || v < 0)) {
      throw FormatException('정수 목록 오류: $key');
    }
    return List<int>.unmodifiable(value.cast<int>());
  }

  Map<String, dynamic> skill(String id) =>
      _map(_map(section('skill_purchase')['entries'])[id]);
  Map<String, dynamic> mastery(int difficulty) => rows('mastery_difficulties')
      .firstWhere((r) => integer(r, 'difficulty') == difficulty,
          orElse: () => throw const FormatException('난이도 누락'));

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('설정 항목 누락');
    return value;
  }

  static int integer(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int || value < 0) throw FormatException('정수 오류: $key');
    return value;
  }

  static BigInt decimal(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value)) {
      throw FormatException('재화 문자열 오류: $key');
    }
    return BigInt.parse(value);
  }
}
