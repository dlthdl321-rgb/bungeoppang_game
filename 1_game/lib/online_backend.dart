import 'invite_models.dart';

// The app's view of the Firebase backend (firebase/functions): sign-in with
// a Kakao account, the 황금 붕어빵 wallet, friends, invitations and the
// online ranking. FirebaseOnlineBackend
// (lib/firebase_online_backend.dart) talks to the real server;
// FakeOnlineBackend follows the same rules in memory for tests.

/// What gold can be spent on (catalog.json "spend").
enum PremiumKind { cosmetic, skill, boost }

/// Why a backend call failed, as the server reports it.
enum OnlineFailure {
  unavailable, // not configured, offline or server error: try again later
  signedOut,
  insufficient,
  alreadyOwned,
  pending, // the payment is still being processed by Google Play
  rejected, // bad input, unknown product, someone else's purchase, ...
  alreadyAccepted,
  notFound,
}

/// How a Kakao login ended. [canceled] means the player backed out: no
/// error is shown for it.
enum SignInResult { success, canceled, failed }

class OnlineException implements Exception {
  final OnlineFailure failure;
  final String message;
  const OnlineException(this.failure, [this.message = '']);
  @override
  String toString() => 'OnlineException(${failure.name}: $message)';
}

/// Something bought with gold. Permanent grants (cosmetics, skill unlocks)
/// come back after a reinstall; consumable ones (boosts) are applied once.
class WalletGrant {
  final String id, itemId;
  final PremiumKind kind;
  final bool consumable;
  final DateTime atUtc;
  const WalletGrant(
      {required this.id,
      required this.kind,
      required this.itemId,
      required this.consumable,
      required this.atUtc});
}

/// A friend in the list, with whether I already visited them today.
class FriendInfo {
  final String playerId, name;
  final Map<String, String> look;
  final bool visitedToday;
  const FriendInfo(
      {required this.playerId,
      required this.name,
      this.look = const {},
      this.visitedToday = false});
}

/// A visit waiting in my inbox: a friend (5-minute boost) or the player who
/// invited me, once I reached Lv.1 (10-minute boost).
class ServerVisit {
  final String id, name;
  final bool invite;
  final Map<String, String> look;
  const ServerVisit(
      {required this.id,
      required this.name,
      required this.invite,
      this.look = const {}});
}

/// One row of an online ranking board. [score] is exact (up to 2^63-1).
class RankingEntry {
  final int rank;
  final String playerId, name;
  final Map<String, String> look;
  final BigInt score;
  final bool me;
  const RankingEntry(
      {required this.rank,
      required this.playerId,
      required this.name,
      required this.score,
      this.look = const {},
      this.me = false});
}

/// The top of a board and my own place on it (null before my first score).
class RankingBoard {
  final String board;
  final List<RankingEntry> entries;
  final ({int rank, BigInt score})? me;
  const RankingBoard(this.board, this.entries, this.me);
}

class WalletSnapshot {
  final int gold;
  final List<WalletGrant> grants;
  const WalletSnapshot(this.gold, this.grants);
}

abstract class OnlineBackend {
  /// False when the build has no Firebase/Kakao configuration.
  bool get configured;

  /// Logs in with Kakao (KakaoTalk if installed, else the Kakao account
  /// page) and signs in to Firebase with the server's custom token. Opens
  /// Kakao's screens, so only call it when the player asked to log in.
  Future<SignInResult> signIn();

  /// True while the Firebase session lasts, also after an app restart.
  bool get signedIn;

  /// Signs out of Firebase and Kakao.
  Future<void> signOut();

  Future<WalletSnapshot> syncWallet();

  /// Sends a Google Play purchase for checking. Returns the new balance.
  Future<int> redeemPurchase(String productId, String purchaseToken);

  /// Spends gold; [requestId] makes retries safe (never charged twice).
  Future<(int gold, WalletGrant grant)> spend(
      String requestId, PremiumKind kind, String itemId);

  /// The signed-in player's Kakao nickname, if they agreed to share it.
  String? get displayName;

  /// Tells the server how my vendor looks, for my visits and invite guest.
  Future<void> setProfile(Map<String, String> look, String name);
  Future<FriendInfo> addFriend(String code);
  Future<List<FriendInfo>> friends();

  /// Visits a friend's stall (once per friend per day).
  Future<void> visitFriend(String playerId);
  Future<List<ServerVisit>> fetchVisits(Set<String> applied);

  Future<InviteProfile> inviteRegister();
  Future<InviteTicket> inviteCreateTicket(String missionToken);

