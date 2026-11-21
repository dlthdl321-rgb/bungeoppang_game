import 'development_balance.dart';

/// 재료 타이쿤 규칙 (묶음 A: 설정·계산·저장 모양, 화면 없음).
///
/// 재료를 사서(기본 재료 = 붕어빵력, 특별한 재료 = 황금붕어빵력) 영업 준비
/// 때 미니게임으로 반죽·속을 '통'으로 만들고, 붕어빵 1개를 만들 때마다
/// 반죽 1인분 + 속 1인분을 씁니다. 모든 숫자는 설정
/// `config/development_balance.json`의 `ingredients` 절에 있습니다.
///
/// 사용자 결정 (2026-11-21, 설계안 `재료_타이쿤_설계안.md`보다 우선):
/// * 기본 재료 7종(붕어빵력), 특별한 재료 4종(황금, 덤). 1통 = 100인분.
/// * 가격 = R × 재료의 초(최저 `min_price_buns`), R = 탭 힘 ×
///   `rate_taps_per_second` + 초당 자동 생산 → 재료비 약 8%.
/// * 큰 붕어빵 탭 10번마다 1인분, 자동 생산 10초마다 1인분, 스페셜 틀 제작
///   1번에 1인분(결과 전 취소면 돌려받음), 6구 칸 하나에 1인분.
/// * 재료 준비(미니게임)는 영업 준비 중에만, 늘 미니게임('바로 만들기' 없음).
/// * 앱을 닫아 둔 동안은 재료를 쓰지 않음(부재 정산은 지금처럼).
/// * 만든 반죽·속은 만든 지 24시간(`expiry_ms`)이 지나면 버림. 상하는 통을
///   오래된 것부터 먼저 씀. 산 재료(기본·특별한)는 상하지 않음.
/// * 처음 재료(`starting_stock`)의 통은 상하지 않음 ([pantryKeepMs] 하나로, 묶음 B·E를
///   4차 병합 3에서 합침).
/// * 특제는 플레이어가 맛 고르기에서 '특제 팥'처럼 고를 때 씀: 그때 특제
///   반죽도 먼저 쓰고, 아니면 일반 반죽·속을 먼저 씀(없으면 특제로 이어 씀).
///
/// ## 다른 묶음이 쓰는 API
///
/// 설정: `PantryConfig.of(config)` (DevelopmentBalance마다 한 번 읽어 둠).
/// 상태: `WorkshopState.pantry` (`PantryState`, 가게 저장 schema 12의 `pantry`).
/// 모든 시각은 UTC ms(`nowMs`, 컨트롤러의 `now()`), 바꾸는 함수는 잘못되면
/// 한국어 문장의 `FormatException`을 던집니다(명령이 되돌리고 안내 줄에 씀).
///
/// **B 생산 연결**
/// * `productionFlavor(c, selected, owned, nowMs)` 대표 맛의 속이 없으면
///   팥소 → 슈크림 → 초코 크림 순으로 남은 맛, 반죽·속이 없으면 null.
///   `fallbackNotice(c, from, to)` = '팥소가 떨어져 슈크림으로 바꿨어요'.
/// * `shortage(c, flavor, nowMs)` → `PantryShortage.none/batter/filling`.
/// * `tap(c, flavor, nowMs, premium:)` 인정된 탭 1번. 쓰는 1인분(`PortionUse`)을
///   돌려주고, null이면 재료가 없어 탭을 세지 않음(10번에 1인분, 남은 탭 수는 저장).
/// * `runAuto(c, flavor, elapsedMs, nowMs, premium:)` 자동 생산 시간 [elapsedMs] 중
///   재료가 덮은 구간들(`AutoSegment` ms·배율). 덮지 못한 시간은 생산 없음.
///   앱을 닫아 둔 동안(부재 정산)은 부르지 않음.
/// * `takePortion(c, flavor, nowMs, premium:)` 스페셜 틀 제작 시작·6구 칸 하나.
///   결과 전 취소면 `refund(use)`. `griddleFlavors(c, candidates, nowMs)`는
///   6구가 고를 수 있는 맛(속이 남은 맛).
/// * `bonusPermille(c, use)` 특제 배율(1000 = 그대로, 특제 하나 1500, 둘 2000).
/// * `expire(c, nowMs)` 24시간 지난 통을 버리고 버린 것 목록을 돌려줌
///   (명령마다 먼저 부름). 안내 문장은 `expiredNotice(c, discarded)`.
///
/// **C 상점 '재료' 탭·구매**
/// * `c.basicPrice(id, rate)`·`c.basicCost(id, quantity, rate)`, rate는
///   `c.incomeRate(tapRate:, autoRate:)`. 단위 `c.buySteps`(1·10·100).
/// * `basicVisible(c, id, recipes)`(코코아 가루는 초코 레시피 뒤),
///   `premiumVisible(c, level)`(Lv.5부터).
/// * `buyBasic(c, id, quantity, recipes)` 개수만 늘림(붕어빵력은 호출한 쪽이
///   같은 명령에서 뺌), `basicRoom(c, id)` 더 살 수 있는 개수.
/// * `buyPremium(c, id, packs)` 서버 황금 구매가 확정된 뒤 묶음 수만큼(1묶음
///   = `c.premiumPackCount`개, `c.premiumPackGold` 황금).
/// * `shortfall(c, kind, tubs, premium:)` 모자란 기본 재료,
///   `shortfallCost(c, kind, tubs, rate)`, `buyShortfall(...)` '모자란 재료 한 번에 사기'.
///
/// **D 재료 준비 창·미니게임**
/// * `c.prepared`(반죽·팥소·슈크림·초코 크림: 이름·미니게임·레시피),
///   `preparedVisible(c, kind, recipes)`, `c.batchTubs`(1·3·5).
/// * `canMake(c, kind, tubs, level, nowMs, premium:)`, `makeBlocker(...)`
///   (못 만드는 까닭 한국어, 만들 수 있으면 null).
/// * `make(c, kind, tubs, level, nowMs, premium:, success:)` 미니게임 결과가
///   나올 때 한 번: 재료를 줄이고 통을 늘림, 성공이면 1통당 덤
///   `c.bonusPerTub`인분(보관 한도까지). 그만두면 부르지 않음(아무것도 안 줆).
/// * `portions(kind)`·`tubsText(c, portions)`·`c.stockLimitTubs(level)`.
///
/// **E 홈 표시·안내**
/// * `portions(c.batterKind, nowMs: nowMs)`, `portions(flavor, nowMs: nowMs)`,
///   `lowStock(c, kind, level, nowMs)`(20% 아래), `pantryEmptyText`.
/// * 레시피를 얻을 때 `grantRecipeGift(c, flavor, nowMs)`(한 번만).
/// * 빈털터리 방지 `rescueAvailable(...)` / `grantRescue(c, today)`.
/// * (묶음 E 구현) 홈 표시 규칙·문구는 `lib/pantry_home.dart`, 화면은
///   `lib/ui/pantry_home.dart`. 컨트롤러가 모든 명령 앞에서 `expire`, 뒤에서
///   꾸러미를 부르고 안내는 `WorkshopController.pantryNews`, 멈춤 판정은
///   `pantryOut`. 다른 묶음은 `expire`를 따로 부르지 않아도 됨.
const pantryEmptyText = '재료를 준비하세요';

