import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
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
  int gold = 0, spent = 0;
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
    spent += cost;
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
  final int level, minutes, skills, gold, goldSpentOnSkills;
  /// Level when lifetime first reached tap_5 / auto_5 unlock (null if never).
  final int? tap5Level, auto5Level;
  _Result(this.level, this.minutes, this.skills, this.gold, this.goldSpentOnSkills, this.tap5Level, this.auto5Level);
}

/// A new player tapping 2 times/s and selling one order per minute, claiming
/// daily missions (server pays the configured gold) and buying the cheapest
/// affordable unlocked skill (up to 3 a minute) whenever both currencies allow.
///
/// 26번 5-1단계: guests come in real time (regular 30 s~5 min since
/// DEC-106, about 3 minutes on average), so [saleEvery] sells only
/// every that many minutes and
/// [target] is the level to reach.
Future<_Result> _play(DevelopmentBalance config, {required int welcome, int target = 5, int minutes = 60,
    int saleEvery = 1, int tapsPerMinute = 120}) async {
  final server = _Server(welcome);
  var clock = DateTime.utc(2026, 11, 3, 1);
  final c = WorkshopController(config, Repository(), now: () => clock, random: Random(3), purchaseGateway: server);
  await c.initialize();
  final ids = [for (final kind in ['tap', 'auto']) for (var i = 1; i <= 16; i++) '${kind}_$i'];
  int? tap5, auto5;
  try {
    await c.openBusiness();
    var skills = 0;
    for (var minute = 1; minute <= minutes; minute++) {
      for (var i = 0; i < tapsPerMinute; i++) { c.tap(); }
      clock = clock.add(const Duration(minutes: 1));
      if (minute % saleEvery == 0) {
      final id = 'sale_$minute';
      await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_$minute', flavor: 'redbean', variant: 2,
          quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
        c.state.customers.insert(0, CustomerOrder(id: id, remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
      });
      expect(await c.sellToCustomer(id), isTrue, reason: '분 $minute 판매');
      }
      for (final goal in ['taps', 'production']) {
        final key = c.state.missions.claimKey('daily', goal);
        if (!c.state.missions.claims.containsKey(key) && c.state.missions.complete(config, 'daily', goal) &&
            await c.claimMission('daily', goal)) {
          server.gold += DevelopmentBalance.integer(config.section('mission_gold_rewards'), 'daily_$goal');
        }
      }
      while (c.canLevelUp) { expect(await c.levelUp(), isTrue); }
      tap5 ??= c.state.lifetime >= DevelopmentBalance.decimal(config.skill('tap_5'), 'unlock_total') ? c.state.level : null;
      auto5 ??= c.state.lifetime >= DevelopmentBalance.decimal(config.skill('auto_5'), 'unlock_total') ? c.state.level : null;
      for (var buy = 0; buy < 3; buy++) {
        CompositeQuote? best;
        for (final id in ids) {
          final q = quoteCompositeSkill(config, id, owned: c.state.purchases.owned[id] ?? 0, quantity: 1);
          if (c.state.lifetime >= DevelopmentBalance.decimal(config.skill(id), 'unlock_total') &&
              q.affordable(c.state.purchases.available(c.state.buns), BigInt.from(server.gold)) &&
              (best == null || q.buns < best.buns)) { best = q; }
        }
        if (best == null) break;
        expect(await c.purchaseSkill(server, best.skillId), isTrue, reason: c.notice);
        skills++;
      }
      if (c.state.level >= target) return _Result(c.state.level, minute, skills, server.gold, server.spent, tap5, auto5);
    }
    return _Result(c.state.level, minutes, skills, server.gold, server.spent, tap5, auto5);
  } finally { c.dispose(); }
}

