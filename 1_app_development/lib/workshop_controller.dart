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

/// Fresh-game local production aggregate. Gold remains in the authenticated
/// server wallet; pending claims here are never spendable gold.
class WorkshopState {
  int sequence = 0, level = 1, taps = 0, completedSales = 0, phaseMs = 0,
      levelStartTaps = 0, levelStartSales = 0, arrivalMs = 0;
  String selectedFlavor = 'redbean';
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
  late BusinessProgress business;
  InventoryProgress inventory = InventoryProgress.empty();
  late GriddleProgress grid;
  final Map<String, FlavorMasteryProgress> flavorMasteries = {
    'redbean': FlavorMasteryProgress(flavor: 'redbean', difficulty: 0)};
  FlavorMasteryProgress get mastery => flavorMasteries[selectedFlavor]!;
  set mastery(FlavorMasteryProgress value) { flavorMasteries[value.flavor] = value; }
  CookingSession? session;
  List<CustomerOrder> customers = [];
  final Map<String, String> sales = {}, pendingGold = {};
  final Set<int> claimedLevels = {};
  WorkshopState.initial(DateTime now, DevelopmentBalance config, String runId) {
    business = BusinessProgress.initial(now); grid = GriddleProgress.empty(runId, config);
    flavorMasteries['redbean'] = FlavorMasteryProgress(flavor: 'redbean',
      difficulty: DevelopmentBalance.integer(config.section('active_recipes')['redbean'] as Map<String, dynamic>, 'difficulty'));
  }
  Map<String, dynamic> toJson() => {'schema': 1, 'sequence': sequence, 'level': level,
    'taps': taps, 'completedSales': completedSales, 'phaseMs': phaseMs,
    'levelStartTaps': levelStartTaps, 'levelStartSales': levelStartSales, 'arrivalMs': arrivalMs,
    'selectedFlavor': selectedFlavor, 'recipes': recipes.toList()..sort(),
    'recipeMissions': recipeMissions.toList()..sort(),
    'masteryAwards': {for (final e in masteryAwards.entries) e.key: Map<String, dynamic>.from(e.value)},
    'tasteObservations': {for (final e in tasteObservations.entries) e.key:
      {for (final f in e.value.entries) f.key: f.value.toList()..sort()}},
    'buns': buns.toString(), 'lifetime': lifetime.toString(), 'business': business.toJson(),
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
    if (row['schema'] is! int || row['schema'] != 1) throw const FormatException('신규 게임 저장 버전 오류');
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
    for (final key in ['sales', 'pendingGold']) {
      final target = key == 'sales' ? state.sales : state.pendingGold;
      for (final e in object(key).entries) {
        if (e.key.isEmpty || e.value is! String || jsonDecode(e.value as String) is! Map) {
          throw const FormatException('판매/심사 원장 오류');
        }
        target[e.key] = e.value as String;
      }
    }
    for (final n in row['claimedLevels'] as List) {
      if (n is! int || n < 2 || n > state.level || !state.claimedLevels.add(n)) throw const FormatException('승급 수령 기록 오류');
    }
    if (state.sales.length != state.completedSales || state.claimedLevels.length != state.level - 1) {
      throw const FormatException('판매/승급 원장 불일치');
    }
    return state;
  }
}

