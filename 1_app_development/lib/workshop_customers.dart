import 'dart:convert';
import 'development_balance.dart';
import 'generated/customer_content.dart';

/// Exact writing is generated from customer_content.json; personal reference
/// names never form a display-name fallback. Runtime context must qualify any
/// character-specific line before it can replace a neutral common line.
class WorkshopCustomerCatalog {
  final Map<String, dynamic> _data;
  WorkshopCustomerCatalog._(this._data);
  static final _bundled = WorkshopCustomerCatalog._(
      jsonDecode(workshopCustomerContentJson) as Map<String,dynamic>);
  factory WorkshopCustomerCatalog.bundled() => _bundled;
  List<String> get ids => List.unmodifiable(
      (_data['npcs'] as List).map((n) => (n as Map)['id'] as String));
  bool contains(String id) => ids.contains(id);
  Map<String, dynamic> npc(String id) {
    final row = (_data['npcs'] as List).cast<Map<String, dynamic>>().where((n) => n['id'] == id);
    if (row.isEmpty) throw const FormatException('알 수 없는 손님');
    return jsonDecode(jsonEncode(row.single)) as Map<String, dynamic>;
  }
  String displayName(String id, Set<String> completedStories) {
    if (!contains(id)) return '이전 주문 손님'; // Never guess a legacy customer_N mapping.
    if (id == 'npc_sua' && completedStories.contains('story_sua_01')) return '우리 동네 수아 씨';
    return npc(id)['display_name'] as String;
  }
  String address(String id, Set<String> completedStories) =>
      id == 'npc_seojin' && completedStories.contains('story_seojin_01')
          ? '서진 씨' : npc(id)['address_default'] as String;
  Map<String,dynamic> story(String id) {
    final row = (_data['story_events'] as List).cast<Map<String,dynamic>>().where((e) => e['id']==id);
    if(row.isEmpty) throw const FormatException('알 수 없는 관계 장면');
    return jsonDecode(jsonEncode(row.single)) as Map<String,dynamic>;
  }
  Map<String, dynamic> choice(String id) {
    final found = (_data['choice_events'] as List).cast<Map<String, dynamic>>().where((e) => e['id'] == id);
    if (found.isEmpty) throw const FormatException('알 수 없는 선택 사건');
    return jsonDecode(jsonEncode(found.single)) as Map<String, dynamic>;
  }
  bool hasDialogue(String npcId,String id) => contains(npcId) &&
      ((npc(npcId)['dialogues'] as List).any((d)=>(d as Map)['id']==id) ||
       (_data['common_dialogues'] as List).any((d)=>'common_${(d as Map)['event']}'==id) || hasStory(id,npcId));
  bool hasStory(String id, String npcId) => (_data['story_events'] as List)
      .any((s) => (s as Map)['id'] == id && s['npc_id'] == npcId);

  /// qualifiedIds must be computed from actual order, outfit and feature state.
  /// An empty set safely falls back instead of saying an unavailable flavor.
  Map<String, String>? dialogue(String npcId, String event,
      {Set<String> qualifiedIds = const {}, List<String> recent = const []}) {
    if (contains(npcId)) {
      final candidates = (npc(npcId)['dialogues'] as List)
          .cast<Map<String, dynamic>>().where((d) => d['event'] == event && qualifiedIds.contains(d['id'])).toList();
      candidates.sort((a, b) {
        final ar = recent.contains(a['id']), br = recent.contains(b['id']);
        return ar == br ? (a['id'] as String).compareTo(b['id'] as String) : ar ? 1 : -1;
      });
      if (candidates.isNotEmpty) return {'id': candidates.first['id'] as String, 'text': candidates.first['text'] as String};
    }
    final neutral = (_data['common_dialogues'] as List).cast<Map<String, dynamic>>().where((d) => d['event'] == event);
    if (neutral.isEmpty) return null; // Never borrow a different event's line.
    return {'id': 'common_$event', 'text': neutral.first['text'] as String};
  }
}

