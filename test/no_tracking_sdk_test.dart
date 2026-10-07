import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The privacy policy and Play data safety form promise no ads, analytics or
// crash reporting. Since stage 15 the app signs in to Firebase (Auth,
// Functions) and sells 황금 붕어빵 through Google Play Billing; those exact
// packages are allowed, nothing else in their families.
const _allowed = <String>{
  'firebase_core',
  'firebase_core_platform_interface',
  'firebase_core_web',
  'firebase_auth',
  'firebase_auth_platform_interface',
  'firebase_auth_web',
  'cloud_functions',
  'cloud_functions_platform_interface',
  'cloud_functions_web',
  '_flutterfire_internals',
  'in_app_purchase',
  'in_app_purchase_android',
  'in_app_purchase_platform_interface',
  'in_app_purchase_storekit',
};
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

// Plugins can add permissions/components that only appear after Gradle merges
// manifests, so the shipped (release) result is checked when it exists.
const _releaseManifestPaths = [
  'build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml',
  'build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml',
];
const _manifestSources = [
  'android/app/src/main/AndroidManifest.xml',
  'android/app/build.gradle.kts',
  'pubspec.lock',
];
// Play Games Services v2, Firebase Auth/Functions (network) and Play
// Billing are expected since stage 15. Ads, the ad ID, ad services, Google
// Analytics measurement and Crashlytics must never appear.
const _forbiddenManifestEntries = <String>[
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES',
  'com.google.android.gms.ads',
  'com.google.android.gms.measurement',
  'com.google.firebase.analytics',
  'com.google.firebase.crashlytics',
];

List<String> manifestViolations(String xml) =>
    _forbiddenManifestEntries.where(xml.contains).toList();

/// The newest release merged manifest, or why it cannot be checked.
({File? file, String? skip}) releaseManifest() {
  final found =
      _releaseManifestPaths.map(File.new).where((f) => f.existsSync());
  if (found.isEmpty) {
    return (
      file: null,
      skip: 'release 병합 매니페스트 없음(${_releaseManifestPaths.first}). '
          '`flutter build apk --release` 또는 `flutter build appbundle` 후 다시 실행하세요.'
    );
  }
  final file = found.reduce(
      (a, b) => a.lastModifiedSync().isAfter(b.lastModifiedSync()) ? a : b);
  final built = file.lastModifiedSync();
  final stale = _manifestSources
      .where((p) => File(p).existsSync())
      .where((p) => File(p).lastModifiedSync().isAfter(built))
      .toList();
  if (stale.isNotEmpty) {
    return (
      file: null,
      skip: 'release 병합 매니페스트(${file.path})가 ${stale.join(', ')}보다 오래됨. '
          'release 빌드를 다시 만든 뒤 실행하세요.'
    );
  }
  return (file: file, skip: null);
}

void main() {
  test('pubspec.lock has no ad, analytics or tracking SDK', () {
    final packages = _packageLine
        .allMatches(File('pubspec.lock').readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();
    expect(packages, isNotEmpty);
    // Match whole name segments so e.g. `path` never trips on `ads`.
    bool isForbidden(String p) => _forbidden
        .any((f) => f.contains('_') ? p.contains(f) : p.split('_').contains(f));
    final hits = packages
        .where((p) => !_allowed.contains(p))
        .where(isForbidden)
        .toList();
    expect(hits, isEmpty);
  });

  test('Android Gradle files add only Play Games Services v2 and no Firebase '
      'analytics', () {
    for (final path in [
      'android/build.gradle.kts',
      'android/app/build.gradle.kts'
    ]) {
      final text = File(path).readAsStringSync();
      // Firebase is set up in Dart (FirebaseOptions), not by the
      // google-services plugin, which could pull in analytics.
      expect(text, isNot(contains('com.google.gms')), reason: path);
      expect(text, isNot(contains('firebase-analytics')), reason: path);
      final services = RegExp(r'play-services-[a-z0-9-]+')
          .allMatches(text)
          .map((m) => m.group(0))
          .toSet();
      expect(services.difference({'play-services-games-v2'}), isEmpty,
          reason: path);
    }
  });

  test('main manifest requests no ad permission', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('AD_ID')));
  });

  test('pubspec.lock 허용 목록 밖의 Firebase·결제 패키지는 여전히 걸린다', () {
    bool isForbidden(String p) => !_allowed.contains(p) &&
        _forbidden.any(
            (f) => f.contains('_') ? p.contains(f) : p.split('_').contains(f));
    expect(isForbidden('firebase_auth'), isFalse);
    expect(isForbidden('in_app_purchase_android'), isFalse);
    expect(isForbidden('firebase_analytics'), isTrue);
    expect(isForbidden('firebase_crashlytics'), isTrue);
    expect(isForbidden('google_mobile_ads'), isTrue);
  });

  test('병합 매니페스트 검사는 금지 권한·SDK 항목을 찾아낸다', () {
    const clean = '<manifest><application android:label="x"/></manifest>';
    expect(manifestViolations(clean), isEmpty);
    const games = '<manifest>'
        '<meta-data android:name="com.google.android.gms.games.APP_ID"/>'
        '<provider android:name="com.google.android.gms.games.provider.PlayGamesInitProvider"/>'
        '</manifest>';
    expect(manifestViolations(games), isEmpty);
    const online = '<manifest>'
        '<uses-permission android:name="android.permission.INTERNET"/>'
        '<uses-permission android:name="com.android.vending.BILLING"/>'
        '<service android:name="com.google.firebase.components.ComponentDiscoveryService"/>'
        '</manifest>';
    expect(manifestViolations(online), isEmpty);
    const dirty = '<manifest>'
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>'
        '<service android:name="com.google.android.gms.measurement.AppMeasurementService"/>'
        '<service android:name="com.google.firebase.analytics.connector.x"/>'
        '</manifest>';
    expect(manifestViolations(dirty), [
      'com.google.android.gms.permission.AD_ID',
      'com.google.android.gms.measurement',
      'com.google.firebase.analytics',
    ]);
  });

  final release = releaseManifest();
  test('release 병합 매니페스트에 광고·광고 ID·분석 항목이 없다', () {
    expect(manifestViolations(release.file!.readAsStringSync()), isEmpty,
        reason: release.file!.path);
  }, skip: release.skip ?? false);
}
