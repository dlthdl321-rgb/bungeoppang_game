import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'billing_service.dart';
import 'firebase_online_backend.dart';
import 'firebase_usage_stats.dart';
import 'game_audio.dart';
import 'game_controller.dart';
import 'online_backend.dart';
import 'online_ranking.dart';
import 'owner_account.dart';
import 'owner_profile.dart';
import 'owner_repository.dart';
import 'play_billing_service.dart';
import 'repository.dart';
import 'save_quarantine.dart';
import 'server_invite_repository.dart';
import 'time_service.dart';
import 'usage_stats.dart';
import 'development_balance_asset.dart';
import 'workshop_controller.dart';
import 'workshop_online.dart';
import 'customer_notifier.dart';
import 'local_test_purchases.dart';
import 'invite_reward_rules.dart';
import 'workshop_friend_visits.dart';
import 'ui/connection_notice.dart';
import 'ui/game_app.dart';
import 'ui/pixel_sprites.dart';
import 'ui/save_recovery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final android = defaultTargetPlatform == TargetPlatform.android;
  // Online features (Kakao or Google login, ranking, friends, visits,
  // invitations, 황금 붕어빵) only in an Android build made with the Firebase
  // settings and the Kakao native app key (firebase_online_backend.dart).
  // Such a build asks every new player to log in first (26번 2-1단계).
  final withOnline = android && firebaseConfigured;
  // 4차 피드백 IC10: the game is online-only. A release build made without
  // the online settings could never reach the server (no login, level-up or
  // purchase), so it shows only why and how to fix it. A debug build
  // without them still runs for development, with a band that says so.
  if (kReleaseMode && !withOnline) {
    await PixelSprites.load();
    runApp(const OnlineSetupMissingApp());
    return;
  }
  if (withOnline) await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  final online = withOnline
      ? await FirebaseOnlineBackend.create()
      : const NoOnlineBackend();
  // 사용 통계(26번 5단계): Firebase Analytics only where Firebase started,
  // for every player (signed in or not); the setting can turn it off. It
  // starts only after the first-run required consent (DEC-126):
  // OwnerAccount.load()/saves call setConsented.
  final usage = online.configured
      ? UsageStats(FirebaseUsageStatsSink(), consented: false)
      : UsageStats.none;
  await _start(online, usage);
}

