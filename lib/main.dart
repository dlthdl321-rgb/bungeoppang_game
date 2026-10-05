import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'game_controller.dart';
import 'online_ranking.dart';
import 'repository.dart';
import 'time_service.dart';
import 'ui/game_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final controller = GameController(SqliteGameRepository(), SystemTimeService(),
      ranking: defaultTargetPlatform == TargetPlatform.android
          ? const PlayGamesRankingService()
          : const NoRankingService());
  try {
    await controller.initialize();
    runApp(GameApp(controller: controller));
  } catch (_) {
    runApp(RecoveryApp(controller: controller));
  }
}