/// `madeAtMs` of the starting stock's tubs (묶음 B, 사용자 결정 2026-11-21):
/// they never go bad. Used after the tubs that do.
const pantryKeepMs = 0;

/// Why production stops.
enum PantryShortage { none, batter, filling }

/// One kind of basic ingredient (bought with 붕어빵력).
class BasicIngredient {
  final String id, label, unitLabel;
  final int priceSeconds, maxStock;
  /// The recipe that shows it in the shop (코코아 가루: `cocoa`), else null.
  final String? requiresRecipe;
  const BasicIngredient(this.id, this.label, this.unitLabel, this.priceSeconds, this.maxStock, this.requiresRecipe);
}

/// One special ingredient (bought with 황금), for the 특제 of [prepared].
class PremiumIngredient {
  final String id, label, prepared;
  final int maxStock;
  const PremiumIngredient(this.id, this.label, this.prepared, this.maxStock);
}

/// Something made in the 재료 준비 window: the batter or a filling.
class PreparedKind {
  final String id, label, premiumLabel, minigame;
  /// The flavor a filling is for (null: the batter).
  final String? flavor;
  /// Basic ingredients for one tub.
  final Map<String, int> recipe;
  /// The special ingredient that makes it 특제 (one per tub).
  final String premiumIngredient;
  const PreparedKind(this.id, this.label, this.premiumLabel, this.minigame, this.flavor, this.recipe, this.premiumIngredient);
  bool get isBatter => flavor == null;
}

/// The `ingredients` section, read and checked once per [DevelopmentBalance].
class PantryConfig {
  final int rateTapsPerSecond, portionsPerTub, bonusPerTub, expiryMs, tapsPerPortion, autoMsPerPortion,
      specialMoldPortions, griddleCellPortions, premiumUnlockLevel, premiumPackGold, premiumPackCount,
      premiumBonusPermille, recipeGiftTubs, recipeGiftSets, rescueDailyLimit;
  final BigInt minPrice;
  final List<int> buySteps, batchTubs;
  /// (from level, tubs), ascending.
  final List<(int, int)> stockLimits;
  final List<String> fillingOrder;
  final Map<String, BasicIngredient> basic;
  final Map<String, PremiumIngredient> premium;
  final Map<String, PreparedKind> prepared;
  final Map<String, int> startingTubs, startingSets, rescueSets;
  /// Recipe names (`active_recipes.<flavor>.label`: 팥·슈크림·초코).
  final Map<String, String> recipeLabels;
  PantryConfig._({required this.recipeLabels, required this.rateTapsPerSecond, required this.portionsPerTub, required this.bonusPerTub,
      required this.expiryMs, required this.tapsPerPortion, required this.autoMsPerPortion,
      required this.specialMoldPortions, required this.griddleCellPortions, required this.premiumUnlockLevel,
      required this.premiumPackGold, required this.premiumPackCount, required this.premiumBonusPermille,
      required this.recipeGiftTubs, required this.recipeGiftSets, required this.rescueDailyLimit,
      required this.minPrice, required this.buySteps, required this.batchTubs, required this.stockLimits,
      required this.fillingOrder, required this.basic, required this.premium, required this.prepared,
      required this.startingTubs, required this.startingSets, required this.rescueSets});

  static final _cache = Expando<PantryConfig>();
  factory PantryConfig.of(DevelopmentBalance config) =>
      _cache[config] ??= PantryConfig.parse(config.section('ingredients'), config.section('active_recipes'));

