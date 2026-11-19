import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/cooking_session_controls.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android production painting touch and durable SQLite replay',
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
                            child: const Text('스페셜 붕어빵 제작 시작'))
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
    await tester.tap(find.text('스페셜 붕어빵 제작 시작'));
    await tester.pumpAndSettle();
    // Rub across the mold like painting (24번 5단계).
    Future<void> paint() async {
      final box = tester.getRect(find.byType(MoldPaintControl));
      final gesture = await tester.startGesture(box.center);
      for (var row = 0; row < 5; row++) {
        final y = box.top + box.height * (.3 + row * .1);
        await gesture.moveTo(Offset(box.left + box.width * .15, y));
        await gesture.moveTo(Offset(box.left + box.width * .85, y));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }
    await paint();
    expect(controller.state.session!.phase, CookingPhase.filling);
    expect(controller.state.session!.firstBatter!.coverage, greaterThan(0));
    await paint();
    final filling = controller.state.session!.filling!;
    final durable = await repository.load();
    expect((durable!['session'] as Map)['fillingAmount'], filling.amount);
    debugPrint('STEP02_PIPING_BAG_OK coverage=${filling.coverage} amount=${filling.amount}');
    expect(controller.state.session!.phase, CookingPhase.secondBatter);
    await paint();
    await controller.command(() {
      controller.state.phaseMs = 1000;
    });
    await tester.tap(find.text('뚜껑 닫기'));
    await tester.pumpAndSettle();
    await controller.command(() {
      controller.state.phaseMs = 1000;
    });
    // Push the mold up over its axle to flip it (26번 3차 피드백 H21).
    final flipBox = tester.getRect(find.byType(FlipCircleControl));
    final from = flipBox.center + Offset(0, flipBox.height * .3);
    final circle = await tester.startGesture(from);
    for (var d = 0.0; d <= flipBox.height; d += 10) {
      await circle.moveTo(from - Offset(0, d));
      await tester.pump();
    }
    await circle.up();
    await tester.pumpAndSettle();
    expect(controller.state.session!.phase, CookingPhase.cooking);
    await controller.command(() {
      controller.state.phaseMs = 15000;
    });
    await tester.tap(find.text('꺼내기'));
    await tester.pumpAndSettle();
    expect(controller.state.session!.phase, CookingPhase.result);
    expect(await controller.storeResult(false), isTrue);

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
