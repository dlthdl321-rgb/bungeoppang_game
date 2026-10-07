part of 'game_controller.dart';

/// How often the app checks the server for visits while playing.
const onlineSyncIntervalMs = 2 * 60 * 1000;

const onlineSignInNeeded = '카카오 계정으로 로그인해 주세요';

/// Kakao login, friends, visits and the invited player's side of an
/// invitation, through [GameController.online]. Every command returns a
/// short Korean message on failure (null on success) and never throws.
extension OnlineCommands on GameController {
  /// True while the Kakao login is open.
  bool get signingIn => _signingIn;

  /// Logs in with Kakao, then syncs and sends my ranking scores. Null on
  /// success and also when the player backs out (no message for that).
  Future<String?> signInOnline() async {
    if (!online.configured) return '온라인 기능을 준비 중이에요';
    if (online.signedIn || _signingIn) return null;
    _signingIn = true;
    _notifyChanged();
    try {
      final result = await online.signIn();
      if (result == SignInResult.failed) {
        return '로그인하지 못했어요. 잠시 후 다시 해 주세요';
      }
      if (result == SignInResult.success && !_disposed) {
        await syncOnline();
        await refreshRanking();
        submitRankingIfDue(force: true);
      }
      return null;
    } finally {
      _signingIn = false;
      _notifyChanged();
    }
  }

  /// Signs out of Firebase and Kakao. The game itself goes on offline.
  Future<void> signOutOnline() async {
    if (!online.configured) return;
    await online.signOut();
    _levelOneReported = false;
    _lastRankingScores = null;
    await refreshRanking();
  }

  /// Logs in first when needed (Kakao's screen opens). Null once signed in.
  Future<String?> _requireSignIn() async {
    if (!online.configured) return '온라인 기능을 준비 중이에요';
    if (online.signedIn) return null;
    final error = await signInOnline();
    return error ?? (online.signedIn ? null : onlineSignInNeeded);
  }

  /// My vendor as the server shows it to friends (avatar slots only).
  Map<String, String> get onlineLook => {
        for (final slot in CosmeticSlot.values)
          if (slot.category == CosmeticCategory.avatar)
            slot.name: state.equippedCosmetic(slot)
      };

  /// When signed in: sends my look, reports Lv.1 for an invitation I
  /// accepted, and turns waiting visits into boosts. Safe to call often;
  /// never opens the Kakao login.
  Future<void> syncOnline() async {
    if (!online.configured || _onlineSyncing || _disposed) return;
    _lastOnlineSyncMs = clock.monotonicMilliseconds;
    if (!online.signedIn) return;
    _onlineSyncing = true;
    try {
      await online.setProfile(onlineLook, online.displayName ?? '친구');
      // The server ignores this unless I accepted an invitation and have
      // not reported yet, so one call per session is enough.
      if (state.level >= 2 && !_levelOneReported) {
        await online.inviteReachedLevelOne();
        _levelOneReported = true;
      }
      await _syncWallet();
      final visits = await online.fetchVisits(state.support.appliedVisits);
      if (visits.isNotEmpty && !_disposed) {
        await applyGuestVisits([
          for (final v in visits)
            GuestVisit(
                id: v.id,
                name: v.name,
                kind: v.invite ? BoostKind.invite : BoostKind.visit,
                look: v.look)
        ]);
      }
    } on OnlineException {
      // Offline or not set up: try again on the next sync.
    } finally {
      _onlineSyncing = false;
    }
  }

  void _syncOnlineIfDue(int nowMs) {
    if (online.configured &&
        nowMs - (_lastOnlineSyncMs ?? -onlineSyncIntervalMs) >=
            onlineSyncIntervalMs) {
      unawaited(syncOnline());
    }
  }

  /// The invited player's side: enter the inviter's ID once.
  Future<String?> acceptInvite(String code) => _online(() async {
        await online.inviteAccept(code.trim().toUpperCase());
        unawaited(syncOnline());
      });

  Future<String?> addFriend(String code) =>
      _online(() => online.addFriend(code.trim().toUpperCase()));

  /// Null when the list could not be loaded.
  Future<List<FriendInfo>?> loadFriends() async {
    List<FriendInfo>? list;
    final error = await _online(() async => list = await online.friends());
    return error == null ? list : null;
  }

  Future<String?> visitFriend(String playerId) =>
      _online(() => online.visitFriend(playerId));

  /// My ID (the invite code) for friends to add, or null if unavailable.
  Future<String?> myOnlineId() async {
    String? id;
    await _online(
        () async => id = (await online.inviteRegister()).referralCode);
    return id;
  }

  Future<String?> _online(Future<void> Function() work) async {
    if (await _requireSignIn() case final error?) return error;
    try {
      await work();
      return null;
    } on OnlineException catch (e) {
      return switch (e.failure) {
        OnlineFailure.signedOut => onlineSignInNeeded,
        OnlineFailure.notFound => '아이디를 찾을 수 없어요',
        OnlineFailure.alreadyAccepted => '초대 아이디는 한 번만 입력할 수 있어요',
        OnlineFailure.alreadyOwned => '오늘은 이미 방문했어요',
        OnlineFailure.rejected => '입력한 아이디를 확인해 주세요',
        _ => '연결이 불안정해요. 잠시 후 다시 해 주세요',
      };
    }
  }
}
