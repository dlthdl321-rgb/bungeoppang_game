import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'workshop_controller_test.dart' show Repository;

/// 28번 10절 (2026-11-24, schema 13): a sale's pending gold is the same string
/// as its evidence in `sales`, so the save writes it once. `pendingGold` keeps
/// no `sale:` entries on disk and `pendingSales` lists their IDs.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  Future<WorkshopController> withSales(int count) async {
    final c = WorkshopController(config, Repository(), now: () => DateTime.utc(2026, 11, 24), random: Random(7));
    await c.initialize();
    await c.openBusiness();
    for (var i = 0; i < count; i++) {
      await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(
            id: 'p$i', flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: 1), keep: true);
        c.state.customers.add(CustomerOrder(id: 'o$i', remainingMs: 10000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
      });
      expect(await c.sellToFirstCustomer(), isTrue, reason: 'sale $i');
    }
    return c;
  }

  /// What schema 12 wrote: each sale's evidence again under `pendingGold`.
  Map<String, dynamic> asSchema12(WorkshopController c) => c.state.toJson()
    ..['schema'] = 12
    ..['pendingGold'] = Map<String, String>.from(c.state.pendingGold)
    ..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns');

  int bytes(Map<String, dynamic> json) => utf8.encode(jsonEncode(json)).length;

  test('판매 증거는 저장에 한 번만 쓰고, 불러오면 황금 심사 대기가 그대로 돌아온다', () async {
    final c = await withSales(3);
    final json = c.state.toJson();
    expect(json['schema'], workshopSchema);
    expect((json['pendingGold'] as Map).keys.where((k) => (k as String).startsWith('sale:')), isEmpty);
    expect(json['pendingSales'], ['o0', 'o1', 'o2']);
    final back = WorkshopState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>, config);
    expect(back.pendingGold, c.state.pendingGold, reason: '메모리 상태는 예전과 같다');
    expect(back.toJson(), json);
    c.dispose();
  });

  test('schema 12 옛 저장(증거 두 벌)도 읽고, 다시 쓰면 새 형식이 된다', () async {
    final c = await withSales(2);
    final old = asSchema12(c);
    final back = WorkshopState.fromJson(jsonDecode(jsonEncode(old)) as Map<String, dynamic>, config);
    expect(back.pendingGold, c.state.pendingGold);
    expect(back.toJson(), c.state.toJson());
    c.dispose();
  });

  test('목록이 판매 기록과 어긋나면 손상 저장으로 거부한다', () async {
    final c = await withSales(1);
    final unknown = c.state.toJson()..['pendingSales'] = ['nope'];
    expect(() => WorkshopState.fromJson(unknown, config), throwsFormatException);
    final missing = c.state.toJson()..['pendingSales'] = <String>[];
    expect(() => WorkshopState.fromJson(missing, config), throwsFormatException, reason: '판매마다 심사 근거 필요');
    final stale = asSchema12(c)..['pendingSales'] = ['o0'];
    expect(() => WorkshopState.fromJson(stale, config), throwsFormatException, reason: '옛 저장에 새 필드');
    c.dispose();
  });

  test('판매가 쌓일수록 저장이 예전보다 작다 (판매 40건)', () async {
    final c = await withSales(40);
    final before = bytes(asSchema12(c)), after = bytes(c.state.toJson());
    expect(after, lessThan(before));
    final out = Platform.environment['SAVE_MEASURE'];
    if (out != null) {
      File(out).writeAsStringSync('pendingSales 40 sales: schema12=$before schema13=$after\n', mode: FileMode.append);
    }
    c.dispose();
  });
}
