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
import 'package:todays_bungeoppang/pantry_rules.dart';
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
  /// 재료 타이쿤 B: 붕어빵력 spent on ingredients, mini-games played and
  /// the seconds they took, taps that found no ingredients.
  final BigInt ingredientBuns;
  final int makes, makeSeconds, emptyTaps;
  _Result(this.level, this.minutes, this.skills, this.gold, this.goldSpentOnSkills, this.tap5Level, this.auto5Level,
      this.waiting, this.reached, this.ingredientBuns, this.makes, this.makeSeconds, this.emptyTaps);
  String get pantryText => '재료비 $ingredientBuns, 재료 준비 $makes번($makeSeconds초), 재료 없는 탭 $emptyTaps번';
}

/// 재료 타이쿤 B: seconds one 재료 준비 takes — the mini-game (설계안 3장:
/// 반죽 젓기 8초, 불 조절 10초, 휘젓기 6초) and about 5 s to choose in the window.
const _makeSeconds = {'stir': 8 + 5, 'heat': 10 + 5, 'whisk': 6 + 5};

/// 재료 타이쿤 B: the player keeps at least one tub of batter and of 팥소. When
/// one falls below, they buy what is missing ('모자란 재료 한 번에 사기') and
/// make the most tubs (5·3·1) that fit the stock limit and the 붕어빵력 on
/// hand, the mini-game a success (+10 portions a tub). With [free] (the
/// game before ingredients) tubs come at no cost and no time.
/// Returns (붕어빵력 spent, makes, seconds).
Future<(BigInt, int, int)> _restock(WorkshopController c, {required bool free}) async {
  final p = c.pantryConfig;
  var spent = BigInt.zero, makes = 0, seconds = 0;
  for (final kind in [p.batterKind, 'redbean']) {
    final at = c.now().millisecondsSinceEpoch;
    final held = c.state.pantry.usable(p, kind, at);
    if (held >= p.portionsPerTub) continue;
    if (free) {
      expect(await c.command(() {
        final keep = c.state.pantry.lots.where((l) => l.kind == kind && !l.premium && l.keeps).firstOrNull;
        if (keep != null) {
          keep.portions += 5 * p.portionsPerTub;
        } else {
          c.state.pantry.lots.insert(0, PantryLot(kind, false, pantryKeepMs, 5 * p.portionsPerTub));
        }
        c.state.pantry.ledger.putIfAbsent(kind, PantryLedger.new).produced += 5 * p.portionsPerTub;
      }), isTrue);
      makes++;
      continue;
    }
    for (final tubs in p.batchTubs.reversed) {
      if (held + tubs * p.portionsPerTub > p.stockLimitPortions(c.state.level)) continue;
      final cost = c.state.pantry.shortfallCost(p, kind, tubs, c.pantryRate);
      if (cost > c.state.purchases.available(c.state.buns)) continue;
      expect(await c.command(() {
        if (cost > BigInt.zero) {
          c.state.buns -= c.state.pantry.buyShortfall(p, kind, tubs, c.pantryRate, c.state.recipes);
        }
        c.state.pantry.make(p, kind, tubs, c.state.level, c.now().millisecondsSinceEpoch, c.state.recipes, success: true);
      }), isTrue, reason: c.notice);
      spent += cost; makes++; seconds += _makeSeconds[p.kind(kind).minigame]!;
      break;
    }
  }
  return (spent, makes, seconds);
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
///
/// 재료 타이쿤 B: every tap and every product sold uses ingredients (taps:
/// one portion per `taps_per_portion`, products: one each, made in the
/// mold or the six-cell griddle), bought and made by [_restock]; the
/// mini-game seconds are taken from the next minute's taps. [freeIngredients]
/// plays the game as before ingredients, to compare. (Auto production is
/// not counted here, as before: the simulated minutes pass on the wall
/// clock only; the ingredient prices still follow R with it.)
Future<_Result> _play(DevelopmentBalance config, {required int welcome, int target = 5, int minutes = 60,
    int saleEvery = 1, int tapsPerMinute = 120, int extraGold = 0, bool freeIngredients = false}) async {
  final server = _Server(welcome)..gold = extraGold;
  var ingredientBuns = BigInt.zero, makes = 0, makeSeconds = 0, emptyTaps = 0, lostTaps = 0;
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
      for (var i = 0; i < tapsPerMinute - lostTaps; i++) {
        if (c.tap() == null) emptyTaps++;
      }
      clock = clock.add(const Duration(minutes: 1));
      final (spent, made, seconds) = await _restock(c, free: freeIngredients);
      ingredientBuns += spent; makes += made; makeSeconds += seconds;
      lostTaps = seconds * tapsPerMinute ~/ 60;
      if (minute % saleEvery == 0) {
      final id = 'sale_$minute';
      final limit = DevelopmentBalance.integer(config.rows('level_progression')[c.state.level - 1], 'order_quantity_limit');
      // Orders of every size in turn (1, 2, …, limit, 1, …): the game's
      // uniform order sizes on average, without a lucky or unlucky seed.
      final quantity = 1 + sold++ % limit;
      await c.command(() {
        // The products were made in the mold or the griddle: one portion each.
        for (var i = 0; i < quantity; i++) {
          c.state.pantry.takePortion(c.pantryConfig, 'redbean', c.now().millisecondsSinceEpoch);
        }
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
      // 4차 g9: a gold level's payment starts by itself once due (the page
      // does it), and 승급 is automatic (4차 IA1): the next save — here the
      // checkpoint — raises it.
      c.goldBalance = server.gold;
      if (c.levelGoldDue) expect(await c.payLevelGold(), isTrue, reason: c.notice);
      if (c.canLevelUp) expect(await c.command(() {}, keepNotice: true), isTrue);
      // Every command promotes (sales, missions, purchases too), so the
      // minute's levels are counted here, once all of it is done.
      for (var l = reached.keys.reduce(max) + 1; l <= c.state.level; l++) { reached[l] = minute; }
      expect(c.canLevelUp, isFalse);
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
      if (c.state.level >= target) {
        return _Result(c.state.level, minute, skills, server.gold, server.spent, tap5, auto5, null, reached,
            ingredientBuns, makes, makeSeconds, emptyTaps);
      }
    }
    c.goldBalance = server.gold;
    return _Result(c.state.level, minutes, skills, server.gold, server.spent, tap5, auto5, c.levelWaitReason, reached,
        ingredientBuns, makes, makeSeconds, emptyTaps);
  } finally { c.dispose(); }
}

void main() {
  late DevelopmentBalance config;
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
    // 재료 타이쿤 B: the same players with ingredients free (the game before them).
    final lv5Free = await _play(config, welcome: welcome, minutes: 600, saleEvery: every, freeIngredients: true);
    final lv10Free = await _play(config, welcome: welcome, minutes: 1200, saleEvery: every, target: 10,
        extraGold: lv10Gold(), freeIngredients: true);
    debugPrint('재료 사기·만들기 포함: Lv.5 ${lv5.minutes}분(재료 없이 ${lv5Free.minutes}분), '
        'Lv.10 ${lv10.minutes}분(재료 없이 ${lv10Free.minutes}분), Lv.10까지 ${lv10.pantryText}');
    expect(lv10.emptyTaps, 0, reason: '재료를 채우는 사람은 재료가 떨어져 멈추지 않음');
    expect(lv10.makes, greaterThan(0));
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
    debugPrint('Lv.50 시뮬레이션(3분마다 판매, 재료 사기·만들기 포함): ${[for (final l in [5, 10, 20, 30, 40, 50]) 'Lv.$l ${result.reached[l]}분'].join(', ')}, ${result.pantryText}');
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
  test('5단계 스킬(첫 황금 스킬)은 실제 손님 간격(3분마다 판매)에서 Lv.15~20에 열린다 (4차 g15)', () async {
    // 4차 g15 (사용자 결정 2026-11-21): with 4차 g9's levels (pieces sold
    // per level, the level-up payment) a sale every 3 minutes opened tier 5
    // at Lv.12~13 with the old unlocks (800,000·1,000,000). The unlocks are
    // now 2,000,000·2,500,000 — tap Lv.16·auto Lv.18 here.
    // The Lv.10·20 level-ups take gold, which this player has.
    final result = await _play(config, welcome: 0, target: 25, minutes: 900, saleEvery: 3, extraGold: lv10Gold() * 3);
    debugPrint('5단계 해금: 탭 Lv.${result.tap5Level}, 자동 Lv.${result.auto5Level} (${result.minutes}분에 Lv.${result.level})');
    expect(result.tap5Level, inInclusiveRange(15, 20));
    expect(result.auto5Level, inInclusiveRange(15, 20));
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
