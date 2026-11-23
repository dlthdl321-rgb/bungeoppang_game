part of 'workshop_controller.dart';

/// 레벨업 조건·승급 (4차 피드백 g9).
/// [WorkshopController]에서 옮긴 그대로다(2026-11-23 안정화, 동작 변경 없음).
extension WorkshopLevelUp on WorkshopController {
  // ---- 레벨업 조건 (4차 피드백 g9, `level_progression`) ----
  // The one place the level-up rule lives. A level asks for pieces sold and
  // taps in that level (both start again at 0 on level-up) and a payment
  // taken when it is reached: `level_cost_buns` 붕어빵력, and at the levels
  // with `level_cost_gold` (Lv.10·20·30·40·50) 황금붕어빵력 too, which the
  // server wallet takes through a `level:N` purchase ([payLevelGold]).
  // API for the automatic 승급 and the Lv ring (4차 피드백 g1):
  //   [levelRequirements] rows for the window, [levelProgressPermille] the
  //   ring, [canLevelUp] whether [_promote] raises the level now,
  //   [levelGoalsMet] sales and taps only, [levelGoldDue] the gold purchase
  //   to start, [levelCostNote] / [levelWaitReason] the texts.
  Map<String, dynamic>? get _nextLevelRule => state.level >= 50 ? null : config.rows('level_progression')[state.level];
  /// 붕어빵력 the next level-up takes (0 at the top level).
  BigInt get levelCostBuns => _nextLevelRule == null ? BigInt.zero : DevelopmentBalance.decimal(_nextLevelRule!, 'level_cost_buns');
  /// 황금붕어빵력 the next level-up takes (Lv.10·20·30·40·50 only).
  int get levelCostGold => _nextLevelRule == null ? 0 : DevelopmentBalance.integer(_nextLevelRule!, 'level_cost_gold');
  int get levelPiecesSold => state.soldPieces - state.levelStartPieces;
  int get levelTaps => state.taps - state.levelStartTaps;
  /// The `level:N` purchase id of the next level when it asks for gold.
  String? get _levelGoldProduct => levelCostGold > 0 ? 'level:${state.level + 1}' : null;
  bool get _levelGoldPaid => _levelGoldProduct != null && state.purchases.owned[_levelGoldProduct] == 1;
  /// Sales and taps of this level are done (the payment may still wait).
  bool get levelGoalsMet {
    final rule = _nextLevelRule;
    return rule != null && levelPiecesSold >= DevelopmentBalance.integer(rule, 'additional_sold_pieces') &&
        levelTaps >= DevelopmentBalance.integer(rule, 'additional_taps');
  }
  /// What the next level asks for, as (label, how far, how much). Empty at
  /// the top level. The payment rows are full once it can be paid.
  List<LevelRequirement> get levelRequirements {
    final rule = _nextLevelRule;
    if (rule == null) return const [];
    final paid = _levelGoldPaid, cost = levelCostBuns, gold = levelCostGold;
    return [
      (label: '이번 레벨에 판 붕어빵', current: BigInt.from(levelPiecesSold),
        target: BigInt.from(DevelopmentBalance.integer(rule, 'additional_sold_pieces'))),
      (label: '이번 레벨 탭', current: BigInt.from(levelTaps), target: BigInt.from(DevelopmentBalance.integer(rule, 'additional_taps'))),
      (label: '레벨업 비용 붕어빵력', current: paid ? cost : state.purchases.available(state.buns), target: cost),
      if (gold > 0) (label: '레벨업 비용 황금붕어빵력', current: BigInt.from(paid ? gold : goldBalance), target: BigInt.from(gold)),
    ];
  }
  /// Whether the next level can be taken now: goals met and the payment
  /// ready (붕어빵력 on hand; at a gold level the `level:N` purchase done).
  bool get canLevelUp => levelGoalsMet &&
      (_levelGoldProduct != null ? _levelGoldPaid : state.purchases.available(state.buns) >= levelCostBuns);
  /// The way to the next level in permille for the Lv ring: the average of
  /// [levelRequirements], each up to its target; 1000 only when [canLevelUp]
  /// (and at the top level).
  int get levelProgressPermille {
    final rows = levelRequirements;
    if (rows.isEmpty) return 1000;
    var sum = 0;
    for (final r in rows) {
      final current = r.current < BigInt.zero ? BigInt.zero : r.current > r.target ? r.target : r.current;
      sum += r.target <= BigInt.zero ? 1000 : (current * BigInt.from(1000) ~/ r.target).toInt();
    }
    final average = sum ~/ rows.length;
    return average >= 1000 && !canLevelUp ? 999 : average;
  }
  void dismissPromotion() { promotedTo = null; }
  /// '레벨업할 때 붕어빵력 3만 개가 쓰여요' (and the gold at Lv.10·20·…), or
  /// null at the top level. Shown in the window and the ring's tooltip.
  String? get levelCostNote {
    if (_nextLevelRule == null) return null;
    final buns = compactNumber(levelCostBuns);
    return levelCostGold > 0 ? '레벨업할 때 붕어빵력 $buns, 황금붕어빵력 $levelCostGold개가 쓰여요'
        : '레벨업할 때 붕어빵력 $buns${subjectParticle(buns)} 쓰여요';
  }
  /// Why the level waits although sales and taps are done, or null.
  String? get levelWaitReason {
    if (!levelGoalsMet || canLevelUp) return null;
    final lack = levelCostBuns - state.purchases.available(state.buns), lackGold = levelCostGold - goldBalance;
    if (lack > BigInt.zero && lackGold > 0) return '붕어빵력이 ${compactNumber(lack)}, 황금붕어빵력이 $lackGold 모자라요.';
    if (lack > BigInt.zero) return '붕어빵력이 ${compactNumber(lack)} 모자라요.';
    if (lackGold > 0) return '황금붕어빵력이 $lackGold 모자라요.';
    if (purchaseGateway == null) return '인터넷에 연결해 주세요.';
    if (purchaseGateway!.authenticatedAccount.isEmpty) return '카카오 로그인 후 레벨업할 수 있어요.';
    return '황금붕어빵력을 내는 중이에요.';
  }
  /// A gold level whose sales, taps and 붕어빵력 are ready and whose gold
  /// the wallet seems to have: start [payLevelGold] (the page does it by
  /// itself, so 승급 stays automatic).
  bool get levelGoldDue => _levelGoldProduct != null && !_levelGoldPaid && levelGoalsMet &&
      state.purchases.available(state.buns) >= levelCostBuns && goldBalance >= levelCostGold &&
      purchaseGateway != null && purchaseGateway!.authenticatedAccount.isNotEmpty &&
      !_purchaseBusy && state.purchases.journals.values.every((j) => j.settled);
  /// Pays a gold level's 붕어빵력 and 황금붕어빵력 through the server
  /// purchase path (reserve → local debit → commit, like a skill); the
  /// level itself is raised by [_promote] after.
  Future<bool> payLevelGold() async {
    final product = _levelGoldProduct, gateway = purchaseGateway;
    if (product == null || gateway == null || !levelGoalsMet || _levelGoldPaid) return false;
    return purchaseSkill(gateway, product);
  }
  /// 승급 is automatic (4차 피드백 IA1): every command — the checkpoint save
  /// each `manual_cooking.checkpoint_ms` included — raises the level while
  /// [canLevelUp], several levels at once if need be, taking each level's payment:
  /// 붕어빵력 from the balance (lifetime stays), or nothing more at a gold
  /// level (its purchase took both). Sales and taps start again at 0.
  /// Each level's 붕어빵력 reward is added and its 황금 waits for the
  /// server's review as before (`pendingGold['level:N']`).
  void _promote() {
    while (canLevelUp) {
      final next = state.level + 1, rule = config.rows('level_progression')[state.level];
      if (!state.claimedLevels.add(next)) throw const FormatException('중복 승급');
      if (_levelGoldProduct == null) state.buns -= levelCostBuns;
      state..level = next ..levelStartTaps = state.taps ..levelStartSales = state.completedSales
        ..levelStartPieces = state.soldPieces;
      final buns = DevelopmentBalance.decimal(rule, 'buns_reward'); state.buns += buns; state.lifetime += buns;
      final gold = DevelopmentBalance.integer(rule, 'gold_reward');
      if (gold > 0) state.pendingGold['level:$next'] = jsonEncode({'level': next, 'gold': gold, 'revision': config.revision});
    }
  }
}
