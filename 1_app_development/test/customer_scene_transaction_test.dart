import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_customers.dart';
import 'workshop_controller_test.dart' show Repository;

void main() {
  test('Lv1~50 실제 주문 생성은 보유 맛·종류·수량·개인 대기 상한을 지킨다', () async {
    final config = DevelopmentBalance.fromJson(jsonDecode(
        File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final repository = Repository();
    final now = DateTime.utc(2026, 10, 1);
    final c = WorkshopController(config, repository, now: () => now, random: Random(53));
    addTearDown(c.dispose);
    await c.initialize();
    expect(await c.openBusiness(), isTrue);
    expect(await c.command(() {
      for (final flavor in ['custard', 'cocoa']) {
        c.state.recipes.add(flavor);
        c.state.flavorMasteries[flavor] = FlavorMasteryProgress(flavor: flavor,
            difficulty: DevelopmentBalance.integer(config.section('active_recipes')[flavor] as Map<String, dynamic>, 'difficulty'));
      }
    }), isTrue);
    for (var level = 1; level <= 50; level++) {
      expect(await c.command(() {
        c.state.level = level;
        // Valid saved progression fixture; this test exercises order generation,
        // not the separate level-up purchase/reward command.
        c.state.claimedLevels
          ..clear()
          ..addAll(List.generate(level - 1, (index) => index + 2));
        c.state.customers.clear();
      }), isTrue, reason: 'level $level: ${c.error ?? c.notice}');
      expect(await c.welcomeCustomer(), isTrue, reason: 'level $level');
      final order = c.state.customers.single;
      final rule = config.rows('level_progression')[level - 1];
      expect(order.remainingMs, DevelopmentBalance.integer(rule, 'order_wait_ms'));
      expect(order.lines.length, lessThanOrEqualTo(DevelopmentBalance.integer(rule, 'order_flavor_limit')));
      expect(order.lines.fold<int>(0, (n, line) => n + line.quantity),
          lessThanOrEqualTo(DevelopmentBalance.integer(rule, 'order_quantity_limit')));
      expect(order.lines.every((line) => c.state.recipes.contains(line.flavor)), isTrue);
      final sale = config.section('ordinary_sale');
      if (level < DevelopmentBalance.integer(sale, 'special_order_unlock_level')) {
        expect(order.lines.any((line) => line.special), isFalse);
      }
      if (level < DevelopmentBalance.integer(sale, 'specific_variant_order_unlock_level')) {
        expect(order.lines.every((line) => line.variant == null || line.special), isTrue);
      }
    }
  });
  test('관계 장면은 입장 후일담보다 우선하며 후일담은 다음 방문까지 보존한다', () async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    raw['customer_relationships']['choice_first_business_day'] = 1;
    raw['customer_story_conditions']['npc_doyun']['stage'] = 0;
    final config = DevelopmentBalance.fromJson(raw);
    final repository = Repository();
    var now = DateTime.utc(2026, 10, 1);
    final c = WorkshopController(config, repository, now: () => now, random: Random(31));
    addTearDown(c.dispose);
    await c.initialize();
    expect(await c.openBusiness(), isTrue);
    expect(await c.command(() {
      c.state.relationships = WorkshopRelationships.empty()
          .visit('prior', 'npc_doyun', 1, c.customerCatalog)
          .rollChoice(1, ['choice_doyun_01'], 0, config, c.customerCatalog)
          .choose('choice_doyun_01', 'a', config, c.customerCatalog)
          .closeReaction('choice_doyun_01');
    }), isTrue);
    now = now.add(const Duration(days: 1));
    expect(await c.openBusiness(), isTrue);
    expect(await c.welcomeCustomer(), isTrue);
    final order = c.state.customers.single;
    expect(order.customerId, 'npc_doyun');
    expect(c.state.customerScene, isNull);
    expect(await c.command(() {
      c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'product',
          flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: 2), keep: true);
    }), isTrue);
    expect(await c.sellToCustomer(order.id), isTrue);
    expect(c.state.customerScene!['kind'], 'story');
    expect(await c.finishCustomerScene(), isTrue);
    expect(c.state.relationships.toJson()['followups'], {'choice_doyun_01': 'a'});
    now = now.add(const Duration(days: 1));
    expect(await c.openBusiness(), isTrue);
    expect(await c.welcomeCustomer(), isTrue);
    expect(c.state.customerScene!['kind'], 'followup');
    expect(await c.finishCustomerScene(), isTrue);
    expect(c.state.relationships.toJson()['followups'], isEmpty);
  });
  for (final storyAlreadyCompleted in [false, true]) {
  test('기본 관계 완료=$storyAlreadyCompleted: 신메뉴→판매→선택 저장 실패/복귀→후일담', () async {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    // The random outcome is fixed in the test, not in production configuration.
    raw['customer_relationships']['choice_chance_basis_points'] = 10000;
    if (storyAlreadyCompleted) raw['customer_story_conditions']['npc_taeo']['stage'] = 0;
    final config = DevelopmentBalance.fromJson(raw);
    final repository = Repository();
    final start = DateTime.utc(2026, 10, 1);
    var now = start;
    final c = WorkshopController(config, repository, now: () => now, random: Random(31));
    addTearDown(c.dispose);
    await c.initialize();
    expect(await c.openBusiness(), isTrue);
    // Existing regulars fixture; subsequent orders and transactions use real commands.
    expect(await c.command(() {
      for (final npc in c.customerCatalog.ids) {
        c.state.relationships = c.state.relationships.visit('known-$npc', npc, 1, c.customerCatalog);
      }
      if (storyAlreadyCompleted) {
        c.state.relationships = c.state.relationships.completeStory(
            'npc_taeo', 'story_taeo_01', c.customerCatalog, eligible: true);
      }
    }), isTrue);
    for (var day = 2; day <= 7; day++) {
      now = start.add(Duration(days: day - 1));
      expect(await c.openBusiness(), isTrue);
      expect(await c.command(() {
        for (final npc in c.customerCatalog.ids.where((id) => id != 'npc_taeo')) {
          c.state.relationships = c.state.relationships.visit('day-$day-$npc', npc, day, c.customerCatalog);
        }
        if (day == 7) {
          c.state.recipes.add('custard');
          c.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: 1);
        }
      }), isTrue);
      expect(await c.welcomeCustomer(), isTrue);
      final order = c.state.customers.single;
      expect(order.customerId, 'npc_taeo');
      expect(order.lines.single.flavor, day == 7 ? 'custard' : 'redbean');
      expect(await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(
            id: 'stock-$day', flavor: order.lines.single.flavor, variant: 2,
            quantity: order.lines.single.quantity, madeOnBusinessIndex: day), keep: true);
      }), isTrue);
      expect(await c.sellToCustomer(order.id), isTrue);
      if (c.photoReactionSale != null) {
        expect(await c.acknowledgePhotoReaction(order.id), isTrue);
      } else {
        expect(storyAlreadyCompleted && day < 7, isTrue);
      }
    }
    expect(c.state.customerScene!['kind'], 'choice');
    expect(c.state.customerScene!['id'], 'choice_taeo_01');
    final affinity = c.state.relationships.affinity('npc_taeo');
    final selection = storyAlreadyCompleted ? 'c' : 'a';
    final gain = storyAlreadyCompleted ? 1 : 3;
    repository.fail = true;
    expect(await c.respondToCustomer(selection), isFalse);
    expect(c.state.relationships.affinity('npc_taeo'), affinity);
    expect(c.state.relationships.active!['choice'], isNull);
    await c.reloadAfterError();
    expect(await c.respondToCustomer(selection), isTrue);
    expect(c.state.relationships.affinity('npc_taeo'), affinity + gain);
    await c.reloadAfterError();
    expect(c.state.relationships.active!['choice'], selection);
    expect(await c.respondToCustomer(selection), isTrue);
    expect(c.state.relationships.affinity('npc_taeo'), affinity + gain);
    expect(await c.finishCustomerScene(), isTrue);

    now = start.add(const Duration(days: 7));
    expect(await c.openBusiness(), isTrue);
    expect(await c.command(() {
      for (final npc in c.customerCatalog.ids.where((id) => id != 'npc_taeo')) {
        c.state.relationships = c.state.relationships.visit('day-8-$npc', npc, 8, c.customerCatalog);
      }
    }), isTrue);
    expect(await c.welcomeCustomer(), isTrue);
    expect(c.state.customerScene!['kind'], 'followup');
    if (selection == 'c') {
      final visit = (c.state.relationships.toJson()['visits'] as Map)[c.state.customers.single.id] as Map;
      expect((visit['context'] as Map)['cameraPresent'], isTrue);
      expect((visit['context'] as Map)['photoReminder'], isTrue);
    }
    await c.reloadAfterError();
    expect(c.state.customerScene!['choice'], selection);
    expect(await c.finishCustomerScene(), isTrue);
    expect(c.state.relationships.toJson()['followups'], isEmpty);
    expect(c.state.relationships.affinity('npc_taeo'), affinity + gain);
    expect(await c.finishCustomerScene(), isFalse);
  });
  }
}
