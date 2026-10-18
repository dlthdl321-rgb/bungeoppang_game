import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_tilt_source.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/cooking_session_controls.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android production touch, native sensor and durable SQLite replay',
      (tester) async {
    final config = DevelopmentBalance.fromJson(jsonDecode(
            await rootBundle.loadString('config/development_balance.json'))
        as Map<String, dynamic>);
    final db = await openDatabase(
        path.join(await getDatabasesPath(), 'step02_audit.sqlite'),
        version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
      await db.execute(
          'CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    });
    final repository = SqliteWorkshopRepository.withDatabase(db);
    var controller = WorkshopController(config, repository);
    await controller.initialize();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => Center(
                    child: controller.state.session == null
                        ? FilledButton(
                            onPressed: controller.startPractice,
                            child: const Text('큰 틀 연습 시작'))
                        : CookingSessionControls(
                            session: controller.state.session!,
                            config: config,
                            blocked: controller.cookingInputBlocked,
                            cookingElapsedMs: controller.state.phaseMs,
                            onCommand: controller.cookingCommand))))));
    if (controller.state.session != null) {
      await controller.command(() {
        controller.state.session = null;
      });
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('큰 틀 연습 시작'));
    await tester.pumpAndSettle();
    final hold = await tester
        .startGesture(tester.getCenter(find.textContaining('첫 반죽 붓기')));
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    await tester.pump();
    await hold.up();
    await tester.pumpAndSettle();
    expect(controller.state.session!.phase, CookingPhase.filling);
    expect(controller.state.session!.firstBatterMs, greaterThanOrEqualTo(2500));
    final squeeze=await tester.startGesture(tester.getCenter(find.byType(PipingBagControl)));
    await Future<void>.delayed(const Duration(milliseconds:1100));
    await tester.pump();await squeeze.up();await tester.pumpAndSettle();
    expect(controller.state.session!.fillingDurationMs,greaterThanOrEqualTo(1000));
    final fillingMs=controller.state.session!.fillingDurationMs;
    final durable=await repository.load();
    expect((durable!['session'] as Map)['fillingDurationMs'],fillingMs);
    debugPrint('STEP02_PIPING_BAG_OK durationMs=$fillingMs');
    expect(controller.state.session!.phase, CookingPhase.secondBatter);
    final second = await tester
        .startGesture(tester.getCenter(find.textContaining('둘째 반죽 붓기')));
    await tester.pump(const Duration(milliseconds: 100));
    await second.up();
    await tester.pumpAndSettle();
    await controller.command(() {
      controller.state.phaseMs = 1000;
    });
    await tester.tap(find.text('뚜껑 닫기'));
    await tester.pumpAndSettle();
    await controller.command(() {
      controller.state.phaseMs = 1000;
    });
    await tester.tap(find.text('뒤집기'));
    await tester.pumpAndSettle();
    await controller.command(() {
      controller.state.phaseMs = 15000;
    });
    await tester.tap(find.text('꺼내기'));
    await tester.pumpAndSettle();
    expect(controller.state.session!.phase, CookingPhase.result);
    expect(await controller.storeResult(false), isTrue);

    final samples = await CookingTiltSource()
        .samples(config)
        .take(3)
        .timeout(const Duration(seconds: 15))
        .toList();
    expect(samples, isNotEmpty);
    expect(samples.first.available, isTrue,
        reason:
            'Device must expose gravity or accelerometer for this sensor audit');
    debugPrint('STEP02_NATIVE_SENSOR_OK samples=${samples.length}');

    // Stage a complete result transaction, recreate controller and open the same
    // Android SQLite file. No user game database or inventory is used here.
    final snapshot = controller.state.toJson();
    final sequence = snapshot['sequence'] as int;
    await repository
        .stageProduction({...snapshot, 'sequence': sequence + 1}, sequence);
    controller.dispose();
    controller = WorkshopController(config, repository);
    await controller.initialize();
    expect(controller.state.sequence, greaterThan(sequence));
    expect(await db.query('production_journal'), isEmpty);
    debugPrint('STEP02_ANDROID_SQLITE_OK');
    controller.dispose();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: Text('직원2 Android 검수 완료')))));
    await db.close();
  });
}
