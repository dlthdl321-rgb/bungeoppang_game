import 'models.dart';
import 'online_backend.dart';
import 'ranking_config.dart';

class RankingStatus {
  final bool configured, authenticated;
  const RankingStatus({this.configured = false, this.authenticated = false});
  static const unavailable = RankingStatus();
}

/// Online ranking port. The game never depends on it to be playable.
abstract class RankingService {
  Future<RankingStatus> status();

  /// Sends my best scores; failures are dropped (the next one retries).
  Future<void> submit(Map<String, int> scores);

  /// The top [rankingTopCount] of [board] and my place. Throws
  /// [OnlineException] when offline or signed out.
  Future<RankingBoard> top(String board);
}

/// Builds without the online server (iOS, tests, no Kakao key).
class NoRankingService implements RankingService {
  const NoRankingService();
  @override
  Future<RankingStatus> status() async => RankingStatus.unavailable;
  @override
  Future<void> submit(Map<String, int> scores) async {}
  @override
  Future<RankingBoard> top(String board) async =>
      throw const OnlineException(OnlineFailure.unavailable);
}

/// The game's own boards on the Firebase server, through [OnlineBackend]
/// and its Kakao sign-in.
class ServerRankingService implements RankingService {
  final OnlineBackend online;
  const ServerRankingService(this.online);

  @override
  Future<RankingStatus> status() async => RankingStatus(
      configured: online.configured,
      authenticated: online.configured && online.signedIn);

  @override
  Future<void> submit(Map<String, int> scores) async {
    try {
      await online.rankingSubmit(scores);
    } on OnlineException {
      // Offline, too soon or refused: the next submission retries the bests.
    }
  }

  @override
  Future<RankingBoard> top(String board) => online.rankingTop(board);
}

int _clamp(BigInt value) =>
    (value > rankingScoreMax ? rankingScoreMax : value).toInt();

/// Best values only; the server keeps each player's highest score.
Map<String, int> rankingScores(GameState s) => {
      rankingBestAutoRate: _clamp(s.records.bestAutoRate),
      rankingLifetime: _clamp(s.lifetime),
      rankingBestCombo: s.records.bestCombo,
    };

bool lifetimeExceedsRanking(GameState s) => s.lifetime > rankingScoreMax;