void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

  test('황금이 0인 서버로도 스킬을 사며 Lv.10까지 막힘 없이 진행한다 (DEC-041)', () async {
    final result = await _play(config, welcome: 0, target: 10);
    expect(result.level, 10);
    expect(result.minutes, lessThanOrEqualTo(15));
    expect(result.skills, greaterThan(10), reason: '1~4단계 스킬은 붕어빵력만으로 살 수 있어야 함');
    expect(result.goldSpentOnSkills, 0);
  });
  test('환영 황금이 없어도 Lv.5 승급 자체는 30분 안에 막히지 않는다', () async {
    final result = await _play(config, welcome: 0);
    expect(result.level, 5);
    expect(result.minutes, lessThanOrEqualTo(30));
  });
  test('실제 시간 일반 손님(30초~5분, 평균 간격마다 한 명)에서도 Lv.5·Lv.10까지 막히지 않는다', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    final arrivals = config.section('customer_arrivals');
    // The average regular interval, rounded up to whole minutes (DEC-106: 30초~5분 → 3분).
    final every = ((DevelopmentBalance.integer(arrivals, 'regular_min_ms') +
            DevelopmentBalance.integer(arrivals, 'regular_max_ms')) / 2 / 60000).ceil();
    final lv5 = await _play(config, welcome: welcome, minutes: 600, saleEvery: every);
    final lv10 = await _play(config, welcome: welcome, minutes: 1200, saleEvery: every, target: 10);
    debugPrint('일반 손님 시뮬레이션: Lv.5 ${lv5.minutes}분, Lv.10 ${lv10.minutes}분 (탭 2/초, $every분마다 판매)');
    expect(every, 3);
    expect(lv5.level, 5);
    expect(lv5.minutes, lessThanOrEqualTo(15));
    expect(lv10.level, 10);
    expect(lv10.minutes, lessThanOrEqualTo(35));
    expect(lv10.goldSpentOnSkills, 0);
  });
  test('환영 황금은 초반 스킬에 쓰이지 않고 꾸미기에 쓸 만큼 남는다', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    final result = await _play(config, welcome: welcome, target: 10);
    expect(result.level, 10);
    expect(result.goldSpentOnSkills, 0);
    expect(result.gold, greaterThanOrEqualTo(welcome));
    final catalog = config.section('avatar_catalog');
    final cheapest = catalog.keys.where((id) => (catalog[id] as Map)['free'] == false)
        .map((id) => quoteWorkshopProduct(config, 'cosmetic:$id', owned: 0, quantity: 1).gold)
        .reduce((a, b) => a < b ? a : b);
    expect(cheapest, greaterThan(BigInt.zero), reason: '꾸미기는 계속 황금이 필요');
    expect(BigInt.from(welcome) >= cheapest, isTrue, reason: '환영 황금으로 꾸미기 하나 이상');
  });
  test('5단계 스킬(첫 황금 스킬)은 Lv.15 이후에 열린다', () async {
    // 4차 g7: with guests every 3 minutes (the real-time average) the
    // tier-5 unlock (lifetime 800,000 / 1,000,000) comes around Lv.15~20.
    final result = await _play(config, welcome: 0, target: 25, minutes: 600, saleEvery: 3);
    debugPrint('5단계 해금: 탭 Lv.${result.tap5Level}, 자동 Lv.${result.auto5Level} (${result.minutes}분에 Lv.${result.level})');
    expect(result.tap5Level, inInclusiveRange(15, 25));
    expect(result.auto5Level, inInclusiveRange(15, 25));
  }, timeout: const Timeout(Duration(minutes: 6)));
  // 4차 피드백 g7 (경제 재조정, 사용자 결정 2026-11-21): 처음 3시간 수입이
  // 약 38배로만 늘고(전에는 약 8,000배), 레벨 한 번이 수입을 두 배로 만들지
  // 않는다. 같은 조건(탭 1초 2번, 3분마다 판매 20, 가장 싼 스킬부터 1분에
  // 3개까지, 황금 스킬은 안 삼)을 설정값만으로 계산한다.
  test('스킬 성장: 3시간 수입 증가폭 50배 미만, 레벨 한 번에 수입이 2배 넘게 뛰지 않는다', () {
    final ids = [for (final kind in ['tap', 'auto']) for (var i = 1; i <= 16; i++) '${kind}_$i'];
    final owned = {for (final id in ids) id: 0};
    BigInt effect(String id) => DevelopmentBalance.decimal(config.skill(id), 'effect');
    BigInt perMinute() {
      var tap = BigInt.one, auto = BigInt.zero;
      for (final id in ids) {
        final add = effect(id) * BigInt.from(owned[id]!);
        if (id.startsWith('tap_')) { tap += add; } else { auto += add; }
      }
      return tap * BigInt.from(120) + auto * BigInt.from(60);
    }
    var buns = BigInt.zero, lifetime = BigInt.zero;
    final income = <int, BigInt>{};
    var biggestJump = 1.0;
    for (var minute = 1; minute <= 180; minute++) {
      final gain = perMinute() + (minute % 3 == 0 ? BigInt.from(20) : BigInt.zero);
      buns += gain; lifetime += gain;
      for (var buy = 0; buy < 3; buy++) {
        CompositeQuote? best;
        for (final id in ids) {
          final q = quoteCompositeSkill(config, id, owned: owned[id]!, quantity: 1);
          if (q.gold == BigInt.zero && lifetime >= DevelopmentBalance.decimal(config.skill(id), 'unlock_total') &&
              q.buns <= buns && (best == null || q.buns < best.buns)) { best = q; }
        }
        if (best == null) break;
        final before = perMinute();
        buns -= best.buns; owned[best.skillId] = owned[best.skillId]! + 1;
        if (minute >= 10) biggestJump = max(biggestJump, perMinute() / before);
      }
      income[minute] = perMinute();
    }
    final growth = income[180]! / income[3]!;
    debugPrint('스킬 성장: 3분 ${income[3]}/분 → 3시간 ${income[180]}/분 ($growth배), 가장 큰 한 레벨 ×$biggestJump');
    expect(growth, lessThan(50));
    expect(growth, greaterThan(10), reason: '성장은 계속 느껴져야 함');
    expect(biggestJump, lessThan(2));
  });
  test('Lv.1~5 승급 조건은 스킬 구매를 요구하지 않는다', () {
    for (final row in config.rows('level_progression').take(5)) {
      expect(row.keys.where((k) => k.contains('skill') || k.contains('purchase')), isEmpty);
    }
  });
}
