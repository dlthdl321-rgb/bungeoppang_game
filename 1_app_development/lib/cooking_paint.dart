import 'dart:math' as math;
import 'dart:typed_data';

import 'generated/fish_cavity_mask.dart';

/// How much one piping step put in the mold, in permille of the fish cavity
/// (DEC-031·032): [coverage] = cells with at least one layer, [amount] = all
/// layers summed (so overpainting raises it past [coverage]). [spill] is the
/// paste squeezed out past the fish (4차 피드백 IC4: rubbing on the mold's
/// rim or outside it still pours, but that paste is spilled), in permille of
/// the fish area; it is judged with the batter amount (cooking_result_rules).
class PaintAmount {
  final int coverage, amount, spill;
  const PaintAmount(this.coverage, this.amount, [this.spill = 0]);

  /// The screen reader's '고르게 칠하기' (24번 5단계 G4): one even layer.
  static const even = PaintAmount(1000, 1000);

  /// A confirmed step: something painted, amount never below coverage and
  /// at most [MoldPaint.maxLayers] layers everywhere.
  bool get valid => coverage > 0 && coverage <= 1000 && amount >= coverage &&
      amount <= MoldPaint.maxLayers * 1000 && spill >= 0 && spill <= MoldPaint.maxSpill;

  /// The paste that went in: inside the fish plus the spilled part.
  int get poured => amount + spill;
  @override
  bool operator ==(Object other) => other is PaintAmount && other.coverage == coverage &&
      other.amount == amount && other.spill == spill;
  @override
  int get hashCode => Object.hash(coverage, amount, spill);
  @override
  String toString() => 'PaintAmount($coverage, $amount, $spill)';
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
/// overpaint. Cells outside the fish never count as layers; the part of
/// the brush that sweeps past the fish (on the mold's rim or off the mold)
/// is [spill]: swept area outside the fish, in permille of the fish area
/// (4차 피드백 IC4), and its points are kept in [spillPoints] for drawing.
class MoldPaint {
  static const maxLayers = 9;
  static const maxSpill = 9000;

  /// Spilled points kept for drawing (mask coordinates), at most this many.
  static const maxSpillPoints = 600;
  final FishCavityMask mask;
  final double radius, leave;
  final Uint8List layers;
  final Uint8List _inside;
  final List<int> _insideList = [];
  final List<(double, double)> spillPoints = [];
  double? _x, _y;
  int _covered = 0, _total = 0, _version = 0;
  double _spillArea = 0;

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
      _covered * 1000 ~/ mask.count, _total * 1000 ~/ mask.count,
      math.min(maxSpill, (_spillArea * 1000 / (mask.count * mask.cell * mask.cell)).floor()));

  /// How much of the brush at ([x], [y]) lies outside the fish (0..1),
  /// sampled on a 3x3 grid across it.
  double outsideShare(double x, double y) {
    var out = 0;
    for (final dy in const [-.6, 0.0, .6]) {
      for (final dx in const [-.6, 0.0, .6]) {
        if (!_fishAt(x + dx * radius, y + dy * radius)) out++;
      }
    }
    return out / 9;
  }

  bool _fishAt(double x, double y) {
    final c = (x / mask.cell).floor(), r = (y / mask.cell).floor();
    return c >= 0 && r >= 0 && c < mask.cols && r < mask.rows && mask.inFish(r * mask.cols + c);
  }

  /// The brush moves to ([x], [y]). Between the last point and this one it is
  /// stamped every half cell, so a fast swipe leaves no gaps.
  void moveTo(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    final lx = _x, ly = _y;
    if (lx == null || ly == null) {
      _stamp(x, y, 0);
    } else {
      final d = math.sqrt((x - lx) * (x - lx) + (y - ly) * (y - ly));
      final steps = math.max(1, (d / (mask.cell / 2)).ceil());
      for (var i = 1; i <= steps; i++) {
        _stamp(lx + (x - lx) * i / steps, ly + (y - ly) * i / steps, d / steps);
      }
    }
    _x = x;
    _y = y;
  }

  /// [step] is how far the brush moved to get here (its swept length).
  void _stamp(double x, double y, double step) {
    final cell = mask.cell;
    // Paste lands in the fish while the nozzle (brush centre) is over it;
    // past the fish's edge the brush's outside part is spilled.
    final out = _fishAt(x, y) ? 0.0 : outsideShare(x, y);
    if (out > 0) {
      _spillArea += step * 2 * radius * out;
      if (out >= .5 && spillPoints.length < maxSpillPoints &&
          (spillPoints.isEmpty || _far(spillPoints.last, x, y))) {
        spillPoints.add((x, y));
        _version++;
      }
    }
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

  bool _far((double, double) p, double x, double y) =>
      (p.$1 - x) * (p.$1 - x) + (p.$2 - y) * (p.$2 - y) >= mask.cell * mask.cell;
}
