import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/save_quarantine.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/save_recovery.dart';
import 'package:todays_bungeoppang/ui/workshop_guide.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 4단계: 첫 실행 안내, 복귀 안내, 저장 손상 대처.
void main() {
  DevelopmentBalance load([void Function(Map<String, dynamic>)? edit]) {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    edit?.call(raw);
    return DevelopmentBalance.fromJson(raw);
  }
  Future<void> stock(WorkshopController c, String id) => c.command(() {
    c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: id, flavor: 'redbean', variant: 2,
        quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
  });
  String? progress(WidgetTester tester) {
    final f = find.byKey(const Key('tutorial-progress'));
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }
  String text(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tutorial-text'))).data!;

  group('첫 실행 안내', () {
    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      testWidgets('새 설치 → 굽기 → 보관 → 영업 시작 → 첫 판매로 안내가 끝난다 $size', (tester) async {
        final account = await mountGame(tester, size, reduced: true);
        final repository = MemoryRepository();
        final c = WorkshopController(load(), repository, now: () => DateTime.utc(2026, 10, 18));
        await c.initialize();
        expect(c.state.tutorial, 'cook');
        expect(repository.saved!['tutorial'], 'cook');
        await tester.pumpWidget(GameApp(controller: account, workshop: c));
        await tester.pump();
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 1/7');
        expect(find.byKey(const Key('tutorial-ring')), findsOneWidget);

        // The overlay lets touches through to the real game underneath.
        expect(await c.startPractice(), isTrue);
        await tester.pump();
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 2/7');
        var session = c.state.session!;
        expect(await c.cookingCommand(session.pour(session.token, 2500)), isTrue);
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 3/7');
        session = c.state.session!;
        expect(await c.cookingCommand(session.squeezeFilling(session.token, 1500)), isTrue);
        session = c.state.session!;
        expect(await c.cookingCommand(session.pour(session.token, 2500)), isTrue);
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 4/7');
        final manual = c.config.section('manual_cooking');
        await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'lid_close_ms'));
        session = c.state.session!;
        expect(await c.cookingCommand(session.close(session.token)), isTrue);
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 5/7');
        await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'flip_ms'));
        session = c.state.session!;
        expect(await c.cookingCommand(session.flip(session.token)), isTrue);
        await tester.pump();
        expect(progress(tester), '첫 영업 안내 6/7');
        session = c.state.session!;
        expect(await c.cookingCommand(session.takeOut(session.token, 0)), isTrue);
        await tester.pump();
        await tester.pump();
        expect(c.state.session!.phase, CookingPhase.result);
        expect(text(tester), contains('보관'));
        await tester.tap(find.byKey(const Key('mold-store')));
        await tester.pump();
        await tester.pump();
        expect(c.state.session, isNull);
        expect(c.state.tutorial, 'sell');
        expect(repository.saved!['tutorial'], 'sell');

        expect(progress(tester), '첫 영업 안내 7/7');
        expect(text(tester), contains('영업 시작'));
        await tester.tap(find.byKey(const Key('business-open')));
        await tester.pump();
        await tester.pump();
        expect(c.state.business.open, isTrue);
        expect(text(tester), contains('첫 손님'));
        await c.command(() => c.state.customers.add(CustomerOrder(id: 'first', customerId: 'anonymous_first',
            remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
        // A burnt practice bun may not have been kept; the sale needs one in stock.
        if (c.saleReadyCount(c.state.customers.first) == 0) await stock(c, 'ready');
        await tester.pump();
        await tester.pump();
        expect(text(tester), contains('판매'));
        // The card never covers the bottom menu, even on the small screen.
        final card = tester.getRect(find.byKey(const Key('tutorial-card')));
        expect(card.bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const Key('home-nav'))).top));
        await tester.tap(find.byKey(const Key('sale-button')));
        await tester.pump();
        await tester.pump();
        expect(c.state.completedSales, 1);
        expect(c.state.tutorial, 'done');
        expect(repository.saved!['tutorial'], 'done');
        expect(find.byKey(const Key('tutorial-card')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('건너뛰기는 저장되고 다시 열어도 안내가 나오지 않는다', (tester) async {
      final account = await mountGame(tester, const Size(360, 800), textScale: 1.5, reduced: true);
      final repository = MemoryRepository();
      final c = WorkshopController(load(), repository, now: () => DateTime.utc(2026, 10, 18));
      await c.initialize();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await tester.pump();
      // Large text: the card stays above the bottom menu.
      expect(tester.getRect(find.byKey(const Key('tutorial-card'))).bottom,
          lessThanOrEqualTo(tester.getRect(find.byKey(const Key('home-nav'))).top));
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pump();
      await tester.pump();
      expect(c.state.tutorial, 'skipped');
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      expect(await c.skipTutorial(), isFalse, reason: 'nothing left to skip');
      await tester.pumpWidget(const SizedBox.shrink());

      final again = WorkshopController(load(), repository, now: () => DateTime.utc(2026, 10, 18));
      await again.initialize();
      expect(again.state.tutorial, 'skipped');
      expect(again.state.tutorialActive, isFalse);
      again.dispose();
    });

    test('안내 중 첫 네임드 손님 판매에는 이야기 장면이 끼지 않는다', () async {
      // The same setup that shows a story after a doyun sale once the guide is done.
      final config = load((raw) {
        raw['customer_relationships']['choice_first_business_day'] = 99;
        raw['customer_story_conditions']['npc_doyun']['stage'] = 0;
      });
      Future<Map<String, dynamic>?> sellTo(String tutorial) async {
        final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 1), random: Random(7));
        await c.initialize();
        expect(await c.openBusiness(), isTrue);
        await c.command(() => c.state.tutorial = tutorial);
        // Let visitors arrive through the real door until doyun is first in line.
        for (var i = 0; i < 200 && c.state.customers.firstOrNull?.customerId != 'npc_doyun'; i++) {
          await c.command(() => c.state.customers.clear());
          expect(await c.welcomeCustomer(), isTrue, reason: '${c.error}');
        }
        expect(c.state.customers.first.customerId, 'npc_doyun');
        expect(c.state.customerScene, isNull);
        await c.command(() => c.state.customers.removeRange(1, c.state.customers.length));
        final id = c.state.customers.single.id;
        for (final line in c.state.customers.single.lines) {
          for (var n = 0; n < line.quantity; n++) {
            await c.command(() {
              c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: '${line.flavor}${line.variant}$n', flavor: line.flavor,
                  variant: line.variant ?? 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
            });
          }
        }
        expect(await c.sellToCustomer(id), isTrue, reason: '${c.error}');
        expect(c.state.tutorial, tutorial == 'sell' ? 'done' : tutorial);
        final scene = c.state.customerScene;
        c.dispose();
        return scene;
      }
      expect(await sellTo('sell'), isNull);
      expect(await sellTo('done'), isNotNull, reason: 'the same sale shows a scene after the guide');
    });

    test('schema 5 이하 저장은 안내를 끝낸 것으로 올리고, 판매 뒤 진행 중 안내는 거절한다', () async {
      final c = WorkshopController(load(), MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
      await c.initialize();
      final old = c.state.toJson()..['schema'] = 5..remove('tutorial');
      final migrated = WorkshopState.fromJson(old, c.config);
      expect(migrated.tutorial, 'done');
      expect(migrated.toJson()['schema'], 6);
      expect(() => WorkshopState.fromJson(c.state.toJson()..['tutorial'] = 'later', c.config), throwsFormatException);
      expect(() => WorkshopState.fromJson(c.state.toJson()..['completedSales'] = 1, c.config), throwsFormatException);
      c.dispose();
    });
  });

  group('복귀 안내', () {
    test('2시간 이상 비우면 복귀 보고를 만들고, 그보다 짧은 부재는 조용히 정산한다', () async {
      var now = DateTime.utc(2026, 10, 18, 12);
      final repository = MemoryRepository();
      final c = WorkshopController(load(), repository, now: () => now);
      await c.initialize();
      expect(c.awayReport, isNull, reason: 'a new install has nothing to report');
      expect(await c.openBusiness(), isTrue);
      await c.setForeground(false);
      now = now.add(const Duration(hours: 1, minutes: 59));
      await c.setForeground(true);
      expect(c.awayReport, isNull, reason: 'just under two hours');

      await c.setForeground(false);
      now = now.add(const Duration(hours: 2, minutes: 3));
      await c.setForeground(true);
      final report = c.awayReport!;
      expect(report.away, const Duration(hours: 2, minutes: 3));
      expect(report.open, isTrue);
      expect(report.buns, BigInt.zero, reason: 'no auto production skill yet');
      c.dismissAwayReport();
      expect(c.awayReport, isNull);
      c.dispose();

      // Reopening the app reports the time since the last save.
      now = now.add(const Duration(hours: 3));
      final again = WorkshopController(load(), repository, now: () => now);
      await again.initialize();
      expect(again.awayReport!.away, const Duration(hours: 3));
      again.dispose();
    });

    testWidgets('복귀 카드는 비운 시간과 쌓인 붕어빵력을 보여주고 확인으로 닫힌다', (tester) async {
      final config = load();
      Future<void> show(WorkshopAwayReport report) async {
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: Center(
            child: TextButton(onPressed: () => showDialog<void>(context: context,
                builder: (_) => WorkshopWelcomeBackCard(report: report, config: config, reduceMotion: true)),
                child: const Text('open')))))));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }
      await show(WorkshopAwayReport(away: const Duration(hours: 3, minutes: 7), buns: BigInt.from(1234), open: true, waiting: 2));
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('welcome-back-away'))).data, '3시간 7분 동안 자리를 비웠어요');
      expect(find.byKey(const Key('welcome-back-buns')), findsOneWidget);
      expect(find.textContaining('기다리던 손님 2명'), findsOneWidget);
      await tester.tap(find.byKey(const Key('welcome-back-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome-back')), findsNothing);

      await show(WorkshopAwayReport(away: const Duration(minutes: 42), buns: BigInt.zero, open: false, waiting: 0));
      expect(tester.widget<Text>(find.byKey(const Key('welcome-back-away'))).data, '42분 동안 자리를 비웠어요');
      expect(find.byKey(const Key('welcome-back-closed')), findsOneWidget);
      expect(find.byKey(const Key('welcome-back-buns')), findsNothing);
    });

    testWidgets('홈은 복귀 보고를 한 번 띄우고 닫으면 지운다', (tester) async {
      var now = DateTime.utc(2026, 10, 18, 12);
      final account = await mountGame(tester, const Size(360, 800), reduced: true);
      final c = WorkshopController(load(), MemoryRepository(), now: () => now);
      await c.initialize();
      await c.command(() => c.state.tutorial = 'done');
      await c.openBusiness();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await c.setForeground(false);
      now = now.add(const Duration(hours: 2));
      await c.setForeground(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome-back')), findsOneWidget);
      expect(find.byKey(const Key('welcome-back-none')), findsOneWidget);
      expect(c.gridVisible, isFalse, reason: 'the card pauses the griddle like other windows');
      await tester.tap(find.byKey(const Key('welcome-back-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome-back')), findsNothing);
      expect(c.awayReport, isNull);
      expect(c.gridVisible, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('저장 손상', () {
    test('손상 DB는 지우지 않고 날짜 이름으로 옮기며 -wal/-shm도 함께 옮긴다', () async {
      final dir = await Directory.systemTemp.createTemp('save_quarantine');
      addTearDown(() => dir.delete(recursive: true));
      final db = '${dir.path}/todays_bungeoppang_workshop.db';
      final at = DateTime(2026, 11, 11, 9, 5, 7);
      expect(await setAsideDatabaseFile(db, at), isNull, reason: 'nothing to move');
      File(db).writeAsStringSync('broken');
      File('$db-wal').writeAsStringSync('wal');
      final moved = await setAsideDatabaseFile(db, at);
      expect(moved, '${dir.path}/todays_bungeoppang_workshop.damaged-20261111-090507.db');
      expect(File(db).existsSync(), isFalse);
      expect(File(moved!).readAsStringSync(), 'broken');
      expect(File('$moved-wal').readAsStringSync(), 'wal');
      // A second failure in the same second keeps both copies.
      File(db).writeAsStringSync('broken again');
      final second = await setAsideDatabaseFile(db, at);
      expect(second, '${dir.path}/todays_bungeoppang_workshop.damaged-20261111-090507-2.db');
      expect(File(moved).readAsStringSync(), 'broken');
      expect(File(second!).readAsStringSync(), 'broken again');
    });

    testWidgets('복구 시도 → 실패 후 처음부터 시작은 두 번 확인하고 오류 내용을 복사할 수 있다', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      var retries = 0, fresh = 0;
      final failure = SaveFailure(SaveStage.workshop, 'FormatException: 구매 보호 기록 충돌', DateTime.utc(2026, 11, 11, 1));
      Future<void> mount(int attempts) async {
        await tester.pumpWidget(SaveRecoveryApp(failure: failure, attempts: attempts,
            onRetry: () async => retries++, onStartFresh: () async => fresh++));
        await tester.pumpAndSettle();
      }

      await mount(0);
      expect(find.text('저장을 열지 못했어요'), findsOneWidget);
      expect(find.byKey(const Key('recovery-fresh')), findsNothing, reason: 'retry comes first');
      await tester.tap(find.byKey(const Key('recovery-retry')));
      await tester.pumpAndSettle();
      expect(retries, 1);

      await mount(1);
      expect(find.byKey(const Key('recovery-attempts')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recovery-copy')));
      await tester.pumpAndSettle();
      expect(copied, contains('가게 진행 저장 (workshop)'));
      expect(copied, contains('복구 시도: 1회'));
      expect(copied, contains('구매 보호 기록 충돌'));

      // Cancel at the first and at the second question: nothing happens.
      await tester.tap(find.byKey(const Key('recovery-fresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-fresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-fresh-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(fresh, 0);
      await tester.tap(find.byKey(const Key('recovery-fresh')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-fresh-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-fresh-confirm')));
      await tester.pumpAndSettle();
      expect(fresh, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('게임 설정 파일 오류에는 처음부터 시작을 두지 않는다', (tester) async {
      await tester.pumpWidget(SaveRecoveryApp(
          failure: SaveFailure(SaveStage.config, 'bad config', DateTime.utc(2026, 11, 11)),
          attempts: 2, onRetry: () async {}));
      await tester.pumpAndSettle();
      expect(find.textContaining('앱을 업데이트하거나 다시 설치'), findsOneWidget);
      expect(find.byKey(const Key('recovery-fresh')), findsNothing);
    });

    testWidgets('되살리기 실패는 화면에 알리고 버튼을 다시 쓸 수 있다', (tester) async {
      var calls = 0;
      await tester.pumpWidget(SaveRecoveryApp(
          failure: SaveFailure(SaveStage.account, 'broken', DateTime.utc(2026, 11, 11)),
          attempts: 0, onRetry: () async { calls++; throw StateError('still broken'); }));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-message')), findsOneWidget);
      await tester.tap(find.byKey(const Key('recovery-retry')));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  });
}
