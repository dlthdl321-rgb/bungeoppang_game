import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_customers.dart';
import 'package:todays_bungeoppang/workshop_customer_dialogue.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/workshop_customer_events.dart';
void main() {
  late DevelopmentBalance config;
  late WorkshopCustomerCatalog catalog;
  setUp(() {
    config = DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>);
    catalog = WorkshopCustomerCatalog.bundled();
  });
  WorkshopRelationships met(int day, {String npc = 'npc_doyun'}) => WorkshopRelationships.empty().visit('visit', npc, day, catalog);
  test('초기 팥 주문에 슈크림 대사를 추정해 노출하지 않는다', () {
    expect(catalog.ids.length, 8);
    final fallback = catalog.dialogue('npc_doyun', 'first_visit');
    expect(fallback!['id'], 'common_first_visit');
    expect(fallback['text'], isNot(contains('슈크림')));
    expect(catalog.dialogue('npc_doyun', 'not_an_event'), isNull);
    expect(catalog.displayName('customer_1', {}), '이전 주문 손님');
    final order=CustomerOrder(id:'first',customerId:'npc_doyun',remainingMs:1000,lines:[CustomerOrderLine(flavor:'redbean',quantity:1)]);
    expect(qualifiesCustomerDialogue('first_visit',CustomerDialogueFacts(order:order)),isFalse);
    expect(qualifiesCustomerDialogue('rain',CustomerDialogueFacts(order:order)),isFalse);
    final custard=CustomerOrder(id:'later',customerId:'npc_doyun',remainingMs:1000,lines:[CustomerOrderLine(flavor:'custard',quantity:1)]);
    expect(qualifiesCustomerDialogue('first_visit',CustomerDialogueFacts(order:custard)),isTrue);
  });
  test('명시적으로 조건이 확인된 대사만 사용하고 원본 카탈로그를 변경하지 않는다', () {
    final line = catalog.dialogue('npc_doyun','order',qualifiedIds:{'doyun_order_01'});
    expect(line!['text'],contains('슈크림'));
    catalog.npc('npc_doyun')['display_name']='변조';
    expect(catalog.displayName('npc_doyun',{}),'노란 가방 도윤이');
  });
  test('방문 재시도는 동일하며 같은 ID의 다른 손님/날짜를 거부한다', () {
    var p = met(1);
    expect(p.visit('visit','npc_doyun',1,catalog).toJson(),p.toJson());
    expect(()=>p.visit('visit','npc_yunha',1,catalog),throwsFormatException);
    expect(()=>p.visit('visit','npc_doyun',2,catalog),throwsFormatException);
    p = WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(p.met,{'npc_doyun'});
  });
  test('전량 판매 한 건에 일반 친밀도1회이며 다른 판매ID로 같은 방문을 재보상하지 않는다', () {
    var p = met(1).successfulSale('sale','visit',1,config);
    expect(p.affinity('npc_doyun'),2);
    expect(p.successfulSale('sale','visit',1,config).toJson(),p.toJson());
    expect(()=>p.successfulSale('another','visit',1,config),throwsFormatException);
    final q = p.toJson();(q['actions'] as Map)['sale:fake']={'visit':'missing','day':1};
    expect(()=>WorkshopRelationships.fromJson(q,config,catalog),throwsFormatException);
  });
  test('새 자동 대화는 일반상한에 포함하고 같은 날 여러 새 대화로 반복 보상하지 않는다', () {
    var p=met(1).successfulSale('sale','visit',1,config);
    p=p.recordDialogue('npc_doyun','doyun_friendly_01',1,config,catalog,firstAutomaticCompletion:true);
    p=p.recordDialogue('npc_doyun','doyun_regular_01',1,config,catalog,firstAutomaticCompletion:true);
    expect(p.affinity('npc_doyun'),3);
    p=p.visit('visit2','npc_doyun',2,catalog);
    p=p.recordDialogue('npc_doyun','doyun_friendly_01',2,config,catalog,firstAutomaticCompletion:true);
    expect(p.affinity('npc_doyun'),3);
    expect(WorkshopRelationships.fromJson(p.toJson(),config,catalog).toJson(),p.toJson());
  });
  test('실패한 희귀 추첨은 저장·재실행·다른 후보에서도 다시 굴리지 않는다', () {
    var p=met(7).rollChoice(7,['choice_doyun_01'],9999,config,catalog);
    p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(p.rollChoice(7,['choice_doyun_01'],0,config,catalog).active,isNull);
  });
  test('유효 후보가 없으면 하루 추첨을 소비하지 않고 튜토리얼/관계장면 날은 보류한다', () {
    final p=met(7);
    expect(p.rollChoice(7,[],0,config,catalog).toJson()['rolls'],isEmpty);
    expect(p.rollChoice(7,['choice_doyun_01'],0,config,catalog,tutorial:true).active,isNull);
    expect(p.rollChoice(7,['choice_doyun_01'],0,config,catalog,anotherStoryToday:true).active,isNull);
  });
  test('배웅은0·영구완료/후일담 없음·같은날 재추첨 없음·재후보10일', () {
    var p=met(7).rollChoice(7,['choice_doyun_01'],0,config,catalog);
    p=p.choose('choice_doyun_01','wave',config,catalog);
    expect(p.affinity('npc_doyun'),0);expect(p.toJson()['choices'],isEmpty);expect(p.toJson()['followups'],isEmpty);
    expect(p.rollChoice(7,['choice_doyun_01'],0,config,catalog).active,isNull);
    expect(p.rollChoice(16,['choice_doyun_01'],0,config,catalog).active,isNull);
    expect(p.rollChoice(17,['choice_doyun_01'],0,config,catalog).active,isNotNull);
  });
  test('일반3과 선택3을 구분하고 반응 넘기기/중복 선택은 재보상하지 않는다', () {
    var p=met(7).successfulSale('sale','visit',7,config);
    p=p.recordDialogue('npc_doyun','doyun_friendly_01',7,config,catalog,firstAutomaticCompletion:true);
    p=p.rollChoice(7,['choice_doyun_01'],0,config,catalog).choose('choice_doyun_01','a',config,catalog);
    expect(p.affinity('npc_doyun'),6);
    p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(p.choose('choice_doyun_01','a',config,catalog).affinity('npc_doyun'),6);
    expect(()=>p.choose('choice_doyun_01','b',config,catalog),throwsFormatException);
    p=p.closeReaction('choice_doyun_01');
    expect(p.affinity('npc_doyun'),6);
    expect(()=>p.consumeFollowup('choice_doyun_01',contextMatches:false),throwsFormatException);
    p=p.consumeFollowup('choice_doyun_01',contextMatches:true);
    expect(p.toJson()['followups'],isEmpty);
  });
  test('수아 표시명과 서진 개인 호칭은 서로 다른 이벤트 완료로 바뀐다', () {
    var p=met(1,npc:'npc_sua').visit('writer','npc_seojin',1,catalog);
    expect(catalog.displayName('npc_sua',p.stories),'새 이웃 수아 씨');
    p=p.completeStory('npc_sua','story_sua_01',catalog,eligible:true);
    p=p.completeStory('npc_seojin','story_seojin_01',catalog,eligible:true);
    expect(catalog.displayName('npc_sua',p.stories),'우리 동네 수아 씨');
    expect(catalog.displayName('npc_seojin',p.stories),'옥탑방 오 작가');
    expect(catalog.address('npc_seojin',p.stories),'서진 씨');
    expect(()=>p.completeStory('npc_sua','story_sua_01',catalog,eligible:false),throwsFormatException);
  });
  test('손상된 상한·미래 방문·다른 선택 후일담을 거부한다', () {
    var row=met(7).toJson();(row['affinity'] as Map)['npc_doyun']=101;
    expect(()=>WorkshopRelationships.fromJson(row,config,catalog),throwsFormatException);
    row=met(7).toJson();((row['visits'] as Map)['visit'] as Map)['day']=8;
    expect(()=>WorkshopRelationships.fromJson(row,config,catalog),throwsFormatException);
    row=met(7).toJson();(row['followups'] as Map)['choice_doyun_01']='a';
    expect(()=>WorkshopRelationships.fromJson(row,config,catalog),throwsFormatException);
  });
  test('NPC별 조건은 친밀도만으로 통과하지 않으며 끝난 장면 이전 사건은 금지한다', () {
    const first=CustomerEventFacts(npcId:'npc_doyun',affinity:100,visits:3,recipeCount:3,receivedFlavorCount:2,mapStoryKnown:true,firstVisit:true);
    expect(eligibleCustomerChoice(first,config,candidateOrderMatches:true),isFalse);
    const ready=CustomerEventFacts(npcId:'npc_doyun',affinity:10,visits:3,recipeCount:3,receivedFlavorCount:2,mapStoryKnown:true);
    expect(eligibleCustomerChoice(ready,config,candidateOrderMatches:true),isTrue);
    expect(eligibleCustomerChoice(ready,config,candidateOrderMatches:false),isFalse);
    const past=CustomerEventFacts(npcId:'npc_seojin',affinity:100,visits:5,sketchVisitCount:2,completedStories:{'story_seojin_01'});
    expect(eligibleCustomerChoice(past,config,candidateOrderMatches:true),isFalse);
  });
  test('8명 선택 사건의 서로 다른 최소 조건을 설정에서 판정한다', () {
    const ready = [
      CustomerEventFacts(npcId:'npc_yunha',affinity:10,visits:4,redbeanTwoSuccessDays:3),
      CustomerEventFacts(npcId:'npc_doyun',affinity:10,visits:3,recipeCount:3,receivedFlavorCount:2,mapStoryKnown:true),
      CustomerEventFacts(npcId:'npc_makrye',affinity:20,visits:3,largeOrderSuccessDays:2,otherMetCount:3),
      CustomerEventFacts(npcId:'npc_seojin',affinity:20,visits:5,sketchVisitCount:2),
      CustomerEventFacts(npcId:'npc_taeo',affinity:10,visits:3,newFlavorFirstServed:true,forgotPhotoShown:true),
      CustomerEventFacts(npcId:'npc_eunchae',affinity:10,visits:3,workVisits:3,workSuccessDays:2,workingVisit:true),
      CustomerEventFacts(npcId:'npc_minjae',affinity:20,visits:5,runningVisits:3,runningTurnedBack:true),
      CustomerEventFacts(npcId:'npc_sua',affinity:10,visits:3,distinctVisitDays:3,custardSuccesses:2,daysSinceLastVisit:3),
    ];
    for(final facts in ready) { expect(eligibleCustomerChoice(facts,config,candidateOrderMatches:true),isTrue,reason:facts.npcId); }
  });
  test('선택 사건 없이도 수아 관계 장면을 열고 막례 선행 조건을 검사한다', () {
    const noNeighbor=WorkshopStoryFacts(met:{'npc_sua'},affinity:{'npc_sua':60});
    expect(eligibleCustomerStory('npc_sua',noNeighbor,config),isFalse);
    const ready=WorkshopStoryFacts(met:{'npc_sua','npc_makrye'},affinity:{'npc_sua':60,'npc_makrye':30});
    expect(eligibleCustomerStory('npc_sua',ready,config),isTrue);
  });
  test('4영업일 소개 하루 2명은 저장 복원 뒤에도 유지되고 하루 1회 제한은 없다 (5-1단계)', () {
    var p=WorkshopRelationships.empty();
    String? last;
    for(var day=1;day<=4;day++) {
      if(day>1) {
        final familiar=p.selectNamedVisitor(day,0,config,catalog,lastVisitor:last);
        // Unmet neighbors left but none introduced today yet: introduce first.
        expect(p.met, isNot(contains(familiar)));
      }
      for(var i=0;i<2;i++) {
        final next=p.selectNamedVisitor(day,0,config,catalog,lastVisitor:last)!;
        expect(p.met, isNot(contains(next)));
        p=p.visit('new-$day-$i',next,day,catalog);
        last=next;
        p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
      }
      expect(p.introducedOnDay(day),2);
      // After two introductions a met neighbor comes, again and again the same day.
      for(var i=0;i<3;i++) {
        final again=p.selectNamedVisitor(day,i,config,catalog,lastVisitor:last)!;
        expect(p.met,contains(again));
        expect(again,isNot(last),reason:'바로 앞 네임드는 빼고 고른다');
        p=p.visit('again-$day-$i',again,day,catalog);
        last=again;
      }
    }
    expect(p.met.length,8);
  });
  test('네임드 고르기: 첫 손님 도윤, 직전 제외, 한 명뿐이면 그 사람, 줄에 선 사람 제외 (5-1단계)', () {
    final empty=WorkshopRelationships.empty();
    expect(empty.selectNamedVisitor(1,12345,config,catalog),'npc_doyun');
    expect(empty.selectNamedVisitor(1,0,config,catalog,alreadyQueued:{'npc_doyun'}),isNull);
    // Only 도윤 met and the day's introductions used up: 도윤 again.
    var p=WorkshopRelationships.empty().visit('a','npc_doyun',1,catalog).visit('b','npc_yunha',1,catalog);
    final picks={for(var pick=0;pick<20;pick++) p.selectNamedVisitor(1,pick,config,catalog,lastVisitor:'npc_yunha')};
    expect(picks,{'npc_doyun'});
    expect(p.selectNamedVisitor(1,3,config,catalog,lastVisitor:'npc_yunha',alreadyQueued:{'npc_doyun'}),'npc_yunha',
        reason:'남은 사람이 직전 손님뿐이면 그 사람');
    expect(p.selectNamedVisitor(1,3,config,catalog,alreadyQueued:{'npc_doyun','npc_yunha'}),isNull);
    // A new day introduces the next unmet neighbor in catalog order.
    expect(p.selectNamedVisitor(2,0,config,catalog,lastVisitor:'npc_yunha'),'npc_makrye');
    // Every met neighbor but the last one is possible.
    for(final id in catalog.ids) { p=p.visit('all-$id',id,2,catalog); }
    final spread={for(var pick=0;pick<200;pick++) p.selectNamedVisitor(3,pick,config,catalog,lastVisitor:'npc_sua')};
    expect(spread,catalog.ids.toSet()..remove('npc_sua'));
  });
  test('짧은 이름과 이/가 조사 (S4-1-Q2)', () {
    expect(catalog.shortName('npc_doyun',{}),'도윤');
    expect(withSubjectParticle(catalog.shortName('npc_doyun',{})),'도윤이');
    expect(withSubjectParticle(catalog.shortName('npc_yunha',{})),'윤하 씨가');
    expect(withSubjectParticle(catalog.shortName('npc_makrye',{})),'막례 할머니가');
    expect(withSubjectParticle(catalog.shortName('npc_seojin',{})),'오 작가님이');
    expect(catalog.shortName('npc_seojin',{'story_seojin_01'}),'서진 씨');
    for(final id in catalog.ids) { expect(catalog.shortName(id,{}),isNotEmpty); }
    expect(withSubjectParticle('Kim'),'Kim이(가)');
  });
  test('선택 전과 반응 중 복원·닫기·재선택은 보상과 후일담을 한 번만 유지한다', () {
    var p=met(7).rollChoice(7,['choice_doyun_01'],0,config,catalog);
    p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(p.active!['choice'],isNull);
    p=p.choose('choice_doyun_01','b',config,catalog);
    p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(p.active!['choice'],'b');
    p=p.closeReaction('choice_doyun_01');
    p=p.choose('choice_doyun_01','b',config,catalog);
    expect(p.active,isNull);
    expect(p.affinity('npc_doyun'),2);
    expect(p.toJson()['followups'],{'choice_doyun_01':'b'});
    expect(()=>p.consumeFollowup('choice_doyun_01',contextMatches:false),throwsFormatException);
    p=p.consumeFollowup('choice_doyun_01',contextMatches:true);
    p=WorkshopRelationships.fromJson(p.toJson(),config,catalog);
    expect(()=>p.consumeFollowup('choice_doyun_01',contextMatches:true),throwsFormatException);
  });
  test('친밀도 합계를 원장과 대조하고 수치 변경은 기존 지급을 다시 계산하지 않는다', () {
    final p=met(7).successfulSale('sale','visit',7,config);
    final row=p.toJson();(row['affinity'] as Map)['npc_doyun']=3;
    expect(()=>WorkshopRelationships.fromJson(row,config,catalog),throwsFormatException);
    final changed=jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>;
    (changed['customer_relationships'] as Map)['sale_affinity']=1;
    final nextConfig=DevelopmentBalance.fromJson(changed);
    expect(WorkshopRelationships.fromJson(p.toJson(),nextConfig,catalog).affinity('npc_doyun'),2);
    expect(p.active,isNull);
  });

}