  /// Checks and reads the section; any mistake is a `FormatException`.
  factory PantryConfig.parse(Map<String, dynamic> s, Map<String, dynamic> recipes) {
    int i(Map<String, dynamic> row, String key, {int min = 0}) {
      final v = DevelopmentBalance.integer(row, key);
      if (v < min) throw FormatException('재료 설정 오류: $key');
      return v;
    }
    Map<String, dynamic> m(Object? v, String what) {
      if (v is! Map<String, dynamic> || v.isEmpty) throw FormatException('재료 설정 오류: $what');
      return v;
    }
    List<int> ints(Object? v, String what) {
      if (v is! List || v.isEmpty || v.any((e) => e is! int || e < 1)) throw FormatException('재료 설정 오류: $what');
      final list = v.cast<int>();
      for (var k = 1; k < list.length; k++) {
        if (list[k] <= list[k - 1]) throw FormatException('재료 설정 오류: $what');
      }
      return List<int>.unmodifiable(list);
    }
    String text(Map<String, dynamic> row, String key) {
      final v = row[key];
      if (v is! String || v.isEmpty) throw FormatException('재료 설정 오류: $key');
      return v;
    }
    final consume = m(s['consume'], 'consume');
    final basic = <String, BasicIngredient>{};
    for (final e in m(s['basic'], 'basic').entries) {
      final row = m(e.value, e.key);
      final requires = row['requires_recipe'];
      if (requires != null && (requires is! String || !recipes.containsKey(requires))) {
        throw FormatException('재료 설정 오류: ${e.key}.requires_recipe');
      }
      basic[e.key] = BasicIngredient(e.key, text(row, 'label'), text(row, 'unit_label'),
          i(row, 'price_seconds', min: 1), i(row, 'max_stock', min: 1), requires as String?);
    }
    final premiumSection = m(s['premium'], 'premium');
    final premium = <String, PremiumIngredient>{};
    for (final e in m(premiumSection['items'], 'premium.items').entries) {
      final row = m(e.value, e.key);
      if (basic.containsKey(e.key)) throw FormatException('재료 설정 오류: 겹치는 ID ${e.key}');
      premium[e.key] = PremiumIngredient(e.key, text(row, 'label'), text(row, 'prepared'), i(row, 'max_stock', min: 1));
    }
    final prepared = <String, PreparedKind>{};
    for (final e in m(s['prepared'], 'prepared').entries) {
      final row = m(e.value, e.key);
      final flavor = row['flavor'];
      if (flavor != null && (flavor is! String || flavor != e.key || !recipes.containsKey(flavor))) {
        throw FormatException('재료 설정 오류: ${e.key}.flavor(맛 ID와 같아야 함)');
      }
      final recipe = <String, int>{};
      for (final r in m(row['recipe'], '${e.key}.recipe').entries) {
        if (!basic.containsKey(r.key) || r.value is! int || (r.value as int) < 1) {
          throw FormatException('재료 설정 오류: ${e.key}.recipe.${r.key}');
        }
        recipe[r.key] = r.value as int;
      }
      final premiumIds = [for (final p in premium.values) if (p.prepared == e.key) p.id];
      if (premiumIds.length != 1) throw FormatException('재료 설정 오류: ${e.key}의 특별한 재료는 하나');
      const minigames = {'stir', 'heat', 'whisk'};
      if (!minigames.contains(row['minigame'])) throw FormatException('재료 설정 오류: ${e.key}.minigame');
      prepared[e.key] = PreparedKind(e.key, text(row, 'label'), text(row, 'premium_label'), row['minigame'] as String,
          flavor as String?, Map.unmodifiable(recipe), premiumIds.single);
    }
    final batters = prepared.values.where((p) => p.isBatter).toList();
    if (batters.length != 1 || batters.single.id != 'batter') throw const FormatException('재료 설정 오류: 반죽은 batter 하나');
    if (!recipes.keys.every((f) => prepared.containsKey(f))) throw const FormatException('재료 설정 오류: 맛마다 속이 있어야 함');
    if (premium.values.any((p) => !prepared.containsKey(p.prepared))) throw const FormatException('재료 설정 오류: 특별한 재료의 대상');
    final order = s['filling_fallback_order'];
    if (order is! List || order.length != recipes.length || !order.every(recipes.containsKey) ||
        order.toSet().length != order.length) {
      throw const FormatException('재료 설정 오류: filling_fallback_order');
    }
    final limits = <(int, int)>[];
    final rawLimits = s['stock_limit_tubs'];
    if (rawLimits is! List || rawLimits.isEmpty) throw const FormatException('재료 설정 오류: stock_limit_tubs');
    for (final raw in rawLimits) {
      final row = m(raw, 'stock_limit_tubs');
      final from = i(row, 'from_level', min: 1), tubs = i(row, 'tubs', min: 1);
      if (limits.isEmpty ? from != 1 : from <= limits.last.$1 || tubs < limits.last.$2) {
        throw const FormatException('재료 설정 오류: stock_limit_tubs(Lv.1부터, 레벨·통 수 오름차순)');
      }
      limits.add((from, tubs));
    }
    Map<String, int> amounts(Object? raw, String what, bool Function(String) known) {
      final out = <String, int>{};
      for (final e in m(raw, what).entries) {
        if (!known(e.key) || e.value is! int || (e.value as int) < 1) throw FormatException('재료 설정 오류: $what.${e.key}');
        out[e.key] = e.value as int;
      }
      return Map.unmodifiable(out);
    }
    final start = m(s['starting_stock'], 'starting_stock');
    bool initialKind(String k) => k == 'batter' || (recipes[k] is Map && (recipes[k] as Map)['initial'] == true);
    final gift = m(s['recipe_gift'], 'recipe_gift'), rescue = m(s['rescue_pack'], 'rescue_pack');
    final config = PantryConfig._(
      recipeLabels: Map.unmodifiable({for (final e in recipes.entries) e.key: text(m(e.value, e.key), 'label')}),
      rateTapsPerSecond: i(s, 'rate_taps_per_second', min: 1),
      portionsPerTub: i(s, 'portions_per_tub', min: 1),
      bonusPerTub: i(s, 'minigame_bonus_portions_per_tub'),
      expiryMs: i(s, 'expiry_ms', min: 1),
      tapsPerPortion: i(consume, 'taps_per_portion', min: 1),
      autoMsPerPortion: i(consume, 'auto_ms_per_portion', min: 1),
      specialMoldPortions: i(consume, 'special_mold_portions', min: 1),
      griddleCellPortions: i(consume, 'griddle_cell_portions', min: 1),
      premiumUnlockLevel: i(premiumSection, 'unlock_level', min: 1),
      premiumPackGold: i(premiumSection, 'pack_gold', min: 1),
      premiumPackCount: i(premiumSection, 'pack_count', min: 1),
      premiumBonusPermille: i(premiumSection, 'bonus_permille'),
      recipeGiftTubs: i(gift, 'tubs'),
      recipeGiftSets: i(gift, 'recipe_sets'),
      rescueDailyLimit: i(rescue, 'daily_limit'),
      minPrice: DevelopmentBalance.decimal(s, 'min_price_buns'),
      buySteps: ints(s['buy_steps'], 'buy_steps'),
      batchTubs: ints(s['batch_tubs'], 'batch_tubs'),
      stockLimits: List.unmodifiable(limits),
      fillingOrder: List.unmodifiable(order.cast<String>()),
      basic: Map.unmodifiable(basic), premium: Map.unmodifiable(premium), prepared: Map.unmodifiable(prepared),
      startingTubs: amounts(start['tubs'], 'starting_stock.tubs', initialKind),
      startingSets: amounts(start['recipe_sets'], 'starting_stock.recipe_sets', initialKind),
      rescueSets: amounts(rescue['recipe_sets'], 'rescue_pack.recipe_sets', initialKind),
    );
    if (config.minPrice == BigInt.zero) throw const FormatException('재료 설정 오류: min_price_buns는 1 이상');
    for (final e in config.startingTubs.entries) {
      if (e.value > config.stockLimitTubs(1)) throw FormatException('재료 설정 오류: 처음 ${e.key}이 보관 한도보다 많음');
    }
    return config;
  }

