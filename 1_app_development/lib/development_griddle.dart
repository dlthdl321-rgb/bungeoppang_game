import 'development_balance.dart';
import 'development_inventory.dart';
import 'development_rules.dart';

class GriddleCell {
  final int cycle, elapsedMs, idleMs;
  final String? flavor;
  final int? difficulty;
  GriddleCell._(this.cycle, this.elapsedMs, this.idleMs, this.flavor, this.difficulty);
  bool get cooking => flavor != null;
}
class GriddleHarvest {
  final GriddleProgress state;
  final ProductBatch? product;
  final String resultId;
  GriddleHarvest(this.state, this.product, this.resultId);
}

/// Only explicitly admitted active cooking time is supplied here. Never pass offline time
/// to this method; this module cannot automatically harvest or create inventory.
class GriddleProgress {
  final String runId;
  final List<GriddleCell> cells;
  GriddleProgress._(this.runId, List<GriddleCell> cells) : cells = List.unmodifiable(cells);
  factory GriddleProgress.empty(String runId, DevelopmentBalance config) {
    if (runId.isEmpty) throw const FormatException('6구 실행 식별자 누락');
    final count = DevelopmentBalance.integer(config.section('fixed_requirements'), 'griddle_slots');
    final delay = DevelopmentBalance.integer(config.section('griddle'), 'reinsertion_delay_ms');
    return GriddleProgress._(runId, List.generate(count, (_) => GriddleCell._(0, 0, delay, null, null)));
  }
  GriddleProgress _replace(int index, GriddleCell cell) {
    if (index < 0 || index >= cells.length) throw const FormatException('6구 칸 오류');
    final next = cells.toList(); next[index] = cell; return GriddleProgress._(runId, next);
  }
  GriddleProgress start(int index, DevelopmentBalance config, {
      required Map<String, int> ownedAndMastered, required String Function(List<String>) choose}) {
    if (index < 0 || index >= cells.length) throw const FormatException('6구 칸 오류');
    final cell = cells[index], candidates = ownedAndMastered.keys.toList()..sort();
    if (cell.cooking || candidates.isEmpty || cell.idleMs < DevelopmentBalance.integer(
        config.section('griddle'), 'reinsertion_delay_ms')) throw const FormatException('6구 투입 불가');
    final flavor = choose(List.unmodifiable(candidates));
    if (!ownedAndMastered.containsKey(flavor)) throw const FormatException('잠긴 맛 배정');
    final difficulty = ownedAndMastered[flavor]!;
    config.mastery(difficulty); // Validates the recipe's difficulty before assignment.
    return _replace(index, GriddleCell._(cell.cycle + 1, 0, 0, flavor, difficulty));
  }
  GriddleProgress advanceActive(int elapsedMs) {
    if (elapsedMs < 0) throw const FormatException('음수 6구 경과');
    return GriddleProgress._(runId, [for (final c in cells) GriddleCell._(c.cycle,
      c.elapsedMs + (c.cooking ? elapsedMs : 0), c.idleMs + (c.cooking ? 0 : elapsedMs), c.flavor, c.difficulty)]);
  }
  int doneness(int index, DevelopmentBalance config) {
    if (index < 0 || index >= cells.length || !cells[index].cooking) throw const FormatException('굽는 칸 없음');
    final speed = config.integers('griddle', 'slot_speed_permille')[index];
    return provisionalDoneness(config, elapsedMs: cells[index].elapsedMs, speedPermille: speed,
        difficulty: cells[index].difficulty!);
  }
  GriddleHarvest harvest(int index, DevelopmentBalance config, {required int businessIndex, int? expectedCycle}) {
    if (index < 0 || index >= cells.length ||
        (expectedCycle != null && cells[index].cycle != expectedCycle)) {
      throw const FormatException('지난 6구 수확 입력');
    }
    if (businessIndex < 0) throw const FormatException('제작 영업일 오류');
    final variant = doneness(index, config), cell = cells[index];
    final id = 'griddle:$runId:$index:${cell.cycle}';
    final product = variant == 4 ? null : ProductBatch(id: id, flavor: cell.flavor!,
        variant: variant, quantity: DevelopmentBalance.integer(config.section('griddle'), 'products_per_harvest'),
        madeOnBusinessIndex: businessIndex);
    return GriddleHarvest(_replace(index, GriddleCell._(cell.cycle, 0, 0, null, null)), product, id);
  }
  /// Apply one previously frozen harvest after a failed save without replacing
  /// the other five cells or re-evaluating its doneness/business day.
  GriddleProgress applyHarvest(int index, GriddleHarvest harvest) {
    if (index < 0 || index >= cells.length || !cells[index].cooking ||
        harvest.resultId != 'griddle:$runId:$index:${cells[index].cycle}') {
      throw const FormatException('지난 6구 확정 결과');
    }
    return _replace(index, GriddleCell._(cells[index].cycle, 0, 0, null, null));
  }
  Set<String> get cookingSourceIds => {for (var i = 0; i < cells.length; i++)
      if (cells[i].cooking) 'griddle:$runId:$i:${cells[i].cycle}'};
  Map<String, dynamic> toJson() => {'schema': 1, 'runId': runId, 'cells': [for (final c in cells) {
    'cycle': c.cycle, 'elapsedMs': c.elapsedMs, 'idleMs': c.idleMs,
    'flavor': c.flavor, 'difficulty': c.difficulty,
  }]};
  factory GriddleProgress.fromJson(Map<String, dynamic> row, DevelopmentBalance config) {
    final raw = row['cells'];
    if (row['schema'] is! int || row['schema'] != 1 || row['runId'] is! String ||
        (row['runId'] as String).isEmpty || raw is! List || raw.length != 6) {
      throw const FormatException('6구 저장 형식 오류');
    }
    final cells = <GriddleCell>[];
    for (final value in raw) {
      if (value is! Map<String, dynamic>) throw const FormatException('6구 칸 저장 오류');
      final flavor = value['flavor'], difficulty = value['difficulty'];
      final cycle = DevelopmentBalance.integer(value, 'cycle');
      final elapsed = DevelopmentBalance.integer(value, 'elapsedMs');
      final idle = DevelopmentBalance.integer(value, 'idleMs');
      if (flavor == null) {
        if (difficulty != null || elapsed != 0) throw const FormatException('빈 칸 상태 오류');
      } else {
        if (flavor is! String || flavor.isEmpty || cycle == 0 || idle != 0 || difficulty is! int) {
          throw const FormatException('굽는 칸 상태 오류');
        }
        config.mastery(difficulty);
      }
      cells.add(GriddleCell._(cycle, elapsed, idle, flavor as String?, difficulty as int?));
    }
    return GriddleProgress._(row['runId'] as String, cells);
  }
}
