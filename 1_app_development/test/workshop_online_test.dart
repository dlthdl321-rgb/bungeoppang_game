import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/workshop_online.dart';
import 'package:todays_bungeoppang/workshop_ads.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'workshop_controller_test.dart' show Repository;

class Transport implements WorkshopTransport {
  @override
  String authenticatedAccount='account';
  bool switchAccount=false,loseReward=false;
  void Function()? onReward;
  final Map<String,Map<String,dynamic>> results={};
  @override
  Future<Map<String,dynamic>> callWorkshop(String name,Map<String,dynamic> data) async {
    final account=authenticatedAccount;
    if(switchAccount) authenticatedAccount='other';
    if(name=='workshopProgressClaim') return {'account':account,'progressId':data['progress'],'epoch':1};
    if(name=='workshopRewardSubmit') {
      final claim=data['claim'] as String,kind=data['kind'] as String,payload=data['payload'] as Map<String,dynamic>;
      final result=results.putIfAbsent(claim,()=>{'account':account,'progress':data['progress'],'claim':claim,'kind':kind,
        'fingerprint':workshopRewardFingerprint(account,data['progress'] as String,claim,kind,payload),
        'outcome':'eligible','gold':1,'receiptId':'receipt:$claim'});
      onReward?.call();
      if(loseReward) {loseReward=false;throw Exception('response lost');} return result;
    }
    throw StateError('unexpected endpoint $name');
  }
}
class AdTransport extends Transport {
  final String token=List.filled(64,'a').join();
  Map<String,dynamic>? approval;
  @override
  Future<Map<String,dynamic>> callWorkshop(String name,Map<String,dynamic> data) async {
    if(name=='workshopAdStart') return approval={'account':authenticatedAccount,'attempt':data['attempt'],
      'status':'reserved','day':'2026-10-16','revision':'ad-r','gold':1,
      'startedAtMs':DateTime.utc(2026,10,16).millisecondsSinceEpoch,'customData':token};
    if(name=='workshopAdQuery') return {...approval!,'paid':false};
    return super.callWorkshop(name,data);
  }
}
class AdDriver implements WorkshopAdDriver {
  final void Function() onShow;
  AdDriver(this.onShow);
  @override
  bool get ready=>true;
  @override
  Future<WorkshopAdFinish> show({required String customData}) async {onShow();return WorkshopAdFinish.completed;}
}
void main() {
  late DevelopmentBalance config;
  setUp(()=>config=DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>));
  test('인증 계정이 바뀐 응답은 진행 권위로 저장하지 않는다',() async {
    final transport=Transport()..switchAccount=true;
    final gateway=WorkshopOnline(transport);
    await expectLater(gateway.requireActiveProgress('progress_0001'),throwsFormatException);
  });
  test('정렬된 증거 지문은 Map 삽입 순서와 무관하며 float는 거부한다',() {
    expect(workshopRewardFingerprint('a','p','c','sale',{'b':2,'a':{'z':1,'b':0}}),
      workshopRewardFingerprint('a','p','c','sale',{'a':{'b':0,'z':1},'b':2}));
    expect(()=>workshopRewardFingerprint('a','p','c','sale',{'b':1.5}),throwsFormatException);
  });
  test('서버 지급 수신이 유실돼도 같은 claim으로 복구하고 로컬 황금을 만들지 않는다',() async {
    final repository=Repository(),transport=Transport()..loseReward=true;
    final c=WorkshopController(config,repository,purchaseGateway:WorkshopOnline(transport));
    addTearDown(c.dispose);await c.initialize();
    await c.command(() {
      c.state.level=2;c.state.claimedLevels.add(2);
      c.state.pendingGold['level:2']=jsonEncode({'level':2,'gold':1,'revision':config.revision});
    });
    expect(await c.syncRewards(),isFalse);expect(c.pendingRewardCount,1);
    expect(await c.syncRewards(),isTrue);expect(c.pendingRewardCount,0);
    expect(transport.results.length,1);expect(c.state.buns,BigInt.zero);
    expect(c.state.toJson().containsKey('gold'),isFalse);
    expect(WorkshopState.fromJson(c.state.toJson(),config).rewardReceipts.length,1);
  });
  test('수신 기록 저장 실패는 새 보상이 아니라 원본 claim 재확인으로 복구한다',() async {
    final repository=Repository(),transport=Transport();
    final c=WorkshopController(config,repository,purchaseGateway:WorkshopOnline(transport));
    addTearDown(c.dispose);await c.initialize();
    await c.command(() {c.state.level=2;c.state.claimedLevels.add(2);
      c.state.pendingGold['level:2']=jsonEncode({'level':2,'gold':1,'revision':config.revision});});
    transport.onReward=()=>repository.fail=true;
    expect(await c.syncRewards(),isFalse);expect(c.error,isNotNull);
    expect(transport.results.length,1);
    transport.onReward=null;
    await c.reloadAfterError();expect(await c.syncRewards(),isTrue);
    expect(transport.results.length,1);
  });
  test('광고 unknown은 로컬 지급/취소가 아니며 다른 날짜와 유료 표식 오류를 거부한다',() {
    final start=DateTime.utc(2026,10,16,15).millisecondsSinceEpoch;
    final ad={'account':'a','attempt':'attempt_0001','status':'reserved','startedAtMs':start,'day':'2026-10-17','gold':1,'revision':'r'};
    expect(validateWorkshopAd(ad,'a','attempt_0001')['day'],'2026-10-17');
    expect(()=>validateWorkshopAd({...ad,'day':'2026-10-16'},'a','attempt_0001'),throwsFormatException);
    expect(()=>validateWorkshopAd({...ad,'paid':true,'receiptId':'x'},'a','attempt_0001'),throwsFormatException);
    expect(const UnconfiguredWorkshopAdDriver().ready,isFalse);
  });
  test('아바타 기본 무료 착용은 저장되고 보유하지 않은 유료 착용은 막는다',() async {
    final c=WorkshopController(config,Repository());addTearDown(c.dispose);await c.initialize();
    expect(await c.equipAvatar('boy'),isTrue);expect(c.state.avatarEquipment['character'],'boy');
    expect(await c.equipAvatar('short'),isFalse);expect(c.error,isNull);
    final restored=WorkshopState.fromJson(c.state.toJson(),config);expect(restored.avatarEquipment['character'],'boy');
    final damaged=c.state.toJson();damaged['avatarEquipment']={'hair':'short'};
    expect(()=>WorkshopState.fromJson(damaged,config),throwsFormatException);
  });
  test('시청 완료 callback은 로컬 지급이 아니고 광고 중 게임만 멈춘다',() async {
    final transport=AdTransport(),c=WorkshopController(config,Repository(),purchaseGateway:WorkshopOnline(transport));
    addTearDown(c.dispose);await c.initialize();
    final driver=AdDriver(()=>expect(c.gameplayPaused,isTrue));
    expect(await c.showRewardedAd(driver),isTrue);
    expect(c.gameplayPaused,isFalse);expect(c.state.adAttempts.values.single['paid'],isFalse);
    expect(c.state.buns,BigInt.zero);expect(c.state.toJson().containsKey('gold'),isFalse);
    final originalId=c.state.adAttempts.keys.single;
    expect(await c.recoverAds(),isTrue);expect(c.state.adAttempts.keys.single,originalId);
  });
  test('광고 SDK 예외 후에도 pause를 풀고 승인 ID를 보존한다',() async {
    final c=WorkshopController(config,Repository(),purchaseGateway:WorkshopOnline(AdTransport()));
    addTearDown(c.dispose);await c.initialize();
    expect(await c.showRewardedAd(AdDriver(()=>throw Exception('SDK failed'))),isFalse);
    expect(c.gameplayPaused,isFalse);expect(c.adBusy,isFalse);
    expect(c.state.adAttempts.length,1);
  });

  test('기본 배경의 무료 시간 선택은 독립 저장하고 유료 배경을 지급하지 않는다',() async {
    final c=WorkshopController(config,Repository());addTearDown(c.dispose);await c.initialize();
    expect(await c.setBackgroundTime('night_time'),isTrue);
    expect(WorkshopState.fromJson(c.state.toJson(),config).sceneTime,'night_time');
    expect(c.state.purchases.owned,isEmpty);
    expect(await c.setBackgroundTime('forest'),isFalse);
  });

}
