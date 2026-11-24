import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_online.dart';
import 'package:todays_bungeoppang/workshop_sale_archive.dart';
import 'workshop_controller_test.dart' show Repository;
import 'workshop_online_test.dart' show Transport;

/// 30번 2-A (2026-11-24): settled sales to anonymous guests leave the save
/// for two totals; the checks and the money stay the same.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  late DateTime at;
  late Repository repository;
  late WorkshopController c;
  setUp(() async {
    at = DateTime.utc(2026, 11, 24, 3);
    repository = Repository();
    c = WorkshopController(config, repository, now: () => at, random: Random(7),
        purchaseGateway: WorkshopOnline(Transport()));
    await c.initialize();
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
    await c.openBusiness();
  });
  tearDown(() => c.dispose());

  Future<void> sell(String id, {String customer = 'anonymous_1'}) async {
    await c.command(() {
      c.state.inventory = c.state.inventory.recordResult(ProductBatch(
          id: 'p_$id', flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
      c.state.customers.insert(0, CustomerOrder(id: id, customerId: customer, remainingMs: 10000,
          lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
    });
    expect(await c.sellToCustomer(id), isTrue, reason: c.notice);
  }

  Future<void> nextDay() async {
    await c.setForeground(false);
    at = at.add(const Duration(days: 1));
    await c.setForeground(true);
  }

  BigInt salesBuns(WorkshopState s) => s.sales.entries.fold(s.archivedSalesBuns,
      (sum, e) => sum + saleBuns(validateStoredCustomerSale(e.key, e.value)));

  test('심사가 끝난 지난 영업일의 무기명 판매는 요약으로 옮기고, 합계·검증은 그대로', () async {
    for (final id in ['s1', 's2', 's3']) { await sell(id); }
    expect(await c.syncRewards(), isTrue, reason: c.notice);
    final before = (count: c.state.completedSales, buns: salesBuns(c.state), lifetime: c.state.lifetime);
    expect(c.state.sales.length, 3, reason: '오늘 판매는 아직 그대로');
    await nextDay();
    expect(c.state.sales, isEmpty);
    expect(c.state.pendingGold.keys.where((k) => k.startsWith('sale:')), isEmpty);
    expect(c.state.rewardReceipts.keys.where((k) => k.startsWith('sale:')), isEmpty);
    expect(c.state.archivedSales, 3);
    expect(c.state.completedSales, before.count);
    expect(salesBuns(c.state), before.buns, reason: '판매 대금 합계 유지');
    expect(c.state.lifetime, before.lifetime);
    final saved = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>;
    expect(saved['archivedSales'], 3);
    final back = WorkshopState.fromJson(saved, config);
    expect(back.archivedSales, 3);
    expect(back.archivedSalesBuns, c.state.archivedSalesBuns);
  });

  test('심사가 안 끝났거나 오늘 판매거나 단골 손님 판매면 남겨 둔다', () async {
    await sell('pending');                       // 서버 심사 전
    await nextDay();
    expect(c.state.sales.keys, contains('pending'), reason: '심사 결과가 없으면 남김');
    expect(c.state.archivedSales, 0);
    await sell('today');
    expect(await c.syncRewards(), isTrue, reason: c.notice);
    // A command on the same day: 'pending' (now reviewed, sold yesterday)
    // goes; 'today' stays until the day turns.
    await c.command(() {});
    expect(c.state.sales.keys, ['today']);
    expect(c.state.archivedSales, 1);
  });

  test('보관 합계가 판매 수·대금과 어긋난 저장은 거부한다', () async {
    await sell('s1');
    expect(await c.syncRewards(), isTrue, reason: c.notice);
    await nextDay();
    final saved = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>;
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['archivedSales'] = 2, config),
        throwsFormatException, reason: '판매 수 불일치');
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['archivedSalesBuns'] = '${c.state.lifetime + BigInt.one}', config),
        throwsFormatException, reason: '대금 합이 누적보다 큼');
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['schema'] = 13, config),
        throwsFormatException, reason: '옛 저장에 새 필드');
  });

  test('판매 40건이 보관되면 저장이 크게 줄어든다', () async {
    for (var i = 0; i < 40; i++) { await sell('s$i'); }
    var synced = 0;
    while (c.pendingRewardCount > 0 && synced++ < 20) { expect(await c.syncRewards(), isTrue, reason: c.notice); }
    final before = utf8.encode(jsonEncode(c.state.toJson())).length;
    await nextDay();
    final after = utf8.encode(jsonEncode(c.state.toJson())).length;
    expect(c.state.archivedSales, 40);
    expect(after, lessThan(before ~/ 2));
    final out = Platform.environment['SAVE_MEASURE'];
    if (out != null) File(out).writeAsStringSync('archive 40 anonymous sales: before=$before after=$after\n', mode: FileMode.append);
  });

  /// Sells to the named neighbor [npc]: stock for each line, then the sale.
  Future<String> sellNamed(String npc) async {
    expect(await c.welcomeCustomer(visitor: npc), isTrue, reason: c.notice);
    final order = c.state.customers.lastWhere((o) => o.customerId == npc);
    await c.command(() {
      for (final (i, line) in order.lines.indexed) {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'n_${order.id}_$i', flavor: line.flavor,
            variant: line.variant ?? 2, quantity: line.quantity, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
      }
    });
    expect(await c.sellToCustomer(order.id), isTrue, reason: c.notice);
    // A story or choice scene may open after the sale; close it for the test.
    await c.command(() => c.state.customerScene = null);
    return order.id;
  }

  String facts(String npc) {
    final f = c.choiceFactsForTest(npc, CustomerOrder(id: 'probe', customerId: npc, remainingMs: 1000,
        lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
    // Only what the sales give: a new day may bring another visit (the clock).
    return [f.redbeanTwoSuccessDays, f.largeOrderSuccessDays, f.receivedFlavorCount,
      f.workSuccessDays, f.custardSuccesses, f.newFlavorFirstServed].join(',');
  }

  test('30번 2-B: 단골 판매도 요약으로 옮기고, 선택 이벤트 조건은 그대로', () async {
    final named = <String>[];
    for (final npc in ['npc_yunha', 'npc_taeo', 'npc_makrye']) { named.add(await sellNamed(npc)); }
    await sell('anon');
    expect(await c.syncRewards(), isTrue, reason: c.notice);
    final before = {for (final npc in ['npc_yunha', 'npc_taeo', 'npc_makrye']) npc: facts(npc)};
    final bytesBefore = utf8.encode(jsonEncode(c.state.toJson())).length;
    expect(c.state.inventory.dispositions.keys, containsAll(['p_anon', 'n_${named.first}_0']), reason: '심사 전엔 생산 근거 유지');
    await nextDay();
    expect(c.state.sales, isEmpty);
    expect(c.state.archivedNamedSales, named.toSet());
    expect(c.state.archivedSales, 4);
    expect(c.state.inventory.dispositions, isEmpty, reason: '다 쓴 생산 결과 지문은 지움');
    for (final npc in before.keys) { expect(facts(npc), before[npc], reason: npc); }
    final out = Platform.environment['SAVE_MEASURE'];
    if (out != null) {
      File(out).writeAsStringSync('archive 3 named + 1 anonymous sales: before=$bytesBefore '
          'after=${utf8.encode(jsonEncode(c.state.toJson())).length}\n', mode: FileMode.append);
    }
    // The relationship record of each sale stays.
    final actions = c.state.relationships.toJson()['actions'] as Map;
    for (final id in named) { expect(actions, contains('sale:$id')); }
    // Reloaded from the save: same facts, same archive.
    final saved = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>;
    final back = WorkshopState.fromJson(saved, config);
    expect(back.archivedNamedSales, named.toSet());
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['archivedNamedSales'] = [...named, 'ghost'], config),
        throwsFormatException, reason: '관계 기록 없는 보관 ID');
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['archivedNamedSales'] = named.skip(1).toList(), config),
        throwsFormatException, reason: '관계 판매의 원장이 사라짐');
    expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['schema'] = 14, config),
        throwsFormatException, reason: '옛 저장에 새 필드');
  });

  test('pickSettledSales: keep이 참이면 남기고, 단골 판매는 따로 알려 준다', () {
    final pick = pickSettledSales(sales: const {}, rewardReceipts: const {}, liveBatches: const {},
        businessIndex: 5, named: (_) => true, keep: (_, __) => true);
    expect(pick.ids, isEmpty);
    expect(pick.namedIds, isEmpty);
  });

  test('keepNeededResults: 재고·준비 제품·남은 판매·화면의 결과만 지문을 남긴다', () {
    var inventory = InventoryProgress.empty();
    for (final id in ['live', 'sold', 'spent', 'screen']) {
      inventory = inventory.recordResult(ProductBatch(id: id, flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: 1),
          keep: id == 'live');
    }
    final sale = jsonEncode({'fingerprint': 'f', 'evidence': {'products': [{'batch': 'sold'}]}});
    final kept = keepNeededResults(inventory, salesEvidence: [sale], waiting: const [], sessionId: 'screen');
    expect(kept.dispositions.keys.toSet(), {'live', 'sold', 'screen'});
    expect(identical(keepNeededResults(kept, salesEvidence: [sale], waiting: const [], sessionId: 'screen'), kept), isTrue);
  });
}
