import 'dart:async';
import 'package:todays_bungeoppang/ui/sparkle_art.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';

/// Runs before every test file in this folder.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // An endless weather animation would keep pumpAndSettle from settling;
  // tests see one still frame instead.
  WeatherLayer.animate = false;
  TwinklingSparkles.animate = false;
  await testMain();
}
