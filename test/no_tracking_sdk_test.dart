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
const _forbiddenManifestEntries = <String>[
  'android.permission.INTERNET',
  'android.permission.ACCESS_NETWORK_STATE',
  'com.google.android.gms.permission.AD_ID',
  'android.permission.ACCESS_ADSERVICES',
  'com.android.vending.BILLING',
  'com.google.android.gms',
  'com.google.firebase',
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

  test('병합 매니페스트 검사는 금지 권한·SDK 항목을 찾아낸다', () {
    const clean = '<manifest><application android:label="x"/></manifest>';
    expect(manifestViolations(clean), isEmpty);
    const dirty = '<manifest>'
        '<uses-permission android:name="android.permission.INTERNET"/>'
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>'
        '<uses-permission android:name="com.android.vending.BILLING"/>'
        '</manifest>';
    expect(manifestViolations(dirty), [
      'android.permission.INTERNET',
      'com.google.android.gms.permission.AD_ID',
      'com.android.vending.BILLING',
      'com.google.android.gms',
    ]);
  });

  final release = releaseManifest();
  test('release 병합 매니페스트에 네트워크·광고·결제·Play 서비스 항목이 없다', () {
    expect(manifestViolations(release.file!.readAsStringSync()), isEmpty,
        reason: release.file!.path);
  }, skip: release.skip ?? false);
}
