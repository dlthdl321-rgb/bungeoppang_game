import 'dart:math' as math;
import 'dart:typed_data';

import 'generated/fish_cavity_mask.dart';

/// How much one piping step put in the mold, in permille of the fish cavity
/// (DEC-031·032): [coverage] = cells with at least one layer, [amount] = all
/// layers summed (so overpainting raises it past [coverage]).
class PaintAmount {
  final int coverage, amount;
  const PaintAmount(this.coverage, this.amount);

  /// The screen reader's '고르게 칠하기' (24번 5단계 G4): one even layer.
  static const even = PaintAmount(1000, 1000);

  /// A confirmed step: something painted, amount never below coverage and
  /// at most [MoldPaint.maxLayers] layers everywhere.
  bool get valid => coverage > 0 && coverage <= 1000 && amount >= coverage &&
      amount <= MoldPaint.maxLayers * 1000;
  @override
  bool operator ==(Object other) =>
      other is PaintAmount && other.coverage == coverage && other.amount == amount;
  @override
  int get hashCode => Object.hash(coverage, amount);
  @override
  String toString() => 'PaintAmount($coverage, $amount)';
}

/// The fish cavity of the special bungeoppang mold as a grid of cells
/// (lib/generated/fish_cavity_mask.dart, tools/fish_cavity_mask.py).
/// Coordinates are mold-picture pixels relative to fishRect's top-left.
class FishCavityMask {
  final int cols, rows, count;
  final double cell, width, height;
  final Uint8List cells;
  FishCavityMask._(this.cols, this.rows, this.cell, this.width, this.height, this.cells)
      : count = cells.where((c) => c == 1).length;

  factory FishCavityMask.fromRows(List<String> rows,
      {required double cell, required double width, required double height}) {
    if (rows.isEmpty || rows.any((r) => r.length != rows.first.length)) {
      throw const FormatException('마스크 형식 오류');
    }
    final cells = Uint8List(rows.length * rows.first.length);
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        cells[r * rows.first.length + c] = rows[r][c] == '#' ? 1 : 0;
      }
    }
    final mask = FishCavityMask._(rows.first.length, rows.length, cell, width, height, cells);
    if (mask.count == 0) throw const FormatException('빈 마스크');
    return mask;
  }

  static final standard = FishCavityMask.fromRows(fishCavityRows,
      cell: fishCavityCell, width: fishCavityWidth, height: fishCavityHeight);

  bool inFish(int index) => cells[index] == 1;
}

/// One continuous brush stroke over the mold (24번 5단계). Pure: the screen
/// feeds points in mask coordinates and reads [amount] / [layers].
///
/// A cell gains one layer each time the brush (radius = [brushWidthPermille]
/// of the fish width / 2) newly reaches its centre. While the brush stays on
/// it nothing more is counted; it only counts as left once the brush centre
/// is farther than radius + one cell (G7), so a shaking finger does not
/// overpaint. Cells outside the fish never count.
class MoldPaint {
  static const maxLayers = 9;
  final FishCavityMask mask;
  final double radius, leave;
  final Uint8List layers;
  final Uint8List _inside;
  final List<int> _insideList = [];
  double? _x, _y;
  int _covered = 0, _total = 0, _version = 0;

  MoldPaint(this.mask, {required int brushWidthPermille})
      : radius = mask.width * brushWidthPermille / 2000,
        leave = mask.width * brushWidthPermille / 2000 + mask.cell,
        layers = Uint8List(mask.cols * mask.rows),
        _inside = Uint8List(mask.cols * mask.rows) {
    if (brushWidthPermille <= 0 || brushWidthPermille > 1000) {
      throw const FormatException('붓 굵기 오류');
    }
  }

  /// Bumped whenever a layer is added (for repainting).
  int get version => _version;
  bool get painted => _covered > 0;
  PaintAmount get amount => PaintAmount(
      _covered * 1000 ~/ mask.count, _total * 1000 ~/ mask.count);

  /// The brush moves to ([x], [y]). Between the last point and this one it is
  /// stamped every half cell, so a fast swipe leaves no gaps.
  void moveTo(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    final lx = _x, ly = _y;
    if (lx == null || ly == null) {
      _stamp(x, y);
    } else {
      final d = math.sqrt((x - lx) * (x - lx) + (y - ly) * (y - ly));
      final steps = math.max(1, (d / (mask.cell / 2)).ceil());
      for (var i = 1; i <= steps; i++) {
        _stamp(lx + (x - lx) * i / steps, ly + (y - ly) * i / steps);
      }
    }
    _x = x;
    _y = y;
  }

  void _stamp(double x, double y) {
    final cell = mask.cell;
    // Leave cells first (farther than radius + one cell).
    _insideList.removeWhere((i) {
      final cx = (i % mask.cols + .5) * cell, cy = (i ~/ mask.cols + .5) * cell;
      if ((cx - x) * (cx - x) + (cy - y) * (cy - y) <= leave * leave) return false;
      _inside[i] = 0;
      return true;
    });
    final c0 = math.max(0, ((x - radius) / cell).floor());
    final c1 = math.min(mask.cols - 1, ((x + radius) / cell).floor());
    final r0 = math.max(0, ((y - radius) / cell).floor());
    final r1 = math.min(mask.rows - 1, ((y + radius) / cell).floor());
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final i = r * mask.cols + c;
        if (_inside[i] == 1) continue;
        final cx = (c + .5) * cell, cy = (r + .5) * cell;
        if ((cx - x) * (cx - x) + (cy - y) * (cy - y) > radius * radius) continue;
        _inside[i] = 1;
        _insideList.add(i);
        if (!mask.inFish(i) || layers[i] >= maxLayers) continue;
        if (layers[i] == 0) _covered++;
        layers[i]++;
        _total++;
        _version++;
      }
    }
  }
}
