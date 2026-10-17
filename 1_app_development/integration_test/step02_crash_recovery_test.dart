import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

/// Stage: wait after durable journal commit so the host can force-stop Android.
/// Recover: start a separate process against that exact isolated audit database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android force-stop production recovery', (tester) async {
    const phase =
        String.fromEnvironment('STEP02_PHASE', defaultValue: 'recover');
    const run = String.fromEnvironment('STEP02_RUN', defaultValue: 'local');
    final config = DevelopmentBalance.fromJson(jsonDecode(
            await rootBundle.loadString('config/development_balance.json'))
        as Map<String, dynamic>);
    final db = await openDatabase(
        path.join(await getDatabasesPath(), 'step02_crash_$run.sqlite'),
        version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    });
    final repository = SqliteWorkshopRepository.withDatabase(db);
    var controller = WorkshopController(config, repository);
    await controller.initialize();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('직원2 제작 복구 검수')))));
    if (phase == 'stage') {
      expect(controller.state.mastery.practices, 0);
      var session = CookingSession.start(
          id: 'android-process-crash',
          flavor: 'redbean',
          practice: true,
          fillingSequence: [CookingDirection.left]);
      session = session.pour(session.token, 2500);
      session = session.fill(session.token, CookingDirection.left);
      session = session.pour(session.token, 2500);
      session = session.close(session.token);
      session = session.flip(session.token);
      await controller.command(() {
        controller.state.session = session;
        controller.state.phaseMs = 15000;
      });
      final next = WorkshopState.fromJson(controller.state.toJson(), config);
      next.session = session.takeOut(session.token, 15000);
      next.phaseMs = 0;
      next.mastery = next.mastery
          .record(evaluateCookingResult(config, next.session!, difficulty: 0));
      next.sequence++;
      await repository.stageProduction(
          next.toJson(), controller.state.sequence);
      expect((await db.query('production_journal')).length, 1);
      debugPrint('STEP02_KILL_READY');
      await Future<void>.delayed(const Duration(minutes: 5));
      fail('Host did not force-stop the audit process');
    } else {
      expect(controller.state.session!.id, 'android-process-crash');
      expect(controller.state.session!.phase, CookingPhase.result);
      expect(controller.state.session!.donenessElapsedMs, 15000);
      expect(controller.state.mastery.practices, 1);
      expect(await db.query('production_journal'), isEmpty);
      controller.dispose();
      controller = WorkshopController(config, repository);
      await controller.initialize();
      expect(controller.state.mastery.practices, 1);
      debugPrint('STEP02_FORCE_STOP_RECOVERY_OK');
    }
    controller.dispose();
    await db.close();
  });
}