  String get batterKind => 'batter';
  PreparedKind kind(String id) => prepared[id] ?? (throw FormatException('모르는 재료 준비: $id'));

  /// R: the income per second ingredient prices follow (tap power ×
  /// `rate_taps_per_second` + auto production per second).
  BigInt incomeRate({required BigInt tapRate, required BigInt autoRate}) =>
      tapRate * BigInt.from(rateTapsPerSecond) + autoRate;

  /// One unit of basic ingredient [id] at income [rate]: R × seconds, at
  /// least `min_price_buns`.
  BigInt basicPrice(String id, BigInt rate) {
    final item = basic[id] ?? (throw FormatException('모르는 재료: $id'));
    final price = rate * BigInt.from(item.priceSeconds);
    return price < minPrice ? minPrice : price;
  }
  BigInt basicCost(String id, int quantity, BigInt rate) => basicPrice(id, rate) * BigInt.from(quantity);

  /// Tubs of each prepared kind (batter, each filling) one shop may keep at [level].
  int stockLimitTubs(int level) {
    var tubs = stockLimits.first.$2;
    for (final (from, limit) in stockLimits) {
      if (level >= from) tubs = limit;
    }
    return tubs;
  }
  int stockLimitPortions(int level) => stockLimitTubs(level) * portionsPerTub;
}

/// One portion taken out: 1 batter + 1 filling of [flavor], with which tubs
/// (by the time they were made) and whether they were 특제. Kept to give it
/// back ([PantryState.refund]) and, for the tap and auto portion in use, saved.
class PortionUse {
  final String flavor;
  final bool batterPremium, fillingPremium;
  final int batterMadeAtMs, fillingMadeAtMs;
  const PortionUse({required this.flavor, required this.batterPremium, required this.fillingPremium,
      required this.batterMadeAtMs, required this.fillingMadeAtMs});
  Map<String, dynamic> toJson() => {'flavor': flavor, 'batterPremium': batterPremium, 'fillingPremium': fillingPremium,
    'batterMadeAtMs': batterMadeAtMs, 'fillingMadeAtMs': fillingMadeAtMs};
  factory PortionUse.fromJson(Object? raw, PantryConfig c) {
    if (raw is! Map<String, dynamic> || raw.length != 5 || raw['batterPremium'] is! bool || raw['fillingPremium'] is! bool ||
        raw['flavor'] is! String || c.prepared[raw['flavor']]?.isBatter != false) {
      throw const FormatException('재료 사용 기록 오류');
    }
    return PortionUse(flavor: raw['flavor'] as String, batterPremium: raw['batterPremium'] as bool,
        fillingPremium: raw['fillingPremium'] as bool, batterMadeAtMs: DevelopmentBalance.integer(raw, 'batterMadeAtMs'),
        fillingMadeAtMs: DevelopmentBalance.integer(raw, 'fillingMadeAtMs'));
  }
}

/// Production while the auto portion lasted: [ms] of auto time at [bonusPermille].
class AutoSegment {
  final int ms, bonusPermille;
  const AutoSegment(this.ms, this.bonusPermille);
}

/// Tubs made at one time: [kind] (batter or a flavor), 특제 or not.
class PantryLot {
  final String kind;
  final bool premium;
  final int madeAtMs;
  int portions;
  PantryLot(this.kind, this.premium, this.madeAtMs, this.portions);
  /// The starting stock ([pantryKeepMs]) never goes bad.
  bool get keeps => madeAtMs == pantryKeepMs;
  bool expired(PantryConfig c, int nowMs) => !keeps && nowMs - madeAtMs >= c.expiryMs;
  Map<String, dynamic> toJson() => {'kind': kind, 'premium': premium, 'madeAtMs': madeAtMs, 'portions': portions};
}

/// What a make produced.
class PantryMakeResult {
  final String kind;
  final bool premium;
  final int tubs, portions, bonus;
  const PantryMakeResult(this.kind, this.premium, this.tubs, this.portions, this.bonus);
}

/// Per prepared kind: portions made or given, used, thrown away. Made − used
/// − expired is always what the tubs hold (checked on loading).
class PantryLedger {
  int produced, used, expired;
  PantryLedger([this.produced = 0, this.used = 0, this.expired = 0]);
  int get held => produced - used - expired;
  List<int> toJson() => [produced, used, expired];
}

/// The pantry in the shop save (`pantry`, schema 12).
class PantryState {
  /// Basic ingredients by id (bought with 붕어빵력, never go bad).
  final Map<String, int> basic = {};
  /// Special ingredients by id (bought with 황금, never go bad).
  final Map<String, int> premium = {};
  /// Tubs made, oldest first.
  final List<PantryLot> lots = [];
  final Map<String, PantryLedger> ledger = {};
  /// Taps left on the portion taken out for the big bungeoppang (0~9) and that portion.
  int tapCredit = 0;
  PortionUse? tapPortion;
  /// Auto production time left on the portion taken out (ms) and that portion.
  int autoCreditMs = 0;
  PortionUse? autoPortion;
  /// Gifts already given: `start` (처음 재료), `recipe:<flavor>`.
  final Set<String> gifts = {};
  /// Free 기본 재료 꾸러미 given today ([rescueDay], KST date).
  String? rescueDay;
  int rescueCount = 0;

  PantryState();

  /// A new shop, or a save from before the pantry (schema ≤ 11) once:
  /// `starting_stock` tubs, which never go bad ([pantryKeepMs]), and the
  /// ingredients for `recipe_sets` more. ([nowMs] is kept for callers.)
  factory PantryState.starting(PantryConfig c, int nowMs) {
    final state = PantryState()..gifts.add('start');
    for (final e in c.startingTubs.entries) {
      state._addLot(e.key, false, pantryKeepMs, e.value * c.portionsPerTub);
    }
    for (final e in c.startingSets.entries) {
      state._addSets(c, e.key, e.value);
    }
    return state;
  }

  PantryLedger _ledger(String kind) => ledger.putIfAbsent(kind, PantryLedger.new);

  void _addLot(String kind, bool premium, int madeAtMs, int portions) {
    if (portions <= 0) return;
    _ledger(kind).produced += portions;
    _merge(kind, premium, madeAtMs, portions);
  }

