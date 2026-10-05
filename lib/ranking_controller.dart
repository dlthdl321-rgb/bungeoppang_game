part of 'game_controller.dart';

extension RankingCommands on GameController {
  bool get rankingBusy => _rankingBusy;

  Future<void> refreshRanking() async {
    final status = await ranking.status();
    if (_disposed) return;
    rankingStatus = status;
    _notifyChanged();
  }

  Future<bool> signInRanking() async {
    if (_rankingBusy || !rankingStatus.configured) return false;
    _rankingBusy = true;
    _notifyChanged();
    try {
      await ranking.signIn();
      await refreshRanking();
      submitRankingIfDue(force: true);
      return rankingStatus.authenticated;
    } finally {
      _rankingBusy = false;
      _notifyChanged();
    }
  }

  /// Pushes current bests when signed in. Unforced calls are throttled and
  /// skipped when nothing improved; nothing here touches the save file.
  void submitRankingIfDue({bool force = false}) {
    if (!rankingStatus.authenticated) return;
    final now = clock.monotonicMilliseconds, last = _lastRankingSubmitMs;
    if (!force && last != null && now - last < rankingSubmitIntervalMs) return;
    final scores = rankingScores(state), previous = _lastRankingScores;
    if (previous != null &&
        scores.entries.every((e) => previous[e.key] == e.value)) {
      return;
    }
    _lastRankingSubmitMs = now;
    _lastRankingScores = scores;
    unawaited(ranking.submit(scores));
  }

  Future<bool> showRanking() async {
    if (!rankingStatus.authenticated) return false;
    submitRankingIfDue(force: true);
    return ranking.showLeaderboards();
  }
}
