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
  int gold = 0, spent = 0, levelGold = 0;
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
    if (intent.quote.skillId.startsWith('level:')) { levelGold += cost; } else { spent += cost; }
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

/// `--dart-define=SIM_TRACE=true` prints every simulated minute.
const _trace = bool.fromEnvironment('SIM_TRACE');
class _Result {
  final int level, minutes, skills, gold, goldSpentOnSkills;
  /// Level when lifetime first reached tap_5 / auto_5 unlock (null if never).
  final int? tap5Level, auto5Level;
  /// Why the next level waits at the end (4차 피드백 g9), or null.
  final String? waiting;
  /// Minute each level was reached (index = level).
  final Map<int, int> reached;
  _Result(this.level, this.minutes, this.skills, this.gold, this.goldSpentOnSkills, this.tap5Level, this.auto5Level,
      this.waiting, this.reached);
}

/// A new player tapping 2 times/s and selling one order per minute, claiming
/// daily missions (server pays the configured gold) and buying the cheapest
/// affordable unlocked skill (up to 3 a minute) whenever both currencies allow
/// and, once the level's sales and taps are done, the level-up's 붕어빵력 is kept (4차 피드백 g9: a level asks
/// for pieces sold and taps in it and takes a payment). Orders are as big as
/// the game makes them at that level (1 to `order_quantity_limit` pieces, in turn).
/// [extraGold] is gold the player has on top (earlier days, bought).
///
/// 26번 5-1단계: guests come in real time (regular 30 s~5 min since
/// DEC-106, about 3 minutes on average), so [saleEvery] sells only
/// every that many minutes and
/// [target] is the level to reach.
Future<_Result> _play(DevelopmentBalance config, {required int welcome, int target = 5, int minutes = 60,
    int saleEvery = 1, int tapsPerMinute = 120, int extraGold = 0}) async {
  final server = _Server(welcome)..gold = extraGold;
  var sold = 0;
  final reached = <int, int>{1: 0};
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
      final limit = DevelopmentBalance.integer(config.rows('level_progression')[c.state.level - 1], 'order_quantity_limit');
      // Orders of every size in turn (1, 2, …, limit, 1, …): the game's
      // uniform order sizes on average, without a lucky or unlucky seed.
      final quantity = 1 + sold++ % limit;
      await c.command(() {
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'batch_$minute', flavor: 'redbean', variant: 2,
          quantity: quantity, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
        c.state.customers.insert(0, CustomerOrder(id: id, remainingMs: 60000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: quantity)]));
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
      c.goldBalance = server.gold;
      if (c.levelGoldDue) expect(await c.payLevelGold(), isTrue, reason: c.notice);
      while (c.canLevelUp) {
        expect(await c.levelUp(), isTrue);
        reached[c.state.level] = minute;
      }
      tap5 ??= c.state.lifetime >= DevelopmentBalance.decimal(config.skill('tap_5'), 'unlock_total') ? c.state.level : null;
      auto5 ??= c.state.lifetime >= DevelopmentBalance.decimal(config.skill('auto_5'), 'unlock_total') ? c.state.level : null;
      // Gold the level-ups ahead will take is kept too.
      final levelGoldAhead = config.rows('level_progression').skip(c.state.level)
          .fold(0, (n, r) => n + DevelopmentBalance.integer(r, 'level_cost_gold'));
      // Once this level's sales and taps are done, its 붕어빵력 is saved first.
      final keep = c.levelGoalsMet ? c.levelCostBuns : BigInt.zero;
      for (var buy = 0; buy < 3; buy++) {
        CompositeQuote? best;
        for (final id in ids) {
          final q = quoteCompositeSkill(config, id, owned: c.state.purchases.owned[id] ?? 0, quantity: 1);
          if (c.state.lifetime >= DevelopmentBalance.decimal(config.skill(id), 'unlock_total') &&
              q.affordable(c.state.purchases.available(c.state.buns) - keep, BigInt.from(max(0, server.gold - levelGoldAhead))) &&
              (best == null || q.buns < best.buns)) { best = q; }
        }
        if (best == null) break;
        expect(await c.purchaseSkill(server, best.skillId), isTrue, reason: c.notice);
        skills++;
      }
      c.goldBalance = server.gold;
      if (_trace) debugPrint('분 $minute Lv.${c.state.level} 보유 ${c.state.buns} 누적 ${c.state.lifetime} 탭 ${c.tapRate} 자동 ${c.autoRate} 판매 ${c.levelPiecesSold} 대기 ${c.levelWaitReason}');
      if (c.state.level >= target) return _Result(c.state.level, minute, skills, server.gold, server.spent, tap5, auto5, null, reached);
    }
    c.goldBalance = server.gold;
    return _Result(c.state.level, minutes, skills, server.gold, server.spent, tap5, auto5, c.levelWaitReason, reached);
  } finally { c.dispose(); }
}

