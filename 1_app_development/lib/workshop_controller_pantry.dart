part of 'workshop_controller.dart';

/// 재료 타이쿤 B·C·E: 생산 연결·재료 상점·홈 표시.
/// [WorkshopController]에서 옮긴 그대로다(2026-11-23 안정화, 동작 변경 없음).
extension WorkshopPantry on WorkshopController {
  /// 재료 타이쿤 설정 (`ingredients`, [PantryConfig]).
  PantryConfig get pantryConfig => PantryConfig.of(config);
  /// R for ingredient prices: tap power × `ingredients.rate_taps_per_second` + auto/s.
  BigInt get pantryRate => pantryConfig.incomeRate(tapRate: tapRate, autoRate: autoRate);
  // ---- 재료 타이쿤 B: 생산 연결 (lib/pantry_rules.dart) ----
  int get _nowMs => now().millisecondsSinceEpoch;
  /// Flavors whose 특제 filling is in stock: the picker offers '특제 <맛>'.
  Set<String> get premiumFlavors {
    final c = pantryConfig, at = _nowMs;
    return {for (final l in state.pantry.lots)
      if (l.premium && l.kind != c.batterKind && state.recipes.contains(l.kind) && l.portions > 0 && !l.expired(c, at)) l.kind};
  }
  /// The filling taps and auto production use now, as (flavor, 특제):
  /// taps and auto earn no 특제 bonus (4차 병합 3 사용자 결정), so they use
  /// plain filling — the chosen flavor's, else the next flavor of
  /// `filling_fallback_order` with plain filling (never the same flavor's
  /// 특제). With a plain choice that switch becomes the chosen flavor with a
  /// short notice ('팥소가 떨어져 슈크림으로 바꿨어요'); a '특제 <맛>' choice
  /// stays (the mold and the six cells use it) and only when no plain
  /// filling is left at all do taps use that 특제 filling. A 특제 choice whose
  /// 특제 filling ran out becomes the plain flavor ('특제 팥소가 떨어져 팥소로
  /// 바꿨어요'). Null when the batter or every usable filling is out. Only
  /// with [switchChoice] does the choice change.
  (String, bool)? _productionChoice({bool switchChoice = true}) {
    final c = pantryConfig, p = state.pantry, at = _nowMs, selected = state.selectedFlavor;
    final premiumChosen = state.selectedPremium && premiumFlavors.contains(selected);
    if (switchChoice && state.selectedPremium && !premiumChosen) {
      notice = fallbackNotice(c, selected, selected, fromPremium: true);
      state.selectedPremium = false;
    }
    if (p.usable(c, c.batterKind, at) < 1) return null;
    final plain = p.productionFlavor(c, selected, state.recipes, at);
    if (plain == null) return premiumChosen ? (selected, true) : null;
    if (switchChoice && plain != selected && !premiumChosen) {
      notice = fallbackNotice(c, selected, plain);
      state.selectedFlavor = plain;
    }
    return (plain, false);
  }
  /// Why production stops now ([PantryShortage.none] while it runs).
  PantryShortage get productionShortage {
    final c = pantryConfig, at = _nowMs;
    if (state.pantry.usable(c, c.batterKind, at) < 1) return PantryShortage.batter;
    return _productionChoice(switchChoice: false) == null ? PantryShortage.filling : PantryShortage.none;
  }
  /// The HUD's '멈춤' beside the per-second number: open with an auto skill,
  /// no auto portion left and none to take.
  bool get autoStopped => state.business.open && autoRate > BigInt.zero && state.pantry.autoCreditMs == 0 &&
      productionShortage != PantryShortage.none;
  /// Auto production for [elapsedMs] in the foreground: each portion covers
  /// `auto_ms_per_portion`; time it does not cover makes nothing. Returns
  /// ms × permille for [BusinessProgress.settleActive] (the covered time ×
  /// 1000: no 특제 bonus on auto, 4차 병합 3), or null (×1, nothing to use:
  /// closed, no auto skill, no time). The away settlement never comes here.
  int? _runAutoPantry(int elapsedMs) {
    if (elapsedMs <= 0 || !state.business.open || autoRate <= BigInt.zero) return null;
    final choice = _productionChoice();
    final segments = state.pantry.runAuto(pantryConfig, choice?.$1 ?? state.selectedFlavor, elapsedMs, _nowMs,
        premium: choice?.$2 ?? false);
    final covered = segments.fold(0, (n, s) => n + s.ms);
    if (covered < elapsedMs) _ingredientsOut(say: false);
    return covered * 1000;
  }
  /// Production stopped for lack of batter or filling: '재료를 준비하세요'
  /// once ([say], taps) and the usage event `ingredient_out` (once a day).
  void _ingredientsOut({bool say = true}) {
    if (say && !_outNoticed) { notice = pantryEmptyText; _outNoticed = true; }
    final c = pantryConfig;
    usage.record(UsageEvent.ingredientOut,
        {'what': state.pantry.usable(c, c.batterKind, _nowMs) < 1 ? 'batter' : 'filling'});
  }
  /// Gives the special mold's portion back (canceled before the result).
  void _refundSession() {
    final use = state.sessionPortion;
    if (use != null) state.pantry.refund(use);
    state.sessionPortion = null;
  }
  // ---- 재료 타이쿤 C: 상점 '재료' 탭 (lib/ui/pantry_shop.dart) ----
  /// Basic ingredients the shop lists now, in config order (코코아 가루 only
  /// after the 초코 recipe, [PantryState.basicVisible]).
  List<String> get shopBasicIngredients => [for (final id in pantryConfig.basic.keys)
    if (state.pantry.basicVisible(pantryConfig, id, state.recipes)) id];
  /// What one press of [step] buys of basic ingredient [id]: [step], at most
  /// the room left; the '최대' step ([pantryMaxStep]) as many as the room and
  /// the 붕어빵력 allow. At least 1, so a dark button can still say why.
  int basicBuyQuantity(String id, int step) {
    final c = pantryConfig, room = state.pantry.basicRoom(c, id);
    if (room < 1) return 1;
    if (!WorkshopController.pantryMaxStep(step, c.basic[id]!.maxStock)) return min(step, room);
    final price = c.basicPrice(id, pantryRate), afford = state.purchases.available(state.buns) ~/ price;
    return afford >= BigInt.from(room) ? room : max(1, afford.toInt());
  }
  /// Why [quantity] of basic ingredient [id] cannot be bought now (Korean),
  /// or null.
  String? basicBuyBlocker(String id, int quantity) {
    final c = pantryConfig, item = c.basic[id]!;
    if (error != null) return error;
    if (busy || inputBusy || purchaseBusy) return '잠시 뒤에 다시 눌러 주세요.';
    if (quantity > state.pantry.basicRoom(c, id)) return '${item.label}${WorkshopController._topicOf(item.label)} ${item.maxStock}개까지 보관할 수 있어요.';
    if (state.purchases.available(state.buns) < c.basicCost(id, quantity, pantryRate)) return '붕어빵력이 모자라요.';
    return null;
  }
  /// Buys [quantity] of basic ingredient [id] on this device: the 붕어빵력
  /// leaves in the same save as the ingredients arrive (no server: the
  /// server only bounds how fast 붕어빵력 grows, and this only spends it).
  Future<bool> buyIngredient(String id, int quantity) => command(() {
    final c = pantryConfig, cost = c.basicCost(id, quantity, pantryRate);
    state.pantry.buyBasic(c, id, quantity, state.recipes);
    if (state.purchases.available(state.buns) < cost) throw const FormatException('붕어빵력이 모자라요.');
    state.buns -= cost;
  });
  /// Packs of special ingredient [id] one press of [step] buys: [step], at
  /// most what fits (room ÷ `pack_count`); the '최대' step (no smaller than
  /// `max_stock` ÷ `pack_count`) as many as fit and [gold] pays. At least 1.
  int premiumBuyPacks(String id, int step, int gold) {
    final c = pantryConfig, fit = state.pantry.premiumRoom(c, id) ~/ c.premiumPackCount;
    if (fit < 1) return 1;
    if (!WorkshopController.pantryMaxStep(step, c.premium[id]!.maxStock ~/ c.premiumPackCount)) return min(step, fit);
    return max(1, min(fit, gold ~/ c.premiumPackGold));
  }
  /// Why [packs] packs of special ingredient [id] cannot be bought now with
  /// [gold] 황금붕어빵력 (Korean), or null.
  String? premiumBuyBlocker(String id, int packs, int gold) {
    final c = pantryConfig, item = c.premium[id]!;
    if (!state.pantry.premiumVisible(c, state.level)) return '특별한 재료는 Lv.${c.premiumUnlockLevel}부터 살 수 있어요.';
    if (packs * c.premiumPackCount > state.pantry.premiumRoom(c, id)) {
      return '${item.label}${WorkshopController._topicOf(item.label)} ${item.maxStock}개까지 보관할 수 있어요.';
    }
    if (purchaseGateway == null) return OnlineTexts.premiumIngredientNotSetUp;
    if (purchaseGateway!.authenticatedAccount.isEmpty) return OnlineTexts.premiumIngredientSignIn;
    if (error != null) return error;
    if (busy || inputBusy || purchaseBusy) return '잠시 뒤에 다시 눌러 주세요.';
    if (state.purchases.journals.values.any((j) => !j.settled)) return '앞의 구매 확인이 남아 있어요.';
    if (gold < packs * c.premiumPackGold) return '황금붕어빵력이 모자라요.';
    return null;
  }
  /// Buys [packs] packs of special ingredient [id] through the server
  /// purchase path (`ingredient:<id>`, like a cosmetic: reserve → local
  /// record → commit); the pantry gets them when the purchase settles
  /// ([_finishPurchase]). A test build's gateway answers on this device.
  Future<bool> buyPremiumIngredient(String id, int packs) async {
    final c = pantryConfig;
    if (purchaseGateway == null || !state.pantry.premiumVisible(c, state.level) ||
        packs * c.premiumPackCount > state.pantry.premiumRoom(c, id)) {
      return false;
    }
    return purchaseSkill(purchaseGateway!, ingredientProduct(id), quantity: packs);
  }
  List<String> takePantryNews() { final news = pantryNews.toList(); pantryNews.clear(); return news; }
  /// Every command first throws away tubs made `expiry_ms` ago (the
  /// starting stock never goes bad) and says so — the one place expiry
  /// happens (4차 병합 3: B·D no longer call `expire` themselves).
  void _expirePantry() {
    final notice = expiredNotice(pantryConfig, state.pantry.expire(pantryConfig, _nowMs));
    if (notice != null) pantryNews.add(notice);
  }
  /// After every command: when the batter or every filling is out and
  /// 붕어빵력 cannot buy one tub of it, the free 기본 재료 꾸러미 (up to
  /// `rescue_pack.daily_limit` a KST day). Not during the first-run guide.
  void _rescuePantry() {
    if (state.tutorialActive) return;
    final day = businessDayKst(now());
    if (!state.pantry.rescueAvailable(pantryConfig, day, _nowMs, state.recipes,
        state.purchases.available(state.buns), pantryRate)) {
      return;
    }
    state.pantry.grantRescue(pantryConfig, day);
    pantryNews.add(rescueNotice(pantryConfig, state.pantry.rescueCount));
  }
  /// What stops production now for the home line and bubble: in business
  /// (after the first-run guide), [productionShortage]; none before opening.
  /// (4차 병합 3: B's and E's checks are one.)
  PantryShortage get pantryOut =>
      !state.business.open || state.tutorialActive ? PantryShortage.none : productionShortage;
}
