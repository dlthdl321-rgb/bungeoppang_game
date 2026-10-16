import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_missions.dart';
import 'package:todays_bungeoppang/development_business.dart';
void main() {
  late DevelopmentBalance config;
  final now=DateTime.utc(2026,10,16);
  setUp(() {
    final raw=jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>;
    for(final scope in ['daily','weekly']) {for(final row in (raw['mission_targets'][scope] as Map).values) {row['target']='1';}}
    config=DevelopmentBalance.fromJson(raw);
  });
  test('구매·자동 생산을 포함한 기존 구성이 있어야 일일 전체 완료를 신청한다',() {
    var progress=WorkshopMissions.initial(now).observe(now,taps:1,production:BigInt.one);
    expect(progress.complete(config,'daily','all'),isFalse);
    progress=progress.observe(now,purchases:1,autoPeak:BigInt.one,businessStarted:true);
    expect(progress.complete(config,'daily','all'),isTrue);
    progress=progress.claim(config,'daily','all');
    expect(progress.progress('weekly','dailyAll'),BigInt.one);
    progress=progress.claim(config,'daily','all');
    expect(progress.progress('weekly','dailyAll'),BigInt.one);
    expect(WorkshopMissions.fromJson(progress.toJson()).toJson(),progress.toJson());
  });
  test('KST 자정/월요일과 시계 역행은 과거 미션을 새로 열지 않는다',() {
    var progress=WorkshopMissions.initial(now).observe(now,taps:1,businessStarted:true);
    progress=progress.observe(DateTime.utc(2026,10,16,15));
    expect(progress.day,'2026-10-17');expect(progress.progress('daily','taps'),BigInt.zero);
    progress=progress.observe(now,taps:1,businessStarted:true);
    expect(progress.day,'2026-10-17');expect(progress.progress('weekly','days'),BigInt.from(2));
    progress=progress.observe(DateTime.utc(2026,10,19));
    expect(progress.week,'2026-10-19');expect(progress.progress('weekly','days'),BigInt.zero);
    expect(WorkshopMissions.fromJson(progress.toJson()).week,'2026-10-19');
  });
  test('신청 당시 수치/진행 근거를 보존하고 손상된 전체 완료 합계를 거부한다',() {
    var progress=WorkshopMissions.initial(now).observe(now,taps:1,production:BigInt.one,purchases:1,autoPeak:BigInt.one);
    progress=progress.claim(config,'daily','all');
    final row=progress.toJson();
    (row['weekly'][progress.week] as Map)['dailyAll']='2';
    expect(()=>WorkshopMissions.fromJson(row),throwsFormatException);
    final claim=jsonDecode(progress.claims.values.single) as Map;
    expect(claim['requirements']['taps']['target'],'1');expect(claim['gold'],2);
  });
  test('전경 생산은 벽시계 점프가 아닌 실제 단조 경과시간만 지급한다',() {
    var business=BusinessProgress.initial(now).beginOrContinue(now);
    final result=business.settleActive(now.add(const Duration(days:1)),bunsPerSecond:BigInt.one,elapsedMs:1000);
    expect(result.buns,BigInt.one);
    business=result.state;
    expect(business.settleActive(now,bunsPerSecond:BigInt.one,elapsedMs:0).buns,BigInt.zero);
  });
}
