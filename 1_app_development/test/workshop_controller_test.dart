import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
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
  s = s.pour(s.token, PaintAmount.even); s = s.fill(s.token, CookingDirection.left);
  s = s.pour(s.token, PaintAmount.even); s = s.close(s.token); return s.flip(s.token);
}
void main() {
  late DevelopmentBalance config;
  late Repository repository;
  late WorkshopController controller;
  final now = DateTime.utc(2026, 10, 16);
  setUp(() async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    raw['ordinary_sale']['base_buns_by_difficulty'] = ['20','40','60'];
    (raw['level_progression'][1] as Map).addAll(<String, dynamic>{'level_cost_buns':'10', 'additional_taps':2,
      'additional_sold_pieces':1, 'buns_reward':'3', 'gold_reward':1});
    config = DevelopmentBalance.fromJson(raw);
    repository = Repository();
    controller = WorkshopController(config, repository, now: () => now, random: Random(7));
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  test('신규 게임은 팥 미숙련·숙련된 붕어빵 미투입·재화0이며 코인 필드가 없다', () {
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
  test('승급은 이번 레벨 판매 개수·탭을 채우고 붕어빵력을 내며, 황금 보상은 심사 대기로 저장한다 (4차 g9)', () async {
    for (var i = 0; i < 9; i++) { controller.tap(); }
    expect(controller.levelGoalsMet, isFalse, reason: '이번 레벨 판매 0개');
    expect(await controller.command(() => controller.state.soldPieces = 1), isTrue);
    expect(controller.levelGoalsMet, isTrue);
    expect(controller.canLevelUp, isFalse, reason: '붕어빵력 9 < 비용 10');
    expect(controller.levelWaitReason, '붕어빵력이 1 모자라요.');
    expect(controller.levelProgressPermille, (1000 + 1000 + 900) ~/ 3);
    expect(controller.levelCostNote, '레벨업할 때 붕어빵력 10이 쓰여요');
    expect([for (final r in controller.levelRequirements) r.label],
        ['이번 레벨에 판 붕어빵', '이번 레벨 탭', '레벨업 비용 붕어빵력']);
    controller.tap();
    expect(controller.canLevelUp, isTrue);
    expect(controller.levelProgressPermille, 1000);
    expect(controller.state.level, 1, reason: '탭만으로는 오르지 않고 다음 명령에서 오름');
    expect(await controller.command(() {}), isTrue);
    expect(controller.state.level, 2);
    expect(controller.promotedTo, 2);
    expect(controller.state.buns, BigInt.from(3), reason: '10 내고 보상 3');
    expect(controller.state.lifetime, BigInt.from(13), reason: '낸 값은 누적에서 빼지 않음');
    expect(controller.state.pendingGold.containsKey('level:2'), isTrue);
    expect(controller.state.levelStartTaps, 10);
    expect(controller.state.levelStartPieces, 1);
    expect(controller.levelPiecesSold, 0);
    expect(controller.canLevelUp, isFalse);
    controller.dismissPromotion();
    expect(await controller.command(() {}), isTrue);
    expect(controller.state.level, 2);
    expect(controller.promotedTo, isNull);
    expect(controller.state.claimedLevels, {2});
  });
  test('판매 개수는 다 판 주문의 개수로 세고, 개수 없는 옛 저장은 판매 기록에서 다시 센다 (4차 g9)', () async {
    await controller.openBusiness();
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(ProductBatch(id: 'b1', flavor: 'redbean', variant: 2,
        quantity: 3, madeOnBusinessIndex: controller.state.business.businessIndex), keep: true);
      controller.state.customers.insert(0, CustomerOrder(id: 'o1', remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 3)]));
    });
    expect(await controller.sellToCustomer('o1'), isTrue, reason: controller.notice);
    expect(controller.state.soldPieces, 3);
    final old = controller.state.toJson()..remove('soldPieces')..remove('levelStartPieces');
    final loaded = WorkshopState.fromJson(old, config);
    expect(loaded.soldPieces, 3);
    expect(loaded.levelStartPieces, 0);
    expect(() => WorkshopState.fromJson({...controller.state.toJson(), 'levelStartPieces': 4}, config), throwsFormatException);
  });
  test('황금이 드는 레벨(level:N)은 서버 구매로 두 재화를 낸 뒤에만 오른다 (4차 g9)', () async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    (raw['level_progression'][1] as Map).addAll(<String, dynamic>{'level_cost_buns':'5', 'additional_taps':0,
      'additional_sold_pieces':1, 'level_cost_gold':20});
    final goldConfig = DevelopmentBalance.fromJson(raw), gateway = Gateway();
    final c = WorkshopController(goldConfig, Repository(), now: () => now, random: Random(7), purchaseGateway: gateway);
    addTearDown(c.dispose); await c.initialize();
    for (var i = 0; i < 8; i++) { c.tap(); }
    await c.command(() => c.state.soldPieces = 1);
    expect(c.levelCostNote, '레벨업할 때 붕어빵력 5, 황금붕어빵력 20개가 쓰여요');
    expect(c.levelRequirements.length, 4);
    c.goldBalance = 19;
    expect(c.canLevelUp, isFalse);
    expect(c.levelGoldDue, isFalse);
    expect(c.levelWaitReason, '황금붕어빵력이 1 모자라요.');
    c.goldBalance = 20;
    expect(c.levelGoldDue, isTrue);
    expect(await c.command(() {}), isTrue);
    expect(c.state.level, 1, reason: '황금을 내기 전');
    expect(await c.payLevelGold(), isTrue, reason: c.notice);
    expect(c.state.purchases.owned['level:2'], 1);
    // The purchase took 붕어빵력 5; the automatic 승급 (4차 g1) raises the
    // level by the next command at the latest, without taking it twice.
    await c.command(() {});
    expect(c.state.level, 2);
    expect(c.state.buns, BigInt.from(3) + DevelopmentBalance.decimal(goldConfig.rows('level_progression')[1], 'buns_reward'),
        reason: '8 - 5 + 레벨 보상, 두 번 빼지 않음');
    final reloaded = WorkshopState.fromJson(c.state.toJson(), goldConfig);
    expect(reloaded.purchases.owned['level:2'], 1);
  });
  test('저장에 실패하면 자동 승급도 되돌리고, 레벨마다 판매가 새로 필요해 한 번에 여러 레벨을 오르지 않는다 (4차 IA1·g9)', () async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    for (final i in [1, 2]) {
      (raw['level_progression'][i] as Map).addAll(<String, dynamic>{'level_cost_buns':'5', 'additional_taps':i == 1 ? 2 : 0,
        'additional_sold_pieces':1, 'level_cost_gold':0, 'buns_reward':'3', 'gold_reward':1});
    }
    final chained = DevelopmentBalance.fromJson(raw), repo = Repository();
    final c = WorkshopController(chained, repo, now: () => now, random: Random(7));
    await c.initialize();
    try {
      for (var i = 0; i < 10; i++) { c.tap(); }
      repo.fail = true;
      expect(await c.command(() => c.state.soldPieces = 2), isFalse);
      expect(c.state.level, 1);
      expect(c.promotedTo, isNull);
      await c.reloadAfterError();
      while (c.state.taps < 10) { c.tap(); }
      expect(await c.command(() => c.state.soldPieces = 2), isTrue);
      expect(c.state.level, 2, reason: '앞 레벨에 판 2개는 다음 레벨로 넘어가지 않음');
      expect(c.promotedTo, 2);
      expect(c.state.pendingGold.keys, contains('level:2'));
      expect(await c.command(() => c.state.soldPieces = 3), isTrue);
      expect(c.state.level, 3);
      expect(c.state.claimedLevels, {2, 3});
    } finally { c.dispose(); }
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
    expect(controller.state.buns, BigInt.from(80));
    expect(controller.state.purchases.owned, isEmpty);
    expect(await controller.recoverPurchase(gateway, transaction), isTrue);
    expect(controller.state.purchases.owned, {'tap_1':1});
    expect(await controller.recoverPurchase(gateway, transaction), isTrue);
    expect(controller.state.buns, BigInt.from(80));
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
    expect(controller.state.buns, BigInt.from(80));
    expect(controller.tapRate, BigInt.from(2));
  });
  test('로그인 전 레벨업은 미정산 거래 없이 로그인 안내만 남긴다 (26번 3단계)', () async {
    await controller.command(() { controller.state.buns = BigInt.from(100); controller.state.lifetime = BigInt.from(100); });
    final gateway = Gateway()..authenticatedAccount = '';
    expect(await controller.purchaseSkill(gateway, 'tap_1'), isFalse);
    expect(controller.notice, '카카오 로그인 후 레벨업할 수 있어요.');
    expect(controller.state.purchases.journals, isEmpty);
    expect(gateway.reservations, 0);
    expect(controller.state.buns, BigInt.from(100));
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
    // In business the mold makes orders only (24번 3단계).
    final order = controller.state.customers.single, flavor = order.lines.first.flavor;
    expect(await controller.startOrderProduction(order.id, flavor), isFalse);
    expect(controller.state.customers.single.toJson(), customer);
    controller.setAdPaused(false);
    expect(await controller.startOrderProduction(order.id, flavor), isTrue);
  });
  test('schema1은 구매 없는 schema4로 읽되 신규 구매 누락은 초기화하지 않는다', () {
    final legacy = controller.state.toJson();
    legacy['schema'] = 1;
    for(final key in ['purchases','rewardAccount','rewardReceipts','adAttempts','avatarEquipment','missions','sceneTime','relationships','customerScene','tutorial','regularClock','namedClock','lastNamedVisitor','featureIntros','daily','pantry']) { legacy.remove(key); }
    expect(WorkshopState.fromJson(legacy, config).toJson()['schema'], workshopSchema);
    final corrupted = controller.state.toJson()..remove('purchases');
    expect(() => WorkshopState.fromJson(corrupted, config), throwsFormatException);
  });
  // 4차 피드백 g7 (사용자 결정 2026-11-21): 예전 경제의 저장은 출시 전에 한 번 처음부터.
  test('경제 재조정 전(schema 10) 저장은 처음 열 때 한 번 새 가게로, 고른 사장님·끝낸 안내만 남긴다', () async {
    expect(await controller.command(() {
      controller.state.buns = BigInt.parse('900000000'); controller.state.lifetime = BigInt.parse('900000000');
      controller.state.tutorial = 'done';
    }), isTrue, reason: controller.error);
    expect(await controller.chooseStarterCharacter('boy'), isTrue);
    final old = controller.state.toJson()..['schema'] = 10..remove('pantry');
    final oldRun = controller.state.grid.runId, oldSequence = old['sequence'] as int;
    final stored = Repository()..stored = old;
    final reopened = WorkshopController(config, stored, now: () => now, random: Random(8));
    addTearDown(reopened.dispose);
    await reopened.initialize();
    final s = reopened.state;
    expect(s.level, 1);
    expect(s.buns, BigInt.zero);
    expect(s.lifetime, BigInt.zero);
    expect(s.purchases.owned, isEmpty);
    expect(s.avatarGrants, {'boy'});
    expect(s.avatarEquipment['character'], 'boy');
    expect(s.tutorial, 'done');
    expect(s.grid.runId, isNot(oldRun));
    expect(s.sequence, oldSequence + 1);
    expect(reopened.notice, economyResetNotice);
    expect(reopened.awayReport, isNull);
    expect(stored.stored!['schema'], workshopSchema);
    // Once: the saved schema 11 shop is not reset again.
    await reopened.command(() { reopened.state.buns = BigInt.from(5); reopened.state.lifetime = BigInt.from(5); });
    final again = WorkshopController(config, stored, now: () => now, random: Random(9));
    addTearDown(again.dispose);
    await again.initialize();
    expect(again.state.buns, BigInt.from(5));
    expect(again.state.grid.runId, s.grid.runId);
    expect(again.notice, isNull);
  });
  test('경제 재조정 초기화: 안내 중이던 저장은 안내부터, 사장님을 고르지 않았으면 여자 사장님', () {
    final old = WorkshopState.fromJson(controller.state.toJson(), config);
    expect(old.tutorialActive, isTrue);
    final fresh = WorkshopState.economyReset(old, now, config, 'resetrun0000000000000001');
    expect(fresh.tutorial, 'cook');
    expect(fresh.avatarGrants, {'girl'});
    expect(fresh.avatarEquipment.containsKey('character'), isFalse);
    expect(WorkshopState.fromJson(fresh.toJson(), config).toJson(), fresh.toJson());
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

  test('첫 도윤은 팥 주문, 소개 하루 2명 뒤에는 직전 손님을 뺀 네임드, 일반 손님은 무기명 (5-1단계)', () async {
    await controller.openBusiness();
    expect(await controller.welcomeCustomer(),isTrue);
    final first=controller.state.customers.single;
    expect(first.customerId,'npc_doyun');expect(first.lines.single.flavor,'redbean');
    await controller.command(()=>controller.state.customers.clear());
    await controller.welcomeCustomer();
    expect(controller.state.customers.single.customerId,'npc_yunha');
    await controller.command(()=>controller.state.customers.clear());
    await controller.welcomeCustomer();
    expect(controller.state.customers.single.customerId,'npc_doyun',reason:'하루 1회 제한 없음, 직전 윤하는 뺌');
    expect(controller.state.lastNamedVisitor,'npc_doyun');
    await controller.command(()=>controller.state.customers.clear());
    await controller.welcomeCustomer(named:false);
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
  test('schema3 보상·구매를 유지하여 최신 schema로 읽고 관계 누락은 새 기본값으로 덮지 않는다', () {
    final old=controller.state.toJson()..remove('relationships')..remove('customerScene')..remove('tutorial')..remove('regularClock')..remove('namedClock')..remove('lastNamedVisitor')..remove('featureIntros')..remove('daily')..remove('pantry');old['schema']=3;
    final restored=WorkshopState.fromJson(old,config);
    expect(restored.purchases.toJson(),controller.state.purchases.toJson());
    expect(restored.toJson()['schema'], workshopSchema);
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

  test('주문 ID 재납품은 다음 손님에게 판매하거나 재고를 소비하지 않는다', () async {
    await controller.openBusiness();
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(ProductBatch(
        id:'two-products',flavor:'redbean',variant:2,quantity:2,madeOnBusinessIndex:1),keep:true);
      for (final id in ['first-order','next-order']) {
        controller.state.customers.add(CustomerOrder(id:id,remainingMs:10000,
          lines:[CustomerOrderLine(flavor:'redbean',quantity:1)]));
      }
    });
    expect(await controller.sellToCustomer('next-order'),isFalse);
    expect(await controller.sellToCustomer('first-order'),isTrue);
    final buns=controller.state.buns;
    expect(await controller.sellToCustomer('first-order'),isFalse);
    expect(controller.state.buns,buns);
    expect(controller.state.inventory.batches['two-products']!.quantity,1);
    expect(controller.state.customers.single.id,'next-order');
    expect(controller.state.completedSales,1);
  });
  test('잘못 선택한 제품은 무소비 재선택하며 대기 유예를 만들지 않는다', () async {
    await controller.openBusiness();
    await controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(ProductBatch(
        id:'stock',flavor:'redbean',variant:2,quantity:1,madeOnBusinessIndex:1),keep:true);
      controller.state.customers.add(CustomerOrder(id:'manual-selection',remainingMs:10000,
        lines:[CustomerOrderLine(flavor:'redbean',quantity:1,variant:1)]));
    });
    final before=controller.state.inventory.toJson();
    expect(await controller.sellToCustomer('manual-selection',selectedByLine:[{'stock':1}]),isFalse);
    expect(controller.state.inventory.toJson(),before);
    expect(controller.state.customers.single.remainingMs,lessThanOrEqualTo(10000));
    expect(controller.state.sales,isEmpty);
    expect(controller.state.pendingGold,isEmpty);
  });
  test('개인 대기는 장면 중 멈추고 복귀 뒤 만료된 손님만 이탈한다', () async {
    await controller.openBusiness();await controller.welcomeCustomer();
    await controller.command(() {
      final first=controller.state.customers.single;
      controller.state.customers=[CustomerOrder(id:first.id,customerId:first.customerId,
        remainingMs:50,lines:first.lines),CustomerOrder(id:'long-wait',remainingMs:10000,lines:first.lines)];
      controller.state.customerScene={'kind':'story','id':'story_doyun_01','npc':'npc_doyun'};
    });
    await Future<void>.delayed(const Duration(milliseconds:200));
    await controller.command(() {});
    expect(controller.state.customers.first.remainingMs,50);
    expect(controller.state.customers.last.remainingMs,10000);
    expect(await controller.finishCustomerScene(),isTrue);
    await Future<void>.delayed(const Duration(milliseconds:200));
    await controller.command(() {});
    expect(controller.state.customers.single.id,'long-wait');
    expect(controller.state.customers.single.remainingMs,lessThan(10000));
    expect(controller.state.sales,isEmpty);
    expect(controller.state.relationships.affinity('npc_doyun'),1);
  });

}