/// Copy-on-command local relationship journal. It does not own money, products,
/// gold, server receipts, order timers, or decide whether a sale/story is valid.
/// The aggregate must commit its result with the corresponding sale/story.
class WorkshopRelationships {
  final Map<String, dynamic> _data;
  WorkshopRelationships._(this._data);
  factory WorkshopRelationships.empty() => WorkshopRelationships._({
    'schema': 1, 'day': 0, 'visits': <String, dynamic>{},
    'affinity': <String, dynamic>{}, 'earned': <String, dynamic>{},
    'storyDays': <String,dynamic>{},'followupDays':<String,dynamic>{},
    'actions': <String, dynamic>{}, 'awards': <String, dynamic>{}, 'stories': <String>[],
    'recent': <String, dynamic>{}, 'seenDialogue': <String>[],
    'rolls': <String, dynamic>{}, 'lastChoiceDay': 0,
    'choices': <String, dynamic>{}, 'offered': <String, dynamic>{},
    'deferred': <String, dynamic>{},
    'followups': <String, dynamic>{}, 'active': null});
  Map<String, dynamic> toJson() => jsonDecode(jsonEncode(_data)) as Map<String, dynamic>;
  Set<String> get met => (_data['visits'] as Map).values.map((v) => (v as Map)['npc'] as String).toSet();
  Set<String> get stories => (_data['stories'] as List).cast<String>().toSet();
  int affinity(String npc) => (_data['affinity'] as Map)[npc] as int? ?? 0;
  int stage(String npc, DevelopmentBalance config) => config.integers('customer_relationships', 'stage_thresholds')
      .where((v) => affinity(npc) >= v).length - 1;
  int get day => _data['day'] as int;
  Map<String, dynamic>? get active => _data['active'] == null ? null :
      jsonDecode(jsonEncode(_data['active'])) as Map<String, dynamic>;
  List<String> recent(String npc) => List<String>.from((_data['recent'] as Map)[npc] as List? ?? []);
  int visitsOnDay(String npc, int businessDay) => (_data['visits'] as Map).values
      .where((v) => (v as Map)['npc'] == npc && v['day'] == businessDay).length;
  int lastVisitDay(String npc) => (_data['visits'] as Map).values
      .where((v) => (v as Map)['npc'] == npc).fold<int>(0,(n,v) => ((v as Map)['day'] as int) > n ? v['day'] as int : n);
  int introducedOnDay(int businessDay) => met.where((npc) => (_data['visits'] as Map).values
      .where((v) => (v as Map)['npc'] == npc).every((v) => (v as Map)['day'] >= businessDay) && visitsOnDay(npc,businessDay)>0).length;
  String? selectNamedVisitor(int businessDay, int drawBasisPoints, int pick,
      DevelopmentBalance config, WorkshopCustomerCatalog catalog, {Set<String> alreadyQueued = const {}}) {
    if (businessDay < day || drawBasisPoints < 0 || drawBasisPoints >= 10000 || pick < 0) throw const FormatException('손님 배정 입력 오류');
    final rules = config.section('customer_relationships');
    final priority = ['npc_doyun', ...catalog.ids.where((id) => id != 'npc_doyun')];
    if (met.isEmpty) return alreadyQueued.contains(priority.first) ? null : priority.first;
    final available = priority.where((id) => met.contains(id) && !alreadyQueued.contains(id) && visitsOnDay(id,businessDay) < DevelopmentBalance.integer(rules,'visits_per_npc_business_day')).toList();
    final previous = available.where((id) => lastVisitDay(id) < businessDay).toList();
    final familiarAlreadyVisited = met.any((id) => visitsOnDay(id,businessDay)>0 &&
      (_data['visits'] as Map).values.any((v) => (v as Map)['npc']==id && v['day']<businessDay));
    if (!familiarAlreadyVisited && previous.isNotEmpty) return previous[pick % previous.length];
    final unknown = priority.where((id) => !met.contains(id) && !alreadyQueued.contains(id)).toList();
    if (unknown.isNotEmpty && introducedOnDay(businessDay) < DevelopmentBalance.integer(rules,'new_npcs_daily_limit')) return unknown.first;
    if (drawBasisPoints < DevelopmentBalance.integer(rules,'anonymous_visit_basis_points') || available.isEmpty) return null;
    return available[pick % available.length];
  }
  WorkshopRelationships _copy() => WorkshopRelationships._(toJson());
  void _npc(String npc, WorkshopCustomerCatalog catalog) {
    if (!catalog.contains(npc)) throw const FormatException('손님 식별 오류');
  }
  void _atDay(int value) {
    if (value < 1 || value < day) throw const FormatException('관계 영업일 역행');
    if (value != day && active != null) throw const FormatException('활성 대화 중 영업일 변경 불가');
    if (value != day) { _data['day'] = value; _data['earned'] = <String, dynamic>{}; }
  }
  void _award(String awardId, String npc, int amount, String bucket, DevelopmentBalance config) {
    if ((_data['awards'] as Map).containsKey(awardId)) throw const FormatException('관계 보상 식별 중복');
    final rules = config.section('customer_relationships');
    final earned = _data['earned'] as Map<String, dynamic>;
    final key = '$npc:$bucket', used = earned[key] as int? ?? 0;
    final cap = DevelopmentBalance.integer(rules, '${bucket}_daily_cap');
    final available = cap > used ? cap - used : 0;
    final value = amount < available ? amount : available;
    final totalCap = DevelopmentBalance.integer(rules, 'affinity_cap');
    final room = totalCap > affinity(npc) ? totalCap - affinity(npc) : 0;
    final applied = value < room ? value : room;
    earned[key] = used + value;
    (_data['affinity'] as Map<String, dynamic>)[npc] = affinity(npc) + applied;
    (_data['awards'] as Map<String,dynamic>)[awardId] = {'npc':npc, 'day':day,
      'bucket':bucket, 'earned':value, 'applied':applied, 'dailyCap':cap, 'totalCap':totalCap, 'revision':config.revision};
  }
  /// Idempotent across reloads; same visit ID with different contents is rejected.
  WorkshopRelationships visit(String visit, String npc, int businessDay, WorkshopCustomerCatalog catalog, {Map<String,dynamic>? context}) {
    _npc(npc, catalog);
    if (visit.isEmpty || businessDay < 1) throw const FormatException('방문 식별 오류');
    final next = _copy(), visits = next._data['visits'] as Map<String, dynamic>;
    final old = visits[visit];
    if (old != null) {
      if ((old as Map)['npc'] != npc || old['day'] != businessDay) throw const FormatException('방문 기록 충돌');
      return next;
    }
    next._atDay(businessDay); visits[visit] = {'npc': npc, 'day': businessDay, if(context!=null) 'context':jsonDecode(jsonEncode(context))};
    return next;
  }
  WorkshopRelationships observeVisit(String visitId, String flag) {
    if(!['waitingSeen','sketchObserved','photoShown'].contains(flag)) throw const FormatException('관찰 종류 오류');
    final next=_copy(),row=(next._data['visits'] as Map)[visitId];
    if(row is! Map<String,dynamic>) throw const FormatException('관찰 방문 누락');
    final context=Map<String,dynamic>.from(row['context'] as Map? ?? {});
    context[flag]=true;row['context']=context;return next;
  }
  WorkshopRelationships successfulSale(String saleId, String visitId,
      int businessDay, DevelopmentBalance config) {
    final next = _copy(), visits = next._data['visits'] as Map;
    final visit = visits[visitId];
    if (saleId.isEmpty || visit is! Map) throw const FormatException('판매의 방문 근거 누락');
    final actions = next._data['actions'] as Map<String, dynamic>;
    final key = 'sale:$saleId', payload = {'visit': visitId, 'day': businessDay};
    if (actions.containsKey(key)) {
      if (jsonEncode(actions[key]) != jsonEncode(payload)) throw const FormatException('판매 관계 기록 충돌');
      return next;
    }
    // One full sale per visit. Reissuing a sale ID cannot farm relationship points.
    if (actions.entries.any((e) => e.key.startsWith('sale:') && (e.value as Map)['visit'] == visitId) ||
        (visit['day'] as int) > businessDay) throw const FormatException('방문 판매 중복/날짜 불일치');
    next._atDay(businessDay);
    next._award(key, visit['npc'] as String, DevelopmentBalance.integer(config.section('customer_relationships'), 'sale_affinity'), 'ordinary', config);
    actions[key] = payload;
    return next;
  }
  WorkshopRelationships recordDialogue(String npc, String dialogueId, int businessDay,
      DevelopmentBalance config, WorkshopCustomerCatalog catalog, {bool firstAutomaticCompletion = false}) {
    _npc(npc, catalog);
    if (!met.contains(npc) || !catalog.hasDialogue(npc,dialogueId)) throw const FormatException('대화 근거 오류');
    final next = _copy(); next._atDay(businessDay);
    final history = next.recent(npc)..remove(dialogueId)..add(dialogueId);
    final limit = DevelopmentBalance.integer(config.section('customer_relationships'), 'recent_dialogue_limit');
    (next._data['recent'] as Map<String, dynamic>)[npc] = history.skip(history.length > limit ? history.length - limit : 0).toList();
    final seen = next._data['seenDialogue'] as List;
    final key = '$npc:$dialogueId';
    if (firstAutomaticCompletion && !seen.contains(key)) {
      seen.add(key);
      final actions = next._data['actions'] as Map<String, dynamic>, dailyKey = 'dialogue:$npc:$businessDay';
      if (!actions.containsKey(dailyKey)) {
        next._award(dailyKey, npc, DevelopmentBalance.integer(config.section('customer_relationships'), 'automatic_dialogue_affinity'), 'ordinary', config);
        actions[dailyKey] = {'npc': npc, 'day': businessDay, 'dialogue': dialogueId};
      }
    }
    return next;
  }
  /// Caller validates the authored per-NPC prerequisites before completing.
  WorkshopRelationships completeStory(String npc, String storyId,
      WorkshopCustomerCatalog catalog, {required bool eligible}) {
    _npc(npc, catalog);
    if (!met.contains(npc) || !eligible || !catalog.hasStory(storyId, npc)) throw const FormatException('관계 장면 조건 미충족');
    final next = _copy();
    final completed = next._data['stories'] as List;
    if (!completed.contains(storyId)) {completed.add(storyId);(next._data['storyDays'] as Map<String,dynamic>)[storyId]=day;}
    return next;
  }
  /// Store even a failed rare roll. Eligibility is supplied by the per-NPC
  /// prerequisite evaluator; this method never infers it from affinity alone.
  WorkshopRelationships rollChoice(int businessDay, List<String> eligibleIds,
      int drawBasisPoints, DevelopmentBalance config, WorkshopCustomerCatalog catalog,
      {bool anotherStoryToday = false, bool tutorial = false}) {
    if (drawBasisPoints < 0 || drawBasisPoints >= 10000) throw const FormatException('사건 추첨 범위 오류');
    final next = _copy(), rolls = next._data['rolls'] as Map<String, dynamic>;
    if (rolls.containsKey('$businessDay')) return next;
    next._atDay(businessDay);
    final rules = config.section('customer_relationships');
    if (tutorial || anotherStoryToday || next.active != null ||
        businessDay < DevelopmentBalance.integer(rules, 'choice_first_business_day') ||
        (next._data['lastChoiceDay'] as int) > 0 && businessDay - (next._data['lastChoiceDay'] as int) < DevelopmentBalance.integer(rules, 'choice_gap_business_days')) return next;
    final candidates = eligibleIds.toSet().where((id) {
      final event = catalog.choice(id), npc = event['npc_id'] as String;
      if (!next.met.contains(npc) || (next._data['choices'] as Map).containsKey(id)) return false;
      final offered = (next._data['offered'] as Map)[id] as int?;
      return offered == null || businessDay - offered >= DevelopmentBalance.integer(rules, 'choice_skip_retry_business_days');
    }).toList()..sort();
    if (candidates.isEmpty) return next; // No valid candidate: do not spend the day's roll.
    final eventId = candidates.first;
    final success = drawBasisPoints < DevelopmentBalance.integer(rules, 'choice_chance_basis_points');
    rolls['$businessDay'] = {'event': eventId, 'passed': success};
    if (success) {
      (next._data['offered'] as Map<String, dynamic>)[eventId] = businessDay;
      next._data['lastChoiceDay'] = businessDay;
      next._data['active'] = {'event': eventId, 'day': businessDay, 'choice': null};
    }
    return next;
  }
  WorkshopRelationships choose(String eventId, String selection, DevelopmentBalance config,
      WorkshopCustomerCatalog catalog) {
    final event = catalog.choice(eventId), next = _copy();
    if (!['a', 'b', 'c', 'wave'].contains(selection)) throw const FormatException('선택 ID 오류');
    final completed = next._data['choices'] as Map<String, dynamic>;
    if (completed.containsKey(eventId)) {
      if ((completed[eventId] as Map)['choice'] != selection) throw const FormatException('이미 확정한 선택');
      return next;
    }
    final active = next.active;
    if (selection == 'wave' && active == null && (next._data['deferred'] as Map)[eventId] == day) return next;
    if (active == null || active['event'] != eventId || active['choice'] != null || active['day'] != day) throw const FormatException('활성 선택 사건 불일치');
    if (selection == 'wave') {
      (next._data['deferred'] as Map<String, dynamic>)[eventId] = day;
      next._data['active'] = null; return next;
    }
    final npc = event['npc_id'] as String;
    final points = (config.section('customer_relationships')['choice_affinity'] as Map)[selection] as int;
    next._award('choice:$eventId', npc, points, 'choice', config);
    completed[eventId] = {'choice': selection, 'day': day};
    (next._data['followups'] as Map<String, dynamic>)[eventId] = selection;
    next._data['active'] = {...active, 'choice': selection};
    return next;
  }
  WorkshopRelationships closeReaction(String eventId) {
    final next = _copy(), current = next.active;
    if (current == null || current['event'] != eventId || current['choice'] == null) throw const FormatException('선택 반응 상태 오류');
    next._data['active'] = null; return next;
  }
  WorkshopRelationships consumeFollowup(String eventId, {required bool contextMatches}) {
    if (!contextMatches || !(_data['followups'] as Map).containsKey(eventId)) throw const FormatException('후일담 조건 미충족');
    final next = _copy(); (next._data['followups'] as Map).remove(eventId);
    (next._data['followupDays'] as Map<String,dynamic>)[eventId]=day;return next;
  }