  /// The invited player's side: accept [code] once. True if counted as new.
  Future<bool> inviteAccept(String code, {String? ticketId});
  Future<void> inviteReachedLevelOne();
  Future<List<InviteEvent>> inviteFetchEvents(Set<String> committed);

  /// Sends my best scores (ranking_config.dart board names); the server
  /// keeps each board's highest.
  Future<void> rankingSubmit(Map<String, int> scores);
  Future<RankingBoard> rankingTop(String board);
}

/// No Firebase in this build: everything reports [OnlineFailure.unavailable].
class NoOnlineBackend implements OnlineBackend {
  const NoOnlineBackend();
  static Never _off() => throw const OnlineException(OnlineFailure.unavailable);
  @override
  bool get configured => false;
  @override
  bool get signedIn => false;
  @override
  Future<SignInResult> signIn() async => SignInResult.failed;
  @override
  Future<void> signOut() async {}
  @override
  Future<WalletSnapshot> syncWallet() async => _off();
  @override
  Future<int> redeemPurchase(String productId, String purchaseToken) async =>
      _off();
  @override
  Future<(int, WalletGrant)> spend(
          String requestId, PremiumKind kind, String itemId) async =>
      _off();
  @override
  String? get displayName => null;
  @override
  Future<void> setProfile(Map<String, String> look, String name) async =>
      _off();
  @override
  Future<FriendInfo> addFriend(String code) async => _off();
  @override
  Future<List<FriendInfo>> friends() async => _off();
  @override
  Future<void> visitFriend(String playerId) async => _off();
  @override
  Future<List<ServerVisit>> fetchVisits(Set<String> applied) async => _off();
  @override
  Future<InviteProfile> inviteRegister() async => _off();
  @override
  Future<InviteTicket> inviteCreateTicket(String missionToken) async => _off();
  @override
  Future<bool> inviteAccept(String code, {String? ticketId}) async => _off();
  @override
  Future<void> inviteReachedLevelOne() async => _off();
  @override
  Future<List<InviteEvent>> inviteFetchEvents(Set<String> committed) async =>
      _off();
  @override
  Future<void> rankingSubmit(Map<String, int> scores) async => _off();
  @override
  Future<RankingBoard> rankingTop(String board) async => _off();
}

/// In-memory backend with the server's rules, for tests and debug builds.
class FakeOnlineBackend implements OnlineBackend {
  final Map<String, int> products;
  final Map<PremiumKind, Map<String, int>> prices;
  DateTime Function() now;
  FakeOnlineBackend(
      {required this.products, required this.prices, DateTime Function()? now})
      : now = now ?? DateTime.now;

  int gold = 0;

  /// What the next [signIn] does (the player logs in, backs out or it fails).
  SignInResult signInResult = SignInResult.success;
  int signIns = 0, signOuts = 0;
  bool offline = false;
  @override
  bool signedIn = false;
  final grants = <String, WalletGrant>{};
  final redeemedTokens = <String>{};
  final inviteEvents = <InviteEvent>[];
  String? acceptedCode;
  Map<String, String> look = const {};
  String name = '';
  final friendList = <FriendInfo>[];
  final visited = <String>{};
  final inbox = <ServerVisit>[];
  int levelOneReports = 0;
  @override
  String? displayName = '테스터';

  @override
  Future<void> setProfile(Map<String, String> look, String name) async {
    _check();
    this.look = look;
    this.name = name;
  }

  @override
  Future<FriendInfo> addFriend(String code) async {
    _check();
    if (code == 'BBFAKECODE') {
      throw const OnlineException(OnlineFailure.rejected, 'self');
    }
    if (!RegExp(r'^BB[A-Z2-7]{8}$').hasMatch(code)) {
      throw const OnlineException(OnlineFailure.notFound);
    }
    final friend = FriendInfo(playerId: 'p$code', name: '친구 $code');
    friendList
      ..removeWhere((f) => f.playerId == friend.playerId)
      ..add(friend);
    return friend;
  }

  @override
  Future<List<FriendInfo>> friends() async {
    _check();
    return [
      for (final f in friendList)
        FriendInfo(
            playerId: f.playerId,
            name: f.name,
            look: f.look,
            visitedToday: visited.contains(f.playerId))
    ];
  }

  @override
  Future<void> visitFriend(String playerId) async {
    _check();
    if (!friendList.any((f) => f.playerId == playerId)) {
      throw const OnlineException(OnlineFailure.notFound);
    }
    if (!visited.add(playerId)) {
      throw const OnlineException(OnlineFailure.alreadyOwned, 'visited');
    }
  }

