import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
import 'package:todays_bungeoppang/ranking_config.dart';
import 'controller_test.dart' show FakeTime;
import 'level_missions_widget_test.dart' show tapVisible;
import 'stage8_widget_test.dart' show expectNoPrototypeText;
import 'widget_test.dart' show CountingRepository, mountGame;

class FakeRanking implements RankingService {
  bool configured, authenticated, signInSucceeds;
  final submissions = <Map<String, int>>[];
  int shows = 0, signIns = 0;
  FakeRanking(
      {this.configured = true,
      this.authenticated = true,
      this.signInSucceeds = true});
  @override
  Future<RankingStatus> status() async => RankingStatus(
      configured: configured, authenticated: configured && authenticated);
  @override
  Future<bool> signIn() async {
    signIns++;
    if (signInSucceeds) authenticated = true;
    return authenticated;
  }

  @override
  Future<void> submit(Map<String, int> scores) async =>
      submissions.add(Map.of(scores));
  @override
  Future<bool> showLeaderboards() async {
    shows++;
    return true;
  }
}

final now = DateTime.utc(2026, 10, 5, 3);

void main() {
  group('점수 변환', () {
    test('64비트 상한을 넘는 값은 상한으로 고정', () {
      final s = GameState.initial(now)..lifetime = rankingScoreMax + BigInt.one;
      s.records
        ..bestAutoRate = BigInt.from(123)
        ..todayBestCombo = 7;
      expect(rankingScores(s), {
        rankingBestAutoRate: 123,
        rankingLifetime: rankingScoreMax.toInt(),
        rankingBestCombo: 7,
      });
      expect(lifetimeExceedsRanking(s), isTrue);
      s.lifetime = rankingScoreMax;
      expect(lifetimeExceedsRanking(s), isFalse);
    });
  });

  group('제출 시점', () {
    late FakeTime clock;
    late CountingRepository repo;
    late FakeRanking ranking;
    late GameController c;
    setUp(() async {
      clock = FakeTime()..now = now;
      repo = CountingRepository();
      ranking = FakeRanking();
      c = GameController(repo, clock, ranking: ranking);
      await c.initialize();
      await c.refreshRanking();
    });
    tearDown(() => c.dispose());

    test('탭마다 보내지 않고 5분 간격, 바뀐 점수만 보낸다', () async {
      c.tick();
      expect(ranking.submissions.length, 1); // First authenticated tick.
      final saves = repo.saves;
      for (var i = 0; i < 300; i++) {
        c.tap();
        clock.advance(100);
      }
      expect(ranking.submissions.length, 1);
      clock.advance(rankingSubmitIntervalMs);
      c.tick();
      expect(ranking.submissions.length, 2);
      expect(ranking.submissions.last[rankingBestCombo],
          c.state.records.bestCombo);
      clock.advance(rankingSubmitIntervalMs);
      c.tick();
      expect(ranking.submissions.length, 2); // Nothing improved.
      expect(repo.saves, saves); // Ranking never writes the save file.
    });

    test('레벨업·앱 나가기·순위 열기에서는 바로 보낸다', () async {
      c.tick();
      final base = ranking.submissions.length;
      c.state.tutorialDone = true;
      c.state.lifetime = BigInt.from(10);
      expect(await c.claimLevelUp(2), isTrue);
      expect(ranking.submissions.length, base + 1);
      c.tap();
      await c.leaveActive();
      expect(ranking.submissions.length, base + 2);
      await c.resume();
      c.tap();
      expect(await c.showRanking(), isTrue);
      expect(ranking.submissions.length, base + 3);
      expect(ranking.shows, 1);
    });

    test('로그인하지 않았거나 준비되지 않았으면 보내지 않는다', () async {
      ranking.authenticated = false;
      await c.refreshRanking();
      c.tap();
      clock.advance(rankingSubmitIntervalMs);
      c.tick();
      expect(await c.showRanking(), isFalse);
      expect(ranking.submissions, isEmpty);
      ranking.configured = false;
      await c.refreshRanking();
      expect(await c.signInRanking(), isFalse);
      expect(ranking.signIns, 0);
    });

    test('로그인 성공 후 바로 현재 기록을 보낸다', () async {
      ranking.authenticated = false;
      await c.refreshRanking();
      c.tap();
      expect(await c.signInRanking(), isTrue);
      expect(c.rankingStatus.authenticated, isTrue);
      expect(ranking.submissions.single[rankingLifetime], 1);
    });
  });

  group('Play 게임즈 채널', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = PlayGamesRankingService.channel;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('플러그인이 없는 플랫폼은 준비되지 않음으로 처리', () async {
      const service = PlayGamesRankingService();
      expect((await service.status()).configured, isFalse);
      expect(await service.signIn(), isFalse);
      await service.submit({rankingLifetime: 1});
      expect(await service.showLeaderboards(), isFalse);
    });

    test('상태·제출 인자를 그대로 주고받는다', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'status' => {'configured': true, 'authenticated': true},
          'submitScores' => 3,
          _ => true,
        };
      });
      const service = PlayGamesRankingService();
      final status = await service.status();
      expect(status.configured && status.authenticated, isTrue);
      await service.submit({rankingBestCombo: 9});
      expect(calls.last.arguments, {rankingBestCombo: 9});
      expect(await service.showLeaderboards(), isTrue);
    });

    test('플랫폼 오류는 게임을 멈추지 않는다', () async {
      messenger.setMockMethodCallHandler(
          channel, (_) async => throw PlatformException(code: 'offline'));
      const service = PlayGamesRankingService();
      expect((await service.status()).authenticated, isFalse);
      await service.submit({rankingLifetime: 1});
      expect(await service.signIn(), isFalse);
    });
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('내 기록 온라인 랭킹 카드 ${size.width}/$scale', (tester) async {
        final ranking = FakeRanking(authenticated: false);
        final c = await mountGame(tester, size,
            textScale: scale, developerTools: false, ranking: ranking);
        await tester.runAsync(c.refreshRanking);
        c.state.lifetime = rankingScoreMax + BigInt.one;
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-menu'));
        await tapVisible(tester, const Key('menu-records'));
        expectNoPrototypeText(tester, 'records');
        await tapVisible(tester, const Key('ranking-sign-in'));
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(
            find.byKey(const Key('ranking-lifetime-capped')), findsOneWidget);
        await tapVisible(tester, const Key('ranking-open'));
        expect(ranking.shows, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('Play 게임즈 설정 전에는 준비 중으로 표시', (tester) async {
    final c = await mountGame(tester, const Size(390, 844),
        ranking: FakeRanking(configured: false));
    await tester.runAsync(c.refreshRanking);
    await tester.pump();
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-records'));
    expect(find.byKey(const Key('ranking-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('ranking-sign-in')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
