import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'development_balance.dart';

class CookingTiltSample {
  final bool available;
  final int? angleMillidegrees;
  const CookingTiltSample.unavailable()
      : available = false,
        angleMillidegrees = null;
  const CookingTiltSample.angle(int angle)
      : available = true,
        angleMillidegrees = angle;
  factory CookingTiltSample.fromEvent(dynamic event) {
    if (event is! Map || event['available'] != true) {
      return const CookingTiltSample.unavailable();
    }
    if (event.containsKey('gravityX')) {
      final x = event['gravityX'], y = event['gravityY'], z = event['gravityZ'];
      if (x is! num ||
          y is! num ||
          z is! num ||
          !x.isFinite ||
          !y.isFinite ||
          !z.isFinite ||
          x * x + y * y + z * z < .000001) {
        return const CookingTiltSample.unavailable();
      }
      // Includes Z so a phone held flat has a stable neutral position too.
      return CookingTiltSample.angle(
          (math.atan2(-x, math.sqrt(y * y + z * z)) * 180000 / math.pi)
              .round());
    }
    return event['angleMillidegrees'] is int
        ? CookingTiltSample.angle(event['angleMillidegrees'] as int)
        : const CookingTiltSample.unavailable();
  }
}

/// Consumers subscribe only during active sensor input, cancel on pause/source
/// switch/dispose, and recalibrate before each resume. Touch remains available.
class CookingTiltSource {
  final EventChannel channel;
  final bool supported;
  CookingTiltSource({EventChannel? channel, bool? supported})
      : channel =
            channel ?? const EventChannel('todays_bungeoppang/cooking_tilt'),
        supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  Stream<CookingTiltSample> samples(DevelopmentBalance config) async* {
    if (!supported) {
      yield const CookingTiltSample.unavailable();
      return;
    }
    final interval = DevelopmentBalance.integer(
        config.section('manual_cooking'), 'tilt_sampling_ms');
    if (interval <= 0) throw const FormatException('센서 입력 간격 오류');
    try {
      await for (final event
          in channel.receiveBroadcastStream({'samplingMs': interval})) {
        final sample = CookingTiltSample.fromEvent(event);
        yield sample;
        if (!sample.available) return;
      }
    } on PlatformException {
      yield const CookingTiltSample.unavailable();
    } on MissingPluginException {
      yield const CookingTiltSample.unavailable();
    }
  }
}