  void _merge(String kind, bool premium, int madeAtMs, int portions) {
    for (final lot in lots) {
      if (lot.kind == kind && lot.premium == premium && lot.madeAtMs == madeAtMs) {
        lot.portions += portions;
        return;
      }
    }
    lots.add(PantryLot(kind, premium, madeAtMs, portions));
    _sort();
  }

  void _sort() => lots.sort((a, b) {
    final t = a.madeAtMs.compareTo(b.madeAtMs);
    if (t != 0) return t;
    final k = a.kind.compareTo(b.kind);
    return k != 0 ? k : (a.premium ? 1 : 0) - (b.premium ? 1 : 0);
  });

  void _addSets(PantryConfig c, String kind, int sets) {
    for (final e in c.kind(kind).recipe.entries) {
      basic[e.key] = (basic[e.key] ?? 0) + e.value * sets;
    }
  }

  // ---- 남은 양 ----

  /// Portions of [kind] held (only 특제 or only plain with [premium]); with
  /// [nowMs], tubs past their time are not counted.
  int portions(String kind, {bool? premium, int? nowMs, PantryConfig? config}) {
    var n = 0;
    for (final lot in lots) {
      if (lot.kind != kind || (premium != null && lot.premium != premium)) continue;
      if (nowMs != null && config != null && lot.expired(config, nowMs)) continue;
      n += lot.portions;
    }
    return n;
  }
  int usable(PantryConfig c, String kind, int nowMs) => portions(kind, nowMs: nowMs, config: c);

  /// Below 20% of the stock limit (orange on the home line); 0 is red.
  bool lowStock(PantryConfig c, String kind, int level, int nowMs) =>
      usable(c, kind, nowMs) * 5 < c.stockLimitPortions(level);

  PantryShortage shortage(PantryConfig c, String flavor, int nowMs) {
    if (usable(c, c.batterKind, nowMs) < 1) return PantryShortage.batter;
    if (usable(c, flavor, nowMs) < 1) return PantryShortage.filling;
    return PantryShortage.none;
  }

  /// The flavor production bakes: [selected] while its filling lasts, else
  /// the first owned flavor of `filling_fallback_order` with filling left;
  /// null when the batter or every filling is out (production stops).
  String? productionFlavor(PantryConfig c, String selected, Set<String> owned, int nowMs) {
    if (usable(c, c.batterKind, nowMs) < 1) return null;
    if (owned.contains(selected) && usable(c, selected, nowMs) > 0) return selected;
    for (final f in c.fillingOrder) {
      if (owned.contains(f) && usable(c, f, nowMs) > 0) return f;
    }
    return null;
  }

  /// Of [candidates] (the six-cell griddle's flavors), those it may bake now.
  List<String> griddleFlavors(PantryConfig c, Iterable<String> candidates, int nowMs) =>
      usable(c, c.batterKind, nowMs) < 1 ? const [] : [for (final f in candidates) if (usable(c, f, nowMs) > 0) f];

  // ---- 쓰기 ----

  /// The tub of [kind] to use next: 특제 or plain as [premium] asks first,
  /// then the other; within that, tubs that go bad (oldest first) before
  /// the starting stock that does not.
  PantryLot? _next(PantryConfig c, String kind, int nowMs, bool premium) {
    for (final (wantPremium, wantKeep) in [(premium, false), (premium, true), (!premium, false), (!premium, true)]) {
      for (final lot in lots) {
        if (lot.kind == kind && lot.premium == wantPremium && lot.keeps == wantKeep && lot.portions > 0 &&
            !lot.expired(c, nowMs)) {
          return lot;
        }
      }
    }
    return null;
  }

  /// Takes 1 batter + 1 [flavor] filling (스페셜 틀 제작 시작, 6구 칸 하나,
  /// 탭·자동 생산): 특제 first when [premium] (the player chose '특제 팥'),
  /// else plain first; tubs that go bad, oldest first, before the starting
  /// stock. Null (nothing changes) when either is out.
  PortionUse? takePortion(PantryConfig c, String flavor, int nowMs, {bool premium = false}) {
    final kind = c.kind(flavor);
    if (kind.isBatter) throw const FormatException('속 맛이 아니에요.');
    final batter = _next(c, c.batterKind, nowMs, premium), filling = _next(c, flavor, nowMs, premium);
    if (batter == null || filling == null) return null;
    for (final lot in [batter, filling]) {
      lot.portions--;
      _ledger(lot.kind).used++;
    }
    lots.removeWhere((l) => l.portions == 0);
    return PortionUse(flavor: flavor, batterPremium: batter.premium, fillingPremium: filling.premium,
        batterMadeAtMs: batter.madeAtMs, fillingMadeAtMs: filling.madeAtMs);
  }

  /// Gives back a portion taken out (스페셜 틀 결과 전 취소) into the tubs it
  /// came from. A tub past its time is thrown away at the next [expire].
  void refund(PortionUse use) {
    for (final (kind, premium, madeAt) in [
      ('batter', use.batterPremium, use.batterMadeAtMs),
      (use.flavor, use.fillingPremium, use.fillingMadeAtMs)]) {
      final ledger = _ledger(kind);
      if (ledger.used < 1) throw const FormatException('돌려받을 재료 기록이 없어요.');
      ledger.used--;
      _merge(kind, premium, madeAt, 1);
    }
  }

  /// One counted tap on the big bungeoppang (영업 중). Each portion lasts
  /// `taps_per_portion` taps: the first tap takes it out, the rest use it.
  /// Returns the portion in use, or null when the ingredients are out (the
  /// tap is not counted).
  PortionUse? tap(PantryConfig c, String flavor, int nowMs, {bool premium = false}) {
    if (tapCredit > 0 && tapPortion != null) {
      tapCredit--;
      final use = tapPortion!;
      if (tapCredit == 0) tapPortion = null;
      return use;
    }
    final use = takePortion(c, flavor, nowMs, premium: premium);
    if (use == null) return null;
    tapCredit = c.tapsPerPortion - 1;
    tapPortion = tapCredit == 0 ? null : use;
    return use;
  }

