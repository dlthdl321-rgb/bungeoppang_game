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
import 'workshop_purchases.dart';
import 'workshop_online.dart';
import 'workshop_ads.dart';
import 'workshop_missions.dart';
import 'workshop_customers.dart';
import 'workshop_customer_events.dart';
import 'workshop_customer_dialogue.dart';

/// Fresh-game local production aggregate. Gold remains in the authenticated
/// server wallet; pending claims here are never spendable gold.
class WorkshopState {
  int sequence = 0, level = 1, taps = 0, completedSales = 0, phaseMs = 0,
      levelStartTaps = 0, levelStartSales = 0, arrivalMs = 0;
  String selectedFlavor = 'redbean',sceneTime='scenetime';
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
  BigInt buns = BigInt.zero, lifetime = BigInt.zero;
  WorkshopPurchases purchases = WorkshopPurchases.empty();
  String? rewardAccount;
  final Map<String,String> rewardReceipts = {};
  final Map<String,Map<String,dynamic>> adAttempts = {};
  final Map<String,String> avatarEquipment = {};
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
    flavorMasteries['redbean'] = FlavorMasteryProgress(flavor: 'redbean',
      difficulty: DevelopmentBalance.integer(config.section('active_recipes')['redbean'] as Map<String, dynamic>, 'difficulty'));
  }
  Map<String, dynamic> toJson() => {'schema': 4, 'sequence': sequence, 'level': level,
    'taps': taps, 'completedSales': completedSales, 'phaseMs': phaseMs,
    'levelStartTaps': levelStartTaps, 'levelStartSales': levelStartSales, 'arrivalMs': arrivalMs,
    'selectedFlavor': selectedFlavor,'sceneTime':sceneTime, 'recipes': recipes.toList()..sort(),
    'recipeMissions': recipeMissions.toList()..sort(),
    'masteryAwards': {for (final e in masteryAwards.entries) e.key: Map<String, dynamic>.from(e.value)},
    'relationships':relationships.toJson(), 'customerScene':customerScene==null ? null : jsonDecode(jsonEncode(customerScene)),
    'tasteObservations': {for (final e in tasteObservations.entries) e.key:
      {for (final f in e.value.entries) f.key: f.value.toList()..sort()}},
    'buns': buns.toString(), 'lifetime': lifetime.toString(), 'purchases': purchases.toJson(),
    'rewardAccount':rewardAccount,'rewardReceipts':Map<String,String>.from(rewardReceipts),
    'adAttempts':{for(final e in adAttempts.entries) e.key:Map<String,dynamic>.from(e.value)},
    'avatarEquipment':Map<String,String>.from(avatarEquipment),'missions':missions.toJson(), 'business': business.toJson(),
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
    if (row['schema'] is! int || ![1, 2, 3, 4].contains(row['schema'])) throw const FormatException('신규 게임 저장 버전 오류');
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
    if ((row['schema'] as int)<3 && ['rewardAccount','rewardReceipts','adAttempts','avatarEquipment','missions','sceneTime'].any(row.containsKey)) throw const FormatException('구형 저장에 신규 보호 필드가 있어요.');
    if (row['schema'] == 1 && row.containsKey('purchases')) throw const FormatException('구형 저장의 구매 필드 충돌');
    if ((row['schema'] as int) >= 2) state.purchases = WorkshopPurchases.fromJson(object('purchases'), config);
    state.purchases.available(state.buns);
    if((row['schema'] as int)>=3) state.missions=WorkshopMissions.fromJson(object('missions'));
    if (row['schema'] == 4) {
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
          cell.difficulty != (catalog[cell.flavor] as Map)['difficulty'])) throw const FormatException('잠긴 맛의 6구 저장');
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
    var salesBuns = BigInt.zero;
    final consumed = <String, BigInt>{};
    for (final e in object('sales').entries) {
      if (e.value is! String) throw const FormatException('판매 원장 형식 오류');
      final evidence = validateStoredCustomerSale(e.key, e.value as String);
      if ((evidence['businessIndex'] as int) > state.business.businessIndex) throw const FormatException('미래 영업일의 판매');
      for (final item in evidence['products'] as List) {
        final product = item as Map<String, dynamic>, id = product['batch'] as String;
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
      salesBuns += DevelopmentBalance.decimal(evidence, 'ordinaryBuns');
      state.sales[e.key] = e.value as String;
    }
    if (row['schema'] == 4) {
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
      for (final e in object('avatarEquipment').entries) {
        if (e.value is! String) throw const FormatException('아바타 착용 형식 오류');
        final item=config.section('avatar_catalog')[e.value];
        if (item is! Map<String,dynamic> || item['slot']!=e.key ||
            (item['free']!=true && state.purchases.owned['cosmetic:${e.value}']!=1)) throw const FormatException('아바타 착용 보유 근거 오류');
        state.avatarEquipment[e.key]=e.value as String;
      }
    }
    if (row['schema']==4) {
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
    return state;
  }
}

