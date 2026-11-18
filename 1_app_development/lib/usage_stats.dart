import 'dart:async';

/// 사용 통계(26번 5단계, DEC-045·046): Firebase Analytics로 "어디까지 와서
/// 그만두는지"만 본다. 이름·계정·광고 ID는 보내지 않고 setUserId도 쓰지 않는다.
/// 첫 실행·재방문은 Analytics가 스스로 모으는 first_open·session_start로 보고,
/// 아래 이벤트만 직접 남긴다(10개 이하, 영문 소문자·밑줄).
enum UsageEvent {
  /// 처음으로 굽기 결과가 나왔을 때(평생 1번).
  firstBake('first_bake'),
  /// 첫 판매(평생 1번).
  firstSale('first_sale'),
  /// 첫 실행 안내가 끝났을 때(평생 1번, result: done/skipped).
  tutorialDone('tutorial_done'),
  /// Lv.3·5·10에 올랐을 때(각 1번, level).
  levelReached('level_reached'),
  /// 상점 창을 열었을 때(하루 1번).
  shopOpen('shop_open'),
  /// 황금 충전 화면을 열었을 때(하루 1번).
  payView('pay_view'),
  /// 황금 결제가 서버에서 확인됐을 때(결제마다, product_id만, 금액 없음).
  payDone('pay_done');

  final String wireName;
  const UsageEvent(this.wireName);
}

/// Lv.3·5·10만 남긴다(초반 이탈 지점).
const usageLevelMarks = [3, 5, 10];

/// 하루 1번만 남기는 이벤트.
const _dailyOnce = {UsageEvent.shopOpen, UsageEvent.payView};

/// Where the events go: Firebase Analytics in builds with Firebase keys,
/// nowhere otherwise.
abstract class UsageStatsSink {
  Future<void> setEnabled(bool enabled);
  Future<void> log(String name, Map<String, Object> parameters);
}

/// Builds without Firebase keys and tests: sends nothing.
class NoUsageStatsSink implements UsageStatsSink {
  const NoUsageStatsSink();
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> log(String name, Map<String, Object> parameters) async {}
}

/// The recorder the game calls. Every call is fire-and-forget: it never
/// waits, never throws and never runs inside a game command or a save, so a
/// failing or slow Analytics cannot change the game.
class UsageStats {
  final UsageStatsSink sink;
  final DateTime Function() _now;
  bool _enabled = true;
  final Map<UsageEvent, String> _dailySent = {};
  UsageStats(this.sink, {DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc());

  /// Sends nothing (builds without Firebase, most tests).
  static final UsageStats none = UsageStats(const NoUsageStatsSink());

  bool get enabled => _enabled;

  /// 설정 '사용 통계 보내기'. 끄면 Analytics 수집 자체를 멈춘다
  /// (setAnalyticsCollectionEnabled(false)); 켜면 다시 모은다.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _quietly(() => sink.setEnabled(enabled));
  }

  /// One event. Daily-once events are skipped after the first send of the
  /// Korean (KST) day in this run.
  void record(UsageEvent event, [Map<String, Object> parameters = const {}]) {
    if (!_enabled) return;
    if (_dailyOnce.contains(event)) {
      final day = _kstDay(_now());
      if (_dailySent[event] == day) return;
      _dailySent[event] = day;
    }
    _quietly(() => sink.log(event.wireName, parameters));
  }

  /// Compares the Workshop progress before and after a saved command and
  /// records the lifetime milestones it crossed. Loading an old save (which
  /// reads the guide as done) is not a command step, so it records nothing.
  void observeProgress(UsageProgress before, UsageProgress after) {
    if (before.bakes == 0 && after.bakes > 0) record(UsageEvent.firstBake);
    if (before.sales == 0 && after.sales > 0) record(UsageEvent.firstSale);
    if (before.tutorialActive && !after.tutorialActive) {
      record(UsageEvent.tutorialDone, {'result': after.tutorial});
    }
    for (final level in usageLevelMarks) {
      if (before.level < level && after.level >= level) {
        record(UsageEvent.levelReached, {'level': level});
      }
    }
  }

  static String _kstDay(DateTime utc) {
    final kst = utc.toUtc().add(const Duration(hours: 9));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${kst.year}-${two(kst.month)}-${two(kst.day)}';
  }

  static void _quietly(Future<void> Function() send) {
    try {
      unawaited(send().catchError((Object _) {}));
    } catch (_) {}
  }
}

/// The few Workshop numbers the milestones are read from.
class UsageProgress {
  final int bakes, sales, level;
  final String tutorial;
  const UsageProgress(
      {required this.bakes,
      required this.sales,
      required this.level,
      required this.tutorial});
  bool get tutorialActive => tutorial == 'cook' || tutorial == 'sell';
}
