import 'dart:async';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/sparkle_art.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/ui/workshop_fairy.dart';

/// Runs before every test file in this folder.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // An endless weather animation would keep pumpAndSettle from settling;
  // tests see one still frame instead.
  WeatherLayer.animate = false;
  TwinklingSparkles.animate = false;
  FairyMotion.animate = false;
  WorkshopStatusBadge.animate = false;
  // 4차 피드백 g10: the default day/night follows the clock; tests see noon.
  sceneClock = () => DateTime(2026, 11, 2, 12);
  await testMain();
}
