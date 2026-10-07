part of 'game_controller.dart';

/// How often the app checks the server for visits while playing.
const onlineSyncIntervalMs = 2 * 60 * 1000;

/// Friends, visits and the invited player's side of an invitation, through
/// [GameController.online]. Every command returns a short Korean message on
/// failure (null on success) and never throws.
extension OnlineCommands on GameController {
  /// My vendor as the server shows it to friends (avatar slots only).
  Map<String, String> get onlineLook => {
        for (final slot in CosmeticSlot.values)
          if (slot.category == CosmeticCategory.avatar)
            slot.name: state.equippedCosmetic(slot)
      };

  /// Signs in if needed, sends my look, reports Lv.1 for an invitation I
  /// accepted, and turns waiting visits into boosts. Safe to call often.
  Future<void> syncOnline() async {
    if (!online.configured || _onlineSyncing || _disposed) return;
    _onlineSyncing = true;
    _lastOnlineSyncMs = clock.monotonicMilliseconds;
    try {
      if (!online.signedIn && !await online.signIn()) return;
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
    await _online(() async => id = (await online.inviteRegister()).referralCode);
    return id;
  }

  Future<String?> _online(Future<Object?> Function() work) async {
    if (!online.configured) return '온라인 기능을 준비 중이에요';
    try {
      if (!online.signedIn && !await online.signIn()) {
        return 'Google Play 게임즈에 로그인해 주세요';
      }
      await work();
      return null;
    } on OnlineException catch (e) {
      return switch (e.failure) {
        OnlineFailure.signedOut => 'Google Play 게임즈에 로그인해 주세요',
        OnlineFailure.notFound => '아이디를 찾을 수 없어요',
        OnlineFailure.alreadyAccepted => '초대 아이디는 한 번만 입력할 수 있어요',
        OnlineFailure.alreadyOwned => '오늘은 이미 방문했어요',
        OnlineFailure.rejected => '입력한 아이디를 확인해 주세요',
        _ => '연결이 불안정해요. 잠시 후 다시 해 주세요',
      };
    }
  }
}
