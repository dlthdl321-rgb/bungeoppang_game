import 'dart:convert';
import 'development_balance.dart';
import 'development_business.dart';

String workshopWeekKst(DateTime utc) {
  final date=utc.toUtc().add(const Duration(hours:9));
  return DateTime.utc(date.year,date.month,date.day-(date.weekday-1)).toIso8601String().substring(0,10);
}
/// Fresh daily/weekly progress only. Claims are verification candidates, never
/// gold. Historical rows/claims stay for replay evidence, not late claiming.
class WorkshopMissions {
  final DateTime observedUtc;
  final Map<String,Map<String,String>> daily,weekly;
  final Map<String,Set<String>> playDays;
  final Map<String,String> claims;
  WorkshopMissions._(this.observedUtc,this.daily,this.weekly,this.playDays,this.claims);
  factory WorkshopMissions.initial(DateTime now)=>WorkshopMissions._(now.toUtc(),{},{},{},{});
  String get day=>businessDayKst(observedUtc);
  String get week=>workshopWeekKst(observedUtc);
  WorkshopMissions observe(DateTime now,{int taps=0,BigInt? production,int purchases=0,BigInt? autoPeak,bool businessStarted=false}) {
    production??=BigInt.zero;autoPeak??=BigInt.zero;
    if(taps<0 || production.isNegative || purchases<0 || autoPeak.isNegative) throw const FormatException('미션 진행 역행');
    final at=now.toUtc().isBefore(observedUtc) ? observedUtc : now.toUtc(),d=businessDayKst(at),w=workshopWeekKst(at);
    final days=Map<String,Map<String,String>>.from(daily),weeks=Map<String,Map<String,String>>.from(weekly);
    final played=Map<String,Set<String>>.from(playDays);
    final currentDay=days[d]=Map<String,String>.from(daily[d]??{});
    final currentWeek=weeks[w]=Map<String,String>.from(weekly[w]??{});
    played[w]=Set<String>.from(playDays[w]??{});
    void add(Map<String,String> row,String key,BigInt amount)=>row[key]=((BigInt.tryParse(row[key]??'0')??BigInt.zero)+amount).toString();
    add(currentDay,'taps',BigInt.from(taps));add(currentDay,'production',production);add(currentDay,'purchases',BigInt.from(purchases));
    final peak=BigInt.parse(currentDay['auto']??'0');currentDay['auto']=(autoPeak>peak ? autoPeak:peak).toString();
    add(currentWeek,'taps',BigInt.from(taps));add(currentWeek,'purchases',BigInt.from(purchases));
    final dates=played.putIfAbsent(w,()=>{});if(businessStarted)dates.add(d);
    currentWeek['days']=dates.length.toString();
    return WorkshopMissions._(at,days,weeks,played,claims);
  }
  BigInt progress(String scope,String metric)=>BigInt.parse((scope=='daily' ? daily[day]:weekly[week])?[metric]??'0');
  Map<String,dynamic> goals(DevelopmentBalance config,String scope) {
    if(scope!='daily' && scope!='weekly') throw const FormatException('미션 기간 오류');
    return config.section('mission_targets')[scope] as Map<String,dynamic>;
  }
  bool complete(DevelopmentBalance config,String scope,String goal) {
    if(scope=='daily' && goal=='all') return goals(config,scope).keys.every((g)=>complete(config,scope,g));
    final row=goals(config,scope)[goal];
    return row is Map<String,dynamic> && progress(scope,row['metric'] as String)>=DevelopmentBalance.decimal(row,'target');
  }
  String claimKey(String scope,String goal)=>'$scope:${scope=='daily' ? day:week}:$goal';
  WorkshopMissions claim(DevelopmentBalance config,String scope,String goal) {
    final key=claimKey(scope,goal);
    if(claims.containsKey(key)) return this;
    if(!complete(config,scope,goal)) throw const FormatException('미션 목표를 먼저 달성해 주세요.');
    final reward=scope=='daily' && goal=='all' ? 'daily_all':
      (goals(config,scope)[goal] as Map<String,dynamic>)['reward_key'] as String;
    final gold=DevelopmentBalance.integer(config.section('mission_gold_rewards'),reward);
    final requirements=scope=='daily' && goal=='all' ? goals(config,scope):{goal:goals(config,scope)[goal]};
    final record=jsonEncode({'requirements':{for(final e in requirements.entries) e.key:{'metric':(e.value as Map)['metric'],'target':(e.value as Map)['target']}},'scope':scope,'period':scope=='daily' ? day:week,'goal':goal,'revision':config.revision,
      'gold':gold,'progress':Map<String,String>.from((scope=='daily' ? daily[day]:weekly[week])??{})});
    final weeks=Map<String,Map<String,String>>.from(weekly);
    weeks[week]=Map<String,String>.from(weekly[week]??{});
    if(scope=='daily' && goal=='all') {
      final row=weeks.putIfAbsent(week,()=>{});row['dailyAll']=(BigInt.parse(row['dailyAll']??'0')+BigInt.one).toString();
    }
    return WorkshopMissions._(observedUtc,daily,weeks,playDays,{...claims,key:record});
  }
  Map<String,dynamic> toJson()=>{'schema':1,'observedUtc':observedUtc.toIso8601String(),
    'daily':{for(final e in daily.entries)e.key:Map<String,String>.from(e.value)},
    'weekly':{for(final e in weekly.entries)e.key:Map<String,String>.from(e.value)},
    'playDays':{for(final e in playDays.entries)e.key:e.value.toList()..sort()},'claims':Map<String,String>.from(claims)};
  factory WorkshopMissions.fromJson(Map<String,dynamic> row) {
    final time=row['observedUtc'];
    if(row['schema'] is! int || row['schema']!=1 || time is! String || DateTime.tryParse(time)==null || !DateTime.parse(time).isUtc) throw const FormatException('미션 저장 버전/시각 오류');
    final observed=DateTime.parse(time),daily=<String,Map<String,String>>{},weekly=<String,Map<String,String>>{};
    bool date(String value)=>RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) && DateTime.tryParse('${value}T00:00:00Z')!=null &&
      DateTime.parse('${value}T00:00:00Z').toIso8601String().substring(0,10)==value;
    for(final scope in ['daily','weekly']) {
      final values=row[scope];if(values is! Map<String,dynamic>) throw const FormatException('미션 진행 형식 오류');
      final target=scope=='daily' ? daily:weekly;
      final allowed=scope=='daily' ? {'taps','production','purchases','auto'}:{'taps','purchases','days','dailyAll'};
      for(final e in values.entries) {
        if(!date(e.key) || e.key.compareTo(scope=='daily' ? businessDayKst(observed):workshopWeekKst(observed))>0 ||
            (scope=='weekly' && DateTime.parse('${e.key}T00:00:00Z').weekday!=DateTime.monday) || e.value is! Map<String,dynamic>) throw const FormatException('미션 기간 형식 오류');
        final counters=<String,String>{};
        for(final metric in (e.value as Map<String,dynamic>).entries) {
          if(!allowed.contains(metric.key) || metric.value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(metric.value as String)) throw const FormatException('미션 카운터 오류');
          counters[metric.key]=metric.value as String;
        }
        target[e.key]=counters;
      }
    }
    final days=row['playDays'],claims=row['claims'];
    if(days is! Map<String,dynamic> || claims is! Map<String,dynamic>) throw const FormatException('미션 이력 형식 오류');
    final played=<String,Set<String>>{},saved=<String,String>{},allCounts=<String,int>{};
    for(final e in days.entries) {
      if(!weekly.containsKey(e.key) || e.value is! List) throw const FormatException('주간 영업일 이력 오류');
      final dates=<String>{};
      for(final value in e.value as List) {
        if(value is! String || !date(value) || workshopWeekKst(DateTime.parse('${value}T00:00:00Z'))!=e.key ||
            value.compareTo(businessDayKst(observed))>0 || !dates.add(value)) throw const FormatException('주간 영업일 중복/기간 오류');
      }
      if(BigInt.parse(weekly[e.key]!['days']??'0')!=BigInt.from(dates.length)) throw const FormatException('주간 영업일 합계 오류');
      played[e.key]=dates;
    }
    for(final e in claims.entries) {
      if(e.value is! String) throw const FormatException('미션 신청 형식 오류');
      final body=jsonDecode(e.value as String);
      if(body is! Map<String,dynamic> || !['daily','weekly'].contains(body['scope']) || body['period'] is! String || body['goal'] is! String ||
          body['revision'] is! String || (body['revision'] as String).isEmpty || body['progress'] is! Map<String,dynamic> ||
          DevelopmentBalance.integer(body,'gold')==0 || e.key!="${body['scope']}:${body['period']}:${body['goal']}") throw const FormatException('미션 신청 근거 오류');
      final period=body['period'] as String,scope=body['scope'],goal=body['goal'];
      if(!(scope=='daily' ? daily:weekly).containsKey(period) || !(scope=='daily' ? {'taps','production','purchases','auto','all'}:{'taps','days','purchases','dailyAll'}).contains(goal)) throw const FormatException('미션 신청 기간/목표 오류');
      final original=(scope=='daily' ? daily:weekly)[period]!;
      final counters=body['progress'] as Map<String,dynamic>;
      for(final v in counters.entries) {
        if(!original.containsKey(v.key) || v.value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(v.value as String) ||
            BigInt.parse(v.value as String)>BigInt.parse(original[v.key]!)) throw const FormatException('미션 신청 카운터 오류');
      }
      final requirements=body['requirements'];
      if(requirements is! Map<String,dynamic> || (goal=='all' ?
          requirements.length!=4 || !requirements.keys.toSet().containsAll({'taps','production','purchases','auto'}) :
          requirements.length!=1 || !requirements.containsKey(goal))) throw const FormatException('미션 신청 목표 근거 오류');
      for(final requirement in requirements.entries) {
        final r=requirement.value;
        if(r is! Map<String,dynamic> || r['metric']!=requirement.key || r['metric'] is! String || !original.containsKey(r['metric']) ||
            DevelopmentBalance.decimal(r,'target')<=BigInt.zero ||
            BigInt.parse(counters[r['metric']] as String? ?? '0')<DevelopmentBalance.decimal(r,'target')) throw const FormatException('미션 신청 목표 미충족');
      }
      if(scope=='daily' && goal=='all') {final w=workshopWeekKst(DateTime.parse('${period}T00:00:00Z'));allCounts[w]=(allCounts[w]??0)+1;}
      saved[e.key]=e.value as String;
    }
    for(final e in weekly.entries) {
      if(BigInt.parse(e.value['dailyAll']??'0')!=BigInt.from(allCounts[e.key]??0) ||
          BigInt.parse(e.value['days']??'0')!=BigInt.from(played[e.key]?.length??0)) throw const FormatException('주간 전체 완료/영업일 이력 불일치');
    }
    return WorkshopMissions._(observed,daily,weekly,played,saved);
  }
}
