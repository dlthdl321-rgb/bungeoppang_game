// Shared test helpers (28번 C3-1, 2026-11-23). Moved verbatim from
// widget_test.dart, level_missions_widget_test.dart, stage8_widget_test.dart and
// stage10_feedback_test.dart so that tests no longer import other test files.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/time_service.dart';
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

/// The account controller and the test screen (size, text scale, insets)
/// without showing any home. Workshop tests show their own page on top.
Future<GameController> setUpAccount(WidgetTester tester, Size size,
    {double textScale = 1,
    bool reduced = false,
    FixedTime? clock,
    CountingRepository? repository,
    bool maxLevel = false,
    RankingService ranking = const NoRankingService(),
    OnlineBackend online = const NoOnlineBackend()}) async {
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
  final c = GameController(repo, time, ranking: ranking, online: online);
  await c.initialize();
  return c;
}

Future<void> tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// Prototype wording that must not reach players in a release build.
const _prototypeWords = ['모의', '실제 지급', '예시', '가상', '추정', 'estimated'];

void expectNoPrototypeText(WidgetTester tester, String where) {
  final texts = <String>[
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      t.data ?? t.textSpan?.toPlainText() ?? '',
    for (final t
        in tester.widgetList<SelectableText>(find.byType(SelectableText)))
      t.data ?? '',
  ];
  for (final text in texts) {
    for (final word in _prototypeWords) {
      expect(text.contains(word), isFalse, reason: '$where: "$text"');
    }
  }
}

Future<void> closeSheets(WidgetTester tester) async {
  while (find.byTooltip('닫기').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
  }
}

const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];

class FakeAudio extends SoundPolicy {
  final sounds = <Sfx>[];
  final musicStates = <bool>[];
  bool get musicPlaying => musicStates.isNotEmpty && musicStates.last;
  @override
  Future<void> init() async {}
  @override
  void output(Sfx sfx, double volume) => sounds.add(sfx);
  @override
  void musicOutput({required bool playing, required double volume}) =>
      musicStates.add(playing);
  @override
  Future<void> dispose() async {}
}