/// Reads the saves and runs the game, or the recovery screen when a read
/// fails. Retrying and starting over both come back here.
Future<void> _start(OnlineBackend online, UsageStats usage, {int attempts = 0}) async {
  final accounts = SqliteGameRepository(), workshops = SqliteWorkshopRepository();
  final owners = SqliteOwnerProfileRepository();
  final controller = GameController(accounts, SystemTimeService(),
      ranking: online.configured
          ? ServerRankingService(online)
          : const NoRankingService(),
      online: online,
      billing:
          online.configured ? PlayBillingService() : const NoBillingService(),
      invitationRepository:
          online.configured ? ServerInvitationRepository(online) : null,
      usage: usage);
  final audio = AudioplayersAudio();
  await PixelSprites.load();
  WorkshopController? workshop;
  var stage = SaveStage.account;
  try {
    await controller.initialize();
    stage = SaveStage.config;
    final config = await loadDevelopmentBalance();
    final nameRules = OwnerNameRules.fromJson(
        jsonDecode(await rootBundle.loadString('config/owner_name_rules.json')) as Map<String, dynamic>);
    stage = SaveStage.workshop;
    workshop = WorkshopController(config, workshops,
      // A build without the online settings (debug/profile only; a release
      // one stopped above) levels up and buys on this device, marked as a
      // test save (local_test_purchases.dart, 4차 피드백 IC10 후속).
      purchaseGateway: online is WorkshopTransport
          ? WorkshopOnline(online as WorkshopTransport)
          : LocalTestPurchaseGateway(
              gold: () => controller.state.premium.gold, setGold: controller.setLocalTestGold),
      usage: usage);
    await workshop.initialize();
    // 29번 친구 초대: the invitation's goal is the new game's level.
    final inviteRules = InviteRewardRules.fromConfig(config), shop = workshop;
    controller.inviteGoalReached = () => inviteRules.goalReached(shop.state.level);
    // DEC-154: friends' visits boost the new game's production.
    controller.seenFriendVisits = () => shop.seenFriendVisits;
    controller.onFriendVisits = (visits) => shop.applyFriendVisits([
          for (final v in visits) FriendVisitArrival(id: v.id, name: v.name, invite: v.invite)]);
    // 26번 2-1단계: login, owner name and character before the game.
    final owner = OwnerAccount(
        repository: owners,
        online: online,
        rules: nameRules,
        game: controller,
        workshop: workshop,
        analytics: UsageOwnerAnalytics(usage));
    owner.onDeleted = () => _wipeAndRestart(online, usage, accounts, workshops, owners);
    await owner.load();
    runApp(GameApp(controller: controller, audio: audio, workshop: workshop, owner: owner,
        devBuildBand: !online.configured,
        notifier: defaultTargetPlatform == TargetPlatform.android
            ? (!kReleaseMode && _noticeSelfTest ? _SelfTestNotifier(LocalCustomerNotifier()) : LocalCustomerNotifier())
            : null));
  } catch (e) {
    workshop?.dispose();
    controller.dispose();
    await audio.dispose();
    await accounts.close();
    await workshops.close();
    await owners.close();
    final failed = stage;
    runApp(SaveRecoveryApp(
        failure: SaveFailure(failed, '$e', DateTime.now()),
        attempts: attempts,
        onRetry: () async {
          // The account store keeps a previous snapshot; the workshop store
          // already falls back to its latest witnessed checkpoint on read.
          if (failed == SaveStage.account) {
            try { await accounts.restoreBackup(); } catch (_) {}
            await accounts.close();
          }
          await _start(online, usage, attempts: attempts + 1);
        },
        onStartFresh: failed == SaveStage.config ? null : () async {
          await setAsideDatabaseFile(
              failed == SaveStage.account
                  ? await SqliteGameRepository.defaultPath()
                  : await SqliteWorkshopRepository.defaultPath(),
              DateTime.now());
          await _start(online, usage);
        }));
  }
}

/// After an account deletion (26번 2-1단계): close the game, delete this
/// device's saves (account, workshop, owner profile) and start like a new
/// install.
Future<void> _wipeAndRestart(OnlineBackend online, UsageStats usage, SqliteGameRepository accounts,
    SqliteWorkshopRepository workshops, SqliteOwnerProfileRepository owners) async {
  // Unmounting GameApp disposes the controllers and stops their timers.
  runApp(const SizedBox.shrink());
  await WidgetsBinding.instance.endOfFrame;
  await accounts.close();
  await workshops.close();
  await owners.close();
  for (final path in [
    await SqliteGameRepository.defaultPath(),
    await SqliteWorkshopRepository.defaultPath(),
    await SqliteOwnerProfileRepository.defaultPath(),
  ]) {
    await deleteDatabase(path);
  }
  await _start(online, usage);
}

/// Debug builds made with `--dart-define=CUSTOMER_NOTICE_SELFTEST=true` add
/// one test notice a minute after the app goes to the background, so the
/// device notification path (permission, receivers, inexact alarm) can be
/// checked on an emulator without waiting for a real guest (26번 5-1단계).
const _noticeSelfTest = bool.fromEnvironment('CUSTOMER_NOTICE_SELFTEST');

class _SelfTestNotifier implements CustomerNotifier {
  final CustomerNotifier inner;
  _SelfTestNotifier(this.inner);
  @override
  Future<void> schedule(List<PlannedNotice> notices) => inner.schedule([...notices,
    PlannedNotice(id: 999, at: DateTime.now().toUtc().add(const Duration(minutes: 1)), title: customerNoticeTitle,
        body: '[시험] $regularNoticeBody')]);
  @override
  Future<void> cancelAll() => inner.cancelAll();
  @override
  Future<bool> requestPermission() => inner.requestPermission();
  @override
  Future<bool> hasPermission() => inner.hasPermission();
}
