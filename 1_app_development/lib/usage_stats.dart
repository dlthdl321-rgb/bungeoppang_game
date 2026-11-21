import 'dart:async';

/// 사용 통계(26번 5단계, DEC-045·046): Firebase Analytics로 "어디까지 와서
/// 그만두는지"만 본다. 이름·계정·광고 ID는 보내지 않고 setUserId도 쓰지 않는다.
/// 첫 실행·재방문은 Analytics가 스스로 모으는 first_open·session_start로 보고,
/// 아래 이벤트만 직접 남긴다(11개 이하, 영문 소문자·밑줄. 26번 8단계 share로 10개,
/// 재료 타이쿤 E ingredient_out으로 11개, 사용자 결정 2026-11-21).
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
  payDone('pay_done'),
  /// 오늘의 주문서를 납품했을 때(하루 1번, event: 행사 ID 또는 none, 26번 7단계).
  specialOrderDone('special_order_done'),
  /// 겨울 행사 기간에 처음 들어왔을 때(행사마다 1번, event: 행사 ID, 26번 7단계).
  eventJoin('event_join'),
  /// 공유 카드를 공유 창으로 보냈을 때(하루 1번, moment: perfect/story/
  /// collection/shop, 26번 8단계). 보상 없음.
  share('share'),
  /// 영업 중 재료(반죽 또는 모든 속)가 떨어져 생산이 멈췄을 때(하루 1번,
  /// what: batter/filling, 재료 타이쿤 E).
  ingredientOut('ingredient_out');

  final String wireName;
  const UsageEvent(this.wireName);
}

/// Lv.3·5·10만 남긴다(초반 이탈 지점).
const usageLevelMarks = [3, 5, 10];

/// 하루 1번만 남기는 이벤트.
const _dailyOnce = {UsageEvent.shopOpen, UsageEvent.payView, UsageEvent.share, UsageEvent.ingredientOut};

/// Where the events go: Firebase Analytics in builds with Firebase keys,
/// nowhere otherwise.
abstract class UsageStatsSink {
  Future<void> setEnabled(bool enabled);
  Future<void> log(String name, Map<String, Object> parameters);
  /// An Analytics user property; null clears it.
  Future<void> setUserProperty(String name, String? value);
}

/// Builds without Firebase keys and tests: sends nothing.
class NoUsageStatsSink implements UsageStatsSink {
  const NoUsageStatsSink();
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> log(String name, Map<String, Object> parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

/// The recorder the game calls. Every call is fire-and-forget: it never
/// waits, never throws and never runs inside a game command or a save, so a
/// failing or slow Analytics cannot change the game.
class UsageStats {
  final UsageStatsSink sink;
  final DateTime Function() _now;
  bool _enabled = true;
  bool _consented;
  final Map<UsageEvent, String> _dailySent = {};

  /// [consented]: whether the first-run required consent is already done.
  /// main.dart passes false (DEC-126): nothing is collected — not
  /// even Analytics' own first_open/session_start, the manifest keeps
  /// collection off — until [OwnerAccount] reports the consent with
  /// [setConsented]. Tests that do not care leave it true.
  UsageStats(this.sink, {DateTime Function()? now, bool consented = true})
      : _now = now ?? (() => DateTime.now().toUtc()),
        _consented = consented;

  /// Sends nothing (builds without Firebase, most tests).
  static final UsageStats none = UsageStats(const NoUsageStatsSink());

  /// The '사용 통계 보내기' setting (기본 켬).
  bool get enabled => _enabled;
  /// The first-run required consent is done (see the constructor).
  bool get consented => _consented;
  /// Analytics actually collects: the setting is on and the consent is done.
  bool get collecting => _enabled && _consented;

  /// 설정 '사용 통계 보내기'. 끄면 Analytics 수집 자체를 멈춘다
  /// (setAnalyticsCollectionEnabled(false)); 켜면 다시 모은다(첫 실행 동의
  /// 뒤에만, [setConsented]).
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _quietly(() => sink.setEnabled(collecting));
  }

  /// 첫 실행 필수 동의(약관·개인정보·만 14세 이상)를 마쳤는지. [OwnerAccount]
  /// tells it on every load and save; only a change reaches Analytics. A
  /// player who has to agree again (a new [requiredConsentVersion]) or who
  /// deleted the account stops collection until the consent is given.
  void setConsented(bool consented) {
    if (consented == _consented) return;
    _consented = consented;
    _quietly(() => sink.setEnabled(collecting));
  }

  /// One event. Daily-once events are skipped after the first send of the
  /// Korean (KST) day in this run.
  void record(UsageEvent event, [Map<String, Object> parameters = const {}]) {
    if (!collecting) return;
    if (_dailyOnce.contains(event)) {
      final day = _kstDay(_now());
      if (_dailySent[event] == day) return;
      _dailySent[event] = day;
    }
    _quietly(() => sink.log(event.wireName, parameters));
  }

  /// 선택 정보(26번 2-1단계)를 Analytics 사용자 속성 gender·age_band로.
  /// [OwnerAccount] passes only values the player agreed to give, never the
  /// name or email; null (skipped, '선택 안 함', under 14) clears it.
  void setUserProperties({String? gender, String? ageBand}) {
    _quietly(() => sink.setUserProperty('gender', gender));
    _quietly(() => sink.setUserProperty('age_band', ageBand));
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
    if (after.orderDone != null && after.orderDone != before.orderDone) {
      record(UsageEvent.specialOrderDone, {'event': after.orderEvent ?? 'none'});
    }
    for (final event in after.events.difference(before.events).toList()..sort()) {
      record(UsageEvent.eventJoin, {'event': event});
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
  /// 26번 7단계: the KST day of the order handed over today (null: not yet),
  /// its seasonal event, and the events the player has been in.
  final String? orderDone, orderEvent;
  final Set<String> events;
  const UsageProgress(
      {required this.bakes,
      required this.sales,
      required this.level,
      required this.tutorial,
      this.orderDone,
      this.orderEvent,
      this.events = const {}});
  bool get tutorialActive => tutorial == 'cook' || tutorial == 'sell';
}
