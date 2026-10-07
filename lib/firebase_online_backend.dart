import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'invite_models.dart';
import 'online_backend.dart';

// Firebase project settings, passed at build time so they stay out of the
// repository (docs/stage15_release_online.md):
//   flutter build appbundle --dart-define=FIREBASE_API_KEY=...
//     --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=...
//     --dart-define=FIREBASE_PROJECT_ID=...
//     --dart-define=KAKAO_NATIVE_APP_KEY=...
// Without them the app runs with NoOnlineBackend (online features hidden).
// The Kakao key also goes into the Android manifest (build.gradle.kts).
const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const firebaseConfigured = _apiKey != '' &&
    _appId != '' &&
    _senderId != '' &&
    _projectId != '' &&
    kakaoNativeAppKey != '';

/// The region of the Cloud Functions (firebase/functions/src/index.ts).
const functionsRegion = 'asia-northeast3';

class FirebaseOnlineBackend implements OnlineBackend {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  String? _kakaoName;
  FirebaseOnlineBackend._(this._auth, this._functions);

  /// The real backend when this build has a Firebase project and a Kakao
  /// key (KakaoSdk.init is done in main), else [NoOnlineBackend]. Never
  /// throws. Firebase keeps the session, so a restart stays signed in.
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
  String? get displayName => _auth.currentUser?.displayName ?? _kakaoName;

  @override
  Future<SignInResult> signIn() async {
    if (signedIn) return SignInResult.success;
    try {
      final kakao = await _kakaoLogin();
      if (kakao == null) return SignInResult.canceled;
      final r = await _functions
          .httpsCallable('authKakao')
          .call<Object?>({'accessToken': kakao.accessToken});
      final data = r.data is Map ? r.data as Map : const {};
      final token = data['token'];
      if (token is! String) return SignInResult.failed;
      _kakaoName = data['displayName'] as String?;
      await _auth.signInWithCustomToken(token);
      return signedIn ? SignInResult.success : SignInResult.failed;
    } on FirebaseFunctionsException {
      return SignInResult.failed;
    } on FirebaseAuthException {
      return SignInResult.failed;
    } on KakaoException {
      return SignInResult.failed;
    } on PlatformException {
      return SignInResult.failed;
    } on MissingPluginException {
      return SignInResult.failed;
    }
  }

  /// KakaoTalk first; if it is missing or fails (not logged in there, an
  /// old version, ...) the Kakao account page. Null when the player backed
  /// out.
  static Future<OAuthToken?> _kakaoLogin() async {
    final user = UserApi.instance;
    if (await isKakaoTalkInstalled()) {
      try {
        return await user.loginWithKakaoTalk();
      } catch (e) {
        if (_canceled(e)) return null;
      }
    }
    try {
      return await user.loginWithKakaoAccount();
    } catch (e) {
      if (_canceled(e)) return null;
      rethrow;
    }
  }

  static bool _canceled(Object e) =>
      (e is PlatformException && e.code == 'CANCELED') ||
      (e is KakaoAuthException && e.error == AuthErrorCause.accessDenied) ||
      (e is KakaoClientException && e.reason == ClientErrorCause.cancelled);

  @override
  Future<void> signOut() async {
    _kakaoName = null;
    await _auth.signOut();
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // Kakao clears its token even when the logout call fails.
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
            (
              'invalid-argument' ||
                  'already-exists' ||
                  'failed-precondition' ||
                  'resource-exhausted',
              _
            ) =>
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
    return WalletSnapshot((r['gold'] as num).toInt(),
        [for (final g in r['grants'] as List? ?? const []) _grant(g as Map)]);
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
        for (final f
            in (await _call('friendList'))['friends'] as List? ?? const [])
          _friend(f as Map)
      ];

  @override
  Future<void> visitFriend(String playerId) =>
      _call('friendVisit', {'playerId': playerId});

  @override
  Future<List<ServerVisit>> fetchVisits(Set<String> applied) async => [
        for (final v in (await _call(
                    'visitsFetch', {'applied': applied.toList()}))['visits']
                as List? ??
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
        for (final e in (await _call('inviteFetchEvents',
                {'committed': committed.toList()}))['events'] as List? ??
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

  @override
  Future<void> rankingSubmit(Map<String, int> scores) =>
      // As strings: scores reach 2^63-1, past what JSON numbers keep exact.
      _call('rankingSubmit',
          {for (final e in scores.entries) e.key: e.value.toString()});

  @override
  Future<RankingBoard> rankingTop(String board) async {
    final r = await _call('rankingTop', {'board': board});
    final me = r['me'];
    return RankingBoard(
        board,
        [
          for (final e in r['entries'] as List? ?? const [])
            RankingEntry(
                rank: ((e as Map)['rank'] as num).toInt(),
                playerId: e['playerId'] as String,
                name: e['name'] as String? ?? '친구',
                score: BigInt.parse(e['score'] as String),
                look: _look(e['look']),
                me: e['me'] == true)
        ],
        me is Map
            ? (
                rank: (me['rank'] as num).toInt(),
                score: BigInt.parse(me['score'] as String)
              )
            : null);
  }
}
