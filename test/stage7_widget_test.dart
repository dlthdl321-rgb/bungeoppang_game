import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/event_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/menu_rules.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/fish_painter.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'widget_test.dart' show FixedTime, mountGame;
import 'level_missions_widget_test.dart' show tapVisible;

/// Snapshot number [corruptSequence] fails to decode, like a damaged row.
class CorruptRepository extends MemoryGameRepository {
  int? corruptSequence;
  @override
  Future<GameState?> load() async {
    if (current != null && current!.snapshotSequence == corruptSequence) {
      throw const FormatException('테스트 손상');
    }
    return super.load();
  }
}

Future<(GameController, CorruptRepository)> mountRecovery(
    WidgetTester tester, FixedTime clock,
    {GameState? backup}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  final repo = CorruptRepository()
    ..current = (GameState.initial(clock.utcNow)..snapshotSequence = 9)
    ..corruptSequence = 9
    ..backup = backup;
  final c = GameController(repo, clock);
  await expectLater(c.initialize(), throwsFormatException);
  await tester.pumpWidget(RecoveryApp(controller: c));
  await tester.pump();
  return (c, repo);
}

Future<void> setRecoverySurface(
    WidgetTester tester, Size size, double textScale) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() async {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

Iterable<FishPainter> fishPainters(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<FishPainter>();

void main() {
  group('c. 복구 화면', () {
    testWidgets('이전 저장 복구 성공 시 게임 화면으로 전환', (tester) async {
      final clock = FixedTime();
      final backup = GameState.initial(clock.utcNow)
        ..snapshotSequence = 8
        ..tutorialDone = true
        ..buns = BigInt.from(777);
      final (c, _) = await mountRecovery(tester, clock, backup: backup);
      await tester.tap(find.text('이전 저장 복구'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-capture')), findsOneWidget);
      expect(c.state.buns, BigInt.from(777));
      // A later save must not be discarded as older than the damaged row.
      c.state.buns = BigInt.from(778);
      await c.save();
      expect((await c.repository.load())!.buns, BigInt.from(778));
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('복구할 백업이 없으면 이유를 표시하고 화면에 남는다', (tester) async {
      await mountRecovery(tester, FixedTime());
      await tester.tap(find.text('이전 저장 복구'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-message')), findsOneWidget);
      expect(find.textContaining('이전 저장이 없'), findsOneWidget);
      expect(find.byKey(const Key('home-capture')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('복구 저장에 실패하면 이유를 표시한다', (tester) async {
      final clock = FixedTime();
      final backup = GameState.initial(clock.utcNow)..snapshotSequence = 8;
      final (_, repo) = await mountRecovery(tester, clock, backup: backup);
      repo.failNextSave = true;
      await tester.tap(find.text('이전 저장 복구'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery-message')), findsOneWidget);
      expect(find.byKey(const Key('home-capture')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('새로 시작은 확인 후 초기 상태로 게임 화면 전환', (tester) async {
      final (c, _) = await mountRecovery(tester, FixedTime());
      await tester.tap(find.text('새로 시작 (데이터 초기화)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recovery-reset-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-capture')), findsOneWidget);
      expect(c.state.level, 1);
      expect(c.state.buns, BigInt.zero);
      expect((await c.repository.load())!.level, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('c. 복구 화면 ${size.width}/$scale 실패 안내까지 overflow 없음',
          (tester) async {
        final clock = FixedTime();
        final repo = CorruptRepository()
          ..current = (GameState.initial(clock.utcNow)..snapshotSequence = 9)
          ..corruptSequence = 9;
        final c = GameController(repo, clock);
        await expectLater(c.initialize(), throwsFormatException);
        await setRecoverySurface(tester, size, scale);
        await tester.pumpWidget(RecoveryApp(controller: c));
        await tester.tap(find.text('이전 저장 복구'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('recovery-message')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('새로 시작 (데이터 초기화)'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('recovery-reset-confirm')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('f. 홈 이벤트 카드와 이벤트 화면은 같은 현재 이벤트를 사용', (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    expect(find.textContaining(currentEvent.title), findsOneWidget);
    expect(
        find.textContaining(
            '선착순 잔여 ${eventRemaining(c.state, currentEvent, currentEvent.rewards.last)}명'),
        findsOneWidget);
    await tapVisible(tester, const Key('event-entry'));
    expect(find.text(currentEvent.title), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('g. 옷장 미리보기 속 색상은 실제 홈 외형과 같다', (tester) async {
    final clock = FixedTime();
    final c = await mountGame(tester, const Size(390, 844),
        clock: clock, maxLevel: true);
    c.state.ownedSkins.add('custard');
    c.state.equippedSkin = 'custard';
    c.tick();
    await tester.pump();
    final home = fishPainters(tester).single;
    await tapVisible(tester, const Key('menu-skins'));
    final painters = fishPainters(tester).toList();
    expect(painters.length, 2);
    expect(painters.map((p) => p.filling).toSet(), {home.filling});
    await tapVisible(tester, const Key('preview-cocoa'));
    final preview = fishPainters(tester).firstWhere((p) => p.skin == 'cocoa');
    expect(preview.filling, isNot(home.filling));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('h. 홈 카드와 이벤트 화면 카운트다운은 같은 반올림을 사용', (tester) async {
    final clock = FixedTime()
      ..now = currentEvent.end
          .subtract(const Duration(days: 1, minutes: 2, milliseconds: 500));
    await mountGame(tester, const Size(390, 844), clock: clock);
    final home =
        tester.widget<Text>(find.byKey(const Key('event-countdown'))).data!;
    final label = home.substring(home.indexOf('·') + 2);
    expect(label, '종료까지 1일 00:02:01');
    await tapVisible(tester, const Key('event-entry'));
    expect(find.text(label), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
