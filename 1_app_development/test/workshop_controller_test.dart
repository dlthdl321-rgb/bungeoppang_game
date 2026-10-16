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

}
