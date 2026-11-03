import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';
import 'workshop_controller_test.dart' show Repository;

/// Server-like wallet: welcome gold on the first progress claim, holds gold on
/// reserve and grants only on commit (firebase/functions workshop_service.ts).
class _Server implements WorkshopPurchaseGateway {
  final int welcome;
  int gold = 0;
  bool _claimed = false;
  final Map<String, Map<String, dynamic>> _receipts = {};
  _Server(this.welcome);
  @override
  String get authenticatedAccount => 'kakao:sim';
  @override
  Future<void> requireActiveProgress(String progressId) async {
    if (!_claimed) { _claimed = true; gold += welcome; }
  }
  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent) async {
    final cost = int.parse(intent.quote.gold.toString());
    if (cost > gold) throw Exception('황금붕어빵력 부족');
    gold -= cost;
    return _receipts[intent.transactionId] = {...intent.toJson(), 'status': 'reserved'};
  }
  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal intent) async => _receipts[intent.transactionId] =
      {...intent.toJson(), 'status': 'committed', 'receiptId': 'r-${intent.transactionId}', 'grantId': 'g-${intent.transactionId}'};
  @override
  Future<Map<String, dynamic>> query(String accountId, String transactionId) async =>
      _receipts[transactionId] ?? {'account': accountId, 'transaction': transactionId, 'status': 'unknown'};
  @override
  Future<Map<String, dynamic>> cancel(String accountId, String transactionId) async => throw UnimplementedError();
}

class _Result {
  final int level, minutes, skills, gold;
  _Result(this.level, this.minutes, this.skills, this.gold);
}

/// A new player tapping 2 times/s and selling one order per minute, claiming
/// daily missions (server pays the configured gold) and buying the cheapest
/// affordable skill whenever both currencies allow.
Future<_Result> _play(DevelopmentBalance config, {required int welcome, int minutes = 60}) async {
  final server = _Server(welcome);
  var clock = DateTime.utc(2026, 11, 3, 1);
  final c = WorkshopController(config, Repository(), now: () => clock, random: Random(3), purchaseGateway: server);
  await c.initialize();
  try {
    await c.openBusiness();
    var skills = 0;
    for (var minute = 1; minute <= minutes; minute++) {
      for (var i = 0; i < 120; i++) { c.tap(); }
      clock = clock.add(const Duration(minutes: 1));
      final id = 'sale_$minute';
      await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_$minute', flavor: 'redbean', variant: 2,
          quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
        c.state.customers.insert(0, CustomerOrder(id: id, remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
      });
      expect(await c.sellToCustomer(id), isTrue, reason: '분 $minute 판매');
      for (final goal in ['taps', 'production']) {
        final key = c.state.missions.claimKey('daily', goal);
        if (!c.state.missions.claims.containsKey(key) && c.state.missions.complete(config, 'daily', goal) &&
            await c.claimMission('daily', goal)) {
          server.gold += DevelopmentBalance.integer(config.section('mission_gold_rewards'), 'daily_$goal');
        }
      }
      while (c.canLevelUp) { expect(await c.levelUp(), isTrue); }
      for (final id in ['tap_1', 'auto_1']) {
        final q = quoteCompositeSkill(config, id, owned: c.state.purchases.owned[id] ?? 0, quantity: 1);
        if (c.state.lifetime >= DevelopmentBalance.decimal(config.skill(id), 'unlock_total') &&
            q.affordable(c.state.purchases.available(c.state.buns), BigInt.from(server.gold))) {
          expect(await c.purchaseSkill(server, id), isTrue, reason: c.notice);
          skills++;
        }
      }
      if (c.state.level >= 5) return _Result(c.state.level, minute, skills, server.gold);
    }
    return _Result(c.state.level, minutes, skills, server.gold);
  } finally { c.dispose(); }
}

void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

  test('신규 사용자는 서버 환영 황금으로 스킬을 사며 Lv.5까지 막힘 없이 진행한다', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    expect(welcome, greaterThan(0));
    final result = await _play(config, welcome: welcome);
    expect(result.level, 5);
    expect(result.minutes, lessThanOrEqualTo(30));
    expect(result.skills, greaterThanOrEqualTo(welcome ~/ 2), reason: '환영 황금이 초반 스킬 구매로 이어져야 함');
  });
  test('환영 황금이 없어도 Lv.5 승급 자체는 스킬 없이 막히지 않는다', () async {
    final result = await _play(config, welcome: 0);
    expect(result.level, 5);
    expect(result.minutes, lessThanOrEqualTo(30));
  });
  test('Lv.1~5 승급 조건은 스킬 구매를 요구하지 않는다', () {
    for (final row in config.rows('level_progression').take(5)) {
      expect(row.keys.where((k) => k.contains('skill') || k.contains('purchase')), isEmpty);
    }
  });
}
