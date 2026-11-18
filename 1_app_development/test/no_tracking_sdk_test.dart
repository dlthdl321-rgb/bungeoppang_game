import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The privacy policy and Play data safety form promise no ads, analytics or
// crash reporting. Since stage 15 the app signs in to Firebase (Auth,
// Functions) and sells 황금 붕어빵 through Google Play Billing; those exact
// packages are allowed, nothing else in their families. Since stage 16 it
// logs in with the Kakao SDK (kakao_flutter_sdk_user: login only).
// Since plan 23 stage 7 the server enforces Firebase App Check, so the app
// attests itself with firebase_app_check (Play Integrity; no ads or analytics).
// 26번 5-1단계: device-only customer notifications with
// flutter_local_notifications (+ timezone). They schedule on the device and
// send nothing anywhere; no family word of _forbidden matches them, so they
// need no allow-list entry. Exact alarms are not used.
// 26번 5단계(DEC-045·046, DEC-084): Firebase Analytics is the one
// analytics SDK allowed (firebase_analytics and its platform interface/web
// parts only). The ad ID, SSAID and ad personalization signals are off in the
// main manifest, and the ad ID / ad services permissions the library merges in
// are removed (tools:node="remove"). Every other analytics, ads or crash
// reporting SDK stays forbidden.
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
  'firebase_app_check',
  'firebase_app_check_platform_interface',
  'firebase_app_check_web',
  'firebase_analytics',
  'firebase_analytics_platform_interface',
  'firebase_analytics_web',
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
  // 26번 5단계: a profile build merges the same libraries without the upload
  // key (`flutter build apk --profile`), so agents without key.properties
  // can check the permissions too. The newest of these files is read.
  'build/app/intermediates/merged_manifests/profile/processProfileManifest/AndroidManifest.xml',
];
const _manifestSources = [
  'android/app/src/main/AndroidManifest.xml',
  'android/app/build.gradle.kts',
  'pubspec.lock',
];
// Firebase Auth/Functions (network), Play Billing (stage 15), the Kakao
// login activities (stage 16) and, since 26번 5단계, Firebase Analytics
// (com.google.android.gms.measurement / com.google.firebase.analytics
// components) are expected. Ads, the ad ID, ad services permissions and
// Crashlytics must never appear.
const _forbiddenManifestEntries = <String>[
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES',
  'android.ext.adservices',
  'com.google.android.gms.ads',
  'com.google.firebase.crashlytics',
  // 5-1단계 손님 알림은 정확한 알람 권한 없이 inexact 예약만 쓴다.
  'android.permission.SCHEDULE_EXACT_ALARM',
  'android.permission.USE_EXACT_ALARM',
];

/// `<uses-permission|uses-library ... tools:node="remove"/>` lines take a
/// permission or library out of the merged manifest; they are not requests.
final _removedPermission =
    RegExp(r'<uses-(?:permission|library)[^>]*tools:node="remove"[^>]*/>');

List<String> manifestViolations(String xml) {
  final kept = xml.replaceAll(_removedPermission, '');
  return _forbiddenManifestEntries.where(kept.contains).toList();
}

