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
  /// The six-cell griddle: once one flavor is mastered (S2-Q2), at or after
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
}

/// Features with a one-screen introduction card, in the order they are shown
/// when several open together. The saved id is the enum name (schema 8
/// `featureIntros`).
const workshopIntroFeatures = [
  WorkshopFeature.skills,
  WorkshopFeature.griddle,
  WorkshopFeature.collection,
  WorkshopFeature.recipes,
  WorkshopFeature.specialOrders,
  WorkshopFeature.fishCosmetics,
  WorkshopFeature.freshness,
  WorkshopFeature.stallCosmetics,
];

final workshopIntroIds = {for (final f in workshopIntroFeatures) f.name};

/// The level [feature] opens at, or null when it is not opened by level.
int? featureUnlockLevel(DevelopmentBalance config, WorkshopFeature feature) {
  final levels = config.section('feature_unlock_levels');
  int level(String key) => DevelopmentBalance.integer(levels, key);
  return switch (feature) {
    WorkshopFeature.skills => level('skill_shop'),
    WorkshopFeature.collection => level('full_recipe_collection_ui'),
    WorkshopFeature.recipes => config.rows('additional_recipe_acquisition_tiers')
        .map((r) => DevelopmentBalance.integer(r, 'unlock_level')).reduce((a, b) => a < b ? a : b),
    WorkshopFeature.specialOrders =>
      DevelopmentBalance.integer(config.section('ordinary_sale'), 'special_order_unlock_level'),
    WorkshopFeature.fishCosmetics => level('fish_cosmetics'),
    WorkshopFeature.stallCosmetics => level('stall_cosmetics'),
    WorkshopFeature.griddle => level('six_slot_access'),
    WorkshopFeature.wardrobe || WorkshopFeature.freshness => null,
  };
}

/// Whether [feature] is open for [s].
bool featureOpen(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) {
  final level = featureUnlockLevel(config, feature);
  final byLevel = level == null || s.level >= level;
  return switch (feature) {
    WorkshopFeature.wardrobe => !s.tutorialActive,
    // A skill already bought, or a purchase still being settled, keeps the
    // window open whatever the level (old saves, recovery).
    WorkshopFeature.skills => byLevel ||
        s.purchases.owned.entries.any((e) => !e.key.startsWith('cosmetic:') && e.value > 0) ||
        s.purchases.journals.values.any((j) => !j.settled),
    WorkshopFeature.griddle => byLevel && s.masteryAwards.isNotEmpty,
    WorkshopFeature.recipes => byLevel || s.recipes.length > 1,
    WorkshopFeature.freshness => s.inventory.batches.values.any((b) =>
        (s.inventory.bindings[b.id] ?? b.madeOnBusinessIndex) < s.business.businessIndex),
    _ => byLevel,
  };
}

/// What a locked [feature] says: 'Lv.2에 열려요', the guide, or the mastery
/// still to go for the six-cell griddle (S2-Q2). Null when it is open.
String? featureLockReason(WorkshopState s, DevelopmentBalance config, WorkshopFeature feature) {
  if (featureOpen(s, config, feature)) return null;
  final level = featureUnlockLevel(config, feature);
  if (feature == WorkshopFeature.wardrobe) return '첫 영업 안내가 끝나면 열려요';
  if (feature == WorkshopFeature.griddle && (level == null || s.level >= level)) {
    // The first flavor everyone practices: 팥 (redbean).
    final flavor = s.flavorMasteries.containsKey(s.selectedFlavor) ? s.selectedFlavor : 'redbean';
    final m = s.flavorMasteries[flavor]!;
    final rule = config.mastery(m.difficulty);
    final label = (config.section('active_recipes')[flavor] as Map)['label'] as String;
    return '$label${_objectParticle(label)} 숙련하면 열려요 (연습 ${m.practices}/${rule['practice_required']} · '
        '손기술 ${m.techniquePasses}/${rule['technique_passes_required']})';
  }
  if (feature == WorkshopFeature.freshness) return null;
  return 'Lv.$level에 열려요';
}

/// The first introduction card still to show, or null.
WorkshopFeature? pendingFeatureIntro(WorkshopState s, DevelopmentBalance config) {
  if (s.tutorialActive) return null;
  for (final f in workshopIntroFeatures) {
    if (!s.featureIntros.contains(f.name) && featureOpen(s, config, f)) return f;
  }
  return null;
}

/// Intro ids already open for [s]: an older save counts them as seen, so a
/// player past those levels gets no cards (schema 7 → 8).
Set<String> openedIntroIds(WorkshopState s, DevelopmentBalance config) =>
    {for (final f in workshopIntroFeatures) if (featureOpen(s, config, f)) f.name};

/// 을/를 after [word]: by whether its last syllable has a final consonant.
String _objectParticle(String word) {
  if (word.isEmpty) return '을';
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '을';
  return (code - 0xAC00) % 28 == 0 ? '를' : '을';
}

/// One introduction card: a picture, two sentences and '알겠어요'.
class WorkshopFeatureIntro {
  final String title, body, art, fallbackIcon;
  const WorkshopFeatureIntro(this.title, this.body, this.art, this.fallbackIcon);
}

/// The words of each card (사용자에게 보이는 글). [art] is the picture in
/// assets/images/ui (25번 22번); until it is drawn the card shows
/// [fallbackIcon], an existing icon, as the stand-in.
WorkshopFeatureIntro featureIntro(WorkshopFeature feature) => switch (feature) {
      WorkshopFeature.skills => const WorkshopFeatureIntro('스킬이 열렸어요',
          '붕어빵력으로 클릭 스킬과 자동 생산 스킬을 레벨업해요. 카카오 로그인 후 레벨업할 수 있고, 위쪽에 초당·클릭당 숫자가 보여요.',
          'intro_skills', 'skill'),
      WorkshopFeature.griddle => const WorkshopFeatureIntro('숙련된 붕어빵 틀이 열렸어요',
          '숙련한 맛은 아래 6구 틀에서 한 번에 여러 개 구울 수 있어요. 빈 칸을 누르면 굽기 시작하고, 익으면 눌러 꺼내요.',
          'intro_griddle', 'bun'),
      WorkshopFeature.collection => const WorkshopFeatureIntro('도감이 열렸어요',
          '메뉴의 도감에서 맛마다 찾은 익힘과 손님 이야기를 볼 수 있어요. 여러 익힘으로 구워 칸을 채워 보세요.',
          'intro_collection', 'achievements'),
      WorkshopFeature.recipes => const WorkshopFeatureIntro('새 맛 레시피',
          '레벨 미션 창에서 레시피 미션을 마치면 새 맛을 받을 수 있어요. 새 맛도 연습하면 숙련할 수 있어요.',
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
          '꾸미기의 가게 칸에서 배경과 등불을 바꿀 수 있어요. 메뉴의 배경 테마에서도 열 수 있어요.',
          'intro_stall_cosmetics', 'tab_stall'),
      WorkshopFeature.wardrobe => const WorkshopFeatureIntro('꾸미기', '', 'intro_wardrobe', 'tab_outfit'),
    };
