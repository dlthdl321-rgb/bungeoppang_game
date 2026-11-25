part of 'workshop_controller.dart';

/// 매일 돌아올 이유: 오늘의 주문서·출석 (26번 7단계).
/// [WorkshopController]에서 옮긴 그대로다(2026-11-23 안정화, 동작 변경 없음).
extension WorkshopDailyReturn on WorkshopController {
  // ---- 26번 7단계: 매일 돌아올 이유 (lib/workshop_daily.dart) ----
  Map<String, dynamic> get _dailyRules => config.section('daily_return');
  Map<String, dynamic> get _orderRules => _dailyRules['special_order'] as Map<String, dynamic>;
  Map<String, dynamic> get _stampRules => _dailyRules['attendance'] as Map<String, dynamic>;
  /// The KST day of the settled business time. It only moves forward, so a
  /// clock turned back never reopens a day.
  String get today => businessDayKst(state.business.settledUtc);
  /// The seasonal event today (config dates only), after the first-run guide.
  SeasonalEvent? get seasonalEvent => state.tutorialActive ? null : activeSeasonalEvent(config, today);
  /// Today's 오늘의 주문서 once special orders are open (Lv.5), or null.
  DailyOrder? get dailyOrder {
    final order = state.daily.order;
    return order != null && order.day == today && !state.tutorialActive ? order : null;
  }
  /// The income rate daily rewards are based on (4차 피드백 g7): taps at
  /// `rate_taps_per_second` plus auto production, per second.
  BigInt get dailyRate => dailyIncomeRate(config, tapRate: tapRate, autoRate: autoRate);
  /// The buns the order pays now: `reward_seconds` of [dailyRate], at least `min_buns`.
  BigInt get dailyOrderReward => dailyBuns(dailyRate, DevelopmentBalance.integer(_orderRules, 'reward_seconds'),
      DevelopmentBalance.decimal(_orderRules, 'min_buns'));
  int get dailyOrderAffinity => DevelopmentBalance.integer(_orderRules, 'affinity');
  bool _fitsDailyOrder(DailyOrder order, ProductBatch b) {
    final age = state.business.businessIndex - b.madeOnBusinessIndex;
    return b.flavor == order.flavor && b.variant == order.variant && age >= 0 && age < 5;
  }
  /// Stock that fits the order (flavor and doneness, still sellable), oldest
  /// first, or null when there is not enough.
  Map<String, int>? _dailyOrderStock(DailyOrder order) {
    final fits = state.inventory.batches.values.where((b) => _fitsDailyOrder(order, b)).toList()
      ..sort((a, b) => a.madeOnBusinessIndex != b.madeOnBusinessIndex
          ? a.madeOnBusinessIndex.compareTo(b.madeOnBusinessIndex) : a.id.compareTo(b.id));
    var needed = order.quantity;
    final pick = <String, int>{};
    for (final batch in fits) {
      if (needed == 0) break;
      final amount = min(needed, batch.quantity);
      pick[batch.id] = amount; needed -= amount;
    }
    return needed == 0 ? pick : null;
  }
  /// How many fitting products are in stock (for the card).
  int get dailyOrderStock {
    final order = dailyOrder;
    if (order == null) return 0;
    return state.inventory.batches.values.where((b) => _fitsDailyOrder(order, b)).fold(0, (n, b) => n + b.quantity);
  }
  /// Whether today's stamp is still to take.
  bool get attendanceReady => !state.tutorialActive && state.daily.stampDay != today;
  int get attendanceCycle => DevelopmentBalance.integer(_stampRules, 'cycle_days');
  /// The box the next stamp takes (1~7); after the seventh it starts again.
  int get nextStamp => state.daily.stamps >= attendanceCycle ? 1 : state.daily.stamps + 1;
  /// Day 7 gives gold through the server wallet — or, in a test build
  /// without the online settings, the device's test gold (5차 피드백 12:
  /// "도장을 찍으면 보상은 무조건 반영"). Only a build with neither gives
  /// more buns instead.
  bool stampGivesGold(int box) => box == attendanceCycle &&
      (onlineGateway != null || purchaseGateway is LocalTestPurchaseGateway);
  int get attendanceGold => DevelopmentBalance.integer(_stampRules, 'gold');
  BigInt stampBuns(int box) => box == attendanceCycle
      ? dailyBuns(dailyRate, DevelopmentBalance.integer(_stampRules, 'substitute_seconds'),
          DevelopmentBalance.decimal(_stampRules, 'substitute_min_buns'))
      : dailyBuns(dailyRate, DevelopmentBalance.integer(_stampRules, 'buns_seconds'),
          DevelopmentBalance.decimal(_stampRules, 'min_buns'));
  /// Something on the '오늘' slip still waits for the player.
  bool get dailyWaiting => attendanceReady || (dailyOrder != null && !dailyOrder!.done);

