import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'cooking_input.dart';
import 'cooking_result_rules.dart';
import 'cooking_session.dart';
import 'development_balance.dart';
import 'development_business.dart';
import 'development_griddle.dart';
import 'development_inventory.dart';
import 'development_orders.dart';
import 'development_rules.dart';
import 'development_purchase_journal.dart';
import 'economy.dart' show compactNumber;
import 'feedback_config.dart';
import 'workshop_purchases.dart';
import 'workshop_online.dart';
import 'workshop_ads.dart';
import 'workshop_missions.dart';
import 'workshop_customers.dart';
import 'workshop_customer_events.dart';
import 'workshop_customer_dialogue.dart';
import 'workshop_customer_orders.dart';
import 'workshop_arrivals.dart';
import 'workshop_feature_unlocks.dart';
import 'workshop_daily.dart';
import 'usage_stats.dart';
import 'cosmetic_config.dart' show CosmeticSlot, characterDefaultHair, defaultCosmetics, defaultHairOf, movedToTop;

part 'workshop_storage.dart';

const workshopTutorialStates = {'cook', 'sell', 'done', 'skipped'};
/// Avatar slots whose items a shop can have without buying ([WorkshopState.avatarGrants]).
const avatarGrantSlots = {'character', 'skin'};

/// What happened while the app was away, for the welcome-back card. Sales
/// and the customers' waits only run in the foreground; customers still come
/// in real time (26번 5-1단계), so the card counts who arrived.
class WorkshopAwayReport {
  final Duration away;
  final BigInt buns;
  final bool open;
  final int waiting;
  /// Guests who arrived while the app was away.
  final int arrivals;
  /// 26번 7단계: a new 오늘의 주문서 came, today's stamp is still to take.
  final bool newOrder, stampReady;
  const WorkshopAwayReport({required this.away, required this.buns, required this.open, required this.waiting,
      this.arrivals = 0, this.newOrder = false, this.stampReady = false});
}

/// One finished sale as the guest saw it: who, how many stars, what they said.
class WorkshopSalePraise {
  final String name, speech;
  final int stars;
  const WorkshopSalePraise(this.name, this.stars, this.speech);
}

