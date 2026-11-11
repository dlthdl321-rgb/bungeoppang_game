import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_sale_quality.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'workshop_controller_test.dart' show Repository;

/// 부분 판매(DEC-017/023/007, DEC-018/022): 모자란 재고는 있는 만큼 먼저 드리고
/// 일반 대금만 바로 받는다. 판매 횟수·황금 심사는 주문을 다 채운 순간 한 번이다.
void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));
  ProductBatch batch(String id, int day, {int count = 1, int variant = 2}) =>
      ProductBatch(id: id, flavor: 'redbean', variant: variant, quantity: count, madeOnBusinessIndex: day);
  CustomerOrder order({int quantity = 2}) => CustomerOrder(
      id: 'order', remainingMs: 10000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: quantity)]);
  const difficulties = {'redbean': 0};

  group('주문 규칙', () {
    test('부분 납품은 대금만 즉시 받고 판매 원장을 만들지 않는다', () {
      final stock = InventoryProgress.empty().recordResult(batch('first', 1), keep: true);
      final start = CustomerSalesProgress(inventory: stock, ordinaryBuns: BigInt.zero, lifetimeSalesBuns: BigInt.zero);
      final selected = selectCustomerInventory(order(), stock, businessIndex: 1, partial: true);
      expect(selected, [{'first': 1}]);
      expect(() => selectCustomerInventory(order(), stock, businessIndex: 1), throwsFormatException);
      final (progress, next) = start.deliver(config, order(), selectedByLine: selected,
          businessIndex: 1, flavorDifficulties: difficulties);
      expect(progress.sales, isEmpty);
      expect(progress.inventory.batches, isEmpty);
      expect(progress.ordinaryBuns, greaterThan(BigInt.zero));
      expect(progress.ordinaryBuns, progress.lifetimeSalesBuns);
      expect(next.remaining(0), 1);
      expect(next.deliveries.single.ordinaryBuns, progress.ordinaryBuns);
      expect(CustomerOrder.fromJson(jsonDecode(jsonEncode(next.toJson())) as Map<String, dynamic>).toJson(), next.toJson());
    });

    test('완료 별점은 판매 당시 값으로 고정해 개수 가중하고 대금은 이중 지급하지 않는다', () {
      // 첫 제품은 1영업일 나이 0에 바삭함으로, 나머지는 2영업일에 미디엄 나이 1로 드린다.
      var stock = InventoryProgress.empty().recordResult(batch('crisp', 1, variant: 3), keep: true);
      final first = CustomerSalesProgress(inventory: stock, ordinaryBuns: BigInt.zero, lifetimeSalesBuns: BigInt.zero);
      final (partial, waiting) = first.deliver(config, order(), selectedByLine: [{'crisp': 1}],
          businessIndex: 1, flavorDifficulties: difficulties);
      stock = partial.inventory.recordResult(batch('medium', 1), keep: true);
      final done = CustomerSalesProgress(inventory: stock, ordinaryBuns: partial.ordinaryBuns,
          lifetimeSalesBuns: partial.lifetimeSalesBuns, sales: partial.sales)
          .sell(config, waiting, selectedByLine: [{'medium': 1}], businessIndex: 2, flavorDifficulties: difficulties);
      final expected = evaluateSaleQuality(config, [
        SaleQualityPortion(variant: 3, quantity: 1, age: 0, difficulty: 0),
        SaleQualityPortion(variant: 2, quantity: 1, age: 1, difficulty: 0)]);
      final evidence = validateStoredCustomerSale('order', done.sales['order']!);
      expect(evidence['stars'], expected.stars);
      expect(evidence['scorePermille'], expected.scorePermille);
      expect(evidence['ordinaryBuns'], expected.provisionalOrdinaryBuns.toString());
      expect(done.ordinaryBuns, expected.provisionalOrdinaryBuns);
      expect((evidence['order'] as Map).containsKey('deliveries'), isFalse);
      final products = (evidence['products'] as List).cast<Map<String, dynamic>>();
      expect(products.first['soldOnBusinessIndex'], 1);
      expect(products.first['age'], 0);
      expect(products.last.containsKey('soldOnBusinessIndex'), isFalse);
      // 같은 완료 요청 재시도는 그대로 돌려준다.
      expect(done.sell(config, waiting, selectedByLine: [{'medium': 1}], businessIndex: 2,
          flavorDifficulties: difficulties), same(done));
    });

    test('이미 드린 묶음은 같은 행에 다시 고르지 않고 맞는 재고가 없으면 무소비 실패', () {
      final stock = InventoryProgress.empty().recordResult(batch('first', 1), keep: true);
      final waiting = order(quantity: 3).withDeliveries([CustomerDelivery(batch: 'first', flavor: 'redbean', line: 0,
          variant: 2, quantity: 1, madeOnBusinessIndex: 1, soldOnBusinessIndex: 1, ordinaryBuns: BigInt.one)]);
      expect(() => selectCustomerInventory(waiting, stock, businessIndex: 1, partial: true), throwsFormatException);
      final start = CustomerSalesProgress(inventory: stock, ordinaryBuns: BigInt.zero, lifetimeSalesBuns: BigInt.zero);
      expect(() => start.deliver(config, waiting, selectedByLine: [{'first': 1}], businessIndex: 1,
          flavorDifficulties: difficulties), throwsFormatException);
      expect(() => start.deliver(config, order(), selectedByLine: [{}], businessIndex: 1,
          flavorDifficulties: difficulties), throwsFormatException);
      expect(() => order(quantity: 1).withDeliveries([...waiting.deliveries, CustomerDelivery(batch: 'more',
          flavor: 'redbean', line: 0, variant: 2, quantity: 1, madeOnBusinessIndex: 1, soldOnBusinessIndex: 1,
          ordinaryBuns: BigInt.one)]), throwsFormatException);
    });

    test('주문을 다 채우는 납품은 부분 판매로 처리하지 않는다', () {
      final stock = InventoryProgress.empty().recordResult(batch('two', 1, count: 2), keep: true);
      final start = CustomerSalesProgress(inventory: stock, ordinaryBuns: BigInt.zero, lifetimeSalesBuns: BigInt.zero);
      expect(() => start.deliver(config, order(), selectedByLine: [{'two': 2}], businessIndex: 1,
          flavorDifficulties: difficulties), throwsFormatException);
    });
  });

  group('컨트롤러', () {
    late Repository repository;
    late WorkshopController controller;
    setUp(() async {
      repository = Repository();
      controller = WorkshopController(config, repository, now: () => DateTime.utc(2026, 10, 16), random: Random(7));
      await controller.initialize();
      await controller.openBusiness();
    });
    tearDown(() => controller.dispose());
    Future<void> stock(String id, {int count = 1}) => controller.command(() {
      controller.state.inventory = controller.state.inventory.recordResult(batch(id, 1, count: count), keep: true);
    });

    test('모자란 재고는 먼저 드리고 남은 수량을 채우면 판매 1회·황금 심사 1건', () async {
      await controller.command(() => controller.state.customers.add(order(quantity: 3)));
      await stock('first');
      expect(controller.saleReadyCount(controller.state.customers.single), 1);
      expect(await controller.sellToCustomer('order'), isTrue);
      final paid = controller.state.buns;
      expect(paid, greaterThan(BigInt.zero));
      expect(controller.state.completedSales, 0);
      expect(controller.state.sales, isEmpty);
      expect(controller.state.pendingGold, isEmpty);
      expect(controller.state.customers.single.remaining(0), 2);
      // 저장 후 다시 읽어도 납품 기록과 대금이 맞는다.
      final reloaded = WorkshopState.fromJson(jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>, config);
      expect(reloaded.customers.single.deliveries.single.batch, 'first');
      expect(reloaded.buns, paid);

      await stock('rest', count: 2);
      expect(controller.saleReadyCount(controller.state.customers.single), 2);
      expect(await controller.sellToCustomer('order'), isTrue);
      expect(controller.state.completedSales, 1);
      expect(controller.state.customers, isEmpty);
      expect(controller.state.pendingGold.keys, ['sale:order']);
      final evidence = validateStoredCustomerSale('order', controller.state.sales['order']!);
      expect((evidence['products'] as List).fold<int>(0, (n, p) => n + (p as Map)['quantity'] as int), 3);
      expect(controller.state.buns, BigInt.parse(evidence['ordinaryBuns'] as String));
      expect(WorkshopState.fromJson(controller.state.toJson(), config).completedSales, 1);
    });

    test('재고가 없으면 무소비 안내, 부분 판매 뒤 영업 종료는 대금만 남기고 횟수를 만들지 않는다', () async {
      await controller.command(() => controller.state.customers.add(order()));
      expect(await controller.sellToCustomer('order'), isFalse);
      expect(controller.notice, isNotNull);
      expect(controller.error, isNull);
      await stock('first');
      expect(await controller.sellToCustomer('order'), isTrue);
      final paid = controller.state.buns;
      expect(await controller.closeBusiness(), isTrue);
      expect(controller.state.customers, isEmpty);
      expect(controller.state.buns, paid);
      expect(controller.state.completedSales, 0);
      expect(WorkshopState.fromJson(controller.state.toJson(), config).buns, paid);
    });

    test('부분 판매 저장 실패는 재고·대금·납품 기록을 모두 되돌린다', () async {
      await controller.command(() => controller.state.customers.add(order()));
      await stock('first');
      repository.fail = true;
      expect(await controller.sellToCustomer('order'), isFalse);
      expect(controller.state.inventory.batches['first']!.quantity, 1);
      expect(controller.state.buns, BigInt.zero);
      expect(controller.state.customers.single.deliveries, isEmpty);
    });

    test('schema4 저장은 최신 schema로 읽고, schema4에 납품 기록이 있으면 거절한다', () async {
      await controller.command(() => controller.state.customers.add(order()));
      await stock('first');
      final schema4 = controller.state.toJson()..['schema'] = 4..remove('tutorial');
      expect(WorkshopState.fromJson(schema4, config).toJson()['schema'], 6);
      expect(await controller.sellToCustomer('order'), isTrue);
      final forged = controller.state.toJson()..['schema'] = 4..remove('tutorial');
      expect(() => WorkshopState.fromJson(forged, config), throwsFormatException);
    });

    test('납품 기록이 있는 묶음은 생산 근거와 맞아야 하고 대금은 누적에 포함된다', () async {
      await controller.command(() => controller.state.customers.add(order()));
      await stock('first');
      expect(await controller.sellToCustomer('order'), isTrue);
      final saved = controller.state.toJson();
      final customers = jsonDecode(jsonEncode(saved['customers'])) as List;
      ((customers.single as Map)['deliveries'] as List).single['batch'] = 'unknown';
      expect(() => WorkshopState.fromJson({...saved, 'customers': customers}, config), throwsFormatException);
      expect(() => WorkshopState.fromJson({...saved, 'lifetime': '0', 'buns': '0'}, config), throwsFormatException);
    });
  });
}
