import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_griddle.dart';
import 'package:todays_bungeoppang/development_rules.dart';

void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync())
          as Map<String, dynamic>));
  CookingSession start([String id = 'session']) => CookingSession.start(
      id: id,
      flavor: 'redbean',
      practice: true,
      fillingSequence: [CookingDirection.left, CookingDirection.right]);
  test(
      'all doneness boundaries use first integer millisecond in next stage for every slot',
      () {
    final target =
        DevelopmentBalance.integer(config.mastery(0), 'doneness_target_ms');
    final scale = DevelopmentBalance.integer(
        config.section('doneness'), 'reference_scale');
    final boundaries = config.integers('doneness', 'boundary_permille');
    for (final speed in [
      1000,
      ...config.integers('griddle', 'slot_speed_permille')
    ]) {
      for (var i = 0; i < boundaries.length; i++) {
        final denominator = scale * speed;
        final boundary =
            (target * boundaries[i] * 1000 + denominator - 1) ~/ denominator;
        expect(
            provisionalDoneness(config,
                elapsedMs: boundary - 1, difficulty: 0, speedPermille: speed),
            i);
        expect(
            provisionalDoneness(config,
                elapsedMs: boundary, difficulty: 0, speedPermille: speed),
            i + 1);
      }
    }
  });
  test(
      'six cells retain independent start times and stale cycle cannot harvest a new product',
      () {
    var grid = GriddleProgress.empty('run', config);
    GriddleProgress put(GriddleProgress g, int index) => g.start(index, config,
        ownedAndMastered: {'redbean': 0}, choose: (ids) => ids.single);
    grid = put(grid, 0).advanceActive(4000);
    grid = put(grid, 1).advanceActive(2000);
    expect(grid.cells[0].elapsedMs, 6000);
    expect(grid.cells[1].elapsedMs, 2000);
    expect(grid.cells[2].cooking, isFalse);
    final first = grid.harvest(0, config, businessIndex: 1, expectedCycle: 1);
    expect(
        first.product, isNotNull); // approved: undercooked harvest is allowed
    expect(first.state.cells[1].elapsedMs, 2000);
    expect(
        () =>
            first.state.harvest(0, config, businessIndex: 1, expectedCycle: 1),
        throwsFormatException);
    grid = put(first.state.advanceActive(10000), 0);
    expect(() => grid.harvest(0, config, businessIndex: 1, expectedCycle: 1),
        throwsFormatException);
    final burned = grid
        .advanceActive(100000)
        .harvest(0, config, businessIndex: 1, expectedCycle: 2);
    expect(burned.product, isNull);
    expect(burned.resultId, 'griddle:run:0:2');
  });
  test('result stays fixed and order production does not count as practice',
      () {
    var session = start();
    final rule = config.mastery(0);
    session = session.pour(session.token, const PaintAmount(930, 1250));
    for (final direction in session.fillingSequence) {
      session = session.fill(session.token, direction);
    }
    session = session.pour(session.token, const PaintAmount(900, 1300));
    session = session.close(session.token);
    session = session.flip(session.token);
    session = session.takeOut(
        session.token, DevelopmentBalance.integer(rule, 'doneness_target_ms'));
    final result = evaluateCookingResult(config, session, difficulty: 0);
    expect(result.techniquePassed, isTrue);
    expect(session.takeOut(session.token, 999999), same(session));
    final order =
        CookingSession.fromJson({...session.toJson(), 'practice': false});
    final progress = FlavorMasteryProgress(flavor: 'redbean', difficulty: 0)
        .record(evaluateCookingResult(config, order, difficulty: 0));
    expect(progress.practices, 0);
    expect(progress.techniquePasses, 0);
    expect(progress.discovered, contains(result.variant));
  });
}
