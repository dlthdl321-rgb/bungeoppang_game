import 'development_balance.dart';
import 'workshop_controller.dart';

/// 26번 2단계 (DEC-043, A. 하나씩 열기): what the first five minutes show.
/// The guide shows baking, business, guests, sales and the big bungeoppang;
/// everything else opens one at a time. Core progress (baking, selling,
/// business) is never locked by level. The page, the home and the windows all
/// ask [featureOpen] / [featureLockReason], so one rule decides.
enum WorkshopFeature {
  /// 꾸미기 and 상점: after the first-run guide.
  wardrobe,
  /// The skill window (tap and auto) and the per-second / per-tap numbers:
  /// `feature_unlock_levels.skill_shop` (Lv.2).
  skills,
  /// The six-cell griddle: once one flavor's 도감 is complete (4차 피드백 g6,
  /// DEC-TBD-i4g6-2; before: one flavor mastered, S2-Q2), at or after
  /// `six_slot_access` (Lv.1).
  griddle,
  /// 도감: `full_recipe_collection_ui` (Lv.3).
  collection,
  /// New flavor recipes: the first `additional_recipe_acquisition_tiers` level (Lv.4).
  recipes,
  /// Special orders (a doneness on request): `ordinary_sale.special_order_unlock_level` (Lv.5).
  specialOrders,
  /// 붕어빵 꾸미기 tab: `fish_cosmetics` (Lv.5).
  fishCosmetics,
  /// Freshness: once stock has waited a business day. Never locks anything,
  /// it only brings its introduction card.
  freshness,
  /// 가게 꾸미기: `stall_cosmetics` (Lv.8).
  stallCosmetics,
  /// The 가게 tab's 배경 and 시간 (and the menu's 배경 테마):
  /// `stall_background` (Lv.1, 26번 3차 H42). No introduction card.
  stallBackground,
  /// 재료 준비 (재료 타이쿤 E): the '재료 준비' button beside '스페셜 붕어빵
  /// 제작 시작' (during 영업 준비): `feature_unlock_levels.pantry_prep` (Lv.2).
  /// The stock line on the home and using ingredients are never locked.
  pantry,
  /// The 붕어빵 요정's story (4차 피드백 IA3): never locks anything; its
  /// card shows once after the first-run guide, when the fairy is out (in
  /// business, no guests, nothing in the big mold).
  fairy,
}

/// Features with a one-screen introduction card, in the order they are shown
/// when several open together. The saved id is the enum name (schema 8
/// `featureIntros`).
const workshopIntroFeatures = [
  // 4차 g5: every feature that opens later gets a card and a short tour;
  // the 꾸미기·상점·오늘 card only right after the first-run guide.
  WorkshopFeature.wardrobe,
  WorkshopFeature.skills,
  // 재료 타이쿤 E: opens with the skills at Lv.2, its card right after theirs.
  WorkshopFeature.pantry,
  WorkshopFeature.griddle,
  WorkshopFeature.collection,
  WorkshopFeature.recipes,
  WorkshopFeature.specialOrders,
  WorkshopFeature.fishCosmetics,
  WorkshopFeature.freshness,
  WorkshopFeature.stallCosmetics,
  // Last: the story waits for any card that explains a new feature.
  WorkshopFeature.fairy,
];

final workshopIntroIds = {for (final f in workshopIntroFeatures) f.name};

/// The level [feature] opens at, or null when it is not opened by level.
int? featureUnlockLevel(DevelopmentBalance config, WorkshopFeature feature) {
  final levels = config.section('feature_unlock_levels');
  int level(String key) => DevelopmentBalance.integer(levels, key);
  return switch (feature) {
    WorkshopFeature.skills => level('skill_shop'),
    WorkshopFeature.pantry => level('pantry_prep'),
    WorkshopFeature.collection => level('full_recipe_collection_ui'),
    WorkshopFeature.recipes => config.rows('additional_recipe_acquisition_tiers')
        .map((r) => DevelopmentBalance.integer(r, 'unlock_level')).reduce((a, b) => a < b ? a : b),
    WorkshopFeature.specialOrders =>
      DevelopmentBalance.integer(config.section('ordinary_sale'), 'special_order_unlock_level'),
    WorkshopFeature.fishCosmetics => level('fish_cosmetics'),
    WorkshopFeature.stallCosmetics => level('stall_cosmetics'),
    WorkshopFeature.stallBackground => level('stall_background'),
    WorkshopFeature.griddle => level('six_slot_access'),
    WorkshopFeature.wardrobe || WorkshopFeature.freshness || WorkshopFeature.fairy => null,
  };
}

