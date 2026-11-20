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
    integer(purchase, 'gold_step_amount');
    final entries = _map(purchase['entries']);
    if (entries.length != 32) throw const FormatException('스킬 가격 개수 오류');
    for (final kind in ['tap', 'auto']) {
      for (var i = 1; i <= 16; i++) {
        final row = _map(entries['${kind}_$i']);
        if (decimal(row, 'buns') <= BigInt.zero || integer(row, 'gold') < 0 ||
            decimal(row, 'effect') <= BigInt.zero ||
            integer(row, 'ratio_denominator') <= 0 ||
            integer(row, 'ratio_numerator') < integer(row, 'ratio_denominator')) {
          throw const FormatException('잘못된 스킬 가격/효과');
        }
        decimal(row, 'unlock_total');
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
    final missions=result.section('mission_targets'),rewards=result.section('mission_gold_rewards');
    const expectedGoals={'daily':{'taps','production','purchases','auto'},'weekly':{'taps','days','purchases','dailyAll'}};
    if(integer(rewards,'daily_all')<=0) throw const FormatException('미션 보상 누락');
    for(final scope in expectedGoals.entries) {
      final goals=_map(missions[scope.key]);
      if(goals.length!=scope.value.length || !goals.keys.toSet().containsAll(scope.value)) throw const FormatException('확정 미션 구성 변경');
      for(final e in goals.entries) {
        final row=_map(e.value);
        if(row['metric']!=e.key || row['label'] is! String || (row['label'] as String).isEmpty || decimal(row,'target')<=BigInt.zero ||
            row['reward_key'] is! String || integer(rewards,row['reward_key'] as String)<=0) throw const FormatException('미션 목표/보상 오류');
      }
    }
    final avatar=result.section('avatar_catalog');
    // 26번 3차 H42: backgrounds are sold through the same catalog.
    const avatarSlots={'character','skin','hair','top','bottom','shoes','outfit','hat','accessory','tool','background'};
    for(final e in avatar.entries) {
      final row=_map(e.value),level=integer(row,'unlock_level');
      if(row['label'] is! String || (row['label'] as String).isEmpty || !avatarSlots.contains(row['slot']) || row['free'] is! bool ||
          level<1 || level>50 || (row['free']==false && !result.section('cosmetic_purchase').containsKey(e.key))) throw const FormatException('아바타 카탈로그 오류');
      decimal(row,'unlock_total');
    }
    final boundaries = result.integers('doneness', 'boundary_permille');
    if (boundaries.length != 4 || boundaries.first <= 0 ||
        List.generate(3, (i) => boundaries[i] >= boundaries[i + 1]).any((v) => v)) {
      throw const FormatException('익힘 경계 오류');
    }
    final difficulties = result.rows('mastery_difficulties');
    if (difficulties.length != 3 ||
        difficulties.map((r) => integer(r, 'difficulty')).toSet().length != 3 ||
        !difficulties.every((r) => [0, 1, 2].contains(integer(r, 'difficulty')))) {
      throw const FormatException('숙련 난이도 목록 오류');
    }
    if (integer(result.section('doneness'), 'reference_scale') != 1000) {
      throw const FormatException('익힘 배율 오류');
    }
    for (final item in difficulties) {
      if (integer(item, 'practice_required') < integer(item, 'technique_passes_required') ||
          integer(item, 'technique_passes_required') <= 0 ||
          integer(item, 'doneness_target_ms') <= 0 ||
          integer(item, 'success_doneness_min_index') != 1 || integer(item, 'success_doneness_max_index') != 3) {
        throw const FormatException('숙련 수치 오류');
      }
    }
    final recipes = result.section('active_recipes');
    if (recipes.length != 3 || !recipes.keys.toSet().containsAll(['redbean','custard','cocoa'])) {
      throw const FormatException('확정 맛 목록 오류');
    }
    for (final e in recipes.entries) {
      final row = _map(e.value);
      if (row['label'] is! String || (row['label'] as String).isEmpty ||
          integer(row, 'difficulty') > 2 || row['initial'] is! bool ||
          row['initial'] != (e.key == 'redbean')) throw const FormatException('맛 설정 오류');
    }
    final manual = result.section('manual_cooking');
    final brush = integer(manual, 'paint_brush_width_permille');
    final coverage = integer(manual, 'batter_min_coverage_permille');
    if (brush == 0 || brush > 1000 || coverage == 0 || coverage > 1000 ||
        integer(manual, 'paint_overflow_amount_permille') < 1000) {
      throw const FormatException('짤주머니 색칠 수치 오류');
    }
    final turn = integer(manual, 'flip_turn_degrees');
    if (turn == 0 || turn > 720 || integer(manual, 'flip_dead_zone_permille') >= 500 ||
        integer(manual, 'flip_ms') == 0) {
      throw const FormatException('원 그려 뒤집기 수치 오류');
    }
    if (integer(manual, 'checkpoint_ms') == 0 || integer(manual, 'filling_inputs') == 0 ||
        integer(result.section('doneness'), 'reference_medium_stage_index') != 2) {
      throw const FormatException('제작 입력/저장 수치 오류');
    }
    // 26번 4단계: '완벽' 등급은 성공 기준 안쪽(보여 주기 전용).
    final grade = result.section('cooking_grade');
    final perfectCoverage = integer(grade, 'perfect_min_coverage_permille');
    final perfectAmount = integer(grade, 'perfect_max_amount_permille');
    final perfectDoneness = integer(grade, 'perfect_doneness_index');
    if (perfectCoverage < coverage || perfectCoverage > 1000 || perfectAmount < 1000 ||
        perfectAmount > integer(manual, 'paint_overflow_amount_permille') ||
        result.rows('mastery_difficulties').any((row) =>
            perfectDoneness < integer(row, 'success_doneness_min_index') ||
            perfectDoneness > integer(row, 'success_doneness_max_index'))) {
      throw const FormatException('결과 등급 수치 오류');
    }
    final sale = result.section('ordinary_sale');
    if (integer(sale, 'quality_weight_permille') + integer(sale, 'freshness_weight_permille') != 1000) {
      throw const FormatException('만족도 가중치 오류');
    }
    for (final key in ['quality_permille_by_doneness', 'freshness_satisfaction_permille_by_age',
        'freshness_price_permille_by_age']) {
      final values = result.integers('ordinary_sale', key);
      if (values.length != 5 || values.any((v) => v > 1000)) throw const FormatException('판매 계수 오류');
    }
    final levels = result.rows('level_progression');
    if (levels.length != 50) throw const FormatException('레벨 표 누락');
    // 4차 피드백 g9: each level asks for pieces sold and taps in that level
    // and a payment at level-up (no lifetime total); Lv.1 asks nothing and
    // the 붕어빵력 cost never goes down.
    var last = BigInt.zero;
    for (var i = 0; i < levels.length; i++) {
      final row = levels[i], cost = decimal(row, 'level_cost_buns');
      final pieces = integer(row, 'additional_sold_pieces'), gold = integer(row, 'level_cost_gold');
      integer(row, 'additional_taps');
      if (integer(row, 'level') != i + 1 || row.containsKey('season_total_buns') || row.containsKey('additional_sales') ||
          (i == 0 ? cost != BigInt.zero || pieces != 0 || gold != 0 : cost <= BigInt.zero || cost < last || pieces < 1)) {
        throw const FormatException('레벨 조건 표 오류');
      }
      last = cost;
    }
    final relationship = result.section('customer_relationships');
    final thresholds = result.integers('customer_relationships', 'stage_thresholds');
    final cap = integer(relationship, 'affinity_cap');
    if (relationship['provisional'] != true || thresholds.length != 4 || thresholds.first != 0 ||
        thresholds.last > cap || List.generate(3, (i) => thresholds[i] >= thresholds[i+1]).any((v) => v) ||
        integer(relationship, 'choice_chance_basis_points') > 10000 ||
        integer(relationship, 'delay_threshold_permille') > 1000) throw const FormatException('손님 관계 수치 오류');
    for (final key in ['affinity_cap','ordinary_daily_cap','choice_daily_cap','recent_dialogue_limit',
        'return_gap_business_days','new_npcs_daily_limit',
        'choice_first_business_day','choice_gap_business_days','choice_skip_retry_business_days']) {
      if (integer(relationship, key) == 0) throw const FormatException('손님 관계 양수 설정 오류');
    }
    for (final key in ['sale_affinity','corrected_sale_affinity','automatic_dialogue_affinity']) {
      if (integer(relationship, key) > integer(relationship,'ordinary_daily_cap')) throw const FormatException('일반 친밀도 상한 오류');
    }
    final choices = _map(relationship['choice_affinity']);
    if (choices.length != 4 || !choices.keys.toSet().containsAll(['a','b','c','wave']) ||
        integer(choices,'wave') != 0 || !(integer(choices,'a') > integer(choices,'b') && integer(choices,'b') > integer(choices,'c')) ||
        integer(choices,'a') > integer(relationship,'choice_daily_cap')) throw const FormatException('선택 친밀도 설정 오류');
    if (integer(relationship,'new_npcs_daily_limit')!=2) throw const FormatException('확정 신규 손님 일일 소개 한도 변경');
    if (integer(relationship,'holiday_visit_basis_points')>10000 || integer(relationship,'own_portion_extra_quantity')<1) throw const FormatException('손님 방문 비율/수량 오류');
    // 5-1단계: 실제 시간 손님 간격 두 개(일반·네임드)와 자리 수. 옛 무기명 확률·하루 1회·줄 상한은 없앴다.
    if (relationship.containsKey('anonymous_visit_basis_points') || relationship.containsKey('visits_per_npc_business_day') ||
        levels.any((row) => row.containsKey('max_queue'))) {
      throw const FormatException('없앤 손님 방문 설정');
    }
    final arrivals = result.section('customer_arrivals');
    for (final kind in ['regular', 'named']) {
      final low = integer(arrivals, '${kind}_min_ms'), high = integer(arrivals, '${kind}_max_ms');
      if (low == 0 || high < low || integer(arrivals, '${kind}_slots') == 0) {
        throw const FormatException('손님 방문 간격/자리 오류');
      }
    }
    final notices = result.section('customer_notifications');
    if (integer(notices, 'quiet_start_minute') >= 1440 || integer(notices, 'quiet_end_minute') >= 1440 ||
        integer(notices, 'regular_max_notices') == 0 || integer(notices, 'preview_horizon_ms') == 0) {
      throw const FormatException('손님 알림 설정 오류');
    }
    const npcIds={'npc_yunha','npc_doyun','npc_makrye','npc_seojin','npc_taeo','npc_eunchae','npc_minjae','npc_sua'};
    for(final section in ['customer_choice_conditions','customer_story_conditions','customer_order_preferences']) {
      final rows=result.section(section);
      if(rows.length!=npcIds.length || !rows.keys.toSet().containsAll(npcIds)) throw const FormatException('손님 조건 목록 오류');
    }
    for(final id in npcIds) {
      final choice=_map(result.section('customer_choice_conditions')[id]);
      integer(choice,'min_affinity');integer(choice,'min_visits');
      if(integer(_map(result.section('customer_story_conditions')[id]),'stage')>=thresholds.length) throw const FormatException('손님 관계 단계 오류');
      final preference=_map(result.section('customer_order_preferences')[id]);
      if(!recipes.containsKey(preference['flavor']) || integer(preference,'quantity')<1) throw const FormatException('손님 주문 성향 오류');
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
