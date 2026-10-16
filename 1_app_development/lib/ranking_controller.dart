part of 'game_controller.dart';

extension RankingCommands on GameController {
  Future<void> refreshRanking() async {
    final status = await ranking.status();
    if (_disposed) return;
    rankingStatus = status;
    _notifyChanged();
  }

  /// Pushes current bests when signed in. Unforced calls are throttled and
  /// skipped when nothing improved; even forced ones keep the server's
  /// minimum gap. Nothing here touches the save file.
  void submitRankingIfDue({bool force = false}) {
    if (!rankingStatus.authenticated) return;
    final now = clock.monotonicMilliseconds, last = _lastRankingSubmitMs;
    if (last != null &&
        now - last <
            (force ? rankingSubmitMinGapMs : rankingSubmitIntervalMs)) {
      return;
    }
    final scores = rankingScores(state), previous = _lastRankingScores;
    if (previous != null &&
        scores.entries.every((e) => previous[e.key] == e.value)) {
      return;
    }
    _lastRankingSubmitMs = now;
    _lastRankingScores = scores;
    unawaited(_rankingSubmission = ranking.submit(scores));
  }

  /// [board] with my latest bests sent first; null when it cannot be
  /// loaded (offline, signed out).
  Future<RankingBoard?> loadRanking(String board) async {
    if (!rankingStatus.authenticated) return null;
    submitRankingIfDue(force: true);
    await _rankingSubmission;
    try {
      return await ranking.top(board);
    } on OnlineException {
      return null;
    }
  }
}
