@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

class FailingProductionRepository extends SqliteWorkshopRepository {
  bool fail = false;
  FailingProductionRepository(Database db) : super.withDatabase(db);
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    if (fail) {
      fail = false;
      throw StateError('crash after journal commit');
    }
    return super.save(next, expectedSequence);
  }
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database db;
  late DevelopmentBalance config;
  late WorkshopController controller;
  final clock = DateTime.utc(2026, 10, 18);
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('step02-production-');
    config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync())
            as Map<String, dynamic>);
    db = await databaseFactoryFfi.openDatabase('${directory.path}/journal.db');
    await db.execute(
        'CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    controller = WorkshopController(config, FailingProductionRepository(db),
        now: () => clock);
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test(
      'disk journal survives controller/database recreation and final product is recorded once',
      () async {
    var session = CookingSession.start(
        id: 'durable-result',
        flavor: 'redbean',
        practice: true,
        fillingSequence: [CookingDirection.left]);
    session = session.pour(session.token, 2500);
    session = session.squeezeFilling(session.token,1450);
    session = session.pour(session.token, 2500);
    session = session.close(session.token);
    session = session.flip(session.token);
    await controller.command(() {
      controller.state.session = session;
      controller.state.phaseMs = 15000;
    });
    (controller.repository as FailingProductionRepository).fail = true;
    expect(await controller.cookingCommand(session.takeOut(session.token, 0)),
        isFalse);
    expect((await db.query('production_journal')).length, 1);
    controller.dispose();
    await db.close();
    db = await databaseFactoryFfi.openDatabase('${directory.path}/journal.db');
    controller = WorkshopController(
        config, SqliteWorkshopRepository.withDatabase(db),
        now: () => clock.add(const Duration(hours: 1)));
    await controller.initialize();
    expect(controller.state.session!.phase, CookingPhase.result);
    expect(controller.state.session!.fillingDurationMs,1450);
    expect(controller.state.session!.donenessElapsedMs,
        inInclusiveRange(15000, 15999));
    expect(controller.state.mastery.practices, 1);
    expect(await db.query('production_journal'), isEmpty);
    expect(await controller.storeResult(true), isTrue);
    expect(controller.state.inventory.prepared.length, 1);
    await controller.reloadAfterError();
    expect(controller.state.inventory.prepared.length, 1);
    expect(controller.state.mastery.practices, 1);
  });
  test(
      'harvest journal recreates one fixed product and preserves the other five cells',
      () async {
    await controller.openBusiness();
    final rule = config.mastery(0);
    await controller.command(() {
      var mastery = controller.state.mastery;
      final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
      for (var i = 0; i < count; i++) {
        mastery = mastery.record(MasteryResult(
            id: 'seed-$i',
            flavor: 'redbean',
            variant: i < 5 ? i : 2,
            completed: true,
            practice: true,
            techniquePassed: i >= 5));
      }
      controller.state.mastery = mastery;
      controller.state.masteryAward = {
        'revision': config.revision,
        'resultId': 'seed-0',
        'practiceRequired':
            DevelopmentBalance.integer(rule, 'practice_required'),
        'techniqueRequired':
            DevelopmentBalance.integer(rule, 'technique_passes_required')
      };
    });
    await controller.startCell(0);
    await controller.startCell(1);
    await controller.command(() {
      controller.state.grid = controller.state.grid.advanceActive(10000);
    });
    final variant = controller.state.grid.doneness(0, config);
    (controller.repository as FailingProductionRepository).fail = true;
    expect(await controller.harvestCell(0, expectedCycle: 1), isFalse);
    final otherElapsed = controller.state.grid.cells[1].elapsedMs;
    controller.dispose();
    await db.close();
    db = await databaseFactoryFfi.openDatabase('${directory.path}/journal.db');
    controller = WorkshopController(
        config, SqliteWorkshopRepository.withDatabase(db),
        now: () => clock.add(const Duration(hours: 1)));
    await controller.initialize();
    expect(controller.state.inventory.batches.values.single.variant, variant);
    expect(controller.state.inventory.batches.values.single.madeOnBusinessIndex,
        1);
    expect(controller.state.grid.cells[0].cooking, isFalse);
    expect(controller.state.grid.cells[1].elapsedMs, otherElapsed);
    expect(await controller.harvestCell(0, expectedCycle: 1), isFalse);
    expect(controller.state.inventory.batches.length, 1);
  });
  test(
      'mismatched journal baseline is blocked without overwriting the valid checkpoint',
      () async {
    final repository = controller.repository as SqliteWorkshopRepository;
    final base = controller.state.toJson();
    await repository.stageProduction(
        {...base, 'sequence': (base['sequence'] as int) + 1},
        base['sequence'] as int);
    await db.update('production_journal', {'base_body': '{}'});
    await expectLater(repository.loadValidated((row) {
      WorkshopState.fromJson(row, config);
    }), throwsFormatException);
    expect(
        jsonDecode((await db
                .query('snapshots', where: 'slot = ?', whereArgs: ['current']))
            .single['body'] as String),
        base);
  });
  test('another writer cannot replace a staged production transaction',
      () async {
    final repository = SqliteWorkshopRepository.withDatabase(db);
    final base = (await repository.load())!;
    final sequence = base['sequence'] as int;
    final candidate = {...base, 'sequence': sequence + 1};
    await repository.stageProduction(candidate, sequence);
    await expectLater(repository.save({...candidate, 'phaseMs': 1}, sequence),
        throwsFormatException);
    expect((await db.query('production_journal')).length, 1);
    expect((await repository.load())!['sequence'], sequence + 1);
    expect(await db.query('production_journal'), isEmpty);
  });
}