  @override
  Future<List<ServerVisit>> fetchVisits(Set<String> applied) async {
    _check();
    return [
      for (final v in inbox)
        if (!applied.contains(v.id)) v
    ];
  }

  @override
  bool get configured => true;

  void _check() {
    if (offline) throw const OnlineException(OnlineFailure.unavailable);
    if (!signedIn) throw const OnlineException(OnlineFailure.signedOut);
  }

  @override
  Future<SignInResult> signIn() async {
    signIns++;
    final result = offline ? SignInResult.failed : signInResult;
    signedIn = result == SignInResult.success;
    return result;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    signedIn = false;
  }

  /// My best per board, and other players' rows by board (rank ignored).
  final rankingBest = <String, BigInt>{};
  final rankingOthers = <String, List<RankingEntry>>{};
  final rankingSubmissions = <Map<String, int>>[];

  @override
  Future<void> rankingSubmit(Map<String, int> scores) async {
    _check();
    rankingSubmissions.add(Map.of(scores));
    for (final MapEntry(:key, :value) in scores.entries) {
      final score = BigInt.from(value);
      if (score > (rankingBest[key] ?? BigInt.zero)) rankingBest[key] = score;
    }
  }

  @override
  Future<RankingBoard> rankingTop(String board) async {
    _check();
    final mine = rankingBest[board];
    final rows = [
      ...?rankingOthers[board],
      if (mine != null)
        RankingEntry(
            rank: 0,
            playerId: 'pfake',
            name: name,
            score: mine,
            look: look,
            me: true),
    ]..sort((a, b) => b.score.compareTo(a.score));
    int rankOf(BigInt score) => rows.where((r) => r.score > score).length + 1;
    return RankingBoard(
        board,
        [
          for (final r in rows.take(100))
            RankingEntry(
                rank: rankOf(r.score),
                playerId: r.playerId,
                name: r.name,
                score: r.score,
                look: r.look,
                me: r.me)
        ],
        mine == null ? null : (rank: rankOf(mine), score: mine));
  }

  @override
  Future<WalletSnapshot> syncWallet() async {
    _check();
    return WalletSnapshot(gold, grants.values.toList());
  }

  @override
  Future<int> redeemPurchase(String productId, String purchaseToken) async {
    _check();
    final amount = products[productId];
    if (amount == null) throw const OnlineException(OnlineFailure.rejected);
    if (redeemedTokens.add(purchaseToken)) gold += amount;
    return gold;
  }

  @override
  Future<(int, WalletGrant)> spend(
      String requestId, PremiumKind kind, String itemId) async {
    _check();
    final id = 'spend_$requestId';
    if (grants[id] case final done?) return (gold, done);
    final price = prices[kind]?[itemId];
    if (price == null) throw const OnlineException(OnlineFailure.rejected);
    final consumable = kind == PremiumKind.boost;
    if (!consumable &&
        grants.values.any((g) => g.kind == kind && g.itemId == itemId)) {
      throw const OnlineException(OnlineFailure.alreadyOwned);
    }
    if (gold < price) throw const OnlineException(OnlineFailure.insufficient);
    gold -= price;
    final grant = WalletGrant(
        id: id,
        kind: kind,
        itemId: itemId,
        consumable: consumable,
        atUtc: now().toUtc());
    grants[id] = grant;
    return (gold, grant);
  }

  @override
  Future<InviteProfile> inviteRegister() async {
    _check();
    return const InviteProfile('pfake', 'BBFAKECODE', InviteOrigin.server);
  }

  int _tickets = 0;
  @override
  Future<InviteTicket> inviteCreateTicket(String missionToken) async {
    _check();
    final id = 'tfake${_tickets++}';
    return InviteTicket(
        id,
        missionToken,
        'https://play.google.com/store/apps/details?id=example&referrer=invite%3DBBFAKECODE',
        now().toUtc(),
        InviteOrigin.server);
  }

  @override
  Future<bool> inviteAccept(String code, {String? ticketId}) async {
    _check();
    if (acceptedCode != null) {
      throw const OnlineException(OnlineFailure.alreadyAccepted);
    }
    acceptedCode = code;
    return true;
  }

  @override
  Future<void> inviteReachedLevelOne() async {
    _check();
    levelOneReports++;
  }

  @override
  Future<List<InviteEvent>> inviteFetchEvents(Set<String> committed) async {
    _check();
    return [
      for (final e in inviteEvents)
        if (!committed.contains(e.eventId)) e
    ];
  }
}
