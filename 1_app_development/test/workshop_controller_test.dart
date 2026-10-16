import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';

class Repository implements WorkshopRepository {
  Map<String, dynamic>? stored;
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> load() async => stored == null ? null : jsonDecode(jsonEncode(stored)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    if (fail) { fail = false; throw Exception('save failed'); }
    if ((stored?['sequence'] ?? 0) != expectedSequence) throw const FormatException('stale');
    stored = jsonDecode(jsonEncode(next)) as Map<String, dynamic>;
  }
}
class Gateway implements WorkshopPurchaseGateway {
  @override
  String authenticatedAccount = 'account';
  Map<String,dynamic>? receipt;
  bool loseCommit = false;
  Repository? failReceiptSave;
  int commits = 0, reservations = 0;
  @override
  Future<void> requireActiveProgress(String progressId) async {}
  @override
  Future<Map<String,dynamic>> reserve(PurchaseJournal intent) async {
    reservations++;
    return receipt ??= {...intent.toJson(), 'status':'reserved'};
  }
  @override
  Future<Map<String,dynamic>> commit(PurchaseJournal intent) async {
    commits++;
    receipt = {...intent.toJson(), 'status':'committed', 'receiptId':'receipt-fixed', 'grantId':'grant-fixed'};
    if (loseCommit) { loseCommit = false; throw Exception('response lost'); }
    failReceiptSave?.fail = true; failReceiptSave = null;
    return receipt!;
  }
  @override
  Future<Map<String,dynamic>> query(String accountId, String transactionId) async => receipt ??
    {'account':accountId,'transaction':transactionId,'status':'unknown'};
  @override
  Future<Map<String,dynamic>> cancel(String accountId, String transactionId) async => receipt!;
}
CookingSession cookingFixture() {
  var s = CookingSession.start(id: 'practice-result', flavor: 'redbean', practice: true,
      fillingSequence: [CookingDirection.left]);
  s = s.pour(s.token, 2500); s = s.fill(s.token, CookingDirection.left);
  s = s.pour(s.token, 2500); s = s.close(s.token); return s.flip(s.token);
}
void main() {
  late DevelopmentBalance config;
  late Repository repository;
  late WorkshopController controller;
  final now = DateTime.utc(2026, 10, 16);
  setUp(() async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    raw['ordinary_sale']['base_buns_by_difficulty'] = ['20','40','60'];
    (raw['level_progression'][1] as Map).addAll({'season_total_buns':'10', 'additional_taps':2,
      'additional_sales':0, 'buns_reward':'3', 'gold_reward':1});
    config = DevelopmentBalance.fromJson(raw);
    repository = Repository();
    controller = WorkshopController(config, repository, now: () => now, random: Random(7));
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  test('신규 게임은 팥 미숙련·6구 미투입·재화0이며 코인 필드가 없다', () {
    expect(controller.state.buns, BigInt.zero);
    expect(controller.state.mastery.complete(config), isFalse);
    expect(controller.state.grid.cookingSourceIds, isEmpty);
    expect(controller.state.toJson().containsKey('coins'), isFalse);
    expect(WorkshopState.fromJson(controller.state.toJson(), config).toJson(), controller.state.toJson());
  });
  test('제작 결과 저장 실패는 숙련과 단계 모두 복원하며 재시도도 같은 ID다', () async {
    final cooking = cookingFixture();
    await controller.command(() => controller.state.session = cooking);
    repository.fail = true;
    expect(await controller.cookingCommand(cooking.takeOut(cooking.token, 15000)), isFalse);
    expect(controller.state.mastery.practices, 0);
    expect(controller.state.session!.phase, CookingPhase.cooking);
    await controller.reloadAfterError();
    expect(await controller.cookingCommand(cooking.takeOut(cooking.token, 15000)), isTrue);
    expect(controller.state.mastery.practices, 1);
    expect(controller.state.mastery.results.keys, contains('practice-result'));
    expect(controller.state.inventory.batches, isEmpty);
  });
  test('연습 결과 보관은 영업 전 준비품이며 영업 시작 때만 최초 귀속한다', () async {
    final cooking = cookingFixture();
    await controller.command(() => controller.state.session = cooking);
    await controller.cookingCommand(cooking.takeOut(cooking.token, 15000));
    expect(await controller.storeResult(true), isTrue);
    expect(controller.state.inventory.prepared.length, 1);
    expect(controller.state.inventory.batches, isEmpty);
    await controller.openBusiness();
    expect(controller.state.inventory.batches.values.single.madeOnBusinessIndex, 1);
    await controller.openBusiness();
    expect(controller.state.business.businessIndex, 1);
  });
  test('전량 판매 저장 실패는 재고·대금·판매·황금 대기 모두 되돌린다', () async {
    await controller.openBusiness();
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(ProductBatch(
        id: 'product', flavor: 'redbean', variant: 2, quantity: 2, madeOnBusinessIndex: 1), keep: true);
      controller.state.customers.add(CustomerOrder(id: 'customer', remainingMs: 10000,
        lines: [CustomerOrderLine(flavor: 'redbean', quantity: 2)]));
    });
    repository.fail = true;
    expect(await controller.sellToFirstCustomer(), isFalse);
    expect(controller.state.inventory.batches['product']!.quantity, 2);
    expect(controller.state.buns, BigInt.zero);
    expect(controller.state.completedSales, 0);
    expect(controller.state.pendingGold, isEmpty);
    await controller.reloadAfterError();
    expect(await controller.sellToFirstCustomer(), isTrue);
    expect(controller.state.buns, BigInt.from(40));
    expect(controller.state.lifetime, BigInt.from(40));
    expect(controller.state.completedSales, 1);
    expect(controller.state.pendingGold.length, 1);
  });
  test('일반 재고 부족은 저장 장애가 아니라 안내로 처리하고 계속 진행한다', () async {
    await controller.openBusiness();
    await controller.welcomeCustomer();
    expect(await controller.sellToFirstCustomer(), isFalse);
    expect(controller.error, isNull);
    expect(controller.notice, isNotNull);
  });
  test('승급은 수동1회이며 황금은 로컬 지급 대신 심사 대기로 저장한다', () async {
    for (var i = 0; i < 10; i++) { controller.tap(); }
    expect(controller.state.level, 1);
    expect(controller.canLevelUp, isTrue);
    expect(await controller.levelUp(), isTrue);
    expect(controller.state.level, 2);
    expect(controller.state.buns, BigInt.from(13));
    expect(controller.state.pendingGold.containsKey('level:2'), isTrue);
    expect(controller.state.levelStartTaps, 10);
    expect(await controller.levelUp(), isFalse);
    expect(controller.state.claimedLevels, {2});
  });
  test('손님이 취소·퇴장해도 명시 주문 관찰은 남고 도감 보상은 없다', () async {
    await controller.openBusiness();
    await controller.welcomeCustomer();
    final customer = controller.state.customers.single.customerId;
    expect(controller.state.tasteObservations[customer]!.keys, contains('redbean'));
    expect(controller.state.tasteObservations[customer]!['redbean'], isEmpty);
    await controller.closeBusiness();
    expect(controller.state.customers, isEmpty);
    expect(controller.state.tasteObservations.containsKey(customer), isTrue);
    expect(controller.state.pendingGold, isEmpty);
  });

  test('서버 확정 응답 유실 후 같은 거래 조회로 차감·상품을 중복하지 않는다', () async {
    await controller.command(() { controller.state.buns = BigInt.from(100); controller.state.lifetime = BigInt.from(100); });
    final gateway = Gateway()..loseCommit = true;
    expect(await controller.purchaseSkill(gateway, 'tap_1'), isFalse);
    final transaction = controller.state.purchases.journals.keys.single;
    expect(controller.state.buns, BigInt.from(85));
    expect(controller.state.purchases.owned, isEmpty);
    expect(await controller.recoverPurchase(gateway, transaction), isTrue);
    expect(controller.state.purchases.owned, {'tap_1':1});
    expect(await controller.recoverPurchase(gateway, transaction), isTrue);
    expect(controller.state.buns, BigInt.from(85));
    expect(gateway.commits, 1); expect(gateway.reservations, 1);
  });
  test('서버 성공 후 영수증 저장 실패는 재읽기 전 새 상품/구매를 허용하지 않는다', () async {
    await controller.command(() { controller.state.buns = BigInt.from(100); controller.state.lifetime = BigInt.from(100); });
    final gateway = Gateway()..failReceiptSave = repository;
    expect(await controller.purchaseSkill(gateway, 'tap_1'), isFalse);
    expect(controller.error, isNotNull); expect(controller.state.purchases.owned, isEmpty);
    expect(await controller.purchaseSkill(gateway, 'tap_1'), isFalse);
    await controller.reloadAfterError();
    final transaction = controller.state.purchases.journals.keys.single;
    expect(await controller.recoverPurchase(gateway, transaction), isTrue);
    expect(controller.state.buns, BigInt.from(85));
    expect(controller.tapRate, BigInt.from(2));
  });
  test('구매 계정을 바꿔도 기존 지갑의 미정산 거래를 다른 계정으로 이전하지 않는다', () async {
    await controller.command(() { controller.state.buns = BigInt.from(100); controller.state.lifetime = BigInt.from(100); });
    final gateway = Gateway()..loseCommit = true;
    await controller.purchaseSkill(gateway, 'tap_1');
    final transaction = controller.state.purchases.journals.keys.single;
    gateway.authenticatedAccount = 'other';
    expect(await controller.recoverPurchase(gateway, transaction), isFalse);
    expect(controller.state.purchases.account, 'account');
    expect(controller.state.purchases.owned, isEmpty);
  });
  test('자동 스킬의 앱 복귀 정산은 전경100%가 아니라 부재50%를 한 번 적용한다', () async {
    controller.dispose();
    var at = now;
    controller = WorkshopController(config, repository, now: () => at, random: Random(9));
    await controller.initialize(); await controller.openBusiness();
    await controller.command(() { controller.state.buns = BigInt.from(100); controller.state.lifetime = BigInt.from(100); });
    expect(await controller.purchaseSkill(Gateway(), 'auto_1'), isTrue);
    await controller.setForeground(false);
    final before = controller.state.buns;
    at = at.add(const Duration(seconds: 10));
    await controller.setForeground(true);
    expect(controller.state.buns - before, BigInt.from(5));
    await controller.setForeground(true);
    expect(controller.state.buns - before, BigInt.from(5));
  });
  test('광고 일시정지는 고객·제작 입력을 막고 일반 경제 시계는 유지한다', () async {
    await controller.openBusiness(); await controller.welcomeCustomer();
    controller.setAdPaused(true);
    final customer = controller.state.customers.single.toJson();
    final buns = controller.state.buns;
    controller.tap();
    expect(controller.state.buns, buns);
    expect(await controller.startPractice(), isFalse);
    expect(controller.state.customers.single.toJson(), customer);
    controller.setAdPaused(false);
    expect(await controller.startPractice(), isTrue);
  });
  test('schema1은 구매 없는 schema4로 읽되 신규 구매 누락은 초기화하지 않는다', () {
    final legacy = controller.state.toJson();
    legacy['schema'] = 1;
    for(final key in ['purchases','rewardAccount','rewardReceipts','adAttempts','avatarEquipment','missions','sceneTime','relationships','customerScene']) { legacy.remove(key); }
    expect(WorkshopState.fromJson(legacy, config).toJson()['schema'], 4);
    final corrupted = controller.state.toJson()..remove('purchases');
    expect(() => WorkshopState.fromJson(corrupted, config), throwsFormatException);
  });
  test('판매 원장과 심사 증거가 달라지면 손상 저장을 거부한다', () async {
    await controller.openBusiness();
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(ProductBatch(
        id:'sale-product', flavor:'redbean', variant:2, quantity:1, madeOnBusinessIndex:1), keep:true);
      controller.state.customers.add(CustomerOrder(id:'sale-customer', remainingMs:10000,
        lines:[CustomerOrderLine(flavor:'redbean', quantity:1)]));
    });
    expect(await controller.sellToFirstCustomer(), isTrue);
    final saved = controller.state.toJson();
    expect(WorkshopState.fromJson(saved,config).completedSales,1);
    (saved['pendingGold'] as Map)['sale:sale-customer'] = '{}';
    expect(() => WorkshopState.fromJson(saved, config), throwsFormatException);
  });

  test('주문 제작은 연습량/손기술을 올리지 않고 제품과 익힘 발견을 함께 저장한다', () async {
    await controller.openBusiness(); await controller.welcomeCustomer();
    final order = controller.state.customers.single;
    expect(await controller.startOrderProduction(order.id,'redbean'), isTrue);
    expect(controller.state.session!.practice,isFalse);
    final row = cookingFixture().toJson(); row['practice'] = false;
    final cooking = CookingSession.fromJson(row);
    await controller.command(() => controller.state.session = cooking);
    expect(await controller.cookingCommand(cooking.takeOut(cooking.token,0)), isTrue);
    expect(controller.state.mastery.practices,0);
    expect(controller.state.mastery.techniquePasses,0);
    expect(controller.state.mastery.discovered,isNotEmpty);
    expect(controller.state.inventory.batches.containsKey(cooking.id),isTrue);
    final before = controller.state.inventory.toJson();
    expect(await controller.storeResult(true),isTrue);
    expect(controller.state.inventory.toJson(),before);
  });
  test('이미 판매한 제품을 재고에 되살린 저장은 생산량 대조로 거부한다', () async {
    await controller.openBusiness();
    final product = ProductBatch(id:'one-product',flavor:'redbean',variant:2,quantity:1,madeOnBusinessIndex:1);
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(product,keep:true);
      controller.state.customers.add(CustomerOrder(id:'one-order',remainingMs:10000,
        lines:[CustomerOrderLine(flavor:'redbean',quantity:1)]));
    });
    expect(await controller.sellToFirstCustomer(),isTrue);
    final saved = controller.state.toJson();
    (saved['inventory']['batches'] as Map)['one-product'] = product.toJson();
    expect(() => WorkshopState.fromJson(saved,config),throwsFormatException);
  });

  test('첫 도윤은 팥 주문이며 네임드 하루2명 뒤에는 무기명 손님이 온다', () async {
    await controller.openBusiness();
    expect(await controller.welcomeCustomer(),isTrue);
    final first=controller.state.customers.single;
    expect(first.customerId,'npc_doyun');expect(first.lines.single.flavor,'redbean');
    await controller.command(()=>controller.state.customers.clear());
    await controller.welcomeCustomer();
    expect(controller.state.customers.single.customerId,'npc_yunha');
    await controller.command(()=>controller.state.customers.clear());
    await controller.welcomeCustomer();
    final anonymous=controller.state.customers.single.customerId;
    expect(anonymous,startsWith('anonymous_'));
    expect(controller.state.tasteObservations.containsKey(anonymous),isFalse);
    expect(controller.state.relationships.met.length,2);
  });
  test('판매 저장 실패는 재고·방문·친밀도를 함께 복원하고 같은 주문으로 재시도한다', () async {
    await controller.openBusiness();await controller.welcomeCustomer();
    final order=controller.state.customers.single;
    await controller.observeWaiting(order.id);
    await controller.command(() {
      controller.state.inventory=controller.state.inventory.recordResult(ProductBatch(
        id:'named-product',flavor:'redbean',variant:2,quantity:1,madeOnBusinessIndex:1),keep:true);
    });
    repository.fail=true;
    expect(await controller.sellToFirstCustomer(),isFalse);
    expect(controller.state.relationships.affinity('npc_doyun'),1);
    expect(controller.state.customers.single.id,order.id);
    expect(controller.state.inventory.batches['named-product']!.quantity,1);
    await controller.reloadAfterError();
    expect(await controller.sellToFirstCustomer(),isTrue);
    expect(controller.state.relationships.affinity('npc_doyun'),3);
    final restored=WorkshopState.fromJson(controller.state.toJson(),config);
    expect(restored.relationships.affinity('npc_doyun'),3);
    expect(restored.sales.length,1);
  });
  test('schema3 보상·구매를 유지하여 schema4로 읽고 관계 누락은 새 기본값으로 덮지 않는다', () {
    final old=controller.state.toJson()..remove('relationships')..remove('customerScene');old['schema']=3;
    final restored=WorkshopState.fromJson(old,config);
    expect(restored.purchases.toJson(),controller.state.purchases.toJson());
    expect(restored.toJson()['schema'],4);
    final bad=controller.state.toJson()..remove('relationships');
    expect(()=>WorkshopState.fromJson(bad,config),throwsFormatException);
    old['relationships']={};expect(()=>WorkshopState.fromJson(old,config),throwsFormatException);
  });
  test('활성 관계 장면을 복원하며 대화 중 탭·영업일 전진을 막는다', () async {
    await controller.openBusiness();await controller.welcomeCustomer();
    await controller.command(()=>controller.state.customerScene={
      'kind':'story','id':'story_doyun_01','npc':'npc_doyun'});
    final before=controller.state.taps;
    controller.tap();expect(controller.state.taps,before);
    expect(await controller.openBusiness(),isFalse);
    expect(WorkshopState.fromJson(controller.state.toJson(),config).customerScene!['id'],'story_doyun_01');
    expect(await controller.finishCustomerScene(),isTrue);
    expect(controller.state.relationships.stories,contains('story_doyun_01'));
    final affinity=controller.state.relationships.affinity('npc_doyun');
    await controller.replayCustomerStory('story_doyun_01');await controller.finishCustomerScene();
    expect(controller.state.relationships.affinity('npc_doyun'),affinity);
  });

}