/// Whether [feature] is open for [s].
bool featureOpen(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) {
  final level = featureUnlockLevel(config, feature);
  final byLevel = level == null || s.level >= level;
  return switch (feature) {
    WorkshopFeature.wardrobe => !s.tutorialActive,
    // Like the wardrobe it lives in: after the first-run guide.
    WorkshopFeature.stallBackground => byLevel && !s.tutorialActive,
    // A skill already bought, or a purchase still being settled, keeps the
    // window open whatever the level (old saves, recovery).
    WorkshopFeature.skills => byLevel ||
        s.purchases.owned.entries.any((e) => !e.key.contains(':') && e.value > 0) ||
        s.purchases.journals.values.any((j) => !j.settled),
    WorkshopFeature.griddle => byLevel && s.griddleFlavors(config).isNotEmpty,
    WorkshopFeature.recipes => byLevel || s.recipes.length > 1,
    WorkshopFeature.fairy => !s.tutorialActive && s.business.open && s.customers.isEmpty && s.session == null,
    WorkshopFeature.freshness => s.inventory.batches.values.any((b) =>
        (s.inventory.bindings[b.id] ?? b.madeOnBusinessIndex) < s.business.businessIndex),
    _ => byLevel,
  };
}

/// What a locked [feature] says: 'Lv.2 달성하면 열려요' (4차 g5), the guide,
/// or the 도감 cells still to complete for the six-cell griddle (4차 피드백
/// g6). Null when it is open.
String? featureLockReason(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) {
  if (featureOpen(s, config, feature)) return null;
  final level = featureUnlockLevel(config, feature);
  if (feature == WorkshopFeature.wardrobe) return '첫 영업 안내가 끝나면 열려요';
  if (feature == WorkshopFeature.griddle && (level == null || s.level >= level)) {
    // The flavor being baked, else the first one everyone has: 팥 (redbean).
    final flavor = s.recipes.contains(s.selectedFlavor) ? s.selectedFlavor : 'redbean';
    final label = (config.section('active_recipes')[flavor] as Map)['label'] as String;
    return '$label 도감을 완성하면 열려요 (${s.collection(config, flavor).completedCells}/5)';
  }
  if (feature == WorkshopFeature.freshness || feature == WorkshopFeature.fairy) return null;
  return 'Lv.$level 달성하면 열려요';
}

/// Whether [feature] has anything to introduce (4차 피드백 g15): 가게
/// 꾸미기 only once the shop sells a stove or a decoration
/// (`avatar_catalog` slot `stove`·`decoration`), 붕어빵 꾸미기 only once it
/// sells a mold pattern or topping (slot `pattern`·`topping`) — until then
/// those wardrobe slots (and the 붕어빵 tab) are hidden, so the card waits
/// (not marked seen) and the replay list leaves it out.
bool featureAvailable(DevelopmentBalance config, WorkshopFeature feature) {
  final slots = switch (feature) {
    WorkshopFeature.stallCosmetics => const {'stove', 'decoration'},
    WorkshopFeature.fishCosmetics => const {'pattern', 'topping'},
    _ => null,
  };
  return slots == null || config.section('avatar_catalog').values.any((row) => slots.contains((row as Map)['slot']));
}

/// The first introduction card still to show, or null.
WorkshopFeature? pendingFeatureIntro(WorkshopState s, DevelopmentBalance config) {
  if (s.tutorialActive) return null;
  for (final f in workshopIntroFeatures) {
    if (f == WorkshopFeature.wardrobe && !s.guideJustEnded) continue;
    if (!featureAvailable(config, f)) continue;
    if (!s.featureIntros.contains(f.name) && featureOpen(s, config, f)) return f;
  }
  return null;
}

/// What the replay list says about a closed [feature] (4차 g5): the lock
/// reason, or for 신선도 (never locked by level) when it comes.
String featureWaitText(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) =>
    featureLockReason(s, config, feature) ??
    (feature == WorkshopFeature.fairy ? '손님이 없는 영업 중에 만나요' : '재고가 영업일을 넘기면 열려요');

/// Whether the replay list can show [feature] again (4차 병합: the 붕어빵
/// 요정's story, once met, stays replayable with guests around too).
bool featureReplayable(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) =>
    featureOpen(s, config, feature) ||
    (feature == WorkshopFeature.fairy && s.featureIntros.contains(feature.name));

/// The short name in the '튜토리얼 다시 보기' list.
String featureName(WorkshopFeature feature) => switch (feature) {
      WorkshopFeature.wardrobe => '꾸미기·상점·오늘',
      WorkshopFeature.skills => '스킬',
      WorkshopFeature.pantry => '재료 준비',
      WorkshopFeature.griddle => '숙련된 붕어빵 틀',
      WorkshopFeature.collection => '도감',
      WorkshopFeature.recipes => '새 맛 레시피',
      WorkshopFeature.specialOrders => '특별 주문',
      WorkshopFeature.fishCosmetics => '붕어빵 꾸미기',
      WorkshopFeature.freshness => '붕어빵의 신선도',
      WorkshopFeature.stallCosmetics => '가게 꾸미기',
      WorkshopFeature.stallBackground => '배경 테마',
      WorkshopFeature.fairy => '붕어빵 요정',
    };