/// Fresh-game local production aggregate. Gold remains in the authenticated
/// server wallet; pending claims here are never spendable gold.
class WorkshopState {
  int sequence = 0, level = 1, taps = 0, completedSales = 0, phaseMs = 0,
      levelStartTaps = 0, levelStartSales = 0, arrivalMs = 0;
  /// Bungeoppang pieces handed over in finished sales, and that count when
  /// the current level began (4차 피드백 g9: a level asks for pieces sold in
  /// it). Saved as `soldPieces`·`levelStartPieces` in schema 10 too; a save
  /// without them counts its sale ledger and credits it to this level.
  int soldPieces = 0, levelStartPieces = 0;
  String selectedFlavor = 'redbean',sceneTime='scenetime';
  /// First-run guide: `cook` → `sell` → `done`, or `skipped` (schema 6).
  String tutorial = 'cook';
  /// Real-time customer clocks (schema 7, 26번 5-1단계): regular guests and
  /// named neighbors. Stopped (nextAt null) while closed, during the guide,
  /// or while their places are full.
  ArrivalClock regularClock = const ArrivalClock(seed: 0), namedClock = const ArrivalClock(seed: 1);
  /// The named neighbor who came last; the next named visit skips them.
  String? lastNamedVisitor;
  /// Feature introduction cards already shown (schema 8, 26번 2단계):
  /// [WorkshopFeature] names from [workshopIntroIds].
  final Set<String> featureIntros = {};
  /// 오늘의 주문서·출석·행사 (schema 10, 26번 7단계).
  WorkshopDaily daily = WorkshopDaily.empty;
  final Set<String> recipes = {'redbean'};
  final Set<String> recipeMissions = {};
  final Map<String, Map<String, dynamic>> masteryAwards = {};
  final Map<String, Map<String, Set<int>>> tasteObservations = {};
  Map<String, dynamic>? get masteryAward => masteryAwards[selectedFlavor];
  set masteryAward(Map<String, dynamic>? value) {
    if (value == null) { masteryAwards.remove(selectedFlavor); }
    else { masteryAwards[selectedFlavor] = value; }
  }
  bool get mastered => masteryAward != null;
  bool get tutorialActive => tutorial == 'cook' || tutorial == 'sell';
  BigInt buns = BigInt.zero, lifetime = BigInt.zero;
  WorkshopPurchases purchases = WorkshopPurchases.empty();
  String? rewardAccount;
  final Map<String,String> rewardReceipts = {};
  final Map<String,Map<String,dynamic>> adAttempts = {};
  final Map<String,String> avatarEquipment = {};
  /// Avatar items this shop has without buying them (3차 피드백 H11·H12,
  /// saved as `avatarGrants` in schema 10): the character chosen at the
  /// first run, and for a save from before the rule the character and skin
  /// tone it wore then. Other characters and skin tones are bought.
  final Set<String> avatarGrants = {'girl'};
  /// Whether this shop has avatar item [id] of [catalog] (avatar_catalog):
  /// free, granted, bought, or (26번 3차 G) the own default hair of a
  /// character it has ([characterDefaultHair]: the boy's short hair).
  bool hasAvatar(Map<String,dynamic> catalog,String id) {
    final entry=catalog[id];
    if (entry is! Map<String,dynamic>) return false;
    if (entry['free']==true || avatarGrants.contains(id) || purchases.owned['cosmetic:$id']==1) return true;
    return entry['slot']==CosmeticSlot.hair.name &&
      characterDefaultHair.entries.any((e)=>e.value==id && e.key!=id && hasAvatar(catalog,e.key));
  }
  /// The avatar item worn in [slot]: what was picked here, else [legacy]
  /// (the account wardrobe's choice). Hair never picked is the character's
  /// own default ([defaultHairOf], 26번 3차 G: a boy whose save still wears
  /// the old shared default long hair wears his short hair; hair picked or
  /// bought stays).
  String avatarWorn(CosmeticSlot slot,String legacy) {
    final picked=avatarEquipment[slot.name];
    if (picked!=null) return picked;
    if (slot==CosmeticSlot.hair && legacy==defaultCosmetics[CosmeticSlot.hair]) {
      return defaultHairOf(avatarEquipment[CosmeticSlot.character.name] ?? defaultCosmetics[CosmeticSlot.character]!);
    }
    return legacy;
  }
  /// A new character worn: hair that was only the old character's own
  /// default goes back to "never picked", so the new one's default shows
  /// (26번 3차 G).
  void _wearCharacter(String id) {
    final before=avatarEquipment[CosmeticSlot.character.name] ?? defaultCosmetics[CosmeticSlot.character]!;
    if (before!=id && avatarEquipment[CosmeticSlot.hair.name]==defaultHairOf(before)) {
      avatarEquipment.remove(CosmeticSlot.hair.name);
    }
    avatarEquipment[CosmeticSlot.character.name]=id;
  }
  late BusinessProgress business;
  late WorkshopMissions missions;
  InventoryProgress inventory = InventoryProgress.empty();
  late GriddleProgress grid;
  final Map<String, FlavorMasteryProgress> flavorMasteries = {
    'redbean': FlavorMasteryProgress(flavor: 'redbean', difficulty: 0)};
  FlavorMasteryProgress get mastery => flavorMasteries[selectedFlavor]!;
  set mastery(FlavorMasteryProgress value) { flavorMasteries[value.flavor] = value; }
  CookingSession? session;
  List<CustomerOrder> customers = [];
  WorkshopRelationships relationships = WorkshopRelationships.empty();
  Map<String,dynamic>? customerScene;
  final Map<String, String> sales = {}, pendingGold = {};
  final Set<int> claimedLevels = {};
  WorkshopState.initial(DateTime now, DevelopmentBalance config, String runId) {
    missions=WorkshopMissions.initial(now);
    business = BusinessProgress.initial(now); grid = GriddleProgress.empty(runId, config);
    regularClock = ArrivalClock(seed: arrivalSeed(runId, 1));
    namedClock = ArrivalClock(seed: arrivalSeed(runId, 2));
    flavorMasteries['redbean'] = FlavorMasteryProgress(flavor: 'redbean',
      difficulty: DevelopmentBalance.integer(config.section('active_recipes')['redbean'] as Map<String, dynamic>, 'difficulty'));
  }
  Map<String, dynamic> toJson() => {'schema': 10, 'sequence': sequence, 'level': level, 'tutorial': tutorial,
    'featureIntros': featureIntros.toList()..sort(), 'daily': daily.toJson(),
    'regularClock': regularClock.toJson(), 'namedClock': namedClock.toJson(), 'lastNamedVisitor': lastNamedVisitor,
    'taps': taps, 'completedSales': completedSales, 'phaseMs': phaseMs,
    'levelStartTaps': levelStartTaps, 'levelStartSales': levelStartSales, 'arrivalMs': arrivalMs,
    'soldPieces': soldPieces, 'levelStartPieces': levelStartPieces,
    'selectedFlavor': selectedFlavor,'sceneTime':sceneTime, 'recipes': recipes.toList()..sort(),
    'recipeMissions': recipeMissions.toList()..sort(),
    'masteryAwards': {for (final e in masteryAwards.entries) e.key: Map<String, dynamic>.from(e.value)},
    'relationships':relationships.toJson(), 'customerScene':customerScene==null ? null : jsonDecode(jsonEncode(customerScene)),
    'tasteObservations': {for (final e in tasteObservations.entries) e.key:
      {for (final f in e.value.entries) f.key: f.value.toList()..sort()}},
    'buns': buns.toString(), 'lifetime': lifetime.toString(), 'purchases': purchases.toJson(),
    'rewardAccount':rewardAccount,'rewardReceipts':Map<String,String>.from(rewardReceipts),
    'adAttempts':{for(final e in adAttempts.entries) e.key:Map<String,dynamic>.from(e.value)},
    'avatarEquipment':Map<String,String>.from(avatarEquipment),'avatarGrants':avatarGrants.toList()..sort(),'missions':missions.toJson(), 'business': business.toJson(),
    'inventory': inventory.toJson(), 'grid': grid.toJson(),
    'flavorMasteries': {for (final e in flavorMasteries.entries) e.key: e.value.toJson()},
    'session': session?.toJson(), 'customers': customers.map((c) => c.toJson()).toList(),
    'sales': Map<String, String>.from(sales), 'pendingGold': Map<String, String>.from(pendingGold),
    'claimedLevels': claimedLevels.toList()..sort()};
  factory WorkshopState.fromJson(Map<String, dynamic> row, DevelopmentBalance config) {
    Map<String, dynamic> object(String key) {
      final value = row[key];
      if (value is! Map<String, dynamic>) throw FormatException('저장 항목 누락: $key');
      return value;
    }
    if (row['schema'] is! int || ![1, 2, 3, 4, 5, 6, 7, 8, 9, 10].contains(row['schema'])) throw const FormatException('신규 게임 저장 버전 오류');
    if ((row['schema'] as int) < 4 && (row.containsKey('relationships') || row.containsKey('customerScene'))) throw const FormatException('구형 관계 저장 충돌');
    final business = BusinessProgress.fromJson(object('business'));
    final grid = GriddleProgress.fromJson(object('grid'), config);
    final state = WorkshopState.initial(business.settledUtc, config, grid.runId)
      ..business = business ..grid = grid
      ..inventory = InventoryProgress.fromJson(object('inventory'))
      ..sequence = DevelopmentBalance.integer(row, 'sequence')
      ..level = DevelopmentBalance.integer(row, 'level')
      ..taps = DevelopmentBalance.integer(row, 'taps')
      ..completedSales = DevelopmentBalance.integer(row, 'completedSales')
      ..phaseMs = DevelopmentBalance.integer(row, 'phaseMs')
      ..levelStartTaps = DevelopmentBalance.integer(row, 'levelStartTaps')
      ..levelStartSales = DevelopmentBalance.integer(row, 'levelStartSales')
      ..arrivalMs = DevelopmentBalance.integer(row, 'arrivalMs')
      ..buns = DevelopmentBalance.decimal(row, 'buns')
      ..lifetime = DevelopmentBalance.decimal(row, 'lifetime');
    if (state.level < 1 || state.level > 50 || state.buns > state.lifetime ||
        state.levelStartTaps > state.taps || state.levelStartSales > state.completedSales) {
      throw const FormatException('신규 진행/재화 불일치');
    }
    if (state.inventory.batches.values.any((b) => b.madeOnBusinessIndex > business.businessIndex) ||
        state.inventory.bindings.values.any((day) => day > business.businessIndex)) {
      throw const FormatException('미래 영업일의 재고 귀속');
    }
    if ((row['schema'] as int)<3 && ['rewardAccount','rewardReceipts','adAttempts','avatarEquipment','missions','sceneTime'].any(row.containsKey)) throw const FormatException('구형 저장에 신규 보호 필드가 있어요.');
    if (row['schema'] == 1 && row.containsKey('purchases')) throw const FormatException('구형 저장의 구매 필드 충돌');
    if ((row['schema'] as int) >= 2) state.purchases = WorkshopPurchases.fromJson(object('purchases'), config);
    state.purchases.available(state.buns);
    if((row['schema'] as int)>=3) state.missions=WorkshopMissions.fromJson(object('missions'));
    if ((row['schema'] as int) >= 4) {
      state.relationships = WorkshopRelationships.fromJson(object('relationships'),config,WorkshopCustomerCatalog.bundled());
      if (state.relationships.day > business.businessIndex) throw const FormatException('미래 관계 영업일');
    }
    final catalog = config.section('active_recipes');
    if (row['recipes'] is! List || row['selectedFlavor'] is! String || row['recipeMissions'] is! List) throw const FormatException('레시피 보유 형식 오류');
    state.recipes.clear(); state.flavorMasteries.clear();
    for (final flavor in row['recipes'] as List) {
      if (flavor is! String || !catalog.containsKey(flavor) || !state.recipes.add(flavor)) throw const FormatException('레시피 보유 오류');
    }
    state.selectedFlavor = row['selectedFlavor'] as String;
    if (!state.recipes.contains('redbean') || !state.recipes.contains(state.selectedFlavor)) throw const FormatException('기본/선택 레시피 누락');
    for (final e in object('flavorMasteries').entries) {
      if (e.value is! Map<String, dynamic> || !state.recipes.contains(e.key)) throw const FormatException('맛 숙련 형식 오류');
      final mastery = FlavorMasteryProgress.fromJson(e.value as Map<String, dynamic>);
      if (mastery.flavor != e.key || mastery.difficulty != (catalog[e.key] as Map)['difficulty']) throw const FormatException('맛 숙련 식별 오류');
      state.flavorMasteries[e.key] = mastery;
    }
    if (state.flavorMasteries.length != state.recipes.length) throw const FormatException('맛 숙련 누락');
    for (final e in object('masteryAwards').entries) {
      final mastery = state.flavorMasteries[e.key], award = e.value;
      if (award is! Map<String, dynamic> || mastery == null ||
          award['revision'] is! String || (award['revision'] as String).isEmpty ||
          award['resultId'] is! String || !mastery.results.containsKey(award['resultId']) ||
          mastery.practiceDiscovered.length != 5 ||
          mastery.practices < DevelopmentBalance.integer(award, 'practiceRequired') ||
          mastery.techniquePasses < DevelopmentBalance.integer(award, 'techniqueRequired') ||
          DevelopmentBalance.integer(award, 'techniqueRequired') == 0) throw const FormatException('숙련 확정 근거 오류');
      state.masteryAwards[e.key] = Map<String, dynamic>.from(award);
    }
    for (final cell in state.grid.cells) {
      if (cell.cooking && (!state.masteryAwards.containsKey(cell.flavor) || !state.recipes.contains(cell.flavor) ||
          cell.difficulty != (catalog[cell.flavor] as Map)['difficulty'])) throw const FormatException('잠긴 맛의 숙련된 붕어빵 저장');
    }
    for (final flavor in row['recipeMissions'] as List) {
      if (flavor is! String || flavor == 'redbean' || !state.recipes.contains(flavor) || !state.recipeMissions.add(flavor)) throw const FormatException('레시피 미션 기록 오류');
    }
    for (final e in object('tasteObservations').entries) {
      if (e.key.isEmpty || e.value is! Map<String, dynamic>) throw const FormatException('손님 관찰 형식 오류');
      final observed = <String, Set<int>>{};
      for (final f in (e.value as Map<String, dynamic>).entries) {
        final variants = f.value;
        if (!catalog.containsKey(f.key) || variants is! List || variants.any((v) => v is! int || v < 0 || v >= 4) ||
            variants.toSet().length != variants.length) throw const FormatException('손님 명시 취향 오류');
        observed[f.key] = variants.cast<int>().toSet();
      }
      state.tasteObservations[e.key] = observed;
    }
    if (row['session'] != null) {
      if (row['session'] is! Map<String, dynamic>) throw const FormatException('제작 세션 저장 오류');
      state.session = CookingSession.fromJson(row['session'] as Map<String, dynamic>);
      if (state.session!.flavor != state.selectedFlavor || !state.recipes.contains(state.session!.flavor)) throw const FormatException('미확정 맛 진행');
    }
    if (row['customers'] is! List || row['claimedLevels'] is! List) throw const FormatException('진행 목록 오류');
    state.customers = [for (final c in row['customers'] as List)
      if (c is Map<String, dynamic>) CustomerOrder.fromJson(c) else throw const FormatException('손님 목록 오류')];
    if (state.customers.map((c) => c.id).toSet().length != state.customers.length) throw const FormatException('손님 ID 중복');
    if ((row['schema'] as int) < 5 && state.customers.any((c) => c.deliveries.isNotEmpty)) throw const FormatException('구형 저장의 부분 판매 충돌');
    // Saves from before the guide existed already played: never re-run it.
    if ((row['schema'] as int) < 6) {
      if (row.containsKey('tutorial')) throw const FormatException('구형 저장의 안내 필드 충돌');
      state.tutorial = 'done';
    } else {
      if (!workshopTutorialStates.contains(row['tutorial'])) throw const FormatException('첫 실행 안내 저장 오류');
      state.tutorial = row['tutorial'] as String;
      if (state.tutorialActive && state.completedSales > 0) throw const FormatException('판매 뒤 안내 진행 상태 오류');
    }
    var salesBuns = BigInt.zero;
    final consumed = <String, BigInt>{};
    void sold(Map<String, dynamic> product) {
      final id = product['batch'] as String;
      final originalRaw = state.inventory.dispositions[id];
      if (originalRaw == null) throw const FormatException('생산 근거 없는 판매');
      final original = jsonDecode(originalRaw) as List;
      final batch = ProductBatch.fromJson(original[1] as Map<String, dynamic>);
      if (original[0] != true || !state.recipes.contains(batch.flavor) || product['flavor'] != batch.flavor ||
          product['variant'] != batch.variant || product['madeOnBusinessIndex'] !=
          (state.inventory.bindings[id] ?? batch.madeOnBusinessIndex)) throw const FormatException('생산/판매 제품 불일치');
      consumed[id] = (consumed[id] ?? BigInt.zero) + BigInt.from(product['quantity'] as int);
      final remaining = state.inventory.batches[id]?.quantity ?? 0;
      if (consumed[id]! + BigInt.from(remaining) > BigInt.from(batch.quantity)) throw const FormatException('생산량보다 많은 재고/판매');
    }
    for (final e in object('sales').entries) {
      if (e.value is! String) throw const FormatException('판매 원장 형식 오류');
      final evidence = validateStoredCustomerSale(e.key, e.value as String);
      if ((evidence['businessIndex'] as int) > state.business.businessIndex) throw const FormatException('미래 영업일의 판매');
      for (final item in evidence['products'] as List) { sold(item as Map<String, dynamic>); }
      salesBuns += DevelopmentBalance.decimal(evidence, 'ordinaryBuns');
      state.sales[e.key] = e.value as String;
    }
    // Partial deliveries of waiting customers: consumed stock, already paid.
    for (final delivery in state.customers.expand((c) => c.deliveries)) {
      if (delivery.soldOnBusinessIndex > state.business.businessIndex) throw const FormatException('미래 영업일의 부분 판매');
      sold(delivery.toJson());
      salesBuns += delivery.ordinaryBuns;
    }
    if (state.customers.any((c) => state.sales.containsKey(c.id))) throw const FormatException('끝난 주문이 대기 중이에요.');
    if ((row['schema'] as int) >= 4) {
      final relation = state.relationships.toJson(), visits = relation['visits'] as Map;
      final npcs = WorkshopCustomerCatalog.bundled();
      for (final customer in state.customers.where((c) => npcs.contains(c.customerId))) {
        final visit = visits[customer.id];
        if (visit is! Map || visit['npc'] != customer.customerId || (visit['context'] is Map && jsonEncode((visit['context'] as Map)['lines'])!=jsonEncode(customer.lines.map((l)=>l.toJson()).toList()))) throw const FormatException('손님 방문 원장 누락');
      }
      for(final sale in state.sales.entries) {
        final evidence=validateStoredCustomerSale(sale.key,sale.value);
        if(npcs.contains((evidence['order'] as Map)['customerId'] as String) &&
            !(relation['actions'] as Map).containsKey('sale:${sale.key}')) throw const FormatException('판매의 관계 처리 누락');
      }
      for (final entry in (relation['actions'] as Map<String,dynamic>).entries.where((e) => e.key.startsWith('sale:'))) {
        final id = entry.key.substring(5), saved = state.sales[id];
        if (saved == null) throw const FormatException('관계 판매 원장 누락');
        final evidence = validateStoredCustomerSale(id,saved), order = evidence['order'] as Map;
        final action = entry.value as Map, visit = visits[action['visit']] as Map;
        if (order['customerId'] != visit['npc'] || action['day'] != evidence['businessIndex'] || (visit['context'] is Map && jsonEncode((visit['context'] as Map)['lines'])!=jsonEncode(order['lines']))) throw const FormatException('관계 판매 근거 불일치');
      }
    }
    if (salesBuns > state.lifetime) throw const FormatException('판매 대금 누적 근거 불일치');
    // Schema 10 (26번 7단계): today's order, the attendance card and the
    // seasonal events seen. Older saves start empty.
    if ((row['schema'] as int) >= 10) {
      state.daily = WorkshopDaily.fromJson(row['daily'], config, today: businessDayKst(business.settledUtc));
      final order = state.daily.order;
      if (order != null) {
        final action = (state.relationships.toJson()['actions'] as Map)['special:${order.day}'];
        if (!state.recipes.contains(order.flavor) ||
            (order.npc != null && !state.relationships.met.contains(order.npc)) ||
            (order.businessIndex ?? 0) > business.businessIndex ||
            (order.done && order.npc != null
                ? action is! Map || action['npc'] != order.npc || action['day'] != order.businessIndex
                : action != null)) {
          throw const FormatException('오늘의 주문서 근거 오류');
        }
      }
    } else if (row.containsKey('daily')) {
      throw const FormatException('구형 저장에 매일 기록이 있어요.');
    }
    for (final e in object('pendingGold').entries) {
      if (e.value is! String) throw const FormatException('황금 심사 형식 오류');
      final payload = jsonDecode(e.value as String);
      if (payload is! Map<String, dynamic>) throw const FormatException('황금 심사 증거 오류');
      if (e.key.startsWith('sale:')) {
        if (state.sales[e.key.substring(5)] != e.value) throw const FormatException('판매와 황금 심사 증거 불일치');
      } else if (e.key.startsWith('level:')) {
        final level = int.tryParse(e.key.substring(6));
        if (level == null || level < 2 || level > state.level || payload['level'] != level ||
            DevelopmentBalance.integer(payload, 'gold') == 0 || payload['revision'] is! String ||
            (payload['revision'] as String).isEmpty) throw const FormatException('승급 황금 심사 근거 오류');
      } else if(e.key.startsWith('mission:')) {
        if(state.missions.claims[e.key.substring(8)]!=e.value) throw const FormatException('미션 황금 신청 원본 불일치');
      } else if (e.key.startsWith('attendance:')) {
        // 26번 7단계: the seventh stamp's gold, verified like a mission claim.
        final day = e.key.substring(11), stamped = state.daily.stampDay;
        if (payload.length != 5 || payload['scope'] != 'attendance' || payload['period'] != day ||
            payload['goal'] != 'day7' || DevelopmentBalance.integer(payload, 'gold') == 0 ||
            payload['revision'] is! String || (payload['revision'] as String).isEmpty ||
            stamped == null || day.compareTo(stamped) > 0) {
          throw const FormatException('출석 황금 신청 근거 오류');
        }
      } else { throw const FormatException('알 수 없는 황금 심사 종류'); }
      state.pendingGold[e.key] = e.value as String;
    }
    for(final claim in state.missions.claims.entries) {
      if(state.pendingGold['mission:${claim.key}']!=claim.value) throw const FormatException('미션 황금 신청 누락');
    }
    for (final sale in state.sales.keys) {
      if (!state.pendingGold.containsKey('sale:$sale')) throw const FormatException('판매 황금 심사 근거 누락');
    }
    for (final n in row['claimedLevels'] as List) {
      if (n is! int || n < 2 || n > state.level || !state.claimedLevels.add(n)) throw const FormatException('승급 수령 기록 오류');
    }
    if (state.sales.length != state.completedSales || state.claimedLevels.length != state.level - 1) {
      throw const FormatException('판매/승급 원장 불일치');
    }
    // 4차 피드백 g9: pieces sold. A save from before them counts its sale
    // ledger (each finished sale keeps the order as placed) and credits all
    // of it to the current level.
    if (row.containsKey('soldPieces')) {
      state..soldPieces = DevelopmentBalance.integer(row, 'soldPieces')
        ..levelStartPieces = DevelopmentBalance.integer(row, 'levelStartPieces');
    } else {
      state.soldPieces = state.sales.values.fold(0, (n, encoded) {
        final evidence = (jsonDecode(encoded) as Map<String, dynamic>)['evidence'];
        if (evidence is! Map<String, dynamic> || evidence['order'] is! Map<String, dynamic>) throw const FormatException('판매 기록 형식 오류');
        return n + CustomerOrder.fromJson(evidence['order'] as Map<String, dynamic>).lines.fold(0, (a, l) => a + l.quantity);
      });
    }
    if (state.levelStartPieces > state.soldPieces || state.soldPieces < state.completedSales) {
      throw const FormatException('판매 개수 기록 불일치');
    }
    if ((row['schema'] as int)>=3) {
      if(!['scenetime','day','night_time','clock'].contains(row['sceneTime'])) throw const FormatException('배경 시간 저장 오류');
      state.sceneTime=row['sceneTime'] as String;
      if (row['rewardAccount'] != null && (row['rewardAccount'] is! String || (row['rewardAccount'] as String).isEmpty)) throw const FormatException('보상 계정 형식 오류');
      state.rewardAccount=row['rewardAccount'] as String?;
      if (state.purchases.account != null && state.rewardAccount != null && state.purchases.account != state.rewardAccount) throw const FormatException('구매와 보상 계정 불일치');
      for (final e in object('rewardReceipts').entries) {
        final raw=state.pendingGold[e.key];
        if (raw==null || state.rewardAccount==null || e.value is! String) throw const FormatException('보상 수신 원본 누락');
        final receipt=jsonDecode(e.value as String);
        if (receipt is! Map<String,dynamic>) throw const FormatException('보상 수신 형식 오류');
        final sale=e.key.startsWith('sale:');
        validateWorkshopRewardReceipt(receipt,account:state.rewardAccount!,progress:state.grid.runId,
          claim:sale ? e.key.substring(5) : '${state.grid.runId}:${e.key}',kind:sale ? 'sale':'mission',
          payload:jsonDecode(raw) as Map<String,dynamic>);
        state.rewardReceipts[e.key]=e.value as String;
      }
      for (final e in object('adAttempts').entries) {
        if (e.value is! Map<String,dynamic> || state.rewardAccount==null) throw const FormatException('광고 기록 형식 오류');
        state.adAttempts[e.key]=validateWorkshopAd(e.value as Map<String,dynamic>,state.rewardAccount!,e.key);
      }
      final worn=Map<String,dynamic>.of(object('avatarEquipment'));
      // Schema 9 (26번 4-5단계, G12): the chef coat and padded vest are
      // tops now. An older save wearing one as its apron wears it as the
      // top with no apron, so the vendor looks the same.
      if ((row['schema'] as int)<9 && movedToTop.contains(worn[CosmeticSlot.outfit.name])) {
        worn[CosmeticSlot.top.name]=worn[CosmeticSlot.outfit.name];
        worn[CosmeticSlot.outfit.name]='noapron';
      }
      final catalog=config.section('avatar_catalog');
      bool granted(Object? id)=>catalog[id] is Map<String,dynamic> && avatarGrantSlots.contains((catalog[id] as Map)['slot']);
      final grants=row['avatarGrants'];
      if (grants!=null) {
        // 3차 피드백 H11·H12: what this shop has without buying.
        if (grants is! List || grants.any((id) => !granted(id)) || grants.toSet().length!=grants.length ||
            grants.where((id) => (catalog[id] as Map)['slot']=='character').length!=1) throw const FormatException('아바타 기본 보유 저장 오류');
        state.avatarGrants..clear()..addAll(grants.cast<String>());
      } else {
        // A save from before the rule keeps the character and skin tone it
        // wears (girl when none was picked); the others are bought now.
        final character=worn[CosmeticSlot.character.name];
        if (granted(character) && (catalog[character] as Map)['slot']=='character') {
          state.avatarGrants..clear()..add(character as String);
        }
        final skin=worn[CosmeticSlot.skin.name];
        if (granted(skin) && (catalog[skin] as Map)['slot']=='skin') state.avatarGrants.add(skin as String);
      }
      for (final e in worn.entries) {
        if (e.value is! String) throw const FormatException('아바타 착용 형식 오류');
        final item=catalog[e.value];
        if (item is! Map<String,dynamic> || item['slot']!=e.key ||
            !state.hasAvatar(catalog,e.value as String)) throw const FormatException('아바타 착용 보유 근거 오류');
        state.avatarEquipment[e.key]=e.value as String;
      }
    }
    if ((row['schema'] as int)>=4) {
      if(!row.containsKey('customerScene')) throw const FormatException('대화 복원 상태 누락');
      final scene=row['customerScene'];
      final active=state.relationships.active;
      if(scene!=null) {
        if(scene is! Map<String,dynamic> || scene['id'] is! String || scene['npc'] is! String ||
            !state.relationships.met.contains(scene['npc']) || !['story','replay','choice','followup'].contains(scene['kind'])) throw const FormatException('대화 복원 형식 오류');
        final catalog=WorkshopCustomerCatalog.bundled();
        if(active!=null && scene['kind']!='choice') throw const FormatException('활성 선택과 화면 불일치');
        if(scene['kind']=='story' || scene['kind']=='replay') {
          if(!catalog.hasStory(scene['id'] as String,scene['npc'] as String) || (scene['kind']=='replay') != state.relationships.stories.contains(scene['id'])) throw const FormatException('관계 장면 근거 오류');
        } else {
          final definition=catalog.choice(scene['id'] as String);
          if(definition['npc_id']!=scene['npc']) throw const FormatException('대화 인물 불일치');
          if(scene['kind']=='choice') {
            final order=scene['order'];
            if(active==null || active['event']!=scene['id'] || order is! List || order.length!=3 || order.toSet().length!=3 || !order.toSet().containsAll(['a','b','c'])) throw const FormatException('선택 대화 근거 오류');
          } else if((state.relationships.toJson()['followups'] as Map)[scene['id']]!=scene['choice']) throw const FormatException('후일담 근거 오류');
        }
        state.customerScene=jsonDecode(jsonEncode(scene)) as Map<String,dynamic>;
      } else if(active!=null) { throw const FormatException('활성 대화 화면 누락'); }
    }
    const arrivalKeys = ['regularClock', 'namedClock', 'lastNamedVisitor'];
    if ((row['schema'] as int) >= 7) {
      if (!arrivalKeys.every(row.containsKey)) throw const FormatException('손님 시계 저장 누락');
      state.regularClock = ArrivalClock.fromJson(row['regularClock']);
      state.namedClock = ArrivalClock.fromJson(row['namedClock']);
      final last = row['lastNamedVisitor'];
      if (last != null && (last is! String || !state.relationships.met.contains(last))) throw const FormatException('직전 네임드 손님 오류');
      state.lastNamedVisitor = last as String?;
      final rules = WorkshopArrivals.of(config), settled = business.settledUtc.millisecondsSinceEpoch;
      for (final (clock, kind) in [(state.regularClock, ArrivalKind.regular), (state.namedClock, ArrivalKind.named)]) {
        final next = clock.nextAt;
        if (next != null && (!business.open || state.tutorialActive || next > settled + rules.maxInterval(kind))) {
          throw const FormatException('손님 시계 상태 오류');
        }
      }
    } else {
      // Schema 6 and older: clocks start (stopped) from the run id and begin
      // counting on the first settlement after loading; the last named
      // neighbor is the latest visit in the relationship journal.
      if (arrivalKeys.any(row.containsKey)) throw const FormatException('구형 저장에 손님 시계가 있어요.');
      String? last; var lastDay = -1;
      for (final visit in (state.relationships.toJson()['visits'] as Map).values) {
        final day = (visit as Map)['day'] as int;
        if (day >= lastDay) { lastDay = day; last = visit['npc'] as String; }
      }
      state.lastNamedVisitor = last;
    }
    // Schema 8 (26번 2단계): introduction cards already shown. Older saves
    // count every feature already open as introduced, so a player past
    // those levels sees no cards.
    if ((row['schema'] as int) >= 8) {
      final seen = row['featureIntros'];
      if (seen is! List || seen.any((id) => id is! String || !workshopIntroIds.contains(id)) ||
          seen.toSet().length != seen.length) {
        throw const FormatException('기능 소개 저장 오류');
      }
      state.featureIntros.addAll(seen.cast<String>());
    } else {
      if (row.containsKey('featureIntros')) throw const FormatException('구형 저장에 기능 소개 기록이 있어요.');
      state.featureIntros.addAll(openedIntroIds(state, config));
    }
    return state;
  }
}

