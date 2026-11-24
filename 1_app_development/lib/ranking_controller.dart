part of 'game_controller.dart';

/// The ranking boards (DEC-153): the server scores the new game's boards
/// from its own record (online_controller.dart asks it during the sync).
extension RankingCommands on GameController {
  Future<void> refreshRanking() async {
    final status = await ranking.status();
    if (_disposed) return;
    rankingStatus = status;
    _notifyChanged();
  }

  /// [board], or null when it cannot be loaded (offline, signed out).
  Future<RankingBoard?> loadRanking(String board) async {
    if (!rankingStatus.authenticated) return null;
    try {
      return await ranking.top(board);
    } on OnlineException {
      return null;
    }
  }
}