  /// [elapsedMs] of auto production (only while the app is in front): each
  /// portion covers `auto_ms_per_portion`. Returns the covered stretches;
  /// time not covered (ingredients out) produces nothing.
  List<AutoSegment> runAuto(PantryConfig c, String flavor, int elapsedMs, int nowMs, {bool premium = false}) {
    final segments = <AutoSegment>[];
    var left = elapsedMs;
    while (left > 0) {
      if (autoCreditMs == 0 || autoPortion == null) {
        final use = takePortion(c, flavor, nowMs, premium: premium);
        if (use == null) break;
        autoPortion = use;
        autoCreditMs = c.autoMsPerPortion;
      }
      final step = left < autoCreditMs ? left : autoCreditMs;
      final bonus = bonusPermille(c, autoPortion!);
      if (segments.isNotEmpty && segments.last.bonusPermille == bonus) {
        segments[segments.length - 1] = AutoSegment(segments.last.ms + step, bonus);
      } else {
        segments.add(AutoSegment(step, bonus));
      }
      autoCreditMs -= step;
      left -= step;
      if (autoCreditMs == 0) autoPortion = null;
    }
    return segments;
  }

  /// 특제 multiplier of a portion in permille (1000 = plain).
  int bonusPermille(PantryConfig c, PortionUse use) =>
      1000 + (use.batterPremium ? c.premiumBonusPermille : 0) + (use.fillingPremium ? c.premiumBonusPermille : 0);

  /// Throws away tubs made `expiry_ms` or more ago; returns them (for the notice).
  List<PantryLot> expire(PantryConfig c, int nowMs) {
    final gone = [for (final lot in lots) if (lot.expired(c, nowMs)) lot];
    for (final lot in gone) {
      _ledger(lot.kind).expired += lot.portions;
    }
    lots.removeWhere((l) => l.expired(c, nowMs));
    return gone;
  }

  // ---- 사기 ----

  bool basicVisible(PantryConfig c, String id, Set<String> recipes) {
    final need = c.basic[id]?.requiresRecipe;
    return c.basic.containsKey(id) && (need == null || recipes.contains(need));
  }
  bool premiumVisible(PantryConfig c, int level) => level >= c.premiumUnlockLevel;
  int basicRoom(PantryConfig c, String id) => c.basic[id]!.maxStock - (basic[id] ?? 0);
  int premiumRoom(PantryConfig c, String id) => c.premium[id]!.maxStock - (premium[id] ?? 0);

  /// Adds [quantity] of basic ingredient [id]. The caller takes
  /// `c.basicCost(id, quantity, rate)` 붕어빵력 in the same command.
  void buyBasic(PantryConfig c, String id, int quantity, Set<String> recipes) {
    final item = c.basic[id] ?? (throw FormatException('모르는 재료: $id'));
    if (!basicVisible(c, id, recipes)) {
      final recipe = c.recipeLabels[item.requiresRecipe] ?? item.requiresRecipe;
      throw FormatException('${item.label}${_topic(item.label)} $recipe 레시피를 얻으면 살 수 있어요.');
    }
    if (quantity < 1) throw const FormatException('살 개수를 골라 주세요.');
    if (quantity > basicRoom(c, id)) throw FormatException('${item.label}${_topic(item.label)} ${item.maxStock}개까지 보관할 수 있어요.');
    basic[id] = (basic[id] ?? 0) + quantity;
  }

  /// Adds [packs] packs of special ingredient [id] (`pack_count` each), after
  /// the server took `pack_gold` × [packs] 황금.
  void buyPremium(PantryConfig c, String id, int packs, int level) {
    final item = c.premium[id] ?? (throw FormatException('모르는 특별한 재료: $id'));
    if (!premiumVisible(c, level)) throw FormatException('특별한 재료는 Lv.${c.premiumUnlockLevel}부터 살 수 있어요.');
    if (packs < 1) throw const FormatException('살 개수를 골라 주세요.');
    if (packs * c.premiumPackCount > premiumRoom(c, id)) {
      throw FormatException('${item.label}${_topic(item.label)} ${item.maxStock}개까지 보관할 수 있어요.');
    }
    premium[id] = (premium[id] ?? 0) + packs * c.premiumPackCount;
  }

  /// Basic ingredients missing to make [tubs] tubs of [kind] (empty: none).
  Map<String, int> shortfall(PantryConfig c, String kind, int tubs) {
    final out = <String, int>{};
    for (final e in c.kind(kind).recipe.entries) {
      final missing = e.value * tubs - (basic[e.key] ?? 0);
      if (missing > 0) out[e.key] = missing;
    }
    return out;
  }
  BigInt shortfallCost(PantryConfig c, String kind, int tubs, BigInt rate) =>
      shortfall(c, kind, tubs).entries.fold(BigInt.zero, (sum, e) => sum + c.basicCost(e.key, e.value, rate));

  /// '모자란 재료 한 번에 사기': buys what [shortfall] lists and returns its
  /// cost (the caller takes it in the same command).
  BigInt buyShortfall(PantryConfig c, String kind, int tubs, BigInt rate, Set<String> recipes) {
    final missing = shortfall(c, kind, tubs);
    if (missing.isEmpty) throw const FormatException('모자란 재료가 없어요.');
    final cost = shortfallCost(c, kind, tubs, rate);
    for (final e in missing.entries) {
      buyBasic(c, e.key, e.value, recipes);
    }
    return cost;
  }

  // ---- 만들기 (재료 준비, 영업 준비 중에만: 호출한 쪽이 확인) ----

  bool preparedVisible(PantryConfig c, String kind, Set<String> recipes) {
    final flavor = c.kind(kind).flavor;
    return flavor == null || recipes.contains(flavor);
  }

  /// Why [tubs] tubs of [kind] cannot be made now (Korean), or null.
  String? makeBlocker(PantryConfig c, String kind, int tubs, int level, int nowMs, Set<String> recipes,
      {bool premium = false}) {
    final k = c.kind(kind);
    if (!preparedVisible(c, kind, recipes)) return '${c.recipeLabels[k.flavor] ?? k.label} 레시피를 아직 얻지 못했어요.';
    if (!c.batchTubs.contains(tubs)) return '만들 통 수를 골라 주세요.';
    if (premium && !premiumVisible(c, level)) return '특제는 Lv.${c.premiumUnlockLevel}부터 만들 수 있어요.';
    final limit = c.stockLimitTubs(level);
    if (usable(c, kind, nowMs) + tubs * c.portionsPerTub > limit * c.portionsPerTub) {
      return '${k.label}${_topic(k.label)} $limit통까지 보관할 수 있어요.';
    }
    if (shortfall(c, kind, tubs).isNotEmpty) return '재료가 모자라요.';
    if (premium && (this.premium[k.premiumIngredient] ?? 0) < tubs) {
      final item = c.premium[k.premiumIngredient]!;
      return '${item.label}${_subject(item.label)} 모자라요.';
    }
    return null;
  }
  bool canMake(PantryConfig c, String kind, int tubs, int level, int nowMs, Set<String> recipes, {bool premium = false}) =>
      makeBlocker(c, kind, tubs, level, nowMs, recipes, premium: premium) == null;

