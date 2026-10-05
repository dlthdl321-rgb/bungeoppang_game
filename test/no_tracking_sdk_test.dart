import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The privacy policy and Play data safety form promise no ads, IAP or
// analytics. Fail fast if a dependency (direct or transitive) breaks that.
const _forbidden = <String>[
  'admob',
  'google_mobile_ads',
  'ads',
  'in_app_purchase',
  'purchases',
  'billing',
  'revenuecat',
  'firebase',
  'analytics',
  'crashlytics',
  'sentry',
  'amplitude',
  'mixpanel',
  'appsflyer',
  'adjust',
  'facebook',
  'unity_ads',
  'applovin',
  'play_games',
  'games_services',
];

final _packageLine = RegExp(r'^  ([a-z0-9_]+):\s*$', multiLine: true);

void main() {
  test('pubspec.lock has no ad, purchase, analytics or games SDK', () {
    final packages = _packageLine
        .allMatches(File('pubspec.lock').readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();
    expect(packages, isNotEmpty);
    // Match whole name segments so e.g. `path` never trips on `ads`.
    bool isForbidden(String p) => _forbidden
        .any((f) => f.contains('_') ? p.contains(f) : p.split('_').contains(f));
    final hits = packages.where(isForbidden).toList();
    expect(hits, isEmpty);
  });

  test('Android Gradle files add no Play services or Firebase', () {
    for (final path in [
      'android/build.gradle.kts',
      'android/app/build.gradle.kts'
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('com.google.gms')), reason: path);
      expect(text, isNot(contains('com.google.firebase')), reason: path);
      expect(text, isNot(contains('play-services')), reason: path);
    }
  });

  test('main manifest requests no network or ad permission', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('android.permission.INTERNET')));
    expect(manifest, isNot(contains('AD_ID')));
  });
}
