import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'development_balance.dart';

class CookingTiltSample {
  final bool available;
  final int? angleMillidegrees;
  const CookingTiltSample.unavailable() : available = false, angleMillidegrees = null;
  const CookingTiltSample.angle(int angle) : available = true, angleMillidegrees = angle;
}

/// Consumers subscribe only during active sensor input, cancel on pause/source
/// switch/dispose, and recalibrate before each resume. Touch remains available.
class CookingTiltSource {
  final EventChannel channel;
  final bool supported;
  CookingTiltSource({EventChannel? channel, bool? supported})
      : channel = channel ?? const EventChannel('todays_bungeoppang/cooking_tilt'),
        supported = supported ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  Stream<CookingTiltSample> samples(DevelopmentBalance config) async* {
    if (!supported) {
      yield const CookingTiltSample.unavailable();
      return;
    }
    final interval = DevelopmentBalance.integer(config.section('manual_cooking'), 'tilt_sampling_ms');
    if (interval <= 0) throw const FormatException('센서 입력 간격 오류');
    try {
      await for (final event in channel.receiveBroadcastStream({'samplingMs': interval})) {
        if (event is! Map || event['available'] != true || event['angleMillidegrees'] is! int) {
          yield const CookingTiltSample.unavailable();
          return;
        }
        yield CookingTiltSample.angle(event['angleMillidegrees'] as int);
      }
    } on PlatformException {
      yield const CookingTiltSample.unavailable();
    } on MissingPluginException {
      yield const CookingTiltSample.unavailable();
    }
  }
}
