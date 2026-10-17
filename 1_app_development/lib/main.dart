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
import 'server_invite_repository.dart';
import 'time_service.dart';
import 'development_balance_asset.dart';
import 'workshop_controller.dart';
import 'workshop_online.dart';
import 'ui/game_app.dart';
import 'ui/pixel_sprites.dart';

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
  final controller = GameController(SqliteGameRepository(), SystemTimeService(),
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
  try {
    await controller.initialize();
    final config = await loadDevelopmentBalance();
    workshop = WorkshopController(config, SqliteWorkshopRepository(),
      purchaseGateway: online is WorkshopTransport ? WorkshopOnline(online as WorkshopTransport) : null);
    await workshop.initialize();
    runApp(GameApp(controller: controller, audio: audio, workshop: workshop));
  } catch (_) {
    workshop?.dispose();
    controller.dispose();
    await audio.dispose();
    runApp(const _StartupFailure());
  }
}

class _StartupFailure extends StatefulWidget {
  const _StartupFailure();
  @override
  State<_StartupFailure> createState() => _StartupFailureState();
}
class _StartupFailureState extends State<_StartupFailure> {
  bool retrying = false;
  @override
  Widget build(BuildContext context) => MaterialApp(home: Scaffold(body: SafeArea(child: Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('저장을 확인하지 못했어요. 다시 시도해 주세요.'),
      FilledButton(onPressed: retrying ? null : () async {
        setState(() => retrying = true);
        await main();
      }, child: const Text('다시 읽기')),
    ]),
  ))));
}
