import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/time_service.dart';
import 'package:todays_bungeoppang/ui/bake_target.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

class FixedTime implements TimeService {
  DateTime now = DateTime.utc(2026, 9, 29, 12);
  int mono = 0;
  @override
  DateTime get utcNow => now;
  @override
  int get monotonicMilliseconds => mono;
  void advance(Duration duration) {
    now = now.add(duration);
    mono += duration.inMilliseconds;
  }
}

class CountingRepository extends MemoryGameRepository {
  int saves = 0;
  @override
  Future<void> save(GameState state) async {
    saves++;
    await super.save(state);
  }
}

Future<GameController> mountGame(WidgetTester tester, Size size,
    {double textScale = 1,
    bool reduced = false,
    FixedTime? clock,
    CountingRepository? repository,
    bool maxLevel = false,
    bool? developerTools,
    RankingService ranking = const NoRankingService()}) async {
  // Decoding needs real async; the app does this in main() before runApp.
  await tester.runAsync(PixelSprites.load);
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(() async {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  final time = clock ?? FixedTime();
  final repo = repository ?? CountingRepository();
  repo.current = GameState.initial(time.utcNow)
    ..tutorialDone = true
    ..buns = BigInt.parse('1234567890123')
    ..lifetime = BigInt.parse('2345678901234')
    ..level = maxLevel ? 10 : 1;
  repo.current!.missions =
      MissionState.forLevel(repo.current!.level, time.utcNow);
  repo.current!.settings
    ..vibration = false
    ..reduceMotion = reduced;
  final c = GameController(repo, time,
      developerTools: developerTools, ranking: ranking);
  await c.initialize();
  await tester.pumpWidget(GameApp(controller: c));
  await tester.pump();
  return c;
}

void main() {
  testWidgets('길게 누르기 중 비활성화와 화면 해제 시 생산 타이머 정지', (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    c.state.settings.holdToBake = true;
    c.tick();
    await tester.pump();
    final press = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('fish-button'))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    final beforePause = c.state.buns;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(c.state.buns, beforePause);
    await press.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('접근성 굽기와 메뉴 동작을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final c = await mountGame(tester, const Size(360, 800));
    expect(tester.getSemantics(find.bySemanticsLabel('상점')),
        matchesSemantics(label: '상점', isButton: true, hasTapAction: true));
    final before = c.state.buns;
    final node = tester.getSemantics(find.bySemanticsLabel('붕어빵 굽기'));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(c.state.buns, before + BigInt.one);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    testWidgets('주요 화면이 ${size.width}x${size.height}에서 표시된다', (tester) async {
      await mountGame(tester, size);
      expect(find.byKey(const Key('fish-button')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Stage 8 menus: ranking → records, invite → share, plus achievements.
      for (final id in [
        'daily',
        'achievements',
        'shop',
        'skins',
        'records',
        'share'
      ]) {
        expect(find.byKey(Key('menu-$id')).hitTestable(), findsOneWidget);
      }
      final fish = tester.getRect(find.byKey(const Key('fish-button')));
      final shop = tester.getRect(find.byKey(const Key('menu-shop')));
      expect(fish.width, greaterThan(size.width * .65));
      expect(fish.right, lessThanOrEqualTo(shop.left));
      expect(tester.getRect(find.byKey(const Key('event-entry'))).bottom,
          lessThanOrEqualTo(size.height - 24));
      expect(find.text('1.23조'), findsOneWidget);
      expect(find.byKey(const Key('tap-rate')), findsOneWidget);
      expect(find.byKey(const Key('auto-rate')), findsOneWidget);
      expect(find.byKey(const Key('level-progress')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final scale in [1.5, 2.0]) {
      testWidgets('확대 $scale · ${size.width} 모든 메뉴와 설정에 overflow 없음',
          (tester) async {
        await mountGame(tester, size, textScale: scale, maxLevel: true);
        expect(
            MediaQuery.textScalerOf(tester.element(find.byType(BakeTarget)))
                .scale(16),
            16 * scale);
        expect(tester.takeException(), isNull);
        for (final id in [
          'shop',
          'skins',
          'daily',
          'achievements',
          'records',
          'share'
        ]) {
          await tester.ensureVisible(find.byKey(Key('menu-$id')));
          await tester.tap(find.byKey(Key('menu-$id')));
          await tester.pumpAndSettle();
          expect(find.byTooltip('닫기'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('닫기'));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.byKey(const Key('event-entry')));
        await tester.tap(find.byKey(const Key('event-entry')));
        await tester.pumpAndSettle();
        // Stage 8: the mock-season notice became the weekly challenge.
        expect(find.byKey(const Key('weekly-countdown')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('설정'));
        await tester.tap(find.byTooltip('설정'));
        await tester.pumpAndSettle();
        expect(find.text('길게 눌러 굽기'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('연속 200회 탭은 전부 생산하고 효과는 8개 이하, 프레임 DB 저장 없음', (tester) async {
    final repo = CountingRepository();
    final c = await mountGame(tester, const Size(360, 800), repository: repo);
    final before = c.state.buns;
    final saves = repo.saves;
    for (var i = 0; i < 200; i++) {
      await tester.tap(find.byKey(const Key('fish-button')));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const Key('tap-burst')).evaluate().length,
          lessThanOrEqualTo(BakeTarget.maxBursts));
    }
    expect(c.state.buns - before, BigInt.from(200));
    expect(repo.saves, saves);
    expect(
        tester
            .widget<Transform>(find.byKey(const Key('fish-scale')))
            .transform
            .storage[0],
        lessThan(1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('tap-burst')), findsNothing);
    expect(
        tester
            .widget<Transform>(find.byKey(const Key('fish-scale')))
            .transform
            .storage[0],
        1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final system in [false, true]) {
    testWidgets('모션 줄이기 ${system ? '시스템' : '앱'}은 생산만 하고 이동 효과 없음',
        (tester) async {
      if (system) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
      }
      final c = await mountGame(tester, const Size(360, 800), reduced: !system);
      final before = c.state.buns;
      await tester.tap(find.byKey(const Key('fish-button')));
      await tester.pump();
      expect(c.state.buns, before + BigInt.one);
      expect(find.byKey(const Key('tap-burst')), findsNothing);
      expect(find.byKey(const Key('static-gain')), findsOneWidget);
      expect(
          tester
              .widget<Transform>(find.byKey(const Key('fish-scale')))
              .transform
              .storage[0],
          1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TimeService 변경으로 이벤트 카운트다운이 갱신된다', (tester) async {
    final clock = FixedTime();
    final c = await mountGame(tester, const Size(390, 844), clock: clock);
    final before =
        tester.widget<Text>(find.byKey(const Key('event-countdown'))).data;
    clock.advance(const Duration(seconds: 1));
    c.tick();
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('event-countdown'))).data,
        isNot(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('오른쪽 상점 구매 후 홈 재화와 클릭 생산이 갱신된다', (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    final before = c.state.buns;
    await tester.tap(find.byKey(const Key('menu-shop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1개 · 15'));
    await tester.pumpAndSettle();
    expect(c.state.buns, before - BigInt.from(15));
    expect(c.state.upgradeCounts['tap_1'], 1);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('클릭당 +2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
