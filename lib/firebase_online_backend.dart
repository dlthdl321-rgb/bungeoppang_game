import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'invite_models.dart';
import 'online_backend.dart';

// Firebase project settings, passed at build time so they stay out of the
// repository (docs/stage15_release_online.md):
//   flutter build appbundle --dart-define=FIREBASE_API_KEY=...
//     --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=...
//     --dart-define=FIREBASE_PROJECT_ID=...
// Without them the app runs with NoOnlineBackend (online features hidden).
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const firebaseConfigured = _apiKey != '' &&
    _appId != '' &&
    _senderId != '' &&
    _projectId != '';

/// The region of the Cloud Functions (firebase/functions/src/index.ts).
const functionsRegion = 'asia-northeast3';

class FirebaseOnlineBackend implements OnlineBackend {
  static const _playGames = MethodChannel('todays_bungeoppang/play_games');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  FirebaseOnlineBackend._(this._auth, this._functions);

  /// The real backend when this build has a Firebase project, else
  /// [NoOnlineBackend]. Never throws.
  static Future<OnlineBackend> create() async {
    if (!firebaseConfigured) return const NoOnlineBackend();
    try {
      final app = await Firebase.initializeApp(
          options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _senderId,
              projectId: _projectId));
      return FirebaseOnlineBackend._(FirebaseAuth.instanceFor(app: app),
          FirebaseFunctions.instanceFor(app: app, region: functionsRegion));
    } catch (_) {
      return const NoOnlineBackend();
    }
  }

  @override
  bool get configured => true;

  @override
  bool get signedIn => _auth.currentUser != null;

  @override
  String? get displayName => _auth.currentUser?.displayName;

  @override
  Future<bool> signIn() async {
    if (signedIn) return true;
    try {
      final status = await _playGames.invokeMapMethod<String, Object?>('status');
      if (status?['configured'] != true) return false;
      if (status?['authenticated'] != true &&
          await _playGames.invokeMethod<bool>('signIn') != true) {
        return false;
      }
      final code = await _playGames.invokeMethod<String>('serverAuthCode');
      if (code == null || code.isEmpty) return false;
      await _auth.signInWithCredential(
          PlayGamesAuthProvider.credential(serverAuthCode: code));
      return signedIn;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on FirebaseAuthException {
      return false;
    }
  }

  Future<Map<String, Object?>> _call(String name,
      [Map<String, Object?> data = const {}]) async {
    if (!signedIn) throw const OnlineException(OnlineFailure.signedOut);
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final value = result.data;
      return value is Map ? Map<String, Object?>.from(value) : const {};
    } on FirebaseFunctionsException catch (e) {
      final reason = e.details is Map ? (e.details as Map)['reason'] : null;
      throw OnlineException(
          switch ((e.code, reason)) {
            ('unauthenticated' || 'permission-denied', _) =>
              OnlineFailure.signedOut,
            (_, 'insufficient') => OnlineFailure.insufficient,
            (_, 'pending') => OnlineFailure.pending,
            (_, 'already-owned') => OnlineFailure.alreadyOwned,
            (_, 'already-visited') => OnlineFailure.alreadyOwned,
            (_, 'already-accepted') => OnlineFailure.alreadyAccepted,
            ('not-found', _) => OnlineFailure.notFound,
            ('invalid-argument' || 'already-exists' || 'failed-precondition' ||
                  'resource-exhausted',
              _) =>
              OnlineFailure.rejected,
            _ => OnlineFailure.unavailable,
          },
          e.message ?? e.code);
    } on PlatformException {
      throw const OnlineException(OnlineFailure.unavailable);
    }
  }

  static Map<String, String> _look(Object? raw) => raw is Map
      ? {
          for (final e in raw.entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String
        }
      : const {};

  static DateTime _at(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch((ms as num).toInt(), isUtc: true);

  static WalletGrant _grant(Map g) => WalletGrant(
      id: g['id'] as String,
      kind: PremiumKind.values.byName(g['kind'] as String),
      itemId: g['itemId'] as String,
      consumable: g['consumable'] == true,
      atUtc: _at(g['atMs']));

  @override
  Future<WalletSnapshot> syncWallet() async {
    final r = await _call('walletSync');
    return WalletSnapshot((r['gold'] as num).toInt(), [
      for (final g in r['grants'] as List? ?? const []) _grant(g as Map)
    ]);
  }

  @override
  Future<int> redeemPurchase(String productId, String purchaseToken) async {
    final r = await _call('walletRedeem',
        {'productId': productId, 'purchaseToken': purchaseToken});
    return (r['gold'] as num).toInt();
  }

  @override
  Future<(int, WalletGrant)> spend(
      String requestId, PremiumKind kind, String itemId) async {
    final r = await _call('walletSpend',
        {'requestId': requestId, 'kind': kind.name, 'itemId': itemId});
    return ((r['gold'] as num).toInt(), _grant(r['grant'] as Map));
  }

  @override
  Future<void> setProfile(Map<String, String> look, String name) =>
      _call('profileSet', {'look': look, 'name': name});

  static FriendInfo _friend(Map f) => FriendInfo(
      playerId: f['playerId'] as String,
      name: f['name'] as String? ?? '친구',
      look: _look(f['look']),
      visitedToday: f['visitedToday'] == true);

  @override
  Future<FriendInfo> addFriend(String code) async =>
      _friend(await _call('friendAdd', {'code': code}));

  @override
  Future<List<FriendInfo>> friends() async => [
        for (final f in (await _call('friendList'))['friends'] as List? ??
            const [])
          _friend(f as Map)
      ];

  @override
  Future<void> visitFriend(String playerId) =>
      _call('friendVisit', {'playerId': playerId});

  @override
  Future<List<ServerVisit>> fetchVisits(Set<String> applied) async => [
        for (final v in (await _call('visitsFetch', {
              'applied': applied.toList()
            }))['visits'] as List? ??
            const [])
          ServerVisit(
              id: (v as Map)['id'] as String,
              name: v['name'] as String? ?? '친구',
              invite: v['kind'] == 'invite',
              look: _look(v['look']))
      ];

  @override
  Future<InviteProfile> inviteRegister() async {
    final r = await _call('inviteRegister');
    return InviteProfile(r['playerId'] as String, r['referralCode'] as String,
        InviteOrigin.server);
  }

  @override
  Future<InviteTicket> inviteCreateTicket(String missionToken) async {
    final r = await _call('inviteCreateTicket', {'missionToken': missionToken});
    return InviteTicket(r['id'] as String, r['missionToken'] as String,
        r['url'] as String, _at(r['createdAtMs']), InviteOrigin.server);
  }

  @override
  Future<bool> inviteAccept(String code, {String? ticketId}) async {
    final r = await _call('inviteAccept', {
      'code': code,
      if (ticketId != null) 'ticketId': ticketId,
    });
    return r['isNew'] == true;
  }

  @override
  Future<void> inviteReachedLevelOne() => _call('inviteLevelOne');

  @override
  Future<List<InviteEvent>> inviteFetchEvents(Set<String> committed) async => [
        for (final e in (await _call('inviteFetchEvents', {
              'committed': committed.toList()
            }))['events'] as List? ??
            const [])
          InviteEvent(
              eventId: (e as Map)['eventId'] as String,
              ticketId: e['ticketId'] as String,
              visitId: e['visitId'] as String,
              playerId: e['playerId'] as String,
              kind: InviteEventKind.values.byName(e['kind'] as String),
              atUtc: _at(e['atMs']),
              origin: InviteOrigin.server)
      ];
}