abstract class WorkshopRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> next, int expectedSequence);
}
class SqliteWorkshopRepository implements WorkshopRepository {
  Database? _database;
  Future<Database> get database async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'todays_bungeoppang_workshop.db'), version: 1,
    onCreate: (db, _) => db.execute('CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)'));
  @override
  Future<Map<String, dynamic>?> load() async {
    final rows = await (await database).query('snapshots', where: 'slot = ?', whereArgs: ['current']);
    return rows.isEmpty ? null : jsonDecode(rows.single['body'] as String) as Map<String, dynamic>;
  }
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    await (await database).transaction((tx) async {
      final current = await tx.query('snapshots', where: 'slot = ?', whereArgs: ['current']);
      final oldSequence = current.isEmpty ? 0 : current.single['sequence'];
      if (oldSequence != expectedSequence || next['sequence'] != expectedSequence + 1) {
        throw const FormatException('진행 저장 순번 충돌');
      }
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
  late WorkshopState state;
  bool busy = false, foreground = true, disposed = false;
  bool _gridVisible = true;
  bool get gridVisible => _gridVisible;
  set gridVisible(bool value) { _gridVisible = value; if (!disposed) notifyListeners(); }
  String? error, notice;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _lastMono = 0, _checkpoint = 0;
  WorkshopController(this.config, this.repository, {DateTime Function()? now, Random? random})
      : now = now ?? (() => DateTime.now().toUtc()), random = random ?? Random.secure();
  String _id() => List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join();
  Future<void> initialize() async {
    final saved = await repository.load();
    state = saved == null ? WorkshopState.initial(now(), config, _id()) : WorkshopState.fromJson(saved, config);
    // New skills are unavailable until the composite purchase server is wired;
    // never use the old prototype's local-only purchases or coin wallet here.
    final settlement = state.business.settle(config, now(), bunsPerSecond: BigInt.zero, offline: true);
    state.business = settlement.state;
    state.buns += settlement.buns; state.lifetime += settlement.buns;
    error = null;
    if (!await command(() {})) throw StateError('신규 진행 저장 실패');
    _clock.start(); _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }
  Future<bool> command(void Function() mutate) async {
    if (busy || disposed || error != null) return false;
    _flushActive();
    busy = true;
    final before = state.toJson();
    try {
      try { mutate(); } on FormatException catch (e) {
        state = WorkshopState.fromJson(before, config); notice = e.message; return false;
      }
      notice = null;
      state.sequence++;
      await repository.save(state.toJson(), before['sequence'] as int);
      return true;
    } catch (e) {
      state = WorkshopState.fromJson(before, config);
      error = '저장 또는 명령 확인이 필요해요: $e';
      return false;
    } finally { busy = false; if (!disposed) notifyListeners(); }
  }
  Future<void> reloadAfterError() async {
    if (busy || disposed) return;
    final saved = await repository.load();
    if (saved == null) throw const FormatException('복구할 저장 기록 없음');
    state = WorkshopState.fromJson(saved, config); error = null;
    _lastMono = _clock.elapsedMilliseconds; notifyListeners();
  }
  void _advanceMemory(int ms) {
    if (ms <= 0) return;
    if (state.session != null && !state.session!.finished) state.phaseMs += ms;
    if (state.business.permitsProducts(now())) {
      state.customers = state.customers.map((c) => c.advanceActive(ms)).where((c) => c.remainingMs > 0).toList();
      if (state.session == null && gridVisible) state.grid = state.grid.advanceActive(ms);
      state.arrivalMs += ms;
    }
    _checkpoint += ms;
  }
  void _flushActive() {
    final at = _clock.elapsedMilliseconds;
    if (foreground && !busy && error == null) _advanceMemory(at - _lastMono);
    _lastMono = at;
  }
  void _tick() {
    if (busy) return;
    _flushActive();
    if (!foreground || error != null || disposed) return;
    final row = config.rows('level_progression')[state.level - 1];
    if (state.business.permitsProducts(now()) &&
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
    if (!value && foreground && !busy) _flushActive();
    foreground = value; _lastMono = _clock.elapsedMilliseconds;
    if (!value) { await command(() {}); }
    else {
      await command(() {
        final settlement = state.business.settle(config, now(), bunsPerSecond: BigInt.zero, offline: true);
        state.business = settlement.state;
        state.buns += settlement.buns; state.lifetime += settlement.buns;
      });
    }
  }
  Future<bool> openBusiness() => command(() {
    state.business = state.business.settle(config, now(), bunsPerSecond: BigInt.zero, offline: false).state;
    state.business = state.business.beginOrContinue(state.business.settledUtc);
    state.inventory = state.inventory.expire(config, state.business.businessIndex).acceptPrepared(state.business.businessIndex);
  });
  Future<bool> closeBusiness() => command(() {
    final settled = state.business.settle(config, now(), bunsPerSecond: BigInt.zero, offline: false).state;
    state.business = settled.close(settled.settledUtc);
    state.customers.clear(); state.arrivalMs = 0;
    if (state.session?.finished != true) { state.session = null; state.phaseMs = 0; }
  });
  void tap() {
    if (busy || !foreground || disposed || error != null) return;
    _flushActive();
    state.buns += BigInt.one; state.lifetime += BigInt.one; state.taps++;
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
  Future<bool> startPractice() => command(() {
    if (state.session != null || (state.business.open && state.business.needsContinuation(now()))) throw const FormatException('이전 결과/영업일을 먼저 확인해 주세요.');
    final count = DevelopmentBalance.integer(config.section('manual_cooking'), 'filling_inputs');
    state.session = CookingSession.start(id: _id(), flavor: state.selectedFlavor, practice: true,
      fillingSequence: List.generate(count, (i) => i.isEven ? CookingDirection.left : CookingDirection.right));
    state.phaseMs = 0;
  });
  Future<bool> cookingCommand(CookingSession next) => command(() {
    final previous = state.session;
    if (previous == null || next.id != previous.id || next.token != previous.token + 1) throw const FormatException('지난 제작 입력');
    final manual = config.section('manual_cooking');
    if (previous.phase == CookingPhase.closing && next.phase == CookingPhase.flipping &&
        state.phaseMs < DevelopmentBalance.integer(manual, 'lid_close_ms')) throw const FormatException('뚜껑이 닫히는 중이에요.');
    if (previous.phase == CookingPhase.flipping && next.phase == CookingPhase.cooking &&
        state.phaseMs < DevelopmentBalance.integer(manual, 'flip_ms')) throw const FormatException('뒤집는 중이에요.');
    if (next.phase == CookingPhase.result) next = previous.takeOut(previous.token, state.phaseMs);
    state.session = next; state.phaseMs = 0;
    if (next.phase == CookingPhase.result) {
      state.mastery = state.mastery.record(evaluateCookingResult(config, next, difficulty: difficulty(next.flavor)));
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
    final result = evaluateCookingResult(config, session, difficulty: difficulty(session.flavor));
    final active = state.business.permitsProducts(now());
    final batch = ProductBatch(id: session.id, flavor: session.flavor, variant: result.variant,
      quantity: DevelopmentBalance.integer(config.section('manual_cooking'), 'products_per_completed_result'),
      madeOnBusinessIndex: active ? state.business.businessIndex : 0);
    state.inventory = active ? state.inventory.recordResult(batch, keep: keep) : state.inventory.recordPreparedResult(batch, keep: keep);
    state.session = null;
  });
  Future<bool> startCell(int index) => command(() {
    if (!state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업/큰 틀 상태 확인');
    state.grid = state.grid.start(index, config, ownedAndMastered: {for (final f in state.recipes) if (state.masteryAwards.containsKey(f)) f: difficulty(f)}, choose: (values) => values[random.nextInt(values.length)]);
  });
  Future<bool> harvestCell(int index) => command(() {
    if (!state.business.permitsProducts(now()) || state.session != null) throw const FormatException('영업/큰 틀 상태 확인');
    final result = state.grid.harvest(index, config, businessIndex: state.business.businessIndex);
    state.grid = result.state;
    if (result.product != null) state.inventory = state.inventory.recordResult(result.product!, keep: true);
  });
  Future<bool> welcomeCustomer() => command(() {
    if (!state.business.permitsProducts(now())) throw const FormatException('영업을 시작해 주세요.');
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
    final customerId = 'customer_${random.nextInt(DevelopmentBalance.integer(sale, 'customer_archetype_count')) + 1}';
    final lines = [for (var i = 0; i < kinds; i++) CustomerOrderLine(flavor: choices[i], variant: variant,
      special: special, quantity: quantities[i])];
    state.customers.add(CustomerOrder(id: _id(), customerId: customerId,
      remainingMs: DevelopmentBalance.integer(rule, 'order_wait_ms'), lines: lines));
    final observed = state.tasteObservations.putIfAbsent(customerId, () => {});
    for (final line in lines) {
      final variants = observed.putIfAbsent(line.flavor, () => <int>{});
      if (line.variant != null) variants.add(line.variant!);
    }
  });
  Future<bool> sellToFirstCustomer() => command(() {
    if (!state.business.permitsProducts(now()) || state.customers.isEmpty) throw const FormatException('판매할 손님 없음');
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
    state.completedSales++; state.customers.removeAt(0);
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
  @override
  void dispose() { disposed = true; _timer?.cancel(); _clock.stop(); super.dispose(); }
}