  /// The mini-game ended: uses the ingredients for [tubs] tubs and adds the
  /// tubs (made at [nowMs]); [success] adds `minigame_bonus_portions_per_tub`
  /// per tub, up to the stock limit. Expired tubs are thrown away first
  /// (they do not take room) — call [expire] before to show them.
  PantryMakeResult make(PantryConfig c, String kind, int tubs, int level, int nowMs, Set<String> recipes,
      {bool premium = false, bool success = false}) {
    final blocker = makeBlocker(c, kind, tubs, level, nowMs, recipes, premium: premium);
    if (blocker != null) throw FormatException(blocker);
    final k = c.kind(kind);
    for (final e in k.recipe.entries) {
      basic[e.key] = basic[e.key]! - e.value * tubs;
      if (basic[e.key] == 0) basic.remove(e.key);
    }
    if (premium) {
      this.premium[k.premiumIngredient] = this.premium[k.premiumIngredient]! - tubs;
      if (this.premium[k.premiumIngredient] == 0) this.premium.remove(k.premiumIngredient);
    }
    final base = tubs * c.portionsPerTub;
    final room = c.stockLimitPortions(level) - usable(c, kind, nowMs) - base;
    final wanted = success ? tubs * c.bonusPerTub : 0;
    final bonus = wanted < room ? wanted : room;
    _addLot(kind, premium, nowMs, base + bonus);
    return PantryMakeResult(kind, premium, tubs, base + bonus, bonus);
  }

  // ---- 선물·꾸러미 ----

  /// A new recipe's gift (once per flavor): `recipe_gift.tubs` tubs of its
  /// filling and the ingredients for `recipe_sets` more. False if given before.
  bool grantRecipeGift(PantryConfig c, String flavor, int nowMs) {
    final k = c.kind(flavor);
    if (k.isBatter || !gifts.add('recipe:$flavor')) return false;
    _addLot(flavor, false, nowMs, c.recipeGiftTubs * c.portionsPerTub);
    _addSets(c, flavor, c.recipeGiftSets);
    return true;
  }

  /// The free 기본 재료 꾸러미: the batter and every owned filling are out,
  /// the ingredients on hand make neither, [buns] cannot buy what is missing
  /// for one tub of each, and fewer than `daily_limit` were given [today].
  bool rescueAvailable(PantryConfig c, String today, int nowMs, Set<String> recipes, BigInt buns, BigInt rate) {
    if ((rescueDay == today ? rescueCount : 0) >= c.rescueDailyLimit) return false;
    final noBatter = usable(c, c.batterKind, nowMs) < 1;
    final noFilling = recipes.every((f) => usable(c, f, nowMs) < 1);
    if (!noBatter && !noFilling) return false;
    var cost = BigInt.zero;
    for (final kind in c.rescueSets.keys) {
      final out = c.kind(kind).isBatter ? noBatter : noFilling;
      if (out) cost += shortfallCost(c, kind, 1, rate);
    }
    return cost > BigInt.zero && buns < cost;
  }
  void grantRescue(PantryConfig c, String today) {
    if (rescueDay != today) { rescueDay = today; rescueCount = 0; }
    if (rescueCount >= c.rescueDailyLimit) throw const FormatException('오늘 받을 수 있는 꾸러미를 다 받았어요.');
    rescueCount++;
    for (final e in c.rescueSets.entries) {
      _addSets(c, e.key, e.value);
    }
  }

  // ---- 저장 ----

  Map<String, dynamic> toJson() => {
    'basic': Map<String, int>.from(basic), 'premium': Map<String, int>.from(premium),
    'lots': [for (final lot in lots) lot.toJson()],
    'ledger': {for (final e in ledger.entries) e.key: e.value.toJson()},
    'tapCredit': tapCredit, 'tapPortion': tapPortion?.toJson(),
    'autoCreditMs': autoCreditMs, 'autoPortion': autoPortion?.toJson(),
    'gifts': gifts.toList()..sort(), 'rescueDay': rescueDay, 'rescueCount': rescueCount};

