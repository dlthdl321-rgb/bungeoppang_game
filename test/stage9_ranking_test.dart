import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
import 'package:todays_bungeoppang/ranking_config.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/ranking_panel.dart';
import 'controller_test.dart' show FakeTime;
import 'level_missions_widget_test.dart' show tapVisible;
import 'online_backend_test.dart' show backend;
import 'stage8_widget_test.dart' show expectNoPrototypeText;
import 'widget_test.dart' show CountingRepository, mountGame;

// Stage 16: Kakao login and the game's own online ranking (the server side
// is tested in firebase/functions/test/ranking.test.ts).

class FakeRanking implements RankingService {
  bool configured, authenticated;
  final submissions = <Map<String, int>>[];
  final loaded = <String>[];
  FakeRanking({this.configured = true, this.authenticated = true});
  @override
  Future<RankingStatus> status() async => RankingStatus(
      configured: configured, authenticated: configured && authenticated);
  @override
  Future<void> submit(Map<String, int> scores) async =>
      submissions.add(Map.of(scores));
  @override
  Future<RankingBoard> top(String board) async {
    loaded.add(board);
    return RankingBoard(board, const [], null);
  }
}

final now = DateTime.utc(2026, 10, 5, 3);

/// Two other players on every board, one with an avatar.
FakeOnlineBackend rankedBackend() {
  final b = backend();
  for (final board in rankingBoards) {
    b.rankingOthers[board] = [
      RankingEntry(
          rank: 0,
          playerId: 'p1',
          name: '붕어왕',
          score: BigInt.parse('123456789012345'),
          look: const {'hair': 'long'}),
      RankingEntry(rank: 0, playerId: 'p2', name: '팥순이', score: BigInt.zero),
    ];
  }
  return b;
}

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

    test('레벨업·앱 나가기·순위 열기에서는 바로 보내되 서버 최소 간격은 지킨다', () async {
      c.tick();
      final base = ranking.submissions.length;
      c.state.tutorialDone = true;
      c.state.lifetime = BigInt.from(10);
      expect(await c.claimLevelUp(2), isTrue);
      expect(ranking.submissions.length, base); // Under a minute: held back.
      clock.advance(rankingSubmitMinGapMs);
      c.state.lifetime = BigInt.from(11);
      await c.leaveActive();
      expect(ranking.submissions.length, base + 1);
      await c.resume();
      clock.advance(rankingSubmitMinGapMs);
      c.tap();
      expect((await c.loadRanking(rankingBestCombo))!.board, rankingBestCombo);
      expect(ranking.submissions.length, base + 2);
      expect(ranking.loaded, [rankingBestCombo]);
    });

    test('로그인하지 않았거나 준비되지 않았으면 보내지도 불러오지도 않는다', () async {
      ranking.authenticated = false;
      await c.refreshRanking();
      c.tap();
      clock.advance(rankingSubmitIntervalMs);
      c.tick();
      expect(await c.loadRanking(rankingLifetime), isNull);
      expect(ranking.submissions, isEmpty);
      expect(ranking.loaded, isEmpty);
    });
  });

  group('카카오 로그인', () {
    late FakeTime clock;
    late FakeOnlineBackend online;
    late GameController c;
    Future<void> start({FakeOnlineBackend? using}) async {
      clock = FakeTime()..now = now;
      online = using ?? rankedBackend();
      c = GameController(MemoryGameRepository(), clock,
          online: online, ranking: ServerRankingService(online));
      await c.initialize();
      await c.refreshRanking();
    }

    tearDown(() => c.dispose());

    test('성공하면 프로필을 보내고 바로 내 기록을 올린다', () async {
      await start();
      expect(c.rankingStatus.configured, isTrue);
      expect(c.rankingStatus.authenticated, isFalse);
      c.tap();
      expect(await c.signInOnline(), isNull);
      expect(online.signedIn, isTrue);
      expect(c.rankingStatus.authenticated, isTrue);
      expect(online.name, '테스터'); // the Kakao nickname
      expect(online.rankingSubmissions.single[rankingLifetime], 1);
      final board = (await c.loadRanking(rankingLifetime))!;
      expect(board.entries.map((e) => (e.rank, e.name)),
          [(1, '붕어왕'), (2, '테스터'), (3, '팥순이')]);
      expect(board.me, (rank: 2, score: BigInt.one));
    });

    test('사용자가 취소하면 메시지 없이 그대로 로그아웃 상태', () async {
      await start();
      online.signInResult = SignInResult.canceled;
      expect(await c.signInOnline(), isNull);
      expect(online.signedIn, isFalse);
      expect(c.rankingStatus.authenticated, isFalse);
      expect(online.rankingSubmissions, isEmpty);
      // An action that needs the account says so instead.
      expect(await c.addFriend('BBAAAAAAAA'), '카카오 계정으로 로그인해 주세요');
    });

    test('실패하면 다시 해 달라고 알린다', () async {
      await start();
      online.signInResult = SignInResult.failed;
      expect(await c.signInOnline(), '로그인하지 못했어요. 잠시 후 다시 해 주세요');
      expect(online.signedIn, isFalse);
      expect(await c.addFriend('BBAAAAAAAA'), '로그인하지 못했어요. 잠시 후 다시 해 주세요');
    });

    test('키가 없는 빌드는 온라인 기능이 준비 중이고 게임은 그대로', () async {
      clock = FakeTime()..now = now;
      c = GameController(MemoryGameRepository(), clock);
      await c.initialize();
      await c.refreshRanking();
      expect(c.rankingStatus.configured, isFalse);
      expect(await c.signInOnline(), '온라인 기능을 준비 중이에요');
      expect(await c.loadRanking(rankingBestAutoRate), isNull);
      c.tap();
      expect(c.state.lifetime, BigInt.one);
    });

    test('배경 동기화는 카카오 로그인 화면을 열지 않는다', () async {
      await start();
      await c.syncOnline();
      clock.advance(onlineSyncIntervalMs);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(online.signIns, 0);
    });

    test('Firebase 세션이 살아 있으면 다시 켜도 로그인 상태', () async {
      await start(using: rankedBackend()..signedIn = true);
      expect(c.rankingStatus.authenticated, isTrue);
      expect(online.signIns, 0);
    });

    test('로그아웃하면 카카오와 Firebase 모두에서 나가고, 다시 로그인하면 기록을 새로 보낸다', () async {
      await start();
      await c.signInOnline();
      await c.signOutOnline();
      expect(online.signOuts, 1);
      expect(online.signedIn, isFalse);
      expect(c.rankingStatus.authenticated, isFalse);
      clock.advance(rankingSubmitMinGapMs);
      await c.signInOnline();
      expect(online.rankingSubmissions.length, 2);
    });
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('온라인 랭킹 화면 ${size.width}/$scale', (tester) async {
        final online = rankedBackend();
        final c = await mountGame(tester, size,
            textScale: scale,
            developerTools: false,
            online: online,
            ranking: ServerRankingService(online));
        c.state.lifetime = rankingScoreMax + BigInt.one;
        c.state.records.bestAutoRate = BigInt.from(5);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-menu'));
        await tapVisible(tester, const Key('menu-ranking'));
        expectNoPrototypeText(tester, 'ranking');
        expect(find.byKey(const Key('ranking-list')), findsNothing);
        await tapVisible(tester, const Key('online-sign-in'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('online-account')), findsOneWidget);
        expect(find.byKey(const Key('ranking-list')), findsOneWidget);
        expect(find.text('붕어왕'), findsOneWidget);
        expect(
            find.text(rankingScoreLabel(
                rankingBestAutoRate, BigInt.parse('123456789012345'))),
            findsOneWidget);
        expect(find.text('내 순위 · 2위'), findsOneWidget);
        await tapVisible(tester, Key('ranking-tab-$rankingLifetime'));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const Key('ranking-lifetime-capped')), findsOneWidget);
        expect(find.text('내 순위 · 1위'), findsOneWidget);
        await tapVisible(tester, Key('ranking-tab-$rankingBestCombo'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ranking-me')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, const Key('online-sign-out'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
        expect(online.signOuts, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('로그인을 취소하면 안내 없이 로그인 버튼이 그대로 있다', (tester) async {
    final online = rankedBackend()..signInResult = SignInResult.canceled;
    await mountGame(tester, const Size(390, 844),
        online: online, ranking: ServerRankingService(online));
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-ranking'));
    await tapVisible(tester, const Key('online-sign-in'));
    expect(online.signIns, 1);
    expect(find.byKey(const Key('online-sign-in-error')), findsNothing);
    expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
    online.signInResult = SignInResult.failed;
    await tapVisible(tester, const Key('online-sign-in'));
    expect(find.text('로그인하지 못했어요. 잠시 후 다시 해 주세요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('키가 없는 빌드는 랭킹과 친구가 준비 중으로 표시', (tester) async {
    await mountGame(tester, const Size(390, 844));
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-ranking'));
    expect(find.byKey(const Key('ranking-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('online-sign-in')), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-friends'));
    expect(find.byKey(const Key('friends-offline')), findsOneWidget);
    expect(find.byKey(const Key('online-sign-in')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('친구 화면을 열어도 로그인 화면이 저절로 뜨지 않는다', (tester) async {
    final online = rankedBackend();
    await mountGame(tester, const Size(390, 844),
        online: online, ranking: ServerRankingService(online));
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-friends'));
    expect(online.signIns, 0);
    expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
    await tapVisible(tester, const Key('online-sign-in'));
    expect(find.text('내 아이디  BBFAKECODE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