/// One step of a feature's short tour (4차 g5): a ring around the home
/// widget keyed [target] and a card with [text], '다음' and '건너뛰기'.
/// When [target] is not on screen the card shows without the ring.
class FeatureTourStep {
  final String text, target;
  const FeatureTourStep(this.text, this.target);
}

/// The 1–3 steps after a feature's card (4차 g5), pointing at the real
/// buttons on the home. The words stay about where to tap, not about the
/// unlock condition (the six-cell griddle's condition may change).
List<FeatureTourStep> featureTour(WorkshopFeature feature) => switch (feature) {
      WorkshopFeature.wardrobe => const [
          FeatureTourStep('여기 ‘꾸미기’에서 사장님 머리와 옷을 바꿔 입어요.', 'menu-skins'),
          FeatureTourStep('‘상점’에서는 새 꾸미기를 사요.', 'menu-shop'),
          FeatureTourStep('이 쪽지를 누르면 출석 도장과 오늘의 주문서가 있어요.', 'daily-ticket'),
        ],
      WorkshopFeature.skills => const [
          FeatureTourStep('여기 ‘스킬’을 눌러 클릭 생산과 자동 생산 스킬을 레벨업해요.', 'menu-skills'),
          FeatureTourStep('위쪽에서 초당·클릭당 붕어빵력을 볼 수 있어요.', 'auto-rate'),
        ],
      WorkshopFeature.pantry => const [
          FeatureTourStep('여기에 남은 반죽과 속이 보여요. 조금 남으면 주황색, 다 떨어지면 빨간색이 돼요.', 'pantry-stock'),
          FeatureTourStep('영업 준비 중에는 ‘스페셜 붕어빵 제작 시작’ 옆의 ‘재료 준비’에서 미니게임으로 반죽과 속을 만들어요.', 'pantry-prep'),
        ],
      WorkshopFeature.griddle => const [
          FeatureTourStep('영업 중에 이 틀의 빈 칸을 누르면 굽기 시작해요. 익으면 눌러 꺼내요.', 'workshop-cell-0'),
        ],
      WorkshopFeature.collection => const [
          FeatureTourStep('여기 ‘메뉴’를 누르면 맨 위에 ‘도감’이 있어요.', 'menu-menubar'),
        ],
      WorkshopFeature.recipes => const [
          FeatureTourStep('‘메뉴’의 ‘레벨 미션’에서 레시피 미션을 마치면 새 맛을 받아요.', 'menu-menubar'),
          FeatureTourStep('받은 맛은 이 맛 버튼을 눌러 골라요.', 'flavor-button'),
        ],
      WorkshopFeature.specialOrders => const [
          FeatureTourStep('손님을 누르면 원하는 익힘을 볼 수 있어요. 그 익힘으로 구워 드려요.', 'customer-0'),
          FeatureTourStep('이 쪽지에는 하루 한 장 오늘의 주문서가 와요.', 'daily-ticket'),
        ],
      WorkshopFeature.fishCosmetics => const [
          FeatureTourStep('‘꾸미기’의 ‘붕어빵’ 칸에서 붕어빵 모양을 바꿔요.', 'menu-skins'),
        ],
      WorkshopFeature.freshness => const [
          FeatureTourStep('판매대의 재고는 오래된 붕어빵부터 손님에게 드려요.', 'sale-counter'),
        ],
      WorkshopFeature.stallCosmetics => const [
          FeatureTourStep('‘꾸미기’의 ‘배경’ 탭에서 화로와 장식을 바꿔요.', 'menu-skins'),
          FeatureTourStep('배경은 ‘메뉴’의 ‘배경 테마’에서도 바꿀 수 있어요.', 'menu-menubar'),
        ],
      WorkshopFeature.stallBackground => const [],
      // 4차 병합: g8's fairy gets g5's one-step tour like every card.
      WorkshopFeature.fairy => const [
          FeatureTourStep('손님이 없을 때 이 붕어빵 요정을 톡톡 눌러 붕어빵력을 모아요.', 'workshop-clicker'),
        ],
    };

/// Intro ids already open for [s]: an older save counts them as seen, so a
/// player past those levels gets no cards (schema 7 → 8). The fairy's story
/// and 재료 준비 (재료 타이쿤 E) are new to everyone, so they are never
/// counted as seen.
Set<String> openedIntroIds(WorkshopState s, DevelopmentBalance config) => {
      for (final f in workshopIntroFeatures)
        if (f != WorkshopFeature.fairy && f != WorkshopFeature.pantry && featureOpen(s, config, f)) f.name};

