import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

class MemoryRepository implements WorkshopRepository {
  Map<String, dynamic>? saved;
  bool fail = false;
  Completer<void>? pauseSave;
  @override
  Future<Map<String, dynamic>?> load() async => saved == null
      ? null
      : jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> value, int expectedSequence) async {
    final gate = pauseSave;
    if (gate != null) await gate.future;
    if (fail) {
      fail = false;
      throw StateError('injected save failure');
    }
    saved = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

void main() {
  late WorkshopController controller;
  late MemoryRepository repository;
  late DevelopmentBalance config;
  setUp(() async {
    config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync())
            as Map<String, dynamic>);
    repository = MemoryRepository();
    controller = WorkshopController(config, repository,
        now: () => DateTime.utc(2026, 10, 18), random: Random(2));
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  CookingSession cooking() {
    var session = CookingSession.start(
        id: 'fixed-result',
        flavor: 'redbean',
        practice: true,
        fillingSequence: [CookingDirection.left]);
    session = session.pour(session.token, 2500);
    session = session.fill(session.token, CookingDirection.left);
    session = session.pour(session.token, 2500);
    session = session.close(session.token);
    return session.flip(session.token);
  }

  test('pause restores manual phase without away cooking time', () async {
    final session = cooking();
    await controller.command(() {
      controller.state.session = session;
      controller.state.phaseMs = 12000;
    });
    await controller.setForeground(false);
    final elapsed = controller.state.phaseMs;
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(controller.state.phaseMs, elapsed);
    expect(await controller.cookingCommand(session.takeOut(session.token, 0)),
        isFalse);
    await controller.setForeground(true);
    expect(controller.state.phaseMs, elapsed);
    expect(controller.state.session!.phase, CookingPhase.cooking);
  });
  test(
      'failed result retry keeps original doneness and duplicate takeout adds no practice',
      () async {
    final session = cooking();
    await controller.command(() {
      controller.state.session = session;
      controller.state.phaseMs = 15000;
    });
    repository.fail = true;
    expect(await controller.cookingCommand(session.takeOut(session.token, 0)),
        isFalse);
    expect(controller.state.mastery.practices, 0);
    await controller.reloadAfterError();
    await controller.command(() => controller.state.phaseMs = 100000);
    expect(await controller.cookingCommand(session.takeOut(session.token, 0)),
        isTrue);
    final fixed = controller.state.session!;
    expect(fixed.donenessElapsedMs!, lessThan(16000));
    expect(controller.state.mastery.practices, 1);
    expect(await controller.cookingCommand(fixed), isFalse);
    expect(controller.state.mastery.practices, 1);
    expect(await controller.storeResult(false), isTrue);
    expect(await controller.storeResult(false), isFalse);
  });
  test(
      'owned unmastered recipe enters order production and ignores vanished orders',
      () async {
    await controller.openBusiness();
    await controller.command(() => controller.state.customers.add(CustomerOrder(
        id: 'order',
        remainingMs: 100000,
        lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
    expect(
        await controller.startOrderProduction('missing', 'redbean'), isFalse);
    expect(await controller.startOrderProduction('order', 'redbean'), isTrue);
    expect(controller.state.session!.practice, isFalse);
    expect(controller.state.mastered, isFalse);
  });
  test(
      'harvest retry retains quality, leaves other cells intact, and cannot harvest twice',
      () async {
    await controller.openBusiness();
    final rule = config.mastery(0);
    final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
    await controller.command(() {
      var mastery = controller.state.mastery;
      for (var i = 0; i < count; i++) {
        mastery = mastery.record(MasteryResult(
            id: 'practice-$i',
            flavor: 'redbean',
            variant: i < 5 ? i : 2,
            completed: true,
            practice: true,
            techniquePassed: i >= 5));
      }
      controller.state.mastery = mastery;
      controller.state.masteryAward = {
        'revision': config.revision,
        'resultId': 'practice-0',
        'practiceRequired':
            DevelopmentBalance.integer(rule, 'practice_required'),
        'techniqueRequired':
            DevelopmentBalance.integer(rule, 'technique_passes_required')
      };
    });
    expect(await controller.startCell(0), isTrue);
    expect(await controller.startCell(1), isTrue);
    await controller.setForeground(false);
    final pausedCells =
        controller.state.grid.cells.map((cell) => cell.elapsedMs).toList();
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(controller.state.grid.cells.map((cell) => cell.elapsedMs).toList(),
        pausedCells);
    await controller.setForeground(true);
    expect(controller.state.grid.cells.map((cell) => cell.elapsedMs).toList(),
        pausedCells);

    await controller.command(() =>
        controller.state.grid = controller.state.grid.advanceActive(10000));
    repository.fail = true;
    expect(await controller.harvestCell(0, expectedCycle: 1), isFalse);
    final originalVariant = controller.state.grid.doneness(0, config);
    expect(controller.state.inventory.batches, isEmpty);
    await controller.reloadAfterError();
    await controller.command(() =>
        controller.state.grid = controller.state.grid.advanceActive(100000));
    final otherElapsed = controller.state.grid.cells[1].elapsedMs;
    expect(await controller.harvestCell(0, expectedCycle: 1), isTrue);
    expect(controller.state.inventory.batches.values.single.variant,
        originalVariant);
    expect(controller.state.grid.cells[1].elapsedMs,
        greaterThanOrEqualTo(otherElapsed));
    expect(await controller.harvestCell(0, expectedCycle: 1), isFalse);
    expect(controller.state.inventory.batches.length, 1);
  });
  test(
      'lid and flip honor configured delay and reject stale or skipped commands',
      () async {
    var session = cooking();
    // Rebuild the earlier phase through the public state machine.
    session = CookingSession.start(
        id: 'steps',
        flavor: 'redbean',
        practice: true,
        fillingSequence: [CookingDirection.left]);
    session = session.pour(session.token, 2500);
    session = session.fill(session.token, CookingDirection.left);
    session = session.pour(session.token, 2500);
    await controller.command(() {
      controller.state.session = session;
      controller.state.phaseMs = 0;
    });
    expect(
        await controller.cookingCommand(session.close(session.token)), isFalse);
    final closeDelay = DevelopmentBalance.integer(
        config.section('manual_cooking'), 'lid_close_ms');
    await controller.command(() => controller.state.phaseMs = closeDelay);
    expect(
        await controller.cookingCommand(session.close(session.token)), isTrue);
    session = controller.state.session!;
    expect(
        await controller.cookingCommand(session.flip(session.token)), isFalse);
    final flipDelay =
        DevelopmentBalance.integer(config.section('manual_cooking'), 'flip_ms');
    await controller.command(() => controller.state.phaseMs = flipDelay);
    expect(
        await controller.cookingCommand(session.flip(session.token)), isTrue);
    expect(
        await controller.cookingCommand(session.flip(session.token)), isFalse);
  });
  test(
      'periodic checkpoint keeps the hold owned and queues its release without losing duration',
      () async {
    await controller.startPractice();
    final session = controller.state.session!;
    final gate = Completer<void>();
    repository.pauseSave = gate;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(controller.busy, isTrue);
    expect(controller.cookingInputBlocked, isFalse);
    final released =
        controller.cookingCommand(session.pour(session.token, 2500));
    expect(controller.state.session!.phase, CookingPhase.firstBatter);
    repository.pauseSave = null;
    gate.complete();
    expect(await released, isTrue);
    expect(controller.state.session!.firstBatterMs, 2500);
    expect(controller.state.session!.phase, CookingPhase.filling);
  });
  test(
      'takeout timestamp is captured before awaiting a delayed periodic checkpoint',
      () async {
    final session = cooking();
    await controller.command(() {
      controller.state.session = session;
      controller.state.phaseMs = 15000;
    });
    final gate = Completer<void>();
    repository.pauseSave = gate;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(controller.busy, isTrue);
    final stamp = controller.activePhaseElapsedMs;
    final taken =
        controller.cookingCommand(session.takeOut(session.token, 999999));
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    repository.pauseSave = null;
    gate.complete();
    expect(await taken, isTrue);
    expect(controller.state.session!.donenessElapsedMs,
        inInclusiveRange(stamp, stamp + 100));
  });
  test('practice entry owns a single session and cancel creates no result',
      () async {
    expect(await controller.startPractice(), isTrue);
    expect(await controller.startPractice(), isFalse);
    final session = controller.state.session!;
    expect(await controller.cookingCommand(session.cancel()), isTrue);
    expect(controller.state.session, isNull);
    expect(controller.state.mastery.practices, 0);
    expect(controller.state.inventory.batches, isEmpty);
  });
}