  /// Reads and checks the saved pantry: known ids, counts ≥ 0, tubs ≥ 1
  /// portion, made − used − expired = what the tubs hold. Fillings of
  /// recipes not owned are refused by `WorkshopState.fromJson`. Limits that
  /// come from the config (stock limits, max stock) are not checked here, so
  /// changing them never breaks a save; credits past a changed config are cut.
  factory PantryState.fromJson(Object? raw, PantryConfig c) {
    if (raw is! Map<String, dynamic>) throw const FormatException('재료 저장 형식 오류');
    const keys = {'basic', 'premium', 'lots', 'ledger', 'tapCredit', 'tapPortion', 'autoCreditMs', 'autoPortion',
      'gifts', 'rescueDay', 'rescueCount'};
    if (raw.length != keys.length || !raw.keys.every(keys.contains)) throw const FormatException('재료 저장 항목 오류');
    final state = PantryState();
    void counts(Object? v, Map<String, int> into, bool Function(String) known) {
      if (v is! Map<String, dynamic>) throw const FormatException('재료 개수 형식 오류');
      for (final e in v.entries) {
        if (!known(e.key) || e.value is! int || (e.value as int) < 1) throw const FormatException('재료 개수 오류');
        into[e.key] = e.value as int;
      }
    }
    counts(raw['basic'], state.basic, c.basic.containsKey);
    counts(raw['premium'], state.premium, c.premium.containsKey);
    final lots = raw['lots'];
    if (lots is! List) throw const FormatException('재료 통 형식 오류');
    for (final row in lots) {
      if (row is! Map<String, dynamic> || row.length != 4 || !c.prepared.containsKey(row['kind']) || row['premium'] is! bool) {
        throw const FormatException('재료 통 오류');
      }
      final portions = DevelopmentBalance.integer(row, 'portions');
      if (portions < 1) throw const FormatException('빈 재료 통');
      final lot = PantryLot(row['kind'] as String, row['premium'] as bool, DevelopmentBalance.integer(row, 'madeAtMs'), portions);
      if (state.lots.any((l) => l.kind == lot.kind && l.premium == lot.premium && l.madeAtMs == lot.madeAtMs)) {
        throw const FormatException('겹친 재료 통');
      }
      state.lots.add(lot);
    }
    state._sort();
    final ledger = raw['ledger'];
    if (ledger is! Map<String, dynamic>) throw const FormatException('재료 기록 형식 오류');
    for (final e in ledger.entries) {
      final v = e.value;
      if (!c.prepared.containsKey(e.key) || v is! List || v.length != 3 || v.any((n) => n is! int || n < 0)) {
        throw const FormatException('재료 기록 오류');
      }
      state.ledger[e.key] = PantryLedger(v[0] as int, v[1] as int, v[2] as int);
    }
    for (final kind in {...state.ledger.keys, for (final l in state.lots) l.kind}) {
      if ((state.ledger[kind]?.held ?? 0) != state.portions(kind)) throw const FormatException('만든 재료와 남은 재료가 맞지 않아요.');
    }
    final tap = DevelopmentBalance.integer(raw, 'tapCredit'), auto = DevelopmentBalance.integer(raw, 'autoCreditMs');
    final tapUse = raw['tapPortion'] == null ? null : PortionUse.fromJson(raw['tapPortion'], c);
    final autoUse = raw['autoPortion'] == null ? null : PortionUse.fromJson(raw['autoPortion'], c);
    if ((tap == 0) != (tapUse == null) || (auto == 0) != (autoUse == null)) throw const FormatException('꺼내 둔 재료 기록 오류');
    state
      ..tapCredit = tap < c.tapsPerPortion ? tap : c.tapsPerPortion - 1
      ..tapPortion = state.tapCredit == 0 ? null : tapUse
      ..autoCreditMs = auto <= c.autoMsPerPortion ? auto : c.autoMsPerPortion
      ..autoPortion = autoUse;
    final gifts = raw['gifts'];
    if (gifts is! List || gifts.any((g) => g is! String ||
        !(g == 'start' || (g.startsWith('recipe:') && c.prepared[g.substring(7)]?.isBatter == false))) ||
        gifts.toSet().length != gifts.length) {
      throw const FormatException('재료 선물 기록 오류');
    }
    state.gifts.addAll(gifts.cast<String>());
    final day = raw['rescueDay'], count = DevelopmentBalance.integer(raw, 'rescueCount');
    if ((day == null) != (count == 0) || (day != null && (day is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)))) {
      throw const FormatException('재료 꾸러미 기록 오류');
    }
    state
      ..rescueDay = day as String?
      ..rescueCount = count;
    return state;
  }

  /// Prepared kinds held that need a recipe (WorkshopState refuses those not owned).
  Set<String> get heldFlavors => {
    for (final l in lots) if (l.kind != 'batter') l.kind,
    for (final p in [tapPortion, autoPortion]) if (p != null) p.flavor};
}

// ---- 문구 ----

/// '3통', or '137인분' when not whole tubs.
String tubsText(PantryConfig c, int portions) =>
    portions > 0 && portions % c.portionsPerTub == 0 ? '${portions ~/ c.portionsPerTub}통' : '$portions인분';

/// '만든 지 24시간이 지난 반죽 1통, 팥소 37인분을 버렸어요.' (null: nothing thrown away).
String? expiredNotice(PantryConfig c, List<PantryLot> discarded) {
  if (discarded.isEmpty) return null;
  final byKind = <String, int>{};
  for (final lot in discarded) {
    final name = lot.premium ? c.kind(lot.kind).premiumLabel : c.kind(lot.kind).label;
    byKind[name] = (byKind[name] ?? 0) + lot.portions;
  }
  final parts = [for (final e in byKind.entries) '${e.key} ${tubsText(c, e.value)}'];
  final hours = c.expiryMs ~/ 3600000;
  final last = parts.last;
  return '만든 지 $hours시간이 지난 ${parts.join(', ')}${_object(last)} 버렸어요.';
}

/// '팥소가 떨어져 슈크림으로 바꿨어요'; with [fromPremium] the 특제 one
/// ran out ('특제 팥소가 떨어져 팥소로 바꿨어요', [to] may be the same flavor).
String fallbackNotice(PantryConfig c, String from, String to, {bool fromPremium = false}) {
  final a = fromPremium ? c.kind(from).premiumLabel : c.kind(from).label, b = c.kind(to).label;
  return '$a${_subject(a)} 떨어져 $b${_toward(b)} 바꿨어요';
}

/// '팥소가 없어요. 재료를 준비하세요' (스페셜 틀 시작 버튼).
String missingFillingText(PantryConfig c, String flavor, int nowMs, PantryState pantry) {
  if (pantry.usable(c, c.batterKind, nowMs) < 1) return '반죽이 없어요. $pantryEmptyText';
  final label = c.kind(flavor).label;
  return '$label${_subject(label)} 없어요. $pantryEmptyText';
}

int? _lastHangul(String word) {
  for (var i = word.length - 1; i >= 0; i--) {
    final code = word.codeUnitAt(i);
    if (code >= 0xac00 && code <= 0xd7a3) return code;
    if (code >= 0x30 && code <= 0x39) return null;
  }
  return null;
}
int _jong(String word) {
  final code = _lastHangul(word);
  if (code != null) return (code - 0xac00) % 28;
  // Numbers and units ('37인분', '1통') end in Hangul; anything else counts as a final consonant.
  return 1;
}
String _subject(String w) => _jong(w) == 0 ? '가' : '이';
String _topic(String w) => _jong(w) == 0 ? '는' : '은';
String _object(String w) => _jong(w) == 0 ? '를' : '을';
/// 으로/로: no final consonant or ㄹ (8) takes 로.
String _toward(String w) {
  final j = _jong(w);
  return j == 0 || j == 8 ? '로' : '으로';
}