void main() {
  late DevelopmentBalance config;
  final oldEconomy = (jsonDecode(File(const String.fromEnvironment('SIM_CONFIG', defaultValue: 'config/development_balance.json'))
      .readAsStringSync())['metadata']['revision']) == 'development-provisional-3';
  setUp(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File(const String.fromEnvironment('SIM_CONFIG', defaultValue: 'config/development_balance.json')).readAsStringSync()) as Map<String, dynamic>));

  // Lv.10's level-up also takes `level_cost_gold` (4차 피드백 g9: 20), more
  // than a first day's free gold; [lv10Gold] is what a player who has it brings.
  int lv10Gold() => DevelopmentBalance.integer(config.rows('level_progression')[9], 'level_cost_gold');
  test('황금이 0인 서버로도 스킬을 사며 Lv.9까지 막힘 없이(1시간 안) 진행하고, Lv.10은 레벨업 황금만 기다린다 (DEC-041, 4차 g9)', () async {
    // One sale a minute: the level-up 붕어빵력 sets the pace here, not sales.
    final result = await _play(config, welcome: 0, target: 10, minutes: 60);
    expect(result.level, 9, reason: '${result.waiting} ${result.reached}');
    expect(result.waiting, startsWith('황금붕어빵력이'));
    expect(result.skills, greaterThan(10), reason: '1~4단계 스킬은 붕어빵력만으로 살 수 있어야 함');
    expect(result.goldSpentOnSkills, 0);
  });
  test('환영 황금이 없어도 Lv.5 승급 자체는 30분 안에 막히지 않는다', () async {
    final result = await _play(config, welcome: 0);
    expect(result.level, 5);
    expect(result.minutes, lessThanOrEqualTo(30));
  });
  test('실제 시간 일반 손님(30초~5분, 평균 간격마다 한 명)에서도 Lv.5 15분·Lv.10 35분 안에 오른다 (4차 g9)', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    final arrivals = config.section('customer_arrivals');
    // The average regular interval, rounded up to whole minutes (DEC-106: 30초~5분 → 3분).
    final every = ((DevelopmentBalance.integer(arrivals, 'regular_min_ms') +
            DevelopmentBalance.integer(arrivals, 'regular_max_ms')) / 2 / 60000).ceil();
    final lv5 = await _play(config, welcome: welcome, minutes: 600, saleEvery: every);
    // Lv.10 with the level-up gold on hand (a second day's player).
    final lv10 = await _play(config, welcome: welcome, minutes: 1200, saleEvery: every, target: 10, extraGold: lv10Gold());
    debugPrint('일반 손님 시뮬레이션: Lv.5 ${lv5.minutes}분, Lv.10 ${lv10.minutes}분 (탭 2/초, $every분마다 판매, 레벨별 ${lv10.reached})');
    expect(every, 3);
    expect(lv5.level, 5);
    expect(lv5.minutes, lessThanOrEqualTo(15));
    expect(lv10.level, 10);
    expect(lv10.minutes, lessThanOrEqualTo(35));
    expect(lv10.goldSpentOnSkills, 0);
    // A first-day player without that gold: everything but the gold is ready.
    final first = await _play(config, welcome: welcome, minutes: 35, saleEvery: every, target: 10);
    expect(first.level, 9);
    expect(first.waiting, startsWith('황금붕어빵력이'));
  });
  test('Lv.50까지: 레벨마다 판매 개수와 비용을 채우며 막히지 않고 오른다 (4차 g9, 시간 기록)', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    final levelGold = config.rows('level_progression').fold(0, (n, r) => n + DevelopmentBalance.integer(r, 'level_cost_gold'));
    final result = await _play(config, welcome: welcome, minutes: 1500, saleEvery: 3, target: 50, extraGold: levelGold);
    debugPrint('Lv.50 시뮬레이션(3분마다 판매): ${[for (final l in [5, 10, 20, 30, 40, 50]) 'Lv.$l ${result.reached[l]}분'].join(', ')}');
    expect(result.level, 50, reason: '${result.waiting}');
  }, timeout: const Timeout(Duration(minutes: 6)));
  test('환영 황금은 초반 스킬에 쓰이지 않고 꾸미기에 쓸 만큼 남는다', () async {
    final welcome = DevelopmentBalance.integer(config.section('welcome_reward'), 'gold');
    final result = await _play(config, welcome: welcome, target: 9);
    expect(result.level, 9);
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
    final result = await _play(config, welcome: 0, target: 20, minutes: 600, extraGold: lv10Gold() * 3);
    expect(result.tap5Level, inInclusiveRange(15, 25));
    expect(result.auto5Level, inInclusiveRange(15, 25));
  }, timeout: const Timeout(Duration(minutes: 6)),
      // 4차 피드백 g9 slowed levels (sales per level, payments); with the old
      // economy (revision 3) tap_5 then opens at Lv.10. The rebalanced
      // economy (g7, revision 4) keeps it at Lv.15~25.
      skip: oldEconomy ? '경제 재조정(g7)과 함께 확인' : false);
  test('Lv.1~5 승급 조건은 스킬 구매를 요구하지 않는다', () {
    for (final row in config.rows('level_progression').take(5)) {
      expect(row.keys.where((k) => k.contains('skill') || k.contains('purchase')), isEmpty);
    }
  });
}
