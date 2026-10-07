import 'invite_models.dart';

// The app's view of the Firebase backend (firebase/functions): sign-in with
// Play Games, the 황금 붕어빵 wallet and invitations. FirebaseOnlineBackend
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

class WalletSnapshot {
  final int gold;
  final List<WalletGrant> grants;
  const WalletSnapshot(this.gold, this.grants);
}

abstract class OnlineBackend {
  /// False when the build has no Firebase/Play Games configuration.
  bool get configured;

  /// Signs in to Firebase with the Play Games account; false if declined.
  Future<bool> signIn();
  bool get signedIn;

  Future<WalletSnapshot> syncWallet();

  /// Sends a Google Play purchase for checking. Returns the new balance.
  Future<int> redeemPurchase(String productId, String purchaseToken);

  /// Spends gold; [requestId] makes retries safe (never charged twice).
  Future<(int gold, WalletGrant grant)> spend(
      String requestId, PremiumKind kind, String itemId);

  /// The signed-in player's name (Play Games), if known.
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
  Future<bool> signIn() async => false;
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
  bool allowSignIn = true;
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
  Future<bool> signIn() async => signedIn = allowSignIn && !offline;

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
