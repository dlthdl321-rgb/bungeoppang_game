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
  Future<RankingBoard> top(String board) => online.rankingTop(board);
}