/// One introduction card: a picture, two sentences and '알겠어요'.
class WorkshopFeatureIntro {
  final String title, body, art, fallbackIcon;
  const WorkshopFeatureIntro(this.title, this.body, this.art, this.fallbackIcon);
}

/// The words of each card (사용자에게 보이는 글). [art] is the picture in
/// assets/images/ui (25번 22번); until it is drawn the card shows
/// [fallbackIcon], an existing icon, as the stand-in.
WorkshopFeatureIntro featureIntro(WorkshopFeature feature) => switch (feature) {
      WorkshopFeature.fairy => const WorkshopFeatureIntro('붕어빵 요정을 만났어요',
          '가게에 사는 붕어빵 요정이에요. 손님이 없으면 헤엄치며 놀다가, 손님이 오면 부끄러워 구석에 숨어요. 숨은 요정을 찾아 눌러도 붕어빵력이 모여요.',
          'intro_fairy', 'bun'),
      WorkshopFeature.skills => const WorkshopFeatureIntro('스킬이 열렸어요',
          '붕어빵력으로 클릭 스킬과 자동 생산 스킬을 레벨업해요. 카카오 로그인 후 레벨업할 수 있고, 위쪽에 초당·클릭당 숫자가 보여요.',
          'intro_skills', 'skill'),
      WorkshopFeature.pantry => const WorkshopFeatureIntro('재료 준비가 열렸어요',
          '붕어빵을 하나 만들 때마다 반죽과 속이 1인분씩 들어가요. 영업 준비 중에 ‘재료 준비’에서 반죽과 속을 넉넉히 만들어 두세요. 만든 반죽과 속은 하루가 지나면 상해요.',
          'intro_pantry', 'btn_prep'),
      WorkshopFeature.griddle => const WorkshopFeatureIntro('숙련된 붕어빵 틀이 열렸어요',
          '도감을 완성한 맛은 아래 6구 틀에서 구울 수 있어요. 빈 칸을 누르면 반죽과 속이 저절로 들어가고, 원하는 익힘이 됐을 때 눌러 꺼내요.',
          'intro_griddle', 'bun'),
      WorkshopFeature.collection => const WorkshopFeatureIntro('도감이 열렸어요',
          '메뉴의 도감에서 맛마다 익힘 다섯 칸을 채워요. 익힘마다 정해진 횟수를 구우면 칸이 완성되고, 다 채우면 칭호와 보상을 받아요.',
          'intro_collection', 'achievements'),
      WorkshopFeature.recipes => const WorkshopFeatureIntro('새 맛 레시피',
          '레벨 미션 창에서 레시피 미션을 마치면 새 맛을 받을 수 있어요. 새 맛도 도감을 다 채우면 숙련된 붕어빵 틀에서 구울 수 있어요.',
          'intro_recipes', 'mission'),
      WorkshopFeature.specialOrders => const WorkshopFeatureIntro('특별 주문이 와요',
          '이제 손님이 익힘을 콕 집어 주문해요. 판매대 옆 ‘오늘’ 쪽지에는 하루 한 장 오늘의 주문서가 와요.',
          'intro_special_orders', 'daily'),
      WorkshopFeature.fishCosmetics => const WorkshopFeatureIntro('붕어빵 꾸미기',
          '꾸미기의 붕어빵 칸에서 붕어빵 모양을 바꿀 수 있어요. 모습만 바뀌고 생산 효과는 없어요.',
          'intro_fish_cosmetics', 'tab_fish'),
      WorkshopFeature.freshness => const WorkshopFeatureIntro('붕어빵의 신선도',
          '재고는 영업일이 지날수록 값과 손님 만족이 조금씩 줄어요. 오래된 붕어빵부터 손님에게 드려요.',
          'intro_freshness', 'records'),
      WorkshopFeature.stallCosmetics => const WorkshopFeatureIntro('가게 꾸미기가 열렸어요',
          '꾸미기의 배경 탭에서 화로와 장식도 바꿀 수 있어요. 풍경은 메뉴의 배경 테마에서도 바꿔요.',
          'intro_stall_cosmetics', 'tab_stall'),
      WorkshopFeature.wardrobe => const WorkshopFeatureIntro('꾸미기·상점·오늘이 열렸어요',
          '아래 꾸미기와 상점에서 사장님과 가게 모습을 바꿀 수 있어요. 오른쪽 위 쪽지에서는 출석 도장과 오늘의 주문서를 받아요.',
          'intro_wardrobe', 'tab_outfit'),
      WorkshopFeature.stallBackground => const WorkshopFeatureIntro('배경 테마', '', 'intro_stall_cosmetics', 'theme'),
    };