/// 26번 5단계: Analytics must not collect the ad ID or SSAID nor allow ad
/// personalization signals. Returns the switches that are missing or on.
const _analyticsOffSwitches = [
  // Collection starts only after the game reads the '사용 통계 보내기' setting.
  'firebase_analytics_collection_enabled',
  'google_analytics_adid_collection_enabled',
  'google_analytics_ssaid_collection_enabled',
  'google_analytics_default_allow_ad_personalization_signals',
];
List<String> analyticsSwitchesNotOff(String xml) => [
      for (final name in _analyticsOffSwitches)
        if (!RegExp('<meta-data[^>]*android:name="$name"[^>]*android:value="false"')
            .hasMatch(xml))
          name
    ];

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

  test(
      'Android Gradle files add no Google Play services library and no '
      'Firebase analytics', () {
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
      expect(services, isEmpty, reason: path);
    }
  });

  test('main manifest requests no ad permission and turns the ad ID off', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    // AD_ID only appears to remove what Analytics would merge in.
    expect(manifest.replaceAll(_removedPermission, ''), isNot(contains('AD_ID')));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID" tools:node="remove"'));
    expect(manifest, contains('android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove"'));
    expect(manifest, contains('android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove"'));
    expect(manifest, contains('android:name="android.ext.adservices" android:required="false" tools:node="remove"'));
    expect(analyticsSwitchesNotOff(manifest), isEmpty);
  });

  test('5-1단계 기기 안 알림: 권한은 알림·부팅 뒤 재예약뿐, 정확한 알람 없음', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final permissions = RegExp(r'uses-permission android:name="([^"]+)"')
        .allMatches(manifest.replaceAll(_removedPermission, ''))
        .map((m) => m.group(1))
        .toSet();
    expect(permissions, {
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
    });
    expect(manifestViolations(manifest), isEmpty);
    final lock = File('pubspec.lock').readAsStringSync();
    expect(lock, contains('flutter_local_notifications:'));
    // No server push: Firebase messaging stays out.
    expect(lock, isNot(contains('firebase_messaging')));
    expect(manifestViolations('<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>'),
        ['android.permission.SCHEDULE_EXACT_ALARM']);
  });

  test('pubspec.lock 허용 목록 밖의 Firebase·결제 패키지는 여전히 걸린다', () {
    bool isForbidden(String p) =>
        !_allowed.contains(p) &&
        _forbidden.any(
            (f) => f.contains('_') ? p.contains(f) : p.split('_').contains(f));
    expect(isForbidden('firebase_auth'), isFalse);
    expect(isForbidden('in_app_purchase_android'), isFalse);
    // 26번 5단계: Firebase Analytics only; its neighbours stay out.
    expect(isForbidden('firebase_analytics'), isFalse);
    expect(isForbidden('firebase_analytics_web'), isFalse);
    expect(isForbidden('firebase_crashlytics'), isTrue);
    expect(isForbidden('firebase_performance'), isTrue);
    expect(isForbidden('firebase_messaging'), isTrue);
    expect(isForbidden('google_analytics'), isTrue);
    expect(isForbidden('amplitude_flutter'), isTrue);
    expect(isForbidden('google_mobile_ads'), isTrue);
  });

  test('병합 매니페스트 검사는 금지 권한·SDK 항목을 찾아낸다', () {
    const clean = '<manifest><application android:label="x"/></manifest>';
    expect(manifestViolations(clean), isEmpty);
    const kakao = '<manifest>'
        '<activity android:name="com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity"/>'
        '<package android:name="com.kakao.talk"/>'
        '</manifest>';
    expect(manifestViolations(kakao), isEmpty);
    const online = '<manifest>'
        '<uses-permission android:name="android.permission.INTERNET"/>'
        '<uses-permission android:name="com.android.vending.BILLING"/>'
        '<service android:name="com.google.firebase.components.ComponentDiscoveryService"/>'
        '</manifest>';
    expect(manifestViolations(online), isEmpty);
    const analytics = '<manifest>'
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>'
        '<service android:name="com.google.android.gms.measurement.AppMeasurementService"/>'
        '<service android:name="com.google.firebase.analytics.connector.x"/>'
        '</manifest>';
    expect(manifestViolations(analytics), isEmpty);
    const dirty = '<manifest>'
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>'
        '<uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION"/>'
        '<service android:name="com.google.firebase.crashlytics.x"/>'
        '</manifest>';
    expect(manifestViolations(dirty), [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES',
      'com.google.firebase.crashlytics',
    ]);
    expect(
        analyticsSwitchesNotOff('<meta-data android:name="google_analytics_adid_collection_enabled" android:value="true" />'),
        _analyticsOffSwitches);
  });

  final release = releaseManifest();
  test('release 병합 매니페스트에 광고·광고 ID·광고 서비스 권한이 없고 Analytics 광고 신호가 꺼져 있다', () {
    final xml = release.file!.readAsStringSync();
    expect(manifestViolations(xml), isEmpty, reason: release.file!.path);
    expect(analyticsSwitchesNotOff(xml), isEmpty, reason: release.file!.path);
  }, skip: release.skip ?? false);
}
