import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'game_audio.dart';
import 'game_controller.dart';
import 'online_ranking.dart';
import 'repository.dart';
import 'time_service.dart';
import 'ui/game_app.dart';
import 'ui/pixel_sprites.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = GameController(SqliteGameRepository(), SystemTimeService(),
      ranking: defaultTargetPlatform == TargetPlatform.android
          ? const PlayGamesRankingService()
          : const NoRankingService());
  final audio = AudioplayersAudio();
  await PixelSprites.load();
  try {
    await controller.initialize();
    runApp(GameApp(controller: controller, audio: audio));
  } catch (_) {
    runApp(RecoveryApp(controller: controller, audio: audio));
  }
}
