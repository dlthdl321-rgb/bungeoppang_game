import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/online_texts.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
import 'package:todays_bungeoppang/ranking_config.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/ranking_panel.dart';
import 'fake_time.dart' show FakeTime;
import 'test_support.dart' show tapVisible;
import 'online_backend_test.dart' show backend;
import 'test_support.dart' show expectNoPrototypeText;
import 'package:todays_bungeoppang/ui/friends_panel.dart';
import 'test_support.dart' show CountingRepository, setUpAccount;

// Stage 16: Kakao login and the game's own online ranking (the server side
// is tested in firebase/functions/test/ranking.test.ts).

/// The ranking and friends panels are kept (the server side still works) but
/// only the old clicker home opened them, so these tests show each panel by
/// itself instead of going through that home's menu (28번 C2). Like that
/// home's sub-window, it rebuilds whenever the controller changes.
Future<void> showPanel(WidgetTester tester, GameController c, Widget Function() panel) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AnimatedBuilder(animation: c, builder: (_, __) => panel()))));
  await tester.pumpAndSettle();
}

class FakeRanking implements RankingService {
  bool configured, authenticated;
  final loaded = <String>[];
  FakeRanking({this.configured = true, this.authenticated = true});
  @override
  Future<RankingStatus> status() async => RankingStatus(
      configured: configured, authenticated: configured && authenticated);
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
  for (final board in [...rankingBoards, ...workshopRankingBoards]) {
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

    // 32번 2단계: the app sends no scores (the server reads its own record
    // of the new game, DEC-153); it only loads the boards.
    test('점수를 보내지 않고 순위만 불러오며, 저장 파일은 건드리지 않는다', () async {
      final saves = repo.saves;
      clock.advance(rankingSubmitIntervalMs);
      c.tick();
      expect((await c.loadRanking(rankingWorkshopPieces))!.board, rankingWorkshopPieces);
      expect(ranking.loaded, [rankingWorkshopPieces]);
      expect(repo.saves, saves);
    });

    test('로그인하지 않았거나 준비되지 않았으면 불러오지 않는다', () async {
      ranking.authenticated = false;
      await c.refreshRanking();
      expect(await c.loadRanking(rankingWorkshopLifetime), isNull);
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

    test('성공하면 프로필을 보내고 순위를 불러올 수 있다', () async {
      await start();
      expect(c.rankingStatus.configured, isTrue);
      expect(c.rankingStatus.authenticated, isFalse);
      expect(await c.signInOnline(), isNull);
      expect(online.signedIn, isTrue);
      expect(c.rankingStatus.authenticated, isTrue);
      expect(online.name, '테스터'); // the Kakao nickname
      expect(online.rankingSubmissions, isEmpty, reason: '예전 점수는 보내지 않음');
      final board = (await c.loadRanking(rankingWorkshopPieces))!;
      expect(board.entries.map((e) => (e.rank, e.name)), [(1, '붕어왕'), (2, '팥순이')]);
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

    test('키가 없는 빌드는 온라인에 연결할 수 없고 게임은 그대로', () async {
      clock = FakeTime()..now = now;
      c = GameController(MemoryGameRepository(), clock);
      await c.initialize();
      await c.refreshRanking();
      expect(c.rankingStatus.configured, isFalse);
      expect(await c.signInOnline(), OnlineTexts.notSetUp);
      expect(await c.loadRanking(rankingWorkshopPieces), isNull);
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

    test('로그아웃하면 카카오와 Firebase 모두에서 나가고, 다시 로그인할 수 있다', () async {
      await start();
      await c.signInOnline();
      await c.signOutOnline();
      expect(online.signOuts, 1);
      expect(online.signedIn, isFalse);
      expect(c.rankingStatus.authenticated, isFalse);
      await c.signInOnline();
      expect(c.rankingStatus.authenticated, isTrue);
    });
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('온라인 랭킹 화면 ${size.width}/$scale', (tester) async {
        final online = rankedBackend();
        final c = await setUpAccount(tester, size,
            textScale: scale,
            online: online,
            ranking: ServerRankingService(online));
        // 32번 1단계: the new game's boards (DEC-153); my score is the
        // server's own record.
        online.rankingBest[rankingWorkshopPieces] = BigInt.from(42);
        await showPanel(tester, c, () => RankingPanel(controller: c));
        expectNoPrototypeText(tester, 'ranking');
        expect(find.byKey(const Key('ranking-list')), findsNothing);
        await tapVisible(tester, const Key('online-sign-in'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('online-account')), findsOneWidget);
        expect(find.byKey(const Key('ranking-list')), findsOneWidget);
        expect(find.text('붕어왕'), findsOneWidget);
        expect(
            find.text(rankingScoreLabel(
                rankingWorkshopPieces, BigInt.parse('123456789012345'))),
            findsOneWidget);
        expect(find.text('내 순위 · 2위'), findsOneWidget);
        await tapVisible(tester, Key('ranking-tab-$rankingWorkshopLifetime'));
        await tester.pumpAndSettle();
        expect(find.text('붕어왕'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, const Key('online-sign-out'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
        expect(online.signOuts, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
      });
    }
  }

  testWidgets('로그인을 취소하면 안내 없이 로그인 버튼이 그대로 있다', (tester) async {
    final online = rankedBackend()..signInResult = SignInResult.canceled;
    final c = await setUpAccount(tester, const Size(390, 844),
        online: online, ranking: ServerRankingService(online));
    await showPanel(tester, c, () => RankingPanel(controller: c));
    await tapVisible(tester, const Key('online-sign-in'));
    expect(online.signIns, 1);
    expect(find.byKey(const Key('online-sign-in-error')), findsNothing);
    expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
    online.signInResult = SignInResult.failed;
    await tapVisible(tester, const Key('online-sign-in'));
    expect(find.text('로그인하지 못했어요. 잠시 후 다시 해 주세요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('키가 없는 빌드는 랭킹과 친구가 연결 불가로 표시', (tester) async {
    final c = await setUpAccount(tester, const Size(390, 844));
    await showPanel(tester, c, () => RankingPanel(controller: c));
    expect(find.byKey(const Key('ranking-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('online-sign-in')), findsNothing);
    await showPanel(tester, c, () => FriendsPanel(controller: c));
    expect(find.byKey(const Key('friends-offline')), findsOneWidget);
    expect(find.byKey(const Key('online-sign-in')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('친구 화면을 열어도 로그인 화면이 저절로 뜨지 않는다', (tester) async {
    final online = rankedBackend();
    final c = await setUpAccount(tester, const Size(390, 844),
        online: online, ranking: ServerRankingService(online));
    await showPanel(tester, c, () => FriendsPanel(controller: c));
    expect(online.signIns, 0);
    expect(find.byKey(const Key('online-sign-in')), findsOneWidget);
    await tapVisible(tester, const Key('online-sign-in'));
    expect(find.text('내 아이디  BBFAKECODE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
