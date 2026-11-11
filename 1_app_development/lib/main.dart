import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'billing_service.dart';
import 'firebase_online_backend.dart';
import 'game_audio.dart';
import 'game_controller.dart';
import 'online_backend.dart';
import 'online_ranking.dart';
import 'play_billing_service.dart';
import 'repository.dart';
import 'save_quarantine.dart';
import 'server_invite_repository.dart';
import 'time_service.dart';
import 'development_balance_asset.dart';
import 'workshop_controller.dart';
import 'workshop_online.dart';
import 'ui/game_app.dart';
import 'ui/pixel_sprites.dart';
import 'ui/save_recovery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final android = defaultTargetPlatform == TargetPlatform.android;
  // Online features (Kakao login, ranking, friends, visits, invitations,
  // 황금 붕어빵) only in an Android build made with the Firebase settings
  // and the Kakao native app key (firebase_online_backend.dart).
  final withOnline = android && firebaseConfigured;
  if (withOnline) await KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  final online = withOnline
      ? await FirebaseOnlineBackend.create()
      : const NoOnlineBackend();
  await _start(online);
}

/// Reads the saves and runs the game, or the recovery screen when a read
/// fails. Retrying and starting over both come back here.
Future<void> _start(OnlineBackend online, {int attempts = 0}) async {
  final accounts = SqliteGameRepository(), workshops = SqliteWorkshopRepository();
  final controller = GameController(accounts, SystemTimeService(),
      ranking: online.configured
          ? ServerRankingService(online)
          : const NoRankingService(),
      online: online,
      billing:
          online.configured ? PlayBillingService() : const NoBillingService(),
      invitationRepository:
          online.configured ? ServerInvitationRepository(online) : null);
  final audio = AudioplayersAudio();
  await PixelSprites.load();
  WorkshopController? workshop;
  var stage = SaveStage.account;
  try {
    await controller.initialize();
    stage = SaveStage.config;
    final config = await loadDevelopmentBalance();
    stage = SaveStage.workshop;
    workshop = WorkshopController(config, workshops,
      purchaseGateway: online is WorkshopTransport ? WorkshopOnline(online as WorkshopTransport) : null);
    await workshop.initialize();
    runApp(GameApp(controller: controller, audio: audio, workshop: workshop));
  } catch (e) {
    workshop?.dispose();
    controller.dispose();
    await audio.dispose();
    await accounts.close();
    await workshops.close();
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
          await _start(online, attempts: attempts + 1);
        },
        onStartFresh: failed == SaveStage.config ? null : () async {
          await setAsideDatabaseFile(
              failed == SaveStage.account
                  ? await SqliteGameRepository.defaultPath()
                  : await SqliteWorkshopRepository.defaultPath(),
              DateTime.now());
          await _start(online);
        }));
  }
}