  /// Records the KST day after the guide: the day's order (once special
  /// orders are open) and the seasonal event the player is in. Runs after
  /// every command and on coming back; pays nothing. Returns whether a new
  /// order came. However many days passed, one order for today.
  /// What [_observeDaily] would change now (the checkpoint's test, 28번 8절).
  bool get _dailyDue {
    if (state.tutorialActive) return false;
    final day = today, daily = state.daily;
    final event = activeSeasonalEvent(config, day);
    return daily.day != day || (event != null && !daily.events.contains(event.id)) ||
        (daily.order?.day != day && featureOpen(state, config, WorkshopFeature.specialOrders));
  }
  bool _observeDaily() {
    if (state.tutorialActive) return false;
    final day = today;
    var daily = state.daily, fresh = false;
    if (daily.day != day) daily = daily.copyWith(day: day);
    final event = activeSeasonalEvent(config, day);
    if (event != null && !daily.events.contains(event.id)) daily = daily.copyWith(events: {...daily.events, event.id});
    if (daily.order?.day != day && featureOpen(state, config, WorkshopFeature.specialOrders)) {
      final met = state.relationships.met;
      daily = daily.copyWith(order: makeDailyOrder(config, day: day, runId: state.grid.runId,
          flavors: state.recipes.toList()..sort(), neighbors: customerCatalog.ids.where(met.contains).toList(),
          event: event));
      fresh = true;
    }
    state.daily = daily;
    return fresh;
  }

  /// '도장 찍기': the first stamp of the KST day takes the next box. Boxes
  /// 1~6 pay buns; the seventh asks the server for gold (pending until
  /// verified, like mission gold).
  Future<bool> stampAttendance() => command(() {
    if (!attendanceReady) throw const FormatException('오늘 출석 도장은 이미 찍었어요.');
    final box = nextStamp, day = today;
    if (stampGivesGold(box)) {
      state.pendingGold['attendance:$day'] = attendanceClaim(config, day);
    } else {
      final buns = stampBuns(box);
      state.buns += buns; state.lifetime += buns;
    }
    state.daily = state.daily.copyWith(stamps: box, stampDay: day);
  });

  /// Bakes for the order in the big mold while open (no customer needed).
  Future<bool> startDailyOrderProduction() => command(() {
    final order = dailyOrder;
    if (order == null || order.done) throw const FormatException('오늘의 주문서를 확인해 주세요.');
    if (!state.business.permitsProducts(now())) throw const FormatException('영업 중에 주문서 붕어빵을 구울 수 있어요.');
    _startCooking(order.flavor, practice: false);
  });

  /// '납품하기': hands the order over from stock while open. Pays buns and
  /// the requester's affinity (its own daily cap), never gold.
  Future<bool> deliverDailyOrder() => command(() {
    final order = dailyOrder;
    if (order == null || order.done) throw const FormatException('오늘의 주문서를 확인해 주세요.');
    if (gameplayPaused || !state.business.permitsProducts(now())) throw const FormatException('영업 중에 납품할 수 있어요.');
    final pick = _dailyOrderStock(order);
    if (pick == null) throw const FormatException('주문서에 맞는 붕어빵이 모자라요.');
    state.inventory = state.inventory.consume(pick);
    final buns = dailyOrderReward;
    state.buns += buns; state.lifetime += buns;
    if (order.npc != null) {
      state.relationships = state.relationships.specialOrder(order.npc!, order.day, state.business.businessIndex,
          dailyOrderAffinity, config, customerCatalog);
    }
    state.daily = state.daily.copyWith(order: order.delivered(buns, state.business.businessIndex));
  });
}