/// One requirement of the next level ([WorkshopController.levelRequirements]).
typedef LevelRequirement = ({String label, BigInt current, BigInt target});
/// '이' or '가' after a number written by [compactNumber], as it is read
/// (200 이백이, 12 십이가, 3만 삼만이, 2조 이조가).
String subjectParticle(String number) {
  if (number.isEmpty) return '이';
  return '2459조'.contains(number[number.length - 1]) ? '가' : '이';
}
class WorkshopController extends ChangeNotifier implements WorkshopProgressSource {
  final DevelopmentBalance config;
  final WorkshopRepository repository;
  final DateTime Function() now;
  final Random random;
  final WorkshopPurchaseGateway? purchaseGateway;
  late WorkshopState state;
  final customerCatalog = WorkshopCustomerCatalog.bundled();
  /// A guest's full name: the nickname for named guests (the customer
  /// window's title), '일반 손님' for walk-ins (26번 4-1단계 F3).
  String customerName(String id) => id.startsWith('anonymous_') ? '일반 손님' : customerCatalog.displayName(id,state.relationships.stories);
  /// The short name the stall and the counter show ('도윤', '막례 할머니';
  /// S4-1-Q2), '일반 손님' for walk-ins.
  String customerShortName(String id) => customerCatalog.contains(id)
      ? customerCatalog.shortName(id,state.relationships.stories) : customerName(id);
  /// Which guest picture stands at the stall (assets/images/customer): the
  /// named guest's own, or one of four walk-in looks picked from the id.
  String guestArtId(String id) {
    if (customerCatalog.contains(id)) return id;
    final sum = id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x3fffffff);
    return 'walkin_${sum % 4 + 1}';
  }
  /// The guest who just left the stall (memory only): happy after a sale,
  /// sad after running out of time. The guest layer shows them for a
  /// moment ([departureAgeMs]).
  ({String customerId, bool happy, int atMs})? guestDeparture;
  int get departureAgeMs => guestDeparture == null ? 1 << 30 : _mono - guestDeparture!.atMs;
  /// The level-up step (×1·×10·×100, [skillLevelUpSteps]) each skill's own
  /// wheel shows in the skill window, by skill id (26번 시안 확인 2차).
  /// Memory only: kept while the app runs, not saved; ×1 when missing.
  final Map<String, int> skillSteps = {};
  bool busy = false, foreground = true, disposed = false;
  bool _gridVisible = true;
  bool get gridVisible => _gridVisible;
  set gridVisible(bool value) { _gridVisible = value; if (!disposed) notifyListeners(); }
  String? error, notice;
  bool _purchaseBusy = false, _adPaused = false, _rewardBusy = false, _adBusy = false;
  bool get rewardBusy => _rewardBusy;
  bool get adBusy => _adBusy;
  bool get adPaused => _adPaused;
  WorkshopOnline? get onlineGateway => purchaseGateway is WorkshopOnline ? purchaseGateway as WorkshopOnline : null;
  int get pendingRewardCount => state.pendingGold.keys.where((key) {
    final raw=state.rewardReceipts[key];return raw==null || (jsonDecode(raw) as Map)['outcome']=='pending';
  }).length;
  bool get purchaseBusy => _purchaseBusy;
  bool get storyPaused => state.customerScene != null;
  bool get gameplayPaused => !foreground || _adPaused || storyPaused;
  BusinessSettlement _settleAway() => storyPaused
      ? state.business.settleActive(now(),bunsPerSecond:autoRate,elapsedMs:0)
      : state.business.settle(config,now(),bunsPerSecond:autoRate,offline:true);
  /// Shown once by the page after a long absence, then dismissed.
  WorkshopAwayReport? awayReport;
  /// Minimum absence that earns the welcome-back card.
  Duration welcomeBackAfter = workshopWelcomeBackAfter;
  WorkshopAwayReport? _settleAwayInto() {
    final from = state.business.settledUtc, open = state.business.open;
    final settlement = _settleAway();
    state.business = settlement.state;
    state.buns += settlement.buns; state.lifetime += settlement.buns;
    // Guests kept coming while away (26번 5-1단계); their waits start now.
    final arrivals = _syncArrivals();
    final newOrder = _observeDaily();
    final away = state.business.settledUtc.difference(from);
    return away < welcomeBackAfter ? null
        : WorkshopAwayReport(away: away, buns: settlement.buns, open: open, waiting: state.customers.length,
            arrivals: arrivals, newOrder: newOrder, stampReady: attendanceReady);
  }
  WorkshopArrivals get arrivalRules => WorkshopArrivals.of(config);
  int _waiting(ArrivalKind kind) => state.customers.where((c) =>
      customerCatalog.contains(c.customerId) == (kind == ArrivalKind.named)).length;
  /// The named neighbor a named-clock draw brings at [at], as the arrival
  /// will choose: the business day turns over first after KST midnight.
  String? _namedFor(ArrivalClock clock, int at) {
    final business = state.business;
    final turned = business.open && business.acceptedDay != null &&
        businessDayKst(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)) != business.acceptedDay;
    return state.relationships.selectNamedVisitor(business.businessIndex + (turned ? 1 : 0), clock.pick, config,
        customerCatalog, alreadyQueued: state.customers.map((c) => c.customerId).toSet(),
        lastVisitor: state.lastNamedVisitor);
  }
  /// Applies every arrival and KST midnight due by the settled business time
  /// (26번 5-1단계). Waits are counted only in the foreground, so a guest who
  /// came while the app was off waits the full `order_wait_ms` from now on.
  /// Nothing happens during a story scene or an ad; due events follow after.
  /// Returns how many guests arrived.
  int _syncArrivals() {
    if (_adPaused || storyPaused) return 0;
    final business = state.business;
    if (!business.open) {
      state.regularClock = state.regularClock.withNext(null);
      state.namedClock = state.namedClock.withNext(null);
      return 0;
    }
    final rules = arrivalRules, until = business.settledUtc.millisecondsSinceEpoch;
    if (!state.tutorialActive) {
      state.regularClock = rules.resume(state.regularClock, ArrivalKind.regular, waiting: _waiting(ArrivalKind.regular), at: until);
      state.namedClock = rules.resume(state.namedClock, ArrivalKind.named, waiting: _waiting(ArrivalKind.named), at: until);
    }
    var arrived = 0;
    for (var guard = 0; guard < 100; guard++) {
      final event = rules.next(regular: state.regularClock, named: state.namedClock,
          open: state.business.open, acceptedDay: state.business.acceptedDay, until: until);
      if (event == null) break;
      switch (event.kind) {
        case ArrivalKind.newDay:
          _startBusinessDay(next: true);
        case ArrivalKind.regular:
          _spawnCustomer(null);
          arrived++;
          state.regularClock = rules.arrived(state.regularClock, ArrivalKind.regular,
              waiting: _waiting(ArrivalKind.regular), at: event.at);
        case ArrivalKind.named:
          final npc = _namedFor(state.namedClock, event.at);
          if (npc != null) { _spawnCustomer(npc); arrived++; }
          state.namedClock = rules.arrived(state.namedClock, ArrivalKind.named,
              waiting: _waiting(ArrivalKind.named), at: event.at);
      }
      if (storyPaused) break;
    }
    return arrived;
  }
  /// The guests the clocks would bring within [horizon] while the app is
  /// away, for the customer notifications. None while closed, during the
  /// guide or a story scene.
  List<PlannedArrival> upcomingArrivals(Duration horizon) {
    if (!state.business.open || state.tutorialActive || storyPaused) return const [];
    return arrivalRules.preview(regular: state.regularClock, named: state.namedClock,
        regularWaiting: _waiting(ArrivalKind.regular), namedWaiting: _waiting(ArrivalKind.named),
        from: state.business.settledUtc.millisecondsSinceEpoch, horizonMs: horizon.inMilliseconds, nameAt: _namedFor);
  }
  /// What opening the business does at the start of a business day; at KST
  /// midnight ([next]) an open business turns over by itself (DEC-054).
  void _startBusinessDay({bool next = false}) {
    state.business = next ? state.business.nextDay() : state.business.beginOrContinue(state.business.settledUtc);
    state.inventory = state.inventory.expire(config, state.business.businessIndex).acceptPrepared(state.business.businessIndex);
    state.missions=state.missions.observe(now(),businessStarted:true,autoPeak:autoRate);
  }
  void dismissAwayReport() { awayReport = null; if (!disposed) notifyListeners(); }
  BigInt get tapRate => state.purchases.rate(config, 'tap');
  BigInt get autoRate => state.purchases.rate(config, 'auto');
  Completer<void>? _commandIdle;
  int _lifecycleGeneration = 0;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  /// Monotonic milliseconds for the phase clock, active settlement and the
  /// clicker tap limit. Tests may pass a fake to keep pictures deterministic.
  final int Function()? _monotonicMs;
  int get _mono => _monotonicMs?.call() ?? _clock.elapsedMilliseconds;
  int _lastMono = 0, _checkpoint = 0;
  /// Monotonic times of clicker taps counted in the last second (DEC-036).
  final List<int> _clickerTaps = [];
  /// 사용 통계(26번 5단계): saved commands report first bake/sale, the end
  /// of the guide and Lv.3·5·10 after the save, never inside it.
  final UsageStats usage;
  UsageProgress get _usageProgress => UsageProgress(
      bakes: state.flavorMasteries.values.fold(0, (n, m) => n + m.results.length),
      sales: state.completedSales, level: state.level, tutorial: state.tutorial,
      orderDone: state.daily.order?.done == true ? state.daily.order!.day : null,
      orderEvent: state.daily.order?.event, events: state.daily.events);
  WorkshopController(this.config, this.repository, {DateTime Function()? now, Random? random, this.purchaseGateway,
      int Function()? monotonicMs, UsageStats? usage})
      : now = now ?? (() => DateTime.now().toUtc()), random = random ?? Random.secure(), _monotonicMs = monotonicMs,
        usage = usage ?? UsageStats.none {
    onlineGateway?.source = this;
  }
  @override
  Map<String,dynamic> progressSnapshot() => {'buns':state.buns.toString(),'lifetimeBuns':state.lifetime.toString(),
    'level':state.level,'taps':state.taps,'sales':state.completedSales,'pieces':state.soldPieces};
  @override
  PurchaseJournal? purchaseJournal(String transaction) => state.purchases.journals[transaction];
  // Retained through reloadAfterError; storage integration can persist these
  // frozen attempts alongside its command journal for process-death recovery.
  bool _savingCheckpoint = false;
  bool get cookingInputBlocked => gameplayPaused || error != null || inputBusy;
  /// Busy with a command the player started, not the periodic checkpoint
  /// save: buttons and the clicker stay usable while it runs (26번 4-1 F1).
  bool get inputBusy => busy && !_savingCheckpoint;
  int get activePhaseElapsedMs => state.phaseMs +
      (gameplayPaused || state.session == null || state.session!.finished ? 0 : _mono - _lastMono);
  CookingSession? _pendingCookingResult;
  final Map<String, GriddleHarvest> _pendingHarvests = {};
  CookingSession? get pendingCookingResolution => _pendingCookingResult;
  Map<String, GriddleHarvest> get pendingHarvestResolutions => Map.unmodifiable(_pendingHarvests);
  String _id() => List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join();
  Future<Map<String, dynamic>?> _loadDurable() => repository is SqliteWorkshopRepository
      ? (repository as SqliteWorkshopRepository).loadValidated(
          (row) { WorkshopState.fromJson(row, config); })
      : repository.load();
  Future<void> initialize() async {
    final saved = await _loadDurable();
    state = saved == null ? WorkshopState.initial(now(), config, _id()) : WorkshopState.fromJson(saved, config);
    // 26번 3차 피드백 H20: the painted cells are not saved (G2), so a bake
    // reopened between the first batter and the lid would show the whole
    // step picture — batter that seems poured before the player came in.
    // It starts again from pouring the batter (nothing was used up). Only
    // here, on opening the app: WorkshopState.fromJson also rolls back
    // failed commands and must keep the session as it was.
    final open = state.session;
    if (open != null && const [CookingPhase.filling, CookingPhase.secondBatter, CookingPhase.closing].contains(open.phase)) {
      state.session = CookingSession.start(id: open.id, flavor: open.flavor, practice: open.practice,
          fillingSequence: open.fillingSequence);
      state.phaseMs = 0;
    }
    // Only server-committed grants reconstructed from the durable purchase
    // ledger can produce skill effects; legacy local purchases are not used.
    final report = saved == null ? null : _settleAwayInto();
    error = null;
    if (!await command(() {}, keepNotice: true)) throw StateError('신규 진행 저장 실패');
    awayReport = report;
    _clock.start(); _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }
  /// Runs [mutate] and saves. A command that comes in while the periodic
  /// checkpoint save runs waits for it instead of being dropped (26번 4-1 F1).
  /// The notice is cleared before the active time is settled, so a guest's
  /// timeout line set by that settlement survives; [keepNotice] (checkpoint,
  /// lifecycle and recovery saves) leaves it alone.
  Future<bool> command(void Function() mutate, {bool production = false, bool keepNotice = false}) async {
    while (busy && _savingCheckpoint && !disposed && _commandIdle != null) {
      await _commandIdle!.future;
    }
    if (busy || disposed || error != null) return false;
    if (!keepNotice) notice = null;
    _flushActive();
    busy = true; _commandIdle = Completer<void>();
    final before = state.toJson();
    final progressBefore = _usageProgress;
    var saved = false;
    try {
      try { mutate(); _observeDaily(); } on FormatException catch (e) {
        state = WorkshopState.fromJson(before, config); notice = e.message; return false;
      }
      state.sequence++;
      final next = state.toJson();
      WorkshopState.fromJson(next, config); // Never persist an inconsistent aggregate.
      if (production && repository is WorkshopProductionJournal) {
        await (repository as WorkshopProductionJournal).stageProduction(next, before['sequence'] as int);
      }
      await repository.save(next, before['sequence'] as int);
      return saved = true;
    } catch (e) {
      state = WorkshopState.fromJson(before, config);
      error = '저장 또는 명령 확인이 필요해요: $e';
      return false;
    } finally {
      busy = false; _commandIdle?.complete(); _commandIdle = null; if (!disposed) notifyListeners();
      // Only after the save: never part of the command or its transaction.
      if (saved) usage.observeProgress(progressBefore, _usageProgress);
    }
  }
  Future<void> reloadAfterError() async {
    if (busy || disposed) return;
    // Reading is part of recovery: do not let a command or lifecycle event
    // overwrite the aggregate while its durable version is being loaded.
    busy = true; _commandIdle = Completer<void>();
    try {
      final saved = await _loadDurable();
      if (disposed) return;
      if (saved == null) throw const FormatException('복구할 저장 기록 없음');
      state = WorkshopState.fromJson(saved, config);
      final pending = _pendingCookingResult;
      if (pending != null && state.flavorMasteries[pending.flavor]?.results.containsKey(pending.id) == true) {
        _pendingCookingResult = null;
      }
      _pendingHarvests.removeWhere((id, _) => !state.grid.cookingSourceIds.contains(id));
      final settlement = _settleAway();
      state.business = settlement.state; state.buns += settlement.buns; state.lifetime += settlement.buns;
      error = null; _lastMono = _mono;
    } catch (e) {
      error = '저장 복구 확인이 필요해요: $e';
      rethrow;
    } finally {
      busy = false; _commandIdle?.complete(); _commandIdle = null;
    }
    await command(() {}, keepNotice: true);
  }
  void _advanceMemory(int ms) {
    if (ms <= 0) return;
    if (_adPaused || storyPaused) { _checkpoint += ms; return; }
    if (state.session != null && !state.session!.finished) state.phaseMs += ms;
    if (state.business.permitsProducts(now())) {
      final advanced=state.customers.map((c)=>c.advanceActive(ms)).toList();
      for(final order in advanced.where((c)=>c.remainingMs==0)) {
        final speech=selectCustomerSpeech(customerCatalog,'timeout',_dialogueFacts(order));
        if(speech!=null) notice='${customerShortName(order.customerId)}: ${speech['text']}';
        guestDeparture=(customerId:order.customerId,happy:false,atMs:_mono);
      }
      state.customers=advanced.where((c)=>c.remainingMs>0).toList();
      if (state.session == null && gridVisible) state.grid = state.grid.advanceActive(ms);
      state.arrivalMs += ms;
    }
    _checkpoint += ms;
  }
  void _flushActive() {
    final at = _mono;
    if (foreground && !busy && error == null) {
      final settlement = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:storyPaused ? 0 : at-_lastMono);
      state.business = settlement.state; state.buns += settlement.buns; state.lifetime += settlement.buns;
      state.missions=state.missions.observe(now(),production:settlement.buns,autoPeak:autoRate);
      _advanceMemory(at - _lastMono);
      _syncArrivalsSafely();
    }
    _lastMono = at;
  }
  /// Outside a command a failed arrival must not leave half a guest behind.
  void _syncArrivalsSafely() {
    if (!state.business.open || _adPaused || storyPaused) return;
    final rules = arrivalRules, until = state.business.settledUtc.millisecondsSinceEpoch;
    bool idle(ArrivalClock clock, ArrivalKind kind) => clock.nextAt == null && _waiting(kind) < rules.slots(kind);
    final due = rules.next(regular: state.regularClock, named: state.namedClock, open: true,
            acceptedDay: state.business.acceptedDay, until: until) != null ||
        (!state.tutorialActive && (idle(state.regularClock, ArrivalKind.regular) || idle(state.namedClock, ArrivalKind.named)));
    if (!due) return;
    final before = state.toJson();
    try { _syncArrivals(); }
    on FormatException catch (e) { state = WorkshopState.fromJson(before, config); notice = e.message; }
  }
  void _tick() {
    if (busy) return;
    _flushActive();
    if (!foreground || error != null || disposed) return;
    // During the first-run guide a guest comes when needed (the old way):
    // 도윤 right away, then one more `customer_arrival_interval_ms` after the
    // line empties. Afterwards the real-time clocks bring everyone.
    if (state.tutorialActive && !_adPaused && !storyPaused && state.business.permitsProducts(now()) &&
        state.customers.isEmpty && (state.relationships.met.isEmpty ||
        state.arrivalMs >= DevelopmentBalance.integer(config.section('ordinary_sale'), 'customer_arrival_interval_ms'))) {
      unawaited(welcomeCustomer(named: state.relationships.met.isEmpty));
    }
    if (_checkpoint >= DevelopmentBalance.integer(config.section('manual_cooking'), 'checkpoint_ms')) {
      _checkpoint = 0; unawaited(_saveCheckpoint());
    }
    if (!disposed) notifyListeners();
  }
  Future<void> _saveCheckpoint() async {
    if (busy || disposed || error != null) return;
    _savingCheckpoint = true;
    try { await command(() {}, keepNotice: true); }
    finally { _savingCheckpoint = false; if (!disposed) notifyListeners(); }
  }
  Future<void> setForeground(bool value) async {
    if (disposed || (value == foreground && !busy)) return;
    final generation = ++_lifecycleGeneration;
    if (!value && !busy) _flushActive();
    // Remain paused while waiting for an in-flight durable command. Resume
    // MUST settle the away interval before foreground command flushing.
    foreground = false; _lastMono = _mono;
    await _commandIdle?.future;
    if (disposed || generation != _lifecycleGeneration) return;
    if (value) {
      WorkshopAwayReport? report;
      if (await command(() { report = _settleAwayInto(); }) && report != null) awayReport = report;
      if (disposed || generation != _lifecycleGeneration) return;
      foreground = true; _lastMono = _mono;
      notifyListeners();
    } else { await command(() {}, keepNotice: true); }
  }
  Future<bool> openBusiness() => command(() {
    if(storyPaused) throw const FormatException('대화를 먼저 마쳐 주세요.');
    // DEC-035: a special bungeoppang in the mold must be finished first.
    if(state.session != null) throw const FormatException('스페셜 붕어빵을 다 만든 뒤 영업을 시작해요.');
    state.business = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:0).state;
    _startBusinessDay();
    _syncArrivals(); // The clocks count from opening.
  });
  Future<bool> closeBusiness() => command(() {
    if(storyPaused) throw const FormatException('대화를 먼저 마쳐 주세요.');
    final settled = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:0).state;
    state.business = settled.close(settled.settledUtc);
    state.customers.clear(); state.arrivalMs = 0;
    _syncArrivals(); // Closed: both clocks stop.
    if (state.session?.finished != true) { state.session = null; state.phaseMs = 0; }
  });
  void tap() {
    if (inputBusy || !foreground || disposed || error != null || state.session != null) return;
    _flushActive();
    if (gameplayPaused) return;
    state.buns += tapRate; state.lifetime += tapRate; state.taps++;
    state.missions=state.missions.observe(now(),taps:1,production:tapRate,autoPeak:autoRate);
    notifyListeners();
  }
  /// The big bungeoppang clicker while open (DEC-036): the [tap] path, only
  /// in business with no special bungeoppang in the mold, and at most
  /// `server_validation.max_taps_per_second` counted taps in any second.
  /// Returns the buns earned, or null when the tap only shows its effect.
  BigInt? clickerTap() {
    if (inputBusy || !foreground || disposed || error != null || gameplayPaused) return null;
    if (state.session != null || !state.business.permitsProducts(now())) return null;
    final at = _mono;
    _clickerTaps.removeWhere((t) => at - t >= 1000);
    if (_clickerTaps.length >= DevelopmentBalance.integer(config.section('server_validation'), 'max_taps_per_second')) return null;
    final before = state.taps;
    tap();
    if (state.taps == before) return null;
    _clickerTaps.add(at);
    return tapRate;
  }
  int difficulty(String flavor) => DevelopmentBalance.integer(config.section('active_recipes')[flavor] as Map<String, dynamic>, 'difficulty');
  String flavorLabel(String flavor) => (config.section('active_recipes')[flavor] as Map)['label'] as String;
  Future<bool> selectFlavor(String flavor) => command(() {
    if (state.session != null || !state.recipes.contains(flavor)) throw const FormatException('레시피 선택 불가');
    state.selectedFlavor = flavor;
  });
  Future<bool> claimRecipeFromMission(String flavor) => command(() {
    final catalog = config.section('active_recipes');
    final row = catalog[flavor];
    if (row is! Map<String, dynamic> || flavor == 'redbean' || state.recipes.contains(flavor)) throw const FormatException('이미 보유했거나 없는 레시피예요.');
    final tier = DevelopmentBalance.integer(row, 'acquisition_tier');
    final rule = config.rows('additional_recipe_acquisition_tiers').firstWhere((r) => r['tier'] == tier);
    if (state.level < DevelopmentBalance.integer(rule, 'unlock_level') || state.completedSales < DevelopmentBalance.integer(rule, 'mission_sales')) throw const FormatException('레시피 미션 조건을 확인해 주세요.');
    state.recipes.add(flavor); state.recipeMissions.add(flavor);
    state.flavorMasteries[flavor] = FlavorMasteryProgress(flavor: flavor, difficulty: difficulty(flavor));
  });
  void _startCooking(String flavor, {required bool practice}) {
    if (gameplayPaused || state.session != null || !state.recipes.contains(flavor) ||
        (state.business.open && state.business.needsContinuation(now()))) throw const FormatException('이전 결과/영업일을 먼저 확인해 주세요.');
    final count = DevelopmentBalance.integer(config.section('manual_cooking'), 'filling_inputs');
    state.selectedFlavor = flavor;
    state.session = CookingSession.start(id: _id(), flavor: flavor, practice: practice,
      fillingSequence: List.generate(count, (i) => i.isEven ? CookingDirection.left : CookingDirection.right));
    state.phaseMs = 0;
  }
  /// Practice only before opening (DEC-035); in business the mold makes orders.
  Future<bool> startPractice() => command(() {
    if (state.business.open) throw const FormatException('연습 제작은 영업 준비 중에만 할 수 있어요.');
    _startCooking(state.selectedFlavor, practice: true);
  });
  Future<bool> startOrderProduction(String orderId, String flavor) => command(() {
    if (!state.business.permitsProducts(now()) || !state.customers.any((c) => c.id == orderId &&
        c.remainingMs > 0 && c.lines.any((l) => l.flavor == flavor))) throw const FormatException('진행 중인 손님 주문을 확인해 주세요.');
    _startCooking(flavor, practice: false);
    _orderProductionFor = (state.session!.id, orderId);
  });

  /// The order an order production was started for (26번 4단계), memory
  /// only: not saved, so after a restart the result has no reaction.
  (String, String)? _orderProductionFor;

  /// The order whose customer gives [resultReaction] (the guest layer puts
  /// the words in a bubble over them), or null.
  String? get resultReactionOrderId => _orderProductionFor?.$2;

  /// The order customer's words about the finished bake's [grade] while the
  /// result shows: '도윤: 와, 이건 …'. Null for practice, after a restart,
  /// or when the customer has already left.
  String? resultReaction(CookingGrade grade) {
    final session = state.session, link = _orderProductionFor;
    if (session == null || session.practice || session.phase != CookingPhase.result ||
        link == null || link.$1 != session.id) {
      return null;
    }
    final found = state.customers.where((o) => o.id == link.$2);
    if (found.isEmpty) return null;
    final order = found.single;
    final speech = selectCustomerSpeech(customerCatalog, cookingGradeEvent(grade), _dialogueFacts(order));
    final name = customerShortName(order.customerId);
    return speech == null ? null : '$name: ${speech['text']}';
  }
  void _recordCookingProduct(CookingSession session, {required bool keep}) {
    final result = evaluateCookingResult(config, session, difficulty: difficulty(session.flavor));
    final active = state.business.permitsProducts(now());
    final batch = ProductBatch(id: session.id, flavor: session.flavor, variant: result.variant,
      quantity: DevelopmentBalance.integer(config.section('manual_cooking'), 'products_per_completed_result'),
      madeOnBusinessIndex: active ? state.business.businessIndex : 0);
    state.inventory = active ? state.inventory.recordResult(batch, keep: keep) : state.inventory.recordPreparedResult(batch, keep: keep);
  }
  Future<bool> cookingCommand(CookingSession next) async {
    final receivedMs = activePhaseElapsedMs;
    if (_savingCheckpoint) await _commandIdle?.future;
    return command(() {
    final previous = state.session;
    if (gameplayPaused) throw const FormatException('제작이 일시정지됐어요.');
    if (previous == null || !isCookingSuccessor(previous, next)) throw const FormatException('지난 제작 입력');
    final manual = config.section('manual_cooking');
    if (previous.phase == CookingPhase.closing && next.phase == CookingPhase.flipping &&
        receivedMs < DevelopmentBalance.integer(manual, 'lid_close_ms')) throw const FormatException('뚜껑이 닫히는 중이에요.');
    if (previous.phase == CookingPhase.flipping && next.phase == CookingPhase.cooking &&
        receivedMs < DevelopmentBalance.integer(manual, 'flip_ms')) throw const FormatException('뒤집는 중이에요.');
    if (next.phase == CookingPhase.result) {
      final pending = _pendingCookingResult;
      next = pending != null && pending.id == previous.id && pending.token == previous.token + 1
        ? pending : previous.takeOut(previous.token, receivedMs);
      _pendingCookingResult = next;
    }
    state.session = next; state.phaseMs = 0;
    if (next.phase == CookingPhase.result) {
      state.mastery = state.mastery.record(evaluateCookingResult(config, next, difficulty: difficulty(next.flavor)));
      if (!next.practice) _recordCookingProduct(next, keep: true);
      if (!state.mastered && state.mastery.complete(config)) {
        final rule = config.mastery(difficulty(next.flavor));
        state.masteryAward = {'revision': config.revision, 'resultId': next.id,
          'practiceRequired': DevelopmentBalance.integer(rule, 'practice_required'),
          'techniqueRequired': DevelopmentBalance.integer(rule, 'technique_passes_required')};
      }
    }
    if (next.phase == CookingPhase.canceled) state.session = null;
  }, production: next.phase == CookingPhase.result).then((saved) {
    if (saved && next.phase == CookingPhase.result && _pendingCookingResult?.id == next.id) {
      _pendingCookingResult = null;
    }
    return saved;
    });
  }
  Future<bool> storeResult(bool keep) => command(() {
    final session = state.session;
    if (session == null || session.phase != CookingPhase.result) throw const FormatException('확정할 제작 결과 없음');
    if (session.practice) { _recordCookingProduct(session, keep: keep); }
    else if (!state.inventory.dispositions.containsKey(session.id)) { throw const FormatException('주문 제작 저장을 확인해 주세요.'); }
    state.session = null;
    if (state.tutorial == 'cook' && (keep || !session.practice)) state.tutorial = 'sell';
  }, production: true);
  /// The first feature introduction card still to show (26번 2단계).
  WorkshopFeature? get pendingIntro => pendingFeatureIntro(state, config);
  bool featureIsOpen(WorkshopFeature feature) => featureOpen(state, config, feature);
  String? featureLock(WorkshopFeature feature) => featureLockReason(state, config, feature);
  /// '알겠어요' on an introduction card: never shown again.
  /// Waits for a command in flight, so the card is not shown again.
  Future<bool> markIntroSeen(WorkshopFeature feature) async {
    if (!workshopIntroIds.contains(feature.name)) return false;
    while (busy && !disposed) {
      await (_commandIdle?.future ?? Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    if (state.featureIntros.contains(feature.name)) return true;
    return command(() => state.featureIntros.add(feature.name));
  }
  Future<bool> skipTutorial() => command(() {
    if (!state.tutorialActive) throw const FormatException('진행 중인 안내가 없어요.');
    state.tutorial = 'skipped';
    _syncArrivals(); // Open already: the real-time clocks start now.
  });
  Future<bool> startCell(int index) => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업 중, 스페셜 붕어빵을 만들지 않을 때만 쓸 수 있어요.');
    state.grid = state.grid.start(index, config, ownedAndMastered: {for (final f in state.recipes) if (state.masteryAwards.containsKey(f)) f: difficulty(f)}, choose: (values) => values[random.nextInt(values.length)]);
  });
  Future<bool> harvestCell(int index, {int? expectedCycle}) async {
    String? frozenId;
    final saved = await command(() {
    if (gameplayPaused || !state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업 중, 스페셜 붕어빵을 만들지 않을 때만 쓸 수 있어요.');
    if (index < 0 || index >= state.grid.cells.length) throw const FormatException('숙련된 붕어빵 틀 칸 오류');
    final cell = state.grid.cells[index];
    if (expectedCycle != null && cell.cycle != expectedCycle) throw const FormatException('지난 숙련된 붕어빵 수확 입력');
    final id = 'griddle:${state.grid.runId}:$index:${cell.cycle}';
    frozenId = id;
    final result = _pendingHarvests.putIfAbsent(id, () =>
      state.grid.harvest(index, config, businessIndex: state.business.businessIndex, expectedCycle: expectedCycle));
    state.grid = state.grid.applyHarvest(index, result);
    if (result.product != null) state.inventory = state.inventory.recordResult(result.product!, keep: true);
    }, production: true);
    if (saved) _pendingHarvests.remove(frozenId);
    return saved;
  }
  /// Brings a guest now: the first-run guide's guests and tests. A named
  /// neighbor by the selection rule unless [named] is false; [visitor] names
  /// one for tests. After the guide the real-time clocks call
  /// [_spawnCustomer] instead and there is no button for this (S5-1-Q2).
  Future<bool> welcomeCustomer({bool named = true, String? visitor}) => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now())) throw const FormatException('영업을 시작해 주세요.');
    final rules = arrivalRules;
    if (state.customers.length >= rules.regularSlots + rules.namedSlots) throw const FormatException('손님 대기열이 가득 찼어요.');
    if (visitor != null && (!customerCatalog.contains(visitor) || state.customers.any((c) => c.customerId == visitor))) {
      throw const FormatException('손님 지정 오류');
    }
    _spawnCustomer(visitor ?? (named ? state.relationships.selectNamedVisitor(state.business.businessIndex,
        random.nextInt(1 << 30), config, customerCatalog,
        alreadyQueued: state.customers.map((c) => c.customerId).toSet(), lastVisitor: state.lastNamedVisitor) : null));
  });
  /// Adds one waiting guest: the [named] neighbor, or an anonymous guest when null.
  void _spawnCustomer(String? named) {
    final rule = config.rows('level_progression')[state.level - 1];
    final sale = config.section('ordinary_sale');
    final special = state.level >= DevelopmentBalance.integer(sale, 'special_order_unlock_level') &&
        random.nextInt(10000) < DevelopmentBalance.integer(sale, 'special_order_basis_points');
    final specific = state.level >= DevelopmentBalance.integer(sale, 'specific_variant_order_unlock_level') &&
        random.nextInt(10000) < DevelopmentBalance.integer(sale, 'specific_variant_basis_points');
    final variant = special ? 0 : specific ? 1 + random.nextInt(3) : null;
    state.arrivalMs = 0;
    final choices = state.recipes.toList()..shuffle(random);
    final kinds = 1 + random.nextInt(min(choices.length, DevelopmentBalance.integer(rule, 'order_flavor_limit')));
    final total = kinds + random.nextInt(DevelopmentBalance.integer(rule, 'order_quantity_limit') - kinds + 1);
    final quantities = List<int>.filled(kinds, 1);
    for (var i = kinds; i < total; i++) { quantities[random.nextInt(kinds)]++; }
    final customerId = named ?? 'anonymous_${_id()}';
    final pending = state.relationships.toJson()['followups'] as Map;
    final pendingChoice = named == null ? null : pending['choice_${named.substring(4)}_01'] as String?;
    var lines = [for (var i = 0; i < kinds; i++) CustomerOrderLine(flavor: choices[i], variant: variant,
      special: special, quantity: quantities[i])];
    var newFlavorForTaeo = false;
    if (named != null) {
      final preference = config.section('customer_order_preferences')[named] as Map<String,dynamic>;
      final served = <String>{};
      if (named == 'npc_taeo') {
        for (final sale in state.sales.entries) {
          final evidence = validateStoredCustomerSale(sale.key, sale.value);
          final previous = CustomerOrder.fromJson(evidence['order'] as Map<String, dynamic>);
          if (previous.customerId == named) {
            served.addAll(previous.lines.map((line) => line.flavor));
          }
        }
      }
      final flavor = preferredCustomerFlavor(named, config, owned: state.recipes,
          previouslyServed: served, firstCustomer: state.relationships.met.isEmpty);
      newFlavorForTaeo = named == 'npc_taeo' && !served.contains(flavor) &&
          (config.section('active_recipes')[flavor] as Map<String, dynamic>)['initial'] != true;
      lines = [CustomerOrderLine(flavor:flavor,variant:variant,special:special,
        quantity:min(DevelopmentBalance.integer(preference,'quantity'),DevelopmentBalance.integer(rule,'order_quantity_limit')))];
    }
    var candidate = false;
    if(named=='npc_yunha' && !(state.relationships.toJson()['choices'] as Map).containsKey('choice_yunha_01') && state.business.businessIndex>=DevelopmentBalance.integer(config.section('customer_relationships'),'choice_first_business_day') &&
        state.relationships.affinity(named!)>=DevelopmentBalance.integer(config.section('customer_choice_conditions')[named] as Map<String,dynamic>,'min_affinity')) {
      final prior=state.relationships.toJson(), own=(prior['visits'] as Map).values.where((v)=>(v as Map)['npc']==named).length;
      final days=<int>{};
      for(final sale in state.sales.entries) {
        final e=validateStoredCustomerSale(sale.key,sale.value),o=e['order'] as Map,ls=o['lines'] as List;
        if(o['customerId']==named && ls.length==1 && (ls.single as Map)['flavor']=='redbean' && (ls.single as Map)['quantity']==DevelopmentBalance.integer(config.section('customer_choice_conditions')['npc_yunha'] as Map<String,dynamic>,'baseline_quantity')) days.add(e['businessIndex'] as int);
      }
      final rules=config.section('customer_choice_conditions')[named] as Map<String,dynamic>;
      candidate=own+1>=DevelopmentBalance.integer(rules,'min_visits') && days.length>=DevelopmentBalance.integer(rules,'redbean_two_success_days');
      if(candidate) lines=[CustomerOrderLine(flavor:'redbean',quantity:DevelopmentBalance.integer(rules,'candidate_redbean_quantity'),variant:variant,special:special)];
    }
    final withOwnPortion=DevelopmentBalance.integer(config.section('customer_order_preferences')['npc_makrye'] as Map<String,dynamic>,'quantity')+DevelopmentBalance.integer(config.section('customer_relationships'),'own_portion_extra_quantity');
    if(named=='npc_makrye' && pendingChoice=='a' && DevelopmentBalance.integer(rule,'order_quantity_limit')>=withOwnPortion) {
      lines=[CustomerOrderLine(flavor:lines.single.flavor,quantity:withOwnPortion,variant:variant,special:special)];
    }
    final order = CustomerOrder(id:_id(),customerId:customerId,
      remainingMs:DevelopmentBalance.integer(rule,'order_wait_ms'),lines:lines);
    state.customers.add(order);
    if (named != null) {
      state.lastNamedVisitor = named;
      state.relationships = state.relationships.visit(order.id,named,state.business.businessIndex,customerCatalog,context:{
        'lines':lines.map((l)=>l.toJson()).toList(),'initialWaitMs':order.remainingMs,'working':named=='npc_eunchae' && (pendingChoice!=null || !state.relationships.stories.contains('story_eunchae_01') || random.nextInt(10000)>=DevelopmentBalance.integer(config.section('customer_relationships'),'holiday_visit_basis_points')),
        'cameraPresent':named=='npc_taeo' && (pendingChoice=='c' || newFlavorForTaeo || !state.relationships.stories.contains('story_taeo_01')),
        'running':named=='npc_minjae' && pendingChoice==null && !state.relationships.stories.contains('story_minjae_01'),'sketchObserved':false,
        'turnedBack':named=='npc_minjae' && pendingChoice==null && state.relationships.affinity(named)>=DevelopmentBalance.integer(config.section('customer_choice_conditions')[named] as Map<String,dynamic>,'min_affinity'),
        'ownPortion':named=='npc_makrye' && pendingChoice=='a' && lines.single.quantity>=withOwnPortion,
        'onSite':named=='npc_makrye' && pendingChoice=='b',
        'photoReminder':named=='npc_taeo' && pendingChoice=='c'});
      final observed = state.tasteObservations.putIfAbsent(named, () => {});
      for (final line in lines) {
        final variants = observed.putIfAbsent(line.flavor, () => <int>{});
        if (line.variant != null) variants.add(line.variant!);
      }
      final followup=_matchingFollowup(order);
      // 이야기 하루 한 조각: a follow-up waits for a day with room.
      if(followup!=null && _storyRoomToday) state.customerScene=followup;
    }
  }

  /// How many products the sale button would hand over to [order] now.
  int saleReadyCount(CustomerOrder order) {
    if (gameplayPaused || !state.business.permitsProducts(now())) return 0;
    try {
      return selectCustomerInventory(order, state.inventory, businessIndex: state.business.businessIndex, partial: true)
          .fold(0, (n, line) => n + line.values.fold(0, (a, b) => a + b));
    } on FormatException { return 0; }
  }
  /// The wait [order] started with, for the queue's time ring.
  int initialWaitMs(CustomerOrder order) {
    final context = ((state.relationships.toJson()['visits'] as Map)[order.id] as Map?)?['context'] as Map?;
    final initial = context?['initialWaitMs'];
    return initial is int && initial > 0 ? initial
        : DevelopmentBalance.integer(config.rows('level_progression')[state.level - 1], 'order_wait_ms');
  }

  /// Capture the displayed order before entering the command. A delayed retry
  /// must never deliver to the next customer after the original has left.
  Future<bool> sellToFirstCustomer() => sellToCustomer(
      state.customers.isEmpty ? '' : state.customers.first.id);

  /// Production and stock-selection UI use the same sale command. Without
  /// [selectedByLine] it hands over the matching stock, oldest first: short
  /// stock is a partial sale (ordinary buns now, no sale count), and the
  /// product that fills the order completes the sale (DEC-017/023/007).
  /// Invalid selections consume nothing; there is no exchange grace period.
  Future<bool> sellToCustomer(String orderId,
      {List<Map<String, int>>? selectedByLine}) => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now())) {
      throw const FormatException('판매할 손님 없음');
    }
    final index = state.customers.indexWhere((order) => order.id == orderId);
    if (index < 0) throw const FormatException('이미 종료된 주문이에요.');
    if (index != 0) throw const FormatException('맨 앞 손님의 주문부터 확인해 주세요.');
    final order = state.customers[index];
    final selected = selectedByLine ?? selectCustomerInventory(order, state.inventory,
        businessIndex: state.business.businessIndex, partial: true);
    final difficulties = {for (final f in state.recipes) f: difficulty(f)};
    final progress = CustomerSalesProgress(inventory: state.inventory, ordinaryBuns: state.buns,
      lifetimeSalesBuns: state.lifetime, sales: state.sales);
    final handed = selected.fold(0, (n, line) => n + line.values.fold(0, (a, b) => a + b));
    if (handed < order.remainingQuantity) {
      final (partial, next) = progress.deliver(config, order, selectedByLine: selected,
        businessIndex: state.business.businessIndex, flavorDifficulties: difficulties);
      state.inventory = partial.inventory; state.buns = partial.ordinaryBuns; state.lifetime = partial.lifetimeSalesBuns;
      state.customers[index] = next;
      return;
    }
    final sales = progress.sell(config, order, selectedByLine: selected,
      businessIndex: state.business.businessIndex, flavorDifficulties: difficulties);
    state.inventory = sales.inventory; state.buns = sales.ordinaryBuns; state.lifetime = sales.lifetimeSalesBuns;
    state.sales..clear()..addAll(sales.sales);
    state.pendingGold['sale:${order.id}'] = sales.sales[order.id]!;
    if (customerCatalog.contains(order.customerId)) {
      state.relationships = state.relationships.successfulSale(order.id,order.id,state.business.businessIndex,config);
    }
    state.completedSales++; state.customers.removeAt(index);
    state.soldPieces += order.lines.fold(0, (n, line) => n + line.quantity);
    guestDeparture = (customerId: order.customerId, happy: true, atMs: _mono);
    // The guide's first sale stays free of story, follow-up and choice scenes.
    // It gets the big praise (26번 2단계, S2-Q4): the guest's words, the
    // stars and a short sparkle, not saved.
    if (state.tutorialActive) { state.tutorial = 'done'; salePraise = _lastSale(); }
    else if(customerCatalog.contains(order.customerId)) { _afterNamedSale(order); }
    _syncArrivals(); // A freed place (or the guide's end) starts a stopped clock.
  });
  Map<String,dynamic>? _matchingFollowup(CustomerOrder order) {
    // Existing relationship scenes precede optional choice follow-ups, even
    // when the latter is normally shown on entry rather than after the sale.
    if (_readyCustomerStory(order.customerId) != null) return null;
    final journal=state.relationships.toJson(),visits=journal['visits'] as Map;
    final context=((visits[order.id] as Map?)?['context'] as Map?) ?? {};
    for(final e in (journal['followups'] as Map).entries) {
      final npc=order.customerId;
      if(customerCatalog.choice(e.key as String)['npc_id']!=npc) continue;
      if (((journal['choices'] as Map)[e.key] as Map)['day'] >= state.business.businessIndex) continue;
      if(npc=='npc_makrye' && (e.value=='a' && context['ownPortion']!=true || e.value=='b' && context['onSite']!=true)) continue;
      if(npc=='npc_minjae' && context['running']!=false || npc=='npc_eunchae' && context['working']!=true || npc=='npc_taeo' && e.value=='c' && context['photoReminder']!=true) continue;
      return {'kind':'followup','id':e.key,'npc':npc,'choice':e.value};
    }
    return null;
  }
  CustomerDialogueFacts _dialogueFacts(CustomerOrder order) {
    final context=((state.relationships.toJson()['visits'] as Map)[order.id] as Map?)?['context'] as Map? ?? {};
    return CustomerDialogueFacts(order:order,stage:state.relationships.stage(order.customerId,config),
      met:state.relationships.met,stories:state.relationships.stories,
      working:context['working']==true,running:context['running']==true,cameraPresent:context['cameraPresent']==true,
      onSite:context['onSite']==true,openingDay:state.business.businessIndex==1);
  }
  Map<String,String> _waitingSpeech(CustomerOrder order) => selectCustomerSpeech(customerCatalog,'waiting',_dialogueFacts(order),
      recent:state.relationships.recent(order.customerId)) ?? {'id':'common_waiting','text':'제 것 나오면 알려주세요.'};
  String? customerOrderSpeech(CustomerOrder order) {
    if(!customerCatalog.contains(order.customerId)) return null;
    final visits=(state.relationships.toJson()['visits'] as Map).values.where((v)=>(v as Map)['npc']==order.customerId).length;
    final event=visits==1 ? 'first_visit':'order';
    return selectCustomerSpeech(customerCatalog,event,_dialogueFacts(order),recent:state.relationships.recent(order.customerId))?['text'];
  }
  Map<String,String> _neighborSpeech(CustomerOrder order) {
    final facts=_dialogueFacts(order),rules=config.section('customer_relationships');
    final events=[if(facts.stage>=DevelopmentBalance.integer(rules,'regular_dialogue_stage')) 'regular',
      if(facts.stage>=DevelopmentBalance.integer(rules,'friendly_dialogue_stage')) 'neighbor',
      if(facts.stage>=DevelopmentBalance.integer(rules,'friendly_dialogue_stage')) 'friendly','smalltalk'];
    final candidates=<Map<String,String>>[];
    for(final event in events) {
      if(qualifiesCustomerDialogue(event,facts)) {
        final definition=(customerCatalog.npc(order.customerId)['dialogues'] as List).cast<Map>().where((d)=>d['event']==event);
        if(definition.isNotEmpty && definition.first['once_only']==true &&
            (state.relationships.toJson()['seenDialogue'] as List).contains('${order.customerId}:${definition.first['id']}')) continue;
        final speech=selectCustomerSpeech(customerCatalog,event,facts,recent:state.relationships.recent(order.customerId));
        if(speech!=null) candidates.add(speech);
      }
    }
    final recent=state.relationships.recent(order.customerId);
    final unused=candidates.where((s)=>!recent.contains(s['id']));
    return unused.isNotEmpty ? unused.first : candidates.isNotEmpty ? candidates.first : _waitingSpeech(order);
  }
  String? customerDelaySpeech(CustomerOrder order) {
    final context=((state.relationships.toJson()['visits'] as Map)[order.id] as Map?)?['context'] as Map?;
    final initial=context?['initialWaitMs'];
    if(initial is! int || initial<=0 || (initial-order.remainingMs)*1000<initial*DevelopmentBalance.integer(config.section('customer_relationships'),'delay_threshold_permille')) return null;
    return selectCustomerSpeech(customerCatalog,'delayed',_dialogueFacts(order))?['text'];
  }
  WorkshopSalePraise? _lastSale() {
    if(state.sales.isEmpty) return null;
    final sale=state.sales.entries.last,evidence=validateStoredCustomerSale(sale.key,sale.value);
    final order=CustomerOrder.fromJson(evidence['order'] as Map<String,dynamic>);
    final speech=selectCustomerSpeech(customerCatalog,'success',_dialogueFacts(order));
    return WorkshopSalePraise(customerShortName(order.customerId),DevelopmentBalance.integer(evidence,'stars'),
      speech?['text'] ?? '감사합니다. 잘 먹을게요.');
  }
  String? get lastSaleFeedback {
    final sale=_lastSale();
    return sale==null ? null : '${sale.name} · 별 ${sale.stars} · ${sale.speech}';
  }
  /// The first-run guide's first sale, shown big for a moment over the
  /// stall (26번 2단계). Never saved: a restart simply skips it.
  WorkshopSalePraise? salePraise;
  void dismissSalePraise() {
    if (salePraise == null) return;
    salePraise = null;
    if (!disposed) notifyListeners();
  }
  String customerConversation(CustomerOrder order)=>_neighborSpeech(order)['text']!;
  String? customerWaitingAction(CustomerOrder order) {
    if(!customerCatalog.contains(order.customerId)) return null;
    final facts=_dialogueFacts(order);
    if(order.customerId=='npc_minjae' && !facts.running || order.customerId=='npc_eunchae' && !facts.working) return '차례를 기다린다.';
    if(order.customerId=='npc_taeo' && !facts.cameraPresent) return '가게를 둘러본다.';
    return (customerCatalog.npc(order.customerId)['expressions'] as Map)['waiting'] as String;
  }
  String waitingLine(CustomerOrder order)=>_waitingSpeech(order)['text']!;
  Future<bool> observeWaiting(String orderId)=>command(() {
    final found=state.customers.where((o)=>o.id==orderId);
    if(gameplayPaused || found.isEmpty || !customerCatalog.contains(found.single.customerId)) throw const FormatException('기다리는 손님을 확인해 주세요.');
    final order=found.single,npc=order.customerId;
    state.relationships=state.relationships.observeVisit(order.id,'waitingSeen');
    if(npc=='npc_seojin') state.relationships=state.relationships.observeVisit(order.id,'sketchObserved');
    final id=_neighborSpeech(order)['id']!;
    state.relationships=state.relationships.recordDialogue(npc,id,state.business.businessIndex,config,customerCatalog,firstAutomaticCompletion:true);
  });
  String? get photoReactionSale {
    final visits=state.relationships.toJson()['visits'] as Map;
    for(final entry in state.sales.entries.toList().reversed) {
      final order=validateStoredCustomerSale(entry.key,entry.value)['order'] as Map;
      if(order['customerId']=='npc_taeo' && ((visits[entry.key] as Map?)?['context'] as Map?)?['cameraPresent']!=false && validateStoredCustomerSale(entry.key,entry.value)['businessIndex']==state.business.businessIndex && ((visits[entry.key] as Map?)?['context'] as Map?)?['photoShown']!=true) return entry.key;
    }
    return null;
  }
  Future<bool> acknowledgePhotoReaction(String saleId)=>command(() {
    if(gameplayPaused || photoReactionSale!=saleId) throw const FormatException('판매 반응을 확인해 주세요.');
    final raw=state.sales[saleId];
    if(raw==null) throw const FormatException('판매 기록 누락');
    final evidence=validateStoredCustomerSale(saleId,raw);
    if(evidence['businessIndex']!=state.business.businessIndex) throw const FormatException('이전 영업일 반응은 기록에서 확인해 주세요.');
    state.relationships=state.relationships.observeVisit(saleId,'photoShown');
    _afterNamedSale(CustomerOrder.fromJson(evidence['order'] as Map<String,dynamic>));
  });
  CustomerEventFacts _choiceFacts(String npc, CustomerOrder current) {
    final journal=state.relationships.toJson(), visits=journal['visits'] as Map;
    final own=visits.entries.where((e)=>(e.value as Map)['npc']==npc).toList();
    final succeeded=<Map<String,dynamic>>[];
    final successDays=<int>{},redbeanDays=<int>{},largeDays=<int>{},workDays=<int>{},received=<String>{};
    var custard=0;
    for(final entry in (journal['actions'] as Map<String,dynamic>).entries.where((e)=>e.key.startsWith('sale:'))) {
      final action=entry.value as Map, visit=visits[action['visit']] as Map;
      if(visit['npc']!=npc) continue;
      final raw=state.sales[entry.key.substring(5)];
      if(raw==null) continue;
      final evidence=validateStoredCustomerSale(entry.key.substring(5),raw),order=evidence['order'] as Map;
      succeeded.add(evidence);final at=action['day'] as int;successDays.add(at);
      final lines=(order['lines'] as List).cast<Map>();
      final quantity=lines.fold<int>(0,(sum,l)=>sum+(l['quantity'] as int));
      for(final line in lines) {received.add(line['flavor'] as String);}
      if(lines.length==1 && lines.single['flavor']=='redbean' && quantity==DevelopmentBalance.integer(config.section('customer_choice_conditions')['npc_yunha'] as Map<String,dynamic>,'baseline_quantity')) redbeanDays.add(at);
      if(quantity>=DevelopmentBalance.integer(config.section('customer_choice_conditions')['npc_makrye'] as Map<String,dynamic>,'large_order_quantity')) largeDays.add(at);
      if(lines.any((l)=>l['flavor']=='custard')) custard++;
      if((visit['context'] as Map?)?['working']==true) workDays.add(at);
    }
    final previous=own.where((e)=>e.key!=current.id).map((e)=>(e.value as Map)['day'] as int).fold<int>(0,(a,b)=>max(a,b));
    final context=(visits[current.id] as Map?)?['context'] as Map? ?? {};
    final otherFlavors=<String>{};
    for(final evidence in succeeded.where((e)=>(e['order'] as Map)['id']!=current.id)) {
      for(final line in ((evidence['order'] as Map)['lines'] as List)) { otherFlavors.add((line as Map)['flavor'] as String); }
    }
    return CustomerEventFacts(npcId:npc,affinity:state.relationships.affinity(npc),visits:own.length,
      distinctVisitDays:own.map((e)=>(e.value as Map)['day']).toSet().length,
      daysSinceLastVisit:previous==0 ? 0 : state.business.businessIndex-previous,
      redbeanTwoSuccessDays:redbeanDays.length,largeOrderSuccessDays:largeDays.length,
      otherMetCount:state.relationships.met.length-1,recipeCount:state.recipes.length,receivedFlavorCount:received.length,
      sketchVisitCount:own.where((e)=>((e.value as Map)['context'] as Map?)?['sketchObserved']==true).length,
      workVisits:own.where((e)=>((e.value as Map)['context'] as Map?)?['working']==true).length,
      workSuccessDays:workDays.length,runningVisits:own.where((e)=>((e.value as Map)['context'] as Map?)?['running']==true).length,
      custardSuccesses:custard,mapStoryKnown:state.relationships.stories.contains('story_doyun_01'),
      newFlavorFirstServed:current.lines.any((l)=>(config.section('active_recipes')[l.flavor] as Map)['initial']!=true && !otherFlavors.contains(l.flavor)),forgotPhotoShown:context['photoShown']==true,
      workingVisit:context['working']==true,runningTurnedBack:context['turnedBack']==true,
      firstVisit:own.length<=1,completedStories:state.relationships.stories);
  }
  String? _readyCustomerStory(String npc) {
    if (!customerCatalog.contains(npc)) return null;
    final journal = state.relationships.toJson();
    final visits=journal['visits'] as Map;
    final success=<String,int>{};
    for(final e in (journal['actions'] as Map<String,dynamic>).entries.where((e)=>e.key.startsWith('sale:'))) {
      final id=(visits[(e.value as Map)['visit']] as Map)['npc'] as String;
      success[id]=(success[id] ?? 0)+1;
    }
    final story='story_${npc.substring(4)}_01';
    final storyFacts=WorkshopStoryFacts(met:state.relationships.met,
      affinity:{for(final id in state.relationships.met) id:state.relationships.affinity(id)},successfulVisits:success,
      drawingConversationSeen:(journal['seenDialogue'] as List).contains('npc_seojin:seojin_waiting_01'));
    return !state.relationships.stories.contains(story) && eligibleCustomerStory(npc,storyFacts,config)
        ? story : null;
  }
  /// 이야기 하루 한 조각 (26번 7단계): story scenes, follow-ups and choice
  /// events opened on this business day, together.
  int get storiesOpenedToday {
    final journal = state.relationships.toJson(), day = state.business.businessIndex;
    final scene = state.customerScene;
    return (journal['storyDays'] as Map).values.where((d) => d == day).length +
        (journal['followupDays'] as Map).values.where((d) => d == day).length +
        (journal['lastChoiceDay'] == day ? 1 : 0) +
        // A story or follow-up on screen counts once it shows.
        (scene != null && (scene['kind'] == 'story' || scene['kind'] == 'followup') ? 1 : 0);
  }
  bool get _storyRoomToday =>
      storiesOpenedToday < DevelopmentBalance.integer(config.section('daily_return'), 'story_daily_limit');
  /// A story ready for [npc] waits for tomorrow: say so, gently.
  void _storyTomorrow(String npc) {
    final name = customerShortName(npc);
    notice = '내일 $name${_subjectParticle(name)} 이야기를 이어 갈 것 같아요.';
  }
  void _afterNamedSale(CustomerOrder order) {
    final npc=order.customerId, facts=_choiceFacts(npc,order);
    final story = _readyCustomerStory(npc);
    if (story != null) {
      if (!_storyRoomToday) { _storyTomorrow(npc); return; }
      state.customerScene={'kind':'story','id':story,'npc':npc};return;
    }
    final followup = _matchingFollowup(order);
    if (followup != null) {
      if (!_storyRoomToday) { _storyTomorrow(npc); return; }
      state.customerScene = followup; return;
    }
    final event='choice_${npc.substring(4)}_01';
    final candidateMatches=npc!='npc_yunha' || (order.lines.length==1 && order.lines.single.flavor=='redbean' &&
      order.lines.single.quantity==DevelopmentBalance.integer(config.section('customer_choice_conditions')[npc] as Map<String,dynamic>,'candidate_redbean_quantity'));
    if(!eligibleCustomerChoice(facts,config,candidateOrderMatches:candidateMatches)) return;
    state.relationships=state.relationships.rollChoice(state.business.businessIndex,[event],random.nextInt(10000),config,customerCatalog,tutorial:state.tutorialActive,
      anotherStoryToday:!_storyRoomToday);
    if(state.relationships.active!=null) {
      final orderIds=['a','b','c']..shuffle(random);
      state.customerScene={'kind':'choice','id':event,'npc':npc,'order':orderIds};
    }
  }
  Future<bool> respondToCustomer(String choice) => command(() {
    final scene=state.customerScene;
    if(scene==null || scene['kind']!='choice') throw const FormatException('선택 대화가 없어요.');
    state.relationships=state.relationships.choose(scene['id'] as String,choice,config,customerCatalog);
    if(choice=='wave') state.customerScene=null;
  });
  Future<bool> replayCustomerStory(String storyId)=>command(() {
    if(gameplayPaused || !state.relationships.stories.contains(storyId)) throw const FormatException('완료한 이야기를 선택해 주세요.');
    final story=customerCatalog.story(storyId);
    state.customerScene={'kind':'replay','id':storyId,'npc':story['npc_id']};
  });
  Future<bool> finishCustomerScene()=>command(() {
    final scene=state.customerScene;
    if(scene==null) throw const FormatException('이어갈 대화가 없어요.');
    final id=scene['id'] as String,npc=scene['npc'] as String;
    if(scene['kind']=='choice') {state.relationships=state.relationships.closeReaction(id);}
    else if(scene['kind']=='followup') {state.relationships=state.relationships.consumeFollowup(id,contextMatches:true);}
    else if(scene['kind']!='replay') {
      state.relationships=state.relationships.completeStory(npc,id,customerCatalog,eligible:true);
      state.relationships=state.relationships.recordDialogue(npc,id,state.business.businessIndex,config,customerCatalog,firstAutomaticCompletion:true);
    }
    state.customerScene=null;
  });
  // ---- 레벨업 조건 (4차 피드백 g9, `level_progression`) ----
  // The one place the level-up rule lives. A level asks for pieces sold and
  // taps in that level (both start again at 0 on level-up) and a payment
  // taken when it is reached: `level_cost_buns` 붕어빵력, and at the levels
  // with `level_cost_gold` (Lv.10·20·30·40·50) 황금붕어빵력 too, which the
  // server wallet takes through a `level:N` purchase ([payLevelGold]).
  // API for the automatic 승급 and the Lv ring (4차 피드백 g1):
  //   [levelRequirements] rows for the window, [levelProgressPermille] the
  //   ring, [canLevelUp] whether [_promote] raises the level now,
  //   [levelGoalsMet] sales and taps only, [levelGoldDue] the gold purchase
  //   to start, [levelCostNote] / [levelWaitReason] the texts.
  Map<String, dynamic>? get _nextLevelRule => state.level >= 50 ? null : config.rows('level_progression')[state.level];
  /// 붕어빵력 the next level-up takes (0 at the top level).
  BigInt get levelCostBuns => _nextLevelRule == null ? BigInt.zero : DevelopmentBalance.decimal(_nextLevelRule!, 'level_cost_buns');
  /// 황금붕어빵력 the next level-up takes (Lv.10·20·30·40·50 only).
  int get levelCostGold => _nextLevelRule == null ? 0 : DevelopmentBalance.integer(_nextLevelRule!, 'level_cost_gold');
  int get levelPiecesSold => state.soldPieces - state.levelStartPieces;
  int get levelTaps => state.taps - state.levelStartTaps;
  /// The server wallet's 황금붕어빵력 as last shown (the page keeps it up to
  /// date from the account); only for the window and [levelGoldDue].
  int goldBalance = 0;
  /// The `level:N` purchase id of the next level when it asks for gold.
  String? get _levelGoldProduct => levelCostGold > 0 ? 'level:${state.level + 1}' : null;
  bool get _levelGoldPaid => _levelGoldProduct != null && state.purchases.owned[_levelGoldProduct] == 1;
  /// Sales and taps of this level are done (the payment may still wait).
  bool get levelGoalsMet {
    final rule = _nextLevelRule;
    return rule != null && levelPiecesSold >= DevelopmentBalance.integer(rule, 'additional_sold_pieces') &&
        levelTaps >= DevelopmentBalance.integer(rule, 'additional_taps');
  }
  /// What the next level asks for, as (label, how far, how much). Empty at
  /// the top level. The payment rows are full once it can be paid.
  List<LevelRequirement> get levelRequirements {
    final rule = _nextLevelRule;
    if (rule == null) return const [];
    final paid = _levelGoldPaid, cost = levelCostBuns, gold = levelCostGold;
    return [
      (label: '이번 레벨에 판 붕어빵', current: BigInt.from(levelPiecesSold),
        target: BigInt.from(DevelopmentBalance.integer(rule, 'additional_sold_pieces'))),
      (label: '이번 레벨 탭', current: BigInt.from(levelTaps), target: BigInt.from(DevelopmentBalance.integer(rule, 'additional_taps'))),
      (label: '레벨업 비용 붕어빵력', current: paid ? cost : state.purchases.available(state.buns), target: cost),
      if (gold > 0) (label: '레벨업 비용 황금붕어빵력', current: BigInt.from(paid ? gold : goldBalance), target: BigInt.from(gold)),
    ];
  }
  /// Whether the next level can be taken now: goals met and the payment
  /// ready (붕어빵력 on hand; at a gold level the `level:N` purchase done).
  bool get canLevelUp => levelGoalsMet &&
      (_levelGoldProduct != null ? _levelGoldPaid : state.purchases.available(state.buns) >= levelCostBuns);
  /// The way to the next level in permille for the Lv ring: the average of
  /// [levelRequirements], each up to its target; 1000 only when [canLevelUp]
  /// (and at the top level).
  int get levelProgressPermille {
    final rows = levelRequirements;
    if (rows.isEmpty) return 1000;
    var sum = 0;
    for (final r in rows) {
      final current = r.current < BigInt.zero ? BigInt.zero : r.current > r.target ? r.target : r.current;
      sum += r.target <= BigInt.zero ? 1000 : (current * BigInt.from(1000) ~/ r.target).toInt();
    }
    final average = sum ~/ rows.length;
    return average >= 1000 && !canLevelUp ? 999 : average;
  }
  /// '레벨업할 때 붕어빵력 3만 개가 쓰여요' (and the gold at Lv.10·20·…), or
  /// null at the top level. Shown in the window and the ring's tooltip.
  String? get levelCostNote {
    if (_nextLevelRule == null) return null;
    final buns = compactNumber(levelCostBuns);
    return levelCostGold > 0 ? '레벨업할 때 붕어빵력 $buns, 황금붕어빵력 $levelCostGold개가 쓰여요'
        : '레벨업할 때 붕어빵력 $buns${subjectParticle(buns)} 쓰여요';
  }
  /// Why the level waits although sales and taps are done, or null.
  String? get levelWaitReason {
    if (!levelGoalsMet || canLevelUp) return null;
    final lack = levelCostBuns - state.purchases.available(state.buns), lackGold = levelCostGold - goldBalance;
    if (lack > BigInt.zero && lackGold > 0) return '붕어빵력이 ${compactNumber(lack)}, 황금붕어빵력이 $lackGold 모자라요.';
    if (lack > BigInt.zero) return '붕어빵력이 ${compactNumber(lack)} 모자라요.';
    if (lackGold > 0) return '황금붕어빵력이 $lackGold 모자라요.';
    if (purchaseGateway == null) return '인터넷에 연결해 주세요.';
    if (purchaseGateway!.authenticatedAccount.isEmpty) return '카카오 로그인 후 레벨업할 수 있어요.';
    return '황금붕어빵력을 내는 중이에요.';
  }
  /// A gold level whose sales, taps and 붕어빵력 are ready and whose gold
  /// the wallet seems to have: start [payLevelGold] (the page does it by
  /// itself, so 승급 stays automatic).
  bool get levelGoldDue => _levelGoldProduct != null && !_levelGoldPaid && levelGoalsMet &&
      state.purchases.available(state.buns) >= levelCostBuns && goldBalance >= levelCostGold &&
      purchaseGateway != null && purchaseGateway!.authenticatedAccount.isNotEmpty &&
      !_purchaseBusy && state.purchases.journals.values.every((j) => j.settled);
  /// Pays a gold level's 붕어빵력 and 황금붕어빵력 through the server
  /// purchase path (reserve → local debit → commit, like a skill); the
  /// level itself is raised by [_promote] after.
  Future<bool> payLevelGold() async {
    final product = _levelGoldProduct, gateway = purchaseGateway;
    if (product == null || gateway == null || !levelGoalsMet || _levelGoldPaid) return false;
    return purchaseSkill(gateway, product);
  }
  /// Raises the level while [canLevelUp], taking each level's payment:
  /// 붕어빵력 from the balance (lifetime stays), or nothing more at a gold
  /// level (its purchase took both). Sales and taps start again at 0.
  /// Each level's 붕어빵력 reward is added and its 황금 waits for the
  /// server's review as before (`pendingGold['level:N']`).
  void _promote() {
    while (canLevelUp) {
      final next = state.level + 1, rule = config.rows('level_progression')[state.level];
      if (!state.claimedLevels.add(next)) throw const FormatException('중복 승급');
      if (_levelGoldProduct == null) state.buns -= levelCostBuns;
      state..level = next ..levelStartTaps = state.taps ..levelStartSales = state.completedSales
        ..levelStartPieces = state.soldPieces;
      final buns = DevelopmentBalance.decimal(rule, 'buns_reward'); state.buns += buns; state.lifetime += buns;
      final gold = DevelopmentBalance.integer(rule, 'gold_reward');
      if (gold > 0) state.pendingGold['level:$next'] = jsonEncode({'level': next, 'gold': gold, 'revision': config.revision});
    }
  }
  /// 승급 by hand until the automatic one (4차 피드백 g1) calls [_promote]
  /// from every command.
  Future<bool> levelUp() => command(() {
    if (!canLevelUp) throw const FormatException('승급 조건을 확인해 주세요.');
    _promote();
  });
  Future<bool> setBackgroundTime(String time)=>command(() {
    if(!['scenetime','day','night_time','clock'].contains(time)) throw const FormatException('배경 시간 선택 오류');
    state.sceneTime=time;
  });
  Future<bool> claimMission(String scope,String goal,{String? expectedPeriod})=>command(() {
    state.missions=state.missions.observe(now(),autoPeak:autoRate);
    if(expectedPeriod!=null && expectedPeriod!=(scope=='daily' ? state.missions.day:state.missions.week)) throw const FormatException('미션 기간이 바뀌었어요. 다시 확인해 주세요.');
    state.missions=state.missions.claim(config,scope,goal);
    final key=state.missions.claimKey(scope,goal);
    state.pendingGold['mission:$key']=state.missions.claims[key]!;
  });
  bool ownsAvatar(String id) => state.hasAvatar(config.section('avatar_catalog'),id);
  /// The first run's 여자/남자 사장님 choice (3차 피드백 H11): that one is
  /// this shop's for good and worn now; the other is bought in 꾸미기.
  /// Only the first-run screen calls this ([OwnerAccount.chooseCharacter]).
  Future<bool> chooseStarterCharacter(String id) => command(() {
    final entry=config.section('avatar_catalog')[id];
    if (entry is! Map<String,dynamic> || entry['slot']!=CosmeticSlot.character.name) throw const FormatException('사장님을 골라 주세요.');
    state.avatarGrants.removeWhere((g)=>(config.section('avatar_catalog')[g] as Map)['slot']==CosmeticSlot.character.name);
    state.avatarGrants.add(id);
    state._wearCharacter(id);
  });
  Future<bool> equipAvatar(String id) => command(() {
    final entry=config.section('avatar_catalog')[id];
    if (entry is! Map<String,dynamic> || !ownsAvatar(id)) throw const FormatException('보유한 아바타 아이템을 골라 주세요.');
    if (entry['slot']==CosmeticSlot.character.name) {
      state._wearCharacter(id);
    } else {
      state.avatarEquipment[entry['slot'] as String]=id;
    }
  });
  Future<bool> _bindRewardAccount(WorkshopOnline gateway,String account) async => command(() {
    if (gateway.authenticatedAccount!=account || account.isEmpty ||
        (state.rewardAccount!=null && state.rewardAccount!=account) ||
        (state.purchases.account!=null && state.purchases.account!=account)) throw const FormatException('원래 진행 계정으로 확인해 주세요.');
    state.rewardAccount=account;
  });
  Future<bool> syncRewards() async {
    final gateway=onlineGateway;
    if (gateway==null || _rewardBusy || disposed || error!=null) return false;
    _rewardBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      var count=0;
      for (final key in state.pendingGold.keys.toList()..sort()) {
        final old=state.rewardReceipts[key];
        if (old!=null && (jsonDecode(old) as Map)['outcome']!='pending') continue;
        if (++count>DevelopmentBalance.integer(config.section('pending_reward_sync'),'batch_size')) break;
        final sale=key.startsWith('sale:'),claim=sale ? key.substring(5) : '${state.grid.runId}:$key';
        final payload=jsonDecode(state.pendingGold[key]!) as Map<String,dynamic>;
        final result=await gateway.reward(claim,sale ? 'sale':'mission',payload);
        if (!await command(() {
          if (gateway.authenticatedAccount!=account) throw const FormatException('계정이 변경됐어요.');
          final checked=validateWorkshopRewardReceipt(result,account:account,progress:state.grid.runId,
            claim:claim,kind:sale ? 'sale':'mission',payload:payload);
          final oldRaw=state.rewardReceipts[key];
          if (oldRaw!=null && (jsonDecode(oldRaw) as Map)['outcome']!='pending' && oldRaw!=jsonEncode(checked)) throw const FormatException('확정 보상 수신 충돌');
          state.rewardReceipts[key]=jsonEncode(checked);
        })) return false;
      }
      return true;
    } catch (e) { notice='보상 확인 대기를 유지했어요: $e';return false;
    } finally { _rewardBusy=false;if(!disposed) notifyListeners(); }
  }
  Future<bool> showRewardedAd(WorkshopAdDriver driver) async {
    final gateway=onlineGateway;
    if (gateway==null || !driver.ready || _adBusy || disposed || error!=null || gameplayPaused) return false;
    _adBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      final id=_id();
      // Persist the ID before reserving a server slot. A failed response is
      // recovered by the same ID and never replayed through the SDK.
      if (!await command(() => state.adAttempts[id]={'account':account,'attempt':id,'status':'unknown'})) return false;
      final approval=validateWorkshopAd(await gateway.startAd(id),account,id);
      if (gateway.authenticatedAccount!=account || approval['status']!='reserved' || approval['customData'] is! String) return false;
      if (!await command(() => state.adAttempts[id]=approval)) return false;
      setAdPaused(true);
      try { await driver.show(customData:approval['customData'] as String); }
      finally { setAdPaused(false); }
      return await _queryAd(gateway,account,id);
    } catch (e) { notice='광고 검증 대기를 유지했어요: $e';return false;
    } finally { setAdPaused(false);_adBusy=false;if(!disposed) notifyListeners(); }
  }
  Future<bool> _queryAd(WorkshopOnline gateway,String account,String id) async {
    final result=validateWorkshopAd(await gateway.queryAd(id),account,id);
    if (gateway.authenticatedAccount!=account) return false;
    return command(() {
      final old=state.adAttempts[id]!;
      if (old['paid']==true && (result['paid']!=true || old['receiptId']!=result['receiptId'] || old['providerProofKey']!=result['providerProofKey'])) throw const FormatException('광고 지급 결과 역행');
      if ((old['status']=='verified' && result['status']!='verified') ||
          (old['status']=='verifying' && result['status']=='reserved') ||
          (old['status']=='rejectedFinal' && result['status']!='rejectedFinal')) throw const FormatException('광고 검증 상태 역행');
      if (old['status']!='unknown' && result['status']!='unknown' &&
          (old['day']!=result['day'] || old['revision']!=result['revision'] || old['gold']!=result['gold'])) throw const FormatException('광고 승인 근거 충돌');
      if (result['status']!='unknown') state.adAttempts[id]=result;
    });
  }
  Future<bool> recoverAds() async {
    final gateway=onlineGateway;
    if (gateway==null || _adBusy || disposed || error!=null) return false;
    _adBusy=true;
    try {
      final account=gateway.authenticatedAccount;
      await gateway.requireActiveProgress(state.grid.runId);
      if (!await _bindRewardAccount(gateway,account)) return false;
      for (final e in state.adAttempts.entries.toList()) {
        if (e.value['paid']==true || e.value['status']=='rejectedFinal') continue;
        if (!await _queryAd(gateway,account,e.key)) return false;
      }
      return true;
    } catch(e) { notice='광고 복구 확인이 필요해요: $e';return false;
    } finally { _adBusy=false;if(!disposed) notifyListeners(); }
  }
  /// Pause gameplay clocks for an approved ad without pausing economy time.
  void setAdPaused(bool value) {
    if (disposed || value == _adPaused) return;
    _flushActive(); _adPaused = value; notifyListeners();
  }
  Future<bool> purchaseSkill(WorkshopPurchaseGateway gateway, String skill, {int quantity = 1}) async {
    if (_purchaseBusy || error != null || disposed) return false;
    _purchaseBusy = true;
    try {
      final account = gateway.authenticatedAccount;
      if (account.isEmpty) {
        // Signed out is not a stuck purchase: say plainly that login is needed.
        notice = skill.startsWith('cosmetic:') ? '카카오 로그인 후 살 수 있어요.' : '카카오 로그인 후 레벨업할 수 있어요.';
        return false;
      }
      if (state.rewardAccount != null && state.rewardAccount != account) throw const FormatException('원래 보상 계정으로 확인해 주세요.');
      await gateway.requireActiveProgress(state.grid.runId);
      if (disposed || gateway.authenticatedAccount != account) return false;
      final quote = quoteWorkshopProduct(config, skill, owned: state.purchases.owned[skill] ?? 0, quantity: quantity);
      final intent = PurchaseJournal.start(account, _id(), quote);
      if (!await command(() => state.purchases = state.purchases.prepare(config, intent,
          buns: state.buns, lifetime: state.lifetime,level:state.level))) return false;
      final response = await gateway.reserve(intent);
      if (!await _purchaseResponse(gateway, account, intent.transactionId, response)) return false;
      return await _finishPurchase(gateway, account, intent.transactionId);
    } catch (e) {
      notice = '${skill.startsWith('cosmetic:') ? '구매' : '레벨업'} 확인이 남아 있어요. 새 거래 대신 같은 기록을 복구해 주세요: $e';
      return false;
    } finally { _purchaseBusy = false; if (!disposed) notifyListeners(); }
  }
  Future<bool> recoverPurchase(WorkshopPurchaseGateway gateway, String transaction, {bool cancel = false}) async {
    if (_purchaseBusy || error != null || disposed) return false;
    _purchaseBusy = true;
    try {
      final account = gateway.authenticatedAccount;
      final saved = state.purchases.journal(transaction);
      if (account != saved.accountId) throw const FormatException('원래 구매 계정으로 확인해 주세요.');
      await gateway.requireActiveProgress(state.grid.runId);
      if (disposed || gateway.authenticatedAccount != account) return false;
      var response = await gateway.query(account, transaction);
      if (response['status'] == 'unknown' && !cancel) response = await gateway.reserve(saved);
      if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
      if (cancel && !state.purchases.journal(transaction).settled) {
        response = await gateway.cancel(account, transaction);
        if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
        if (state.purchases.journal(transaction).serverStatus == 'reserved') return false;
      }
      return await _finishPurchase(gateway, account, transaction);
    } catch (e) {
      final cosmetic = state.purchases.journals[transaction]?.quote.skillId.startsWith('cosmetic:') ?? false;
      notice = '${cosmetic ? '구매' : '레벨업'} 복구 확인이 필요해요: $e'; return false;
    } finally { _purchaseBusy = false; if (!disposed) notifyListeners(); }
  }
  Future<bool> _purchaseResponse(WorkshopPurchaseGateway gateway, String account, String transaction,
      Map<String, dynamic> response) async {
    if (disposed || gateway.authenticatedAccount != account) return false;
    return command(() => state.purchases = state.purchases.response(transaction, response));
  }
  Future<bool> _finishPurchase(WorkshopPurchaseGateway gateway, String account, String transaction) async {
    var journal = state.purchases.journal(transaction);
    if (journal.serverStatus == 'reserved') {
      if (!await command(() {
        final result = state.purchases.debit(transaction, state.buns);
        state.purchases = result.purchases; state.buns = result.buns;
      })) return false;
      journal = state.purchases.journal(transaction);
      final response = await gateway.commit(journal);
      if (!await _purchaseResponse(gateway, account, transaction, response)) return false;
    }
    journal = state.purchases.journal(transaction);
    if (journal.serverStatus == 'unknown' || journal.serverStatus == 'reserved') return false;
    return command(() {
      final previous=state.purchases.journal(transaction);
      final result = state.purchases.settle(transaction, state.buns);
      state.purchases = result.purchases; state.buns = result.buns;
      final current=state.purchases.journal(transaction);
      if(!previous.applied && current.applied && !current.quote.skillId.contains(':')) {
        state.missions=state.missions.observe(now(),purchases:current.quote.quantity,autoPeak:autoRate);
      }
    });
  }
  // ---- 26번 7단계: 매일 돌아올 이유 (lib/workshop_daily.dart) ----
  Map<String, dynamic> get _dailyRules => config.section('daily_return');
  Map<String, dynamic> get _orderRules => _dailyRules['special_order'] as Map<String, dynamic>;
  Map<String, dynamic> get _stampRules => _dailyRules['attendance'] as Map<String, dynamic>;
  /// The KST day of the settled business time. It only moves forward, so a
  /// clock turned back never reopens a day.
  String get today => businessDayKst(state.business.settledUtc);
  /// The seasonal event today (config dates only), after the first-run guide.
  SeasonalEvent? get seasonalEvent => state.tutorialActive ? null : activeSeasonalEvent(config, today);
  /// Today's 오늘의 주문서 once special orders are open (Lv.5), or null.
  DailyOrder? get dailyOrder {
    final order = state.daily.order;
    return order != null && order.day == today && !state.tutorialActive ? order : null;
  }
  /// The buns the order pays now: `reward_seconds` of auto production, at least `min_buns`.
  BigInt get dailyOrderReward => dailyBuns(autoRate, DevelopmentBalance.integer(_orderRules, 'reward_seconds'),
      DevelopmentBalance.decimal(_orderRules, 'min_buns'));
  int get dailyOrderAffinity => DevelopmentBalance.integer(_orderRules, 'affinity');
  bool _fitsDailyOrder(DailyOrder order, ProductBatch b) {
    final age = state.business.businessIndex - b.madeOnBusinessIndex;
    return b.flavor == order.flavor && b.variant == order.variant && age >= 0 && age < 5;
  }
  /// Stock that fits the order (flavor and doneness, still sellable), oldest
  /// first, or null when there is not enough.
  Map<String, int>? _dailyOrderStock(DailyOrder order) {
    final fits = state.inventory.batches.values.where((b) => _fitsDailyOrder(order, b)).toList()
      ..sort((a, b) => a.madeOnBusinessIndex != b.madeOnBusinessIndex
          ? a.madeOnBusinessIndex.compareTo(b.madeOnBusinessIndex) : a.id.compareTo(b.id));
    var needed = order.quantity;
    final pick = <String, int>{};
    for (final batch in fits) {
      if (needed == 0) break;
      final amount = min(needed, batch.quantity);
      pick[batch.id] = amount; needed -= amount;
    }
    return needed == 0 ? pick : null;
  }
  /// How many fitting products are in stock (for the card).
  int get dailyOrderStock {
    final order = dailyOrder;
    if (order == null) return 0;
    return state.inventory.batches.values.where((b) => _fitsDailyOrder(order, b)).fold(0, (n, b) => n + b.quantity);
  }
  /// Whether today's stamp is still to take.
  bool get attendanceReady => !state.tutorialActive && state.daily.stampDay != today;
  int get attendanceCycle => DevelopmentBalance.integer(_stampRules, 'cycle_days');
  /// The box the next stamp takes (1~7); after the seventh it starts again.
  int get nextStamp => state.daily.stamps >= attendanceCycle ? 1 : state.daily.stamps + 1;
  /// Day 7 gives gold through the server wallet; without a server (builds
  /// with no online keys) it gives more buns instead.
  bool stampGivesGold(int box) => box == attendanceCycle && onlineGateway != null;
  int get attendanceGold => DevelopmentBalance.integer(_stampRules, 'gold');
  BigInt stampBuns(int box) => box == attendanceCycle
      ? dailyBuns(autoRate, DevelopmentBalance.integer(_stampRules, 'substitute_seconds'),
          DevelopmentBalance.decimal(_stampRules, 'substitute_min_buns'))
      : dailyBuns(autoRate, DevelopmentBalance.integer(_stampRules, 'buns_seconds'),
          DevelopmentBalance.decimal(_stampRules, 'min_buns'));
  /// Something on the '오늘' slip still waits for the player.
  bool get dailyWaiting => attendanceReady || (dailyOrder != null && !dailyOrder!.done);

  /// Records the KST day after the guide: the day's order (once special
  /// orders are open) and the seasonal event the player is in. Runs after
  /// every command and on coming back; pays nothing. Returns whether a new
  /// order came. However many days passed, one order for today.
  bool _observeDaily() {
    if (state.tutorialActive) return false;
    final day = today;
    var daily = state.daily, fresh = false;
    if (daily.day != day) daily = daily.copyWith(day: day);
    final event = activeSeasonalEvent(config, day);
    if (event != null && !daily.events.contains(event.id)) daily = daily.copyWith(events: {...daily.events, event.id});
    if (daily.order?.day != day && featureOpen(state, config, WorkshopFeature.specialOrders)) {
      final met = state.relationships.met;
      daily = daily.copyWith(order: makeDailyOrder(config, day: day, runId: state.grid.runId,
          flavors: state.recipes.toList()..sort(), neighbors: customerCatalog.ids.where(met.contains).toList(),
          event: event));
      fresh = true;
    }
    state.daily = daily;
    return fresh;
  }

  /// '도장 찍기': the first stamp of the KST day takes the next box. Boxes
  /// 1~6 pay buns; the seventh asks the server for gold (pending until
  /// verified, like mission gold).
  Future<bool> stampAttendance() => command(() {
    if (!attendanceReady) throw const FormatException('오늘 출석 도장은 이미 찍었어요.');
    final box = nextStamp, day = today;
    if (stampGivesGold(box)) {
      state.pendingGold['attendance:$day'] = attendanceClaim(config, day);
    } else {
      final buns = stampBuns(box);
      state.buns += buns; state.lifetime += buns;
    }
    state.daily = state.daily.copyWith(stamps: box, stampDay: day);
  });

  /// Bakes for the order in the big mold while open (no customer needed).
  Future<bool> startDailyOrderProduction() => command(() {
    final order = dailyOrder;
    if (order == null || order.done) throw const FormatException('오늘의 주문서를 확인해 주세요.');
    if (!state.business.permitsProducts(now())) throw const FormatException('영업 중에 주문서 붕어빵을 구울 수 있어요.');
    _startCooking(order.flavor, practice: false);
  });

  /// '납품하기': hands the order over from stock while open. Pays buns and
  /// the requester's affinity (its own daily cap), never gold.
  Future<bool> deliverDailyOrder() => command(() {
    final order = dailyOrder;
    if (order == null || order.done) throw const FormatException('오늘의 주문서를 확인해 주세요.');
    if (gameplayPaused || !state.business.permitsProducts(now())) throw const FormatException('영업 중에 납품할 수 있어요.');
    final pick = _dailyOrderStock(order);
    if (pick == null) throw const FormatException('주문서에 맞는 붕어빵이 모자라요.');
    state.inventory = state.inventory.consume(pick);
    final buns = dailyOrderReward;
    state.buns += buns; state.lifetime += buns;
    if (order.npc != null) {
      state.relationships = state.relationships.specialOrder(order.npc!, order.day, state.business.businessIndex,
          dailyOrderAffinity, config, customerCatalog);
    }
    state.daily = state.daily.copyWith(order: order.delivered(buns, state.business.businessIndex));
  });
  @override
  void dispose() { disposed = true; _timer?.cancel(); _clock.stop(); super.dispose(); }
}

/// 이/가 after [word]: by whether its last syllable has a final consonant.
String _subjectParticle(String word) {
  if (word.isEmpty) return '이';
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '이';
  return (code - 0xAC00) % 28 == 0 ? '가' : '이';
}