abstract class WorkshopRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> next, int expectedSequence);
}
String _workshopGuard(Map<String,dynamic> row) => jsonEncode((row['schema'] as int)>=3 ? {
  'purchases':row['purchases'],'rewardAccount':row['rewardAccount'],
  'rewardReceipts':row['rewardReceipts'],'adAttempts':row['adAttempts'],
  'missionClaims':(row['missions'] as Map<String,dynamic>)['claims'],
  if(row['schema']==4) 'relationships':row['relationships'],
  if(row['schema']==4) 'customerScene':row['customerScene']} : row['purchases']);
class SqliteWorkshopRepository implements WorkshopRepository {
  Database? _database;
  Future<Database> get database async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'todays_bungeoppang_workshop.db'), version: 4,
    onCreate: (db, _) async {
      await db.execute('CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
      await db.execute('CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    },
    onUpgrade: (db, old, next) async {
      if (old < 2) await db.execute('CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    });
  @override
  Future<Map<String, dynamic>?> load() async {
    return (await database).transaction((tx) async {
      final rows = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      final guards = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [1]);
      if (rows.isEmpty) {
        if (guards.isNotEmpty) throw const FormatException('구매 보호 기록의 진행이 누락됐어요.');
        return null;
      }
      final body = jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
      if (body['sequence'] != rows.single['sequence'] ||
          ([2,3,4].contains(body['schema']) && (guards.isEmpty || guards.single['body'] != _workshopGuard(body))) ||
          (body['schema'] == 1 && guards.isNotEmpty)) throw const FormatException('저장/구매 보호 기록 재대조가 필요해요.');
      return body;
    });
  }
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    await (await database).transaction((tx) async {
      final current = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      final guards = await tx.query('purchase_guard', where: 'id = ?', whereArgs: [1]);
      if (current.isEmpty && guards.isNotEmpty) throw const FormatException('구매 보호 기록만 남은 상태');
      if (current.isNotEmpty) {
        final body = jsonDecode(current.single['body'] as String) as Map<String, dynamic>;
        if (body['sequence'] != current.single['sequence'] ||
            ([2,3,4].contains(body['schema']) && (guards.isEmpty || guards.single['body'] != _workshopGuard(body))) ||
            (body['schema'] == 1 && guards.isNotEmpty)) throw const FormatException('구매 보호 기록 충돌');
      }
      final oldSequence = current.isEmpty ? 0 : current.single['sequence'];
      if (oldSequence != expectedSequence || next['sequence'] != expectedSequence + 1) {
        throw const FormatException('진행 저장 순번 충돌');
      }
      if (next['schema'] != 4 || next['purchases'] is! Map<String, dynamic>) throw const FormatException('구매 보호 저장 형식 오류');
      await tx.insert('purchase_guard', {'id': 1, 'body': _workshopGuard(next)}, conflictAlgorithm: ConflictAlgorithm.replace);
      if (current.isNotEmpty) await tx.insert('snapshots', {...current.single, 'slot': 'backup'}, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('snapshots', {'slot': 'current', 'sequence': next['sequence'], 'body': jsonEncode(next)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

class WorkshopController extends ChangeNotifier {
  final DevelopmentBalance config;
  final WorkshopRepository repository;
  final DateTime Function() now;
  final Random random;
  final WorkshopPurchaseGateway? purchaseGateway;
  late WorkshopState state;
  final customerCatalog = WorkshopCustomerCatalog.bundled();
  String customerName(String id) => id.startsWith('anonymous_') ? '지나가는 손님' : customerCatalog.displayName(id,state.relationships.stories);
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
  BigInt get tapRate => state.purchases.rate(config, 'tap');
  BigInt get autoRate => state.purchases.rate(config, 'auto');
  Completer<void>? _commandIdle;
  int _lifecycleGeneration = 0;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _lastMono = 0, _checkpoint = 0;
  WorkshopController(this.config, this.repository, {DateTime Function()? now, Random? random, this.purchaseGateway})
      : now = now ?? (() => DateTime.now().toUtc()), random = random ?? Random.secure();
  String _id() => List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join();
  Future<void> initialize() async {
    final saved = await repository.load();
    state = saved == null ? WorkshopState.initial(now(), config, _id()) : WorkshopState.fromJson(saved, config);
    // Only server-committed grants reconstructed from the durable purchase
    // ledger can produce skill effects; legacy local purchases are not used.
    final settlement = _settleAway();
    state.business = settlement.state;
    state.buns += settlement.buns; state.lifetime += settlement.buns;
    error = null;
    if (!await command(() {})) throw StateError('신규 진행 저장 실패');
    _clock.start(); _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }
  Future<bool> command(void Function() mutate) async {
    if (busy || disposed || error != null) return false;
    _flushActive();
    busy = true; _commandIdle = Completer<void>();
    final before = state.toJson();
    try {
      try { mutate(); } on FormatException catch (e) {
        state = WorkshopState.fromJson(before, config); notice = e.message; return false;
      }
      notice = null;
      state.sequence++;
      final next = state.toJson();
      WorkshopState.fromJson(next, config); // Never persist an inconsistent aggregate.
      await repository.save(next, before['sequence'] as int);
      return true;
    } catch (e) {
      state = WorkshopState.fromJson(before, config);
      error = '저장 또는 명령 확인이 필요해요: $e';
      return false;
    } finally { busy = false; _commandIdle?.complete(); _commandIdle = null; if (!disposed) notifyListeners(); }
  }
  Future<void> reloadAfterError() async {
    if (busy || disposed) return;
    final saved = await repository.load();
    if (saved == null) throw const FormatException('복구할 저장 기록 없음');
    state = WorkshopState.fromJson(saved, config);
    final settlement = _settleAway();
    state.business = settlement.state; state.buns += settlement.buns; state.lifetime += settlement.buns;
    error = null; _lastMono = _clock.elapsedMilliseconds;
    await command(() {});
  }
  void _advanceMemory(int ms) {
    if (ms <= 0) return;
    if (_adPaused || storyPaused) { _checkpoint += ms; return; }
    if (state.session != null && !state.session!.finished) state.phaseMs += ms;
    if (state.business.permitsProducts(now())) {
      final advanced=state.customers.map((c)=>c.advanceActive(ms)).toList();
      for(final order in advanced.where((c)=>c.remainingMs==0)) {
        final speech=selectCustomerSpeech(customerCatalog,'timeout',_dialogueFacts(order));
        if(speech!=null) notice='${customerName(order.customerId)}: ${speech['text']}';
      }
      state.customers=advanced.where((c)=>c.remainingMs>0).toList();
      if (state.session == null && gridVisible) state.grid = state.grid.advanceActive(ms);
      state.arrivalMs += ms;
    }
    _checkpoint += ms;
  }
  void _flushActive() {
    final at = _clock.elapsedMilliseconds;
    if (foreground && !busy && error == null) {
      final settlement = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:storyPaused ? 0 : at-_lastMono);
      state.business = settlement.state; state.buns += settlement.buns; state.lifetime += settlement.buns;
      state.missions=state.missions.observe(now(),production:settlement.buns,autoPeak:autoRate);
      _advanceMemory(at - _lastMono);
    }
    _lastMono = at;
  }
  void _tick() {
    if (busy) return;
    _flushActive();
    if (!foreground || error != null || disposed) return;
    final row = config.rows('level_progression')[state.level - 1];
    if (!_adPaused && !storyPaused && state.business.permitsProducts(now()) &&
        state.arrivalMs >= DevelopmentBalance.integer(config.section('ordinary_sale'), 'customer_arrival_interval_ms') &&
        state.customers.length < DevelopmentBalance.integer(row, 'max_queue')) {
      unawaited(welcomeCustomer());
    }
    if (_checkpoint >= DevelopmentBalance.integer(config.section('manual_cooking'), 'checkpoint_ms')) {
      _checkpoint = 0; unawaited(command(() {}));
    }
    if (!disposed) notifyListeners();
  }
  Future<void> setForeground(bool value) async {
    if (disposed || (value == foreground && !busy)) return;
    final generation = ++_lifecycleGeneration;
    if (!value && !busy) _flushActive();
    // Remain paused while waiting for an in-flight durable command. Resume
    // MUST settle the away interval before foreground command flushing.
    foreground = false; _lastMono = _clock.elapsedMilliseconds;
    await _commandIdle?.future;
    if (disposed || generation != _lifecycleGeneration) return;
    if (value) {
      await command(() {
        final settlement = _settleAway();
        state.business = settlement.state;
        state.buns += settlement.buns; state.lifetime += settlement.buns;
      });
      if (disposed || generation != _lifecycleGeneration) return;
      foreground = true; _lastMono = _clock.elapsedMilliseconds;
      notifyListeners();
    } else { await command(() {}); }
  }
  Future<bool> openBusiness() => command(() {
    if(storyPaused) throw const FormatException('대화를 먼저 마쳐 주세요.');
    state.business = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:0).state;
    state.business = state.business.beginOrContinue(state.business.settledUtc);
    state.inventory = state.inventory.expire(config, state.business.businessIndex).acceptPrepared(state.business.businessIndex);
    state.missions=state.missions.observe(now(),businessStarted:true,autoPeak:autoRate);
  });
  Future<bool> closeBusiness() => command(() {
    if(storyPaused) throw const FormatException('대화를 먼저 마쳐 주세요.');
    final settled = state.business.settleActive(now(), bunsPerSecond:autoRate,elapsedMs:0).state;
    state.business = settled.close(settled.settledUtc);
    state.customers.clear(); state.arrivalMs = 0;
    if (state.session?.finished != true) { state.session = null; state.phaseMs = 0; }
  });
  void tap() {
    if (busy || !foreground || disposed || error != null) return;
    _flushActive();
    if (gameplayPaused) return;
    state.buns += tapRate; state.lifetime += tapRate; state.taps++;
    state.missions=state.missions.observe(now(),taps:1,production:tapRate,autoPeak:autoRate);
    notifyListeners();
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
  Future<bool> startPractice() => command(() => _startCooking(state.selectedFlavor, practice: true));
  Future<bool> startOrderProduction(String orderId, String flavor) => command(() {
    if (!state.business.permitsProducts(now()) || !state.customers.any((c) => c.id == orderId &&
        c.remainingMs > 0 && c.lines.any((l) => l.flavor == flavor))) throw const FormatException('진행 중인 손님 주문을 확인해 주세요.');
    _startCooking(flavor, practice: false);
  });
  void _recordCookingProduct(CookingSession session, {required bool keep}) {
    final result = evaluateCookingResult(config, session, difficulty: difficulty(session.flavor));
    final active = state.business.permitsProducts(now());
    final batch = ProductBatch(id: session.id, flavor: session.flavor, variant: result.variant,
      quantity: DevelopmentBalance.integer(config.section('manual_cooking'), 'products_per_completed_result'),
      madeOnBusinessIndex: active ? state.business.businessIndex : 0);
    state.inventory = active ? state.inventory.recordResult(batch, keep: keep) : state.inventory.recordPreparedResult(batch, keep: keep);
  }
  Future<bool> cookingCommand(CookingSession next) => command(() {
    final previous = state.session;
    if (gameplayPaused) throw const FormatException('제작이 일시정지됐어요.');
    if (previous == null || !isCookingSuccessor(previous, next)) throw const FormatException('지난 제작 입력');
    final manual = config.section('manual_cooking');
    if (previous.phase == CookingPhase.closing && next.phase == CookingPhase.flipping &&
        state.phaseMs < DevelopmentBalance.integer(manual, 'lid_close_ms')) throw const FormatException('뚜껑이 닫히는 중이에요.');
    if (previous.phase == CookingPhase.flipping && next.phase == CookingPhase.cooking &&
        state.phaseMs < DevelopmentBalance.integer(manual, 'flip_ms')) throw const FormatException('뒤집는 중이에요.');
    if (next.phase == CookingPhase.result) next = previous.takeOut(previous.token, state.phaseMs);
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
  });
  Future<bool> storeResult(bool keep) => command(() {
    final session = state.session;
    if (session == null || session.phase != CookingPhase.result) throw const FormatException('확정할 제작 결과 없음');
    if (session.practice) { _recordCookingProduct(session, keep: keep); }
    else if (!state.inventory.dispositions.containsKey(session.id)) { throw const FormatException('주문 제작 저장을 확인해 주세요.'); }
    state.session = null;
  });
  Future<bool> startCell(int index) => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업/큰 틀 상태 확인');
    state.grid = state.grid.start(index, config, ownedAndMastered: {for (final f in state.recipes) if (state.masteryAwards.containsKey(f)) f: difficulty(f)}, choose: (values) => values[random.nextInt(values.length)]);
  });
  Future<bool> harvestCell(int index) => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업/큰 틀 상태 확인');
    final result = state.grid.harvest(index, config, businessIndex: state.business.businessIndex);
    state.grid = result.state;
    if (result.product != null) state.inventory = state.inventory.recordResult(result.product!, keep: true);
  });
  Future<bool> welcomeCustomer() => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now())) throw const FormatException('영업을 시작해 주세요.');
    final rule = config.rows('level_progression')[state.level - 1];
    if (state.customers.length >= DevelopmentBalance.integer(rule, 'max_queue')) throw const FormatException('손님 대기열이 가득 찼어요.');
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
    final named = state.relationships.selectNamedVisitor(state.business.businessIndex,
      random.nextInt(10000), random.nextInt(1 << 30), config, customerCatalog,alreadyQueued:state.customers.map((c) => c.customerId).toSet());
    final customerId = named ?? 'anonymous_${_id()}';
    final pending = state.relationships.toJson()['followups'] as Map;
    final pendingChoice = named == null ? null : pending['choice_${named.substring(4)}_01'] as String?;
    var lines = [for (var i = 0; i < kinds; i++) CustomerOrderLine(flavor: choices[i], variant: variant,
      special: special, quantity: quantities[i])];
    if (named != null) {
      final preference = config.section('customer_order_preferences')[named] as Map<String,dynamic>;
      final flavor = named=='npc_doyun' && state.relationships.met.isEmpty ? 'redbean' : state.recipes.contains(preference['flavor']) ? preference['flavor'] as String : 'redbean';
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
      state.relationships = state.relationships.visit(order.id,named,state.business.businessIndex,customerCatalog,context:{
        'lines':lines.map((l)=>l.toJson()).toList(),'initialWaitMs':order.remainingMs,'working':named=='npc_eunchae' && (pendingChoice!=null || !state.relationships.stories.contains('story_eunchae_01') || random.nextInt(10000)>=DevelopmentBalance.integer(config.section('customer_relationships'),'holiday_visit_basis_points')),
        'cameraPresent':named=='npc_taeo' && !state.relationships.stories.contains('story_taeo_01'),
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
      if(followup!=null) state.customerScene=followup;
    }
  });

  Future<bool> sellToFirstCustomer() => command(() {
    if (gameplayPaused || !state.business.permitsProducts(now()) || state.customers.isEmpty) throw const FormatException('판매할 손님 없음');
    final order = state.customers.first;
    final selected = <Map<String, int>>[];
    final remaining = {for (final b in state.inventory.batches.values) b.id: b.quantity};
    for (final line in order.lines) {
      final selection = <String, int>{}; var needed = line.quantity;
      final eligible = state.inventory.batches.values.where((b) => b.flavor == line.flavor &&
        (line.variant == null ? b.variant >= 1 && b.variant <= 3 : b.variant == line.variant && (b.variant != 0 || line.special)) &&
        state.business.businessIndex - b.madeOnBusinessIndex < 5).toList()..sort((a,b) => a.madeOnBusinessIndex.compareTo(b.madeOnBusinessIndex));
      for (final batch in eligible) {
        if (needed == 0) break;
        final amount = min(needed, remaining[batch.id]!);
        if (amount > 0) { selection[batch.id] = amount; needed -= amount; remaining[batch.id] = remaining[batch.id]! - amount; }
      }
      if (needed != 0) throw const FormatException('주문 전량의 재고가 필요해요.');
      selected.add(selection);
    }
    final sales = CustomerSalesProgress(inventory: state.inventory, ordinaryBuns: state.buns,
      lifetimeSalesBuns: state.lifetime, sales: state.sales).sell(config, order, selectedByLine: selected,
      businessIndex: state.business.businessIndex, flavorDifficulties: {for (final f in state.recipes) f: difficulty(f)});
    state.inventory = sales.inventory; state.buns = sales.ordinaryBuns; state.lifetime = sales.lifetimeSalesBuns;
    state.sales..clear()..addAll(sales.sales);
    state.pendingGold['sale:${order.id}'] = sales.sales[order.id]!;
    if (customerCatalog.contains(order.customerId)) {
      state.relationships = state.relationships.successfulSale(order.id,order.id,state.business.businessIndex,config);
    }
    state.completedSales++; state.customers.removeAt(0);
    if(customerCatalog.contains(order.customerId)) _afterNamedSale(order);
  });
  Map<String,dynamic>? _matchingFollowup(CustomerOrder order) {
    final journal=state.relationships.toJson(),visits=journal['visits'] as Map;
    final context=((visits[order.id] as Map?)?['context'] as Map?) ?? {};
    for(final e in (journal['followups'] as Map).entries) {
      final npc=order.customerId;
      if(customerCatalog.choice(e.key as String)['npc_id']!=npc) continue;
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
  String? get lastSaleFeedback {
    if(state.sales.isEmpty) return null;
    final sale=state.sales.entries.last,evidence=validateStoredCustomerSale(sale.key,sale.value);
    final order=CustomerOrder.fromJson(evidence['order'] as Map<String,dynamic>);
    final speech=selectCustomerSpeech(customerCatalog,'success',_dialogueFacts(order));
    return '${customerName(order.customerId)} · 별 ${evidence['stars']} · ${speech?['text'] ?? '감사합니다. 잘 먹을게요.'}';
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
  void _afterNamedSale(CustomerOrder order) {
    final npc=order.customerId, facts=_choiceFacts(npc,order),journal=state.relationships.toJson();
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
    if(!state.relationships.stories.contains(story) && eligibleCustomerStory(npc,storyFacts,config)) {
      state.customerScene={'kind':'story','id':story,'npc':npc};return;
    }
    final followups=journal['followups'] as Map;
    for(final e in followups.entries) {
      if(customerCatalog.choice(e.key as String)['npc_id']==npc) {
        // Orders/outfits affected by an authored follow-up need generation-time
        // reservations. Do not narrate those before that reservation exists.
        final ctx=((visits[order.id] as Map)['context'] as Map?) ?? {};
        if(npc=='npc_makrye' && (e.value=='a' && ctx['ownPortion']!=true || e.value=='b' && ctx['onSite']!=true)) continue;
        if(npc=='npc_minjae' && ctx['running']!=false) continue;
        if(npc=='npc_eunchae' && ctx['working']!=true) continue;
        if(npc=='npc_taeo' && e.value=='c' && ctx['photoReminder']!=true) continue;
        state.customerScene={'kind':'followup','id':e.key,'npc':npc,'choice':e.value};return;
      }
    }
    final event='choice_${npc.substring(4)}_01';
    final candidateMatches=npc!='npc_yunha' || (order.lines.length==1 && order.lines.single.flavor=='redbean' &&
      order.lines.single.quantity==DevelopmentBalance.integer(config.section('customer_choice_conditions')[npc] as Map<String,dynamic>,'candidate_redbean_quantity'));
    if(!eligibleCustomerChoice(facts,config,candidateOrderMatches:candidateMatches)) return;
    state.relationships=state.relationships.rollChoice(state.business.businessIndex,[event],random.nextInt(10000),config,customerCatalog,anotherStoryToday:
      (journal['storyDays'] as Map).values.contains(state.business.businessIndex) || (journal['followupDays'] as Map).values.contains(state.business.businessIndex));
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
  bool get canLevelUp {
    if (state.level >= 50) return false;
    final rule = config.rows('level_progression')[state.level];
    return state.lifetime >= DevelopmentBalance.decimal(rule, 'season_total_buns') &&
      state.taps - state.levelStartTaps >= DevelopmentBalance.integer(rule, 'additional_taps') &&
      state.completedSales - state.levelStartSales >= DevelopmentBalance.integer(rule, 'additional_sales');
  }
  Future<bool> levelUp() => command(() {
    if (!canLevelUp) throw const FormatException('승급 조건을 확인해 주세요.');
    final next = state.level + 1, rule = config.rows('level_progression')[state.level];
    if (!state.claimedLevels.add(next)) throw const FormatException('중복 승급');
    state.level = next; state.levelStartTaps = state.taps; state.levelStartSales = state.completedSales;
    final buns = DevelopmentBalance.decimal(rule, 'buns_reward'); state.buns += buns; state.lifetime += buns;
    final gold = DevelopmentBalance.integer(rule, 'gold_reward');
    if (gold > 0) state.pendingGold['level:$next'] = jsonEncode({'level': next, 'gold': gold, 'revision': config.revision});
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
  bool ownsAvatar(String id) {
    final entry=config.section('avatar_catalog')[id];
    return entry is Map<String,dynamic> && (entry['free']==true || state.purchases.owned['cosmetic:$id']==1);
  }
  Future<bool> equipAvatar(String id) => command(() {
    final entry=config.section('avatar_catalog')[id];
    if (entry is! Map<String,dynamic> || !ownsAvatar(id)) throw const FormatException('보유한 아바타 아이템을 골라 주세요.');
    state.avatarEquipment[entry['slot'] as String]=id;
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
      if (state.rewardAccount != null && state.rewardAccount != account) throw const FormatException('원래 보상 계정으로 확인해 주세요.');
      if (account.isEmpty) throw const FormatException('로그인 후 구매할 수 있어요.');
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
      notice = '구매 확인이 남아 있어요. 새 거래 대신 같은 기록을 복구해 주세요: $e';
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
    } catch (e) { notice = '구매 복구 확인이 필요해요: $e'; return false;
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
      if(!previous.applied && current.applied && !current.quote.skillId.startsWith('cosmetic:')) {
        state.missions=state.missions.observe(now(),purchases:current.quote.quantity,autoPeak:autoRate);
      }
    });
  }
  @override
  void dispose() { disposed = true; _timer?.cancel(); _clock.stop(); super.dispose(); }
}
