import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'billing_service.dart';
import 'firebase_online_backend.dart';
import 'game_audio.dart';
import 'game_controller.dart';
import 'online_backend.dart';
import 'online_ranking.dart';
import 'play_billing_service.dart';
import 'repository.dart';
import 'server_invite_repository.dart';
import 'time_service.dart';
import 'ui/game_app.dart';
import 'ui/pixel_sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final android = defaultTargetPlatform == TargetPlatform.android;
  // Online features (friends, visits, invitations, 황금 붕어빵) only in an
  // Android build made with the Firebase settings (firebase_online_backend).
  final online = android
      ? await FirebaseOnlineBackend.create()
      : const NoOnlineBackend();
  final controller = GameController(SqliteGameRepository(), SystemTimeService(),
      ranking: android
          ? const PlayGamesRankingService()
          : const NoRankingService(),
      online: online,
      billing: online.configured ? PlayBillingService() : const NoBillingService(),
      invitationRepository:
          online.configured ? ServerInvitationRepository(online) : null);
  final audio = AudioplayersAudio();
  await PixelSprites.load();
  try {
    await controller.initialize();
    runApp(GameApp(controller: controller, audio: audio));
  } catch (_) {
    runApp(RecoveryApp(controller: controller, audio: audio));
  }
}