  static int _historicalCap(Map<String,dynamic> row, String npc, int current) {
    var result = current;
    for (final value in (row['awards'] as Map).values) {
      if (value is Map && value['npc'] == npc && value['totalCap'] is int && (value['totalCap'] as int) > result) result = value['totalCap'] as int;
    }
    return result;
  }
  static int _historicalDailyCap(Map<String,dynamic> row, String key, int current) {
    var result = current;
    for (final value in (row['awards'] as Map).values) {
      if (value is Map && '${value['npc']}:${value['bucket']}' == key && value['day'] == row['day'] &&
          value['dailyCap'] is int && (value['dailyCap'] as int) > result) result = value['dailyCap'] as int;
    }
    return result;
  }
  factory WorkshopRelationships.fromJson(Map<String, dynamic> row,
      DevelopmentBalance config, WorkshopCustomerCatalog catalog) {
    final copy = jsonDecode(jsonEncode(row)) as Map<String, dynamic>;
    final empty = WorkshopRelationships.empty().toJson();
    if (copy.length != empty.length || !copy.keys.toSet().containsAll(empty.keys) || copy['schema'] is! int || copy['schema'] != 1) throw const FormatException('관계 저장 스키마 오류');
    for (final key in ['day', 'lastChoiceDay']) { DevelopmentBalance.integer(copy, key); }
    for (final key in ['visits','affinity','earned','storyDays','followupDays','actions','awards','recent','rolls','choices','offered','followups','deferred']) {
      if (copy[key] is! Map<String, dynamic>) throw const FormatException('관계 저장 목록 오류');
    }
    for (final key in ['stories','seenDialogue']) {
      if (copy[key] is! List || (copy[key] as List).any((v) => v is! String) || (copy[key] as List).toSet().length != (copy[key] as List).length) throw const FormatException('관계 저장 기록 오류');
    }
    final state = WorkshopRelationships._(copy), rules = config.section('customer_relationships');
    if ((copy['lastChoiceDay'] as int) > state.day) throw const FormatException('미래 선택 기록');
    for (final entry in (copy['visits'] as Map<String, dynamic>).entries) {
      if (entry.key.isEmpty || entry.value is! Map<String, dynamic>) throw const FormatException('방문 저장 오류');
      final v = entry.value as Map<String, dynamic>;
      if(v.containsKey('context')) {
        final context=v['context'];
        if(context is! Map<String,dynamic> || context.keys.any((key)=>!['lines','initialWaitMs','working','running','sketchObserved','turnedBack','ownPortion','onSite','photoReminder','waitingSeen','photoShown','cameraPresent'].contains(key))) throw const FormatException('방문 맥락 형식 오류');
        for(final field in context.entries.where((e)=>e.key!='lines' && e.key!='initialWaitMs')) {
          if(field.value is! bool) throw const FormatException('방문 관찰 상태 오류');
        }
        if(context.containsKey('initialWaitMs') && (context['initialWaitMs'] is! int || (context['initialWaitMs'] as int)<1)) throw const FormatException('방문 초기 대기시간 오류');
        if(context['lines'] is! List || (context['lines'] as List).isEmpty) throw const FormatException('방문 주문 맥락 누락');
        for(final line in context['lines'] as List) {
          if(line is! Map<String,dynamic> || !config.section('active_recipes').containsKey(line['flavor']) ||
              DevelopmentBalance.integer(line,'quantity')<1 || line['special'] is! bool ||
              line['variant']!=null && (line['variant'] is! int || (line['variant'] as int)<0 || (line['variant'] as int)>3)) throw const FormatException('방문 주문 맥락 오류');
        }
      }
      state._npc(v['npc'] as String? ?? '', catalog);
      final day = DevelopmentBalance.integer(v, 'day');
      if (day < 1 || day > state.day) throw const FormatException('방문 날짜 오류');
    }
    final soldVisits = <String>{};
    for (final entry in (copy['actions'] as Map<String, dynamic>).entries) {
      final action = entry.value;
      if (action is! Map<String, dynamic>) throw const FormatException('관계 처리 기록 오류');
      final actionDay = DevelopmentBalance.integer(action, 'day');
      if (actionDay < 1 || actionDay > state.day) throw const FormatException('관계 처리 날짜 오류');
      if (entry.key.startsWith('sale:')) {
        final visit = (copy['visits'] as Map)[action['visit']];
        if (entry.key == 'sale:' || visit is! Map || (visit['day'] as int) > actionDay ||
            action['visit'] is! String || !soldVisits.add(action['visit'] as String)) throw const FormatException('관계 판매 근거 오류');
      } else if (entry.key.startsWith('dialogue:')) {
        final npc = action['npc'], dialogue = action['dialogue'];
        if (npc is! String || dialogue is! String || !state.met.contains(npc) ||
            entry.key != 'dialogue:$npc:$actionDay' || !(copy['seenDialogue'] as List).contains('$npc:$dialogue')) throw const FormatException('자동 대화 근거 오류');
      } else { throw const FormatException('알 수 없는 관계 처리 기록'); }
    }
    for (final entry in (copy['affinity'] as Map<String, dynamic>).entries) {
      if (!state.met.contains(entry.key) || entry.value is! int || (entry.value as int) < 0 || (entry.value as int) > _historicalCap(copy, entry.key, DevelopmentBalance.integer(rules,'affinity_cap'))) throw const FormatException('친밀도 저장 오류');
    }
    for (final entry in (copy['earned'] as Map<String, dynamic>).entries) {
      final split = entry.key.split(':');
      if (split.length != 2 || !state.met.contains(split.first) || !['ordinary','choice'].contains(split.last) || entry.value is! int || (entry.value as int) < 0 || (entry.value as int) > _historicalDailyCap(copy, entry.key, DevelopmentBalance.integer(rules,'${split.last}_daily_cap'))) throw const FormatException('관계 일일 상한 오류');
    }
    final totals = <String,int>{}, daily = <String,int>{};
    for (final entry in (copy['awards'] as Map<String,dynamic>).entries) {
      final award = entry.value;
      if (award is! Map<String,dynamic> || award['npc'] is! String || !state.met.contains(award['npc']) ||
          !['ordinary','choice'].contains(award['bucket']) || award['revision'] is! String || (award['revision'] as String).isEmpty) throw const FormatException('관계 보상 원장 오류');
      final npc = award['npc'] as String, bucket = award['bucket'] as String;
      final at = DevelopmentBalance.integer(award,'day'), earned = DevelopmentBalance.integer(award,'earned');
      final applied = DevelopmentBalance.integer(award,'applied'), cap = DevelopmentBalance.integer(award,'dailyCap');
      if (at < 1 || at > state.day || applied > earned || earned > cap || cap == 0 ||
          applied > DevelopmentBalance.integer(award,'totalCap')) throw const FormatException('관계 보상 수치 오류');
      if (bucket == 'ordinary') {
        final action = (copy['actions'] as Map)[entry.key];
        final visit = action is Map ? (copy['visits'] as Map)[action['visit']] : null;
        if (action is! Map || action['day'] != at ||
            (entry.key.startsWith('sale:') ? visit is! Map || visit['npc'] != npc : action['npc'] != npc)) throw const FormatException('일반 관계 보상 근거 오류');
      } else {
        final eventId = entry.key.startsWith('choice:') ? entry.key.substring(7) : '';
        final choice = (copy['choices'] as Map)[eventId];
        if (choice is! Map || choice['day'] != at || catalog.choice(eventId)['npc_id'] != npc) throw const FormatException('선택 관계 보상 근거 오류');
      }
      totals[npc] = (totals[npc] ?? 0) + applied;
      if (at == state.day) daily['$npc:$bucket'] = (daily['$npc:$bucket'] ?? 0) + earned;
    }
    for (final action in (copy['actions'] as Map).keys) {
      if (!(copy['awards'] as Map).containsKey(action)) throw const FormatException('관계 처리의 보상 기록 누락');
    }
    for (final npc in state.met) {
      if (state.affinity(npc) != (totals[npc] ?? 0)) throw const FormatException('친밀도 합계 근거 불일치');
    }
    final savedEarned = copy['earned'] as Map;
    if (daily.length != savedEarned.length || daily.entries.any((e) => savedEarned[e.key] != e.value)) throw const FormatException('친밀도 일일 합계 불일치');
    final storyDays=copy['storyDays'] as Map;
    if(storyDays.length!=state.stories.length || state.stories.any((id)=>storyDays[id] is! int || (storyDays[id] as int)<1 || (storyDays[id] as int)>state.day)) throw const FormatException('관계 장면 날짜 오류');
    for(final entry in (copy['followupDays'] as Map).entries) {
      if(entry.value is! int || (entry.value as int)<1 || (entry.value as int)>state.day || !(copy['choices'] as Map).containsKey(entry.key)) throw const FormatException('후일담 날짜 오류');
    }
    for (final story in state.stories) {
      if (!state.met.any((npc) => catalog.hasStory(story,npc))) throw const FormatException('관계 완료 근거 오류');
    }
    for (final entry in (copy['recent'] as Map<String,dynamic>).entries) {
      if (!state.met.contains(entry.key) || entry.value is! List || (entry.value as List).any((v) => v is! String || !catalog.hasDialogue(entry.key,v)) || (entry.value as List).length > DevelopmentBalance.integer(rules,'recent_dialogue_limit')) throw const FormatException('최근 대사 기록 오류');
    }
    for(final seen in copy['seenDialogue'] as List) {
      final parts=(seen as String).split(':');
      if(parts.length!=2 || !state.met.contains(parts.first) || !catalog.hasDialogue(parts.first,parts.last)) throw const FormatException('최초 대화 기록 오류');
    }
    for (final entry in (copy['rolls'] as Map<String,dynamic>).entries) {
      final rollDay = int.tryParse(entry.key), value = entry.value;
      if (rollDay == null || rollDay < 1 || rollDay > state.day || value is! Map || value['event'] is! String || value['passed'] is! bool) throw const FormatException('사건 추첨 기록 오류');
      catalog.choice(value['event'] as String);
    }
    for (final entry in (copy['offered'] as Map<String,dynamic>).entries) {
      catalog.choice(entry.key);
      if (entry.value is! int || (entry.value as int) < 1 || (entry.value as int) > state.day ||
          ((copy['rolls'] as Map)['${entry.value}'] as Map?)?['event'] != entry.key ||
          ((copy['rolls'] as Map)['${entry.value}'] as Map?)?['passed'] != true) throw const FormatException('사건 제시 근거 오류');
    }
    for (final entry in (copy['deferred'] as Map<String,dynamic>).entries) {
      catalog.choice(entry.key);
      if (entry.value is! int || (entry.value as int) < 1 || (entry.value as int) > state.day ||
          ((copy['rolls'] as Map)['${entry.value}'] as Map?)?['event'] != entry.key ||
          ((copy['rolls'] as Map)['${entry.value}'] as Map?)?['passed'] != true) throw const FormatException('배웅 기록 근거 오류');
    }
    for (final entry in (copy['choices'] as Map<String,dynamic>).entries) {
      final event = catalog.choice(entry.key), v = entry.value;
      if (!(copy['awards'] as Map).containsKey('choice:${entry.key}') || !state.met.contains(event['npc_id']) || v is! Map || !['a','b','c'].contains(v['choice']) || v['day'] != (copy['offered'] as Map)[entry.key]) throw const FormatException('선택 완료 근거 오류');
    }
    for (final entry in (copy['followups'] as Map<String,dynamic>).entries) {
      if (((copy['choices'] as Map)[entry.key] as Map?)?['choice'] != entry.value) throw const FormatException('후일담 선택 근거 오류');
    }
    if (copy['active'] != null) {
      final current = copy['active'];
      if (current is! Map || current['event'] is! String || current['day'] != state.day || current['day'] != (copy['offered'] as Map)[current['event']] ||
          (current['choice'] != null && ((copy['choices'] as Map)[current['event']] as Map?)?['choice'] != current['choice'])) throw const FormatException('활성 대화 복원 오류');
      catalog.choice(current['event'] as String);
    }
    return state;
  }
}
