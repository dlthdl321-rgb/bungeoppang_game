import 'package:flutter/services.dart';
import 'models.dart';
import 'ranking_config.dart';

class RankingStatus {
  final bool configured, authenticated;
  const RankingStatus({this.configured = false, this.authenticated = false});
  static const unavailable = RankingStatus();
}

/// Online leaderboard port. The game never depends on it to be playable.
abstract class RankingService {
  Future<RankingStatus> status();
  Future<bool> signIn();
  Future<void> submit(Map<String, int> scores);
  Future<bool> showLeaderboards();
}

/// Platforms without Play Games (iOS, tests, desktop).
class NoRankingService implements RankingService {
  const NoRankingService();
  @override
  Future<RankingStatus> status() async => RankingStatus.unavailable;
  @override
  Future<bool> signIn() async => false;
  @override
  Future<void> submit(Map<String, int> scores) async {}
  @override
  Future<bool> showLeaderboards() async => false;
}

/// Android Play Games Services v2 through MainActivity's method channel.
class PlayGamesRankingService implements RankingService {
  static const channel = MethodChannel('todays_bungeoppang/play_games');
  const PlayGamesRankingService();

  @override
  Future<RankingStatus> status() async {
    try {
      final m = await channel.invokeMapMethod<String, Object?>('status');
      return RankingStatus(
          configured: m?['configured'] == true,
          authenticated: m?['authenticated'] == true);
    } on MissingPluginException {
      return RankingStatus.unavailable;
    } on PlatformException {
      return RankingStatus.unavailable;
    }
  }

  @override
  Future<bool> signIn() => _bool('signIn');

  @override
  Future<void> submit(Map<String, int> scores) async {
    try {
      await channel.invokeMethod<int>('submitScores', scores);
    } on MissingPluginException {
      // Not available on this platform.
    } on PlatformException {
      // Offline or signed out: the next submission retries the best scores.
    }
  }

  @override
  Future<bool> showLeaderboards() => _bool('showLeaderboards');

  Future<bool> _bool(String method) async {
    try {
      return await channel.invokeMethod<bool>(method) == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

int _clamp(BigInt value) =>
    (value > rankingScoreMax ? rankingScoreMax : value).toInt();

/// Best values only; Play Games keeps each player's highest score.
Map<String, int> rankingScores(GameState s) => {
      rankingBestAutoRate: _clamp(s.records.bestAutoRate),
      rankingLifetime: _clamp(s.lifetime),
      rankingBestCombo: s.records.bestCombo,
    };

bool lifetimeExceedsRanking(GameState s) => s.lifetime > rankingScoreMax;
