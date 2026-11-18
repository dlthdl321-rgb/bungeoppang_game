import 'package:firebase_analytics/firebase_analytics.dart';
import 'usage_stats.dart';

/// 사용 통계를 Firebase Analytics로 보낸다(26번 5단계, DEC-045·046).
/// Firebase가 초기화된 빌드(firebase_online_backend.dart)에서만 만든다.
/// setUserId는 쓰지 않고, 광고 ID·SSAID·개인화 광고 신호는 AndroidManifest
/// meta-data로 끈다. 수집은 매니페스트에서 꺼 두고(firebase_analytics_collection_enabled)
/// 게임이 설정을 읽은 뒤 [setEnabled]로 켠다. 앱 ID는 build.gradle.kts가 넣는
/// google_app_id 리소스에서 읽는다. 보관 기간 14개월은 Firebase 콘솔에서 정한다.
class FirebaseUsageStatsSink implements UsageStatsSink {
  final FirebaseAnalytics _analytics;
  FirebaseUsageStatsSink([FirebaseAnalytics? analytics])
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> setEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> log(String name, Map<String, Object> parameters) =>
      _analytics.logEvent(
          name: name, parameters: parameters.isEmpty ? null : parameters);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _analytics.setUserProperty(name: name, value: value);
}
