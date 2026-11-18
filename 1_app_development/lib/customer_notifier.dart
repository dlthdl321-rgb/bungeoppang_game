import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'development_balance.dart';
import 'models.dart';
import 'workshop_arrivals.dart';
import 'workshop_customers.dart';

/// 26번 5-1단계: customer notifications scheduled on the device only (no
/// server push, no Firebase messaging). When the app goes to the background
/// the page plans the guests the clocks will bring and schedules one notice
/// each; coming back cancels them all.
class PlannedNotice {
  final int id;
  final DateTime at;
  final String title, body;
  const PlannedNotice({required this.id, required this.at, required this.title, required this.body});
  @override
  String toString() => '$id@${at.toIso8601String()} $body';
}

const customerNoticeTitle = '오늘의 붕어빵';
const regularNoticeBody = '손님이 붕어빵을 사러 왔어요! 가게로 가 볼까요?';
String namedNoticeBody(String shortName) => '${withSubjectParticle(shortName)} 찾아왔어요. 따끈한 붕어빵을 기다려요.';

/// Minutes after the device's local midnight at [utc].
int deviceLocalMinute(DateTime utc) {
  final local = utc.toLocal();
  return local.hour * 60 + local.minute;
}

/// Whether [minute] falls in the quiet night from [start] to [end]
/// (`customer_notifications.quiet_start_minute`..`quiet_end_minute`, the end
/// excluded; the range may cross midnight).
bool inQuietNight(int minute, int start, int end) =>
    start <= end ? minute >= start && minute < end : minute >= start || minute < end;

/// The notices for [arrivals]: regular guests only when the player turned
/// them on (at most `regular_max_notices`), named neighbors by short name,
/// and none in the quiet night when that setting is on (the guest still
/// comes). Pure, so the schedule is testable without the plugin.
List<PlannedNotice> planCustomerNotices(List<PlannedArrival> arrivals, {required GameSettings settings,
    required DevelopmentBalance config, required WorkshopCustomerCatalog catalog,
    Set<String> completedStories = const {}, int Function(DateTime utc) localMinute = deviceLocalMinute}) {
  final rules = config.section('customer_notifications');
  final start = DevelopmentBalance.integer(rules, 'quiet_start_minute'),
      end = DevelopmentBalance.integer(rules, 'quiet_end_minute'),
      maxRegular = DevelopmentBalance.integer(rules, 'regular_max_notices');
  final notices = <PlannedNotice>[];
  var regular = 0;
  for (final arrival in arrivals) {
    final named = arrival.kind == ArrivalKind.named && arrival.npc != null;
    if (named ? !settings.notifyNamedGuests : !settings.notifyRegularGuests) continue;
    if (!named && regular >= maxRegular) continue;
    if (settings.quietNightNotices && inQuietNight(localMinute(arrival.at), start, end)) continue;
    if (!named) regular++;
    notices.add(PlannedNotice(id: notices.length + 1, at: arrival.at, title: customerNoticeTitle,
        body: named ? namedNoticeBody(catalog.shortName(arrival.npc!, completedStories)) : regularNoticeBody));
  }
  return notices;
}

/// The notification driver. Tests use a fake; the app uses [LocalCustomerNotifier].
abstract class CustomerNotifier {
  /// Replaces every scheduled customer notice with [notices].
  Future<void> schedule(List<PlannedNotice> notices);
  Future<void> cancelAll();
  /// Asks for the notification permission (Android 13+ at run time).
  /// False when the player refused it.
  Future<bool> requestPermission();
  /// Whether notices can be shown now, without asking (the settings show
  /// '알림 권한이 필요해요' when a switch is on but this is false).
  Future<bool> hasPermission();
}

/// flutter_local_notifications with inexact alarms: no exact-alarm
/// permission, so a notice may come a few minutes late. Tapping it opens the
/// app on the home screen, where the guest is waiting.
class LocalCustomerNotifier implements CustomerNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;
  static const _details = NotificationDetails(
      // Temporary white bungeoppang silhouette (25번 필요한 그림 21번).
      android: AndroidNotificationDetails('customers', '손님 알림', icon: 'ic_stat_customer',
          channelDescription: '앱을 꺼 둔 동안 가게에 손님이 찾아오면 알려 드려요.',
          importance: Importance.defaultImportance, priority: Priority.defaultPriority),
      iOS: DarwinNotificationDetails());

  Future<bool> _init() => _ready ??= _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_customer'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false,
          requestSoundPermission: false))).then((ok) => ok ?? false);

  @override
  Future<void> schedule(List<PlannedNotice> notices) async {
    try {
      if (!await _init()) return;
      await _plugin.cancelAll();
      for (final notice in notices) {
        await _plugin.zonedSchedule(id: notice.id, title: notice.title, body: notice.body,
            scheduledDate: tz.TZDateTime.from(notice.at.toUtc(), tz.UTC), notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (e) {
      // A notice that cannot be scheduled must never break the game.
      debugPrint('손님 알림 예약 실패: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      if (await _init()) await _plugin.cancelAll();
    } catch (e) { debugPrint('손님 알림 취소 실패: $e'); }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      if (!await _init()) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final options = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('손님 알림 권한 확인 실패: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (!await _init()) return false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true) ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('손님 알림 권한 요청 실패: $e');
      return false;
    }
  }
}
