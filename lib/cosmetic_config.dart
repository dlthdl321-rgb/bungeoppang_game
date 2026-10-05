import 'config_values.dart';

// All prices/unlocks are estimated. Artwork is drawn locally, not extracted.
// Slots are listed in display order, grouped by category.
enum CosmeticSlot {
  fish, // Flavour. Name kept for saves, ledgers and test keys.
  pattern,
  topping,
  skin,
  hair,
  outfit,
  hat,
  tool,
  background,
  stove,
  decoration
}

/// What a slot dresses up: the pastry, the vendor (avatar) or the stall.
enum CosmeticCategory { bungeoppang, avatar, stall }

extension CosmeticSlotCategory on CosmeticSlot {
  CosmeticCategory get category => switch (this) {
        CosmeticSlot.fish ||
        CosmeticSlot.pattern ||
        CosmeticSlot.topping =>
          CosmeticCategory.bungeoppang,
        CosmeticSlot.skin ||
        CosmeticSlot.hair ||
        CosmeticSlot.outfit ||
        CosmeticSlot.hat ||
        CosmeticSlot.tool =>
          CosmeticCategory.avatar,
        CosmeticSlot.background ||
        CosmeticSlot.stove ||
        CosmeticSlot.decoration =>
          CosmeticCategory.stall,
      };

  /// Skin tone is a free personal choice, never priced or collected.
  bool get collectible => this != CosmeticSlot.skin;
}

class CosmeticDefinition {
  final String id, name, price, unlockProduction;
  final CosmeticSlot slot;
  final int unlockLevel;
  const CosmeticDefinition(
      this.id, this.name, this.slot, this.price, this.unlockLevel,
      [this.unlockProduction = '0']);
  BigInt get cost => configBigInt(price);
  BigInt get unlockProductionAmount => configBigInt(unlockProduction);

  /// Counts toward the collection: not a slot default and not a skin tone.
  bool get collectible => slot.collectible && defaultCosmetics[slot] != id;

  /// Owned from the start without a purchase.
  bool get free => !collectible;
}

const cosmeticDefinitions = [
  CosmeticDefinition('redbean', '팥 붕어빵', CosmeticSlot.fish, '0', 1),
  CosmeticDefinition('custard', '슈크림 붕어빵', CosmeticSlot.fish, '6', 3),
  CosmeticDefinition('cocoa', '코코아 붕어빵', CosmeticSlot.fish, '12', 6),
  CosmeticDefinition('night', '야간 골목', CosmeticSlot.background, '0', 1),
  CosmeticDefinition('dusk', '보랏빛 해질녘', CosmeticSlot.background, '5', 2, '100'),
  CosmeticDefinition(
      'forest', '숲길 노점', CosmeticSlot.background, '9', 5, '10000'),
  CosmeticDefinition('iron', '기본 화로', CosmeticSlot.stove, '0', 1),
  CosmeticDefinition('copper', '구리 화로', CosmeticSlot.stove, '7', 3, '1000'),
  CosmeticDefinition('none', '장식 없음', CosmeticSlot.decoration, '0', 1),
  CosmeticDefinition('lantern', '종이 등불', CosmeticSlot.decoration, '4', 2),
  CosmeticDefinition(
      'bunting', '작은 축제 깃발', CosmeticSlot.decoration, '8', 4, '5000'),
  // Stage 11 additions.
  CosmeticDefinition('sweetpotato', '고구마 붕어빵', CosmeticSlot.fish, '8', 4),
  CosmeticDefinition('matcha', '녹차 붕어빵', CosmeticSlot.fish, '10', 5),
  CosmeticDefinition('strawberry', '딸기 붕어빵', CosmeticSlot.fish, '14', 7),
  CosmeticDefinition('snow', '눈 오는 밤', CosmeticSlot.background, '7', 3),
  CosmeticDefinition('cherry', '벚꽃 골목', CosmeticSlot.background, '10', 6),
  CosmeticDefinition('seaside', '바닷가 야시장', CosmeticSlot.background, '14', 8),
  CosmeticDefinition('castiron', '무쇠 화로', CosmeticSlot.stove, '6', 2),
  CosmeticDefinition('golden', '황금 화로', CosmeticSlot.stove, '15', 9),
  CosmeticDefinition('starlights', '별 전구', CosmeticSlot.decoration, '5', 3),
  CosmeticDefinition('windchime', '풍경', CosmeticSlot.decoration, '9', 5),
  CosmeticDefinition('snowman', '눈사람', CosmeticSlot.decoration, '12', 7),
  // Stage 12: pastry pattern and topping.
  CosmeticDefinition('scales', '기본 비늘', CosmeticSlot.pattern, '0', 1),
  CosmeticDefinition('heartscale', '하트 비늘', CosmeticSlot.pattern, '5', 2),
  CosmeticDefinition('starmark', '별 도장', CosmeticSlot.pattern, '8', 4),
  CosmeticDefinition('crispgrid', '바삭 격자', CosmeticSlot.pattern, '11', 6),
  CosmeticDefinition('plain', '토핑 없음', CosmeticSlot.topping, '0', 1),
  CosmeticDefinition('sugar', '슈가파우더', CosmeticSlot.topping, '4', 2),
  CosmeticDefinition('choco', '초코 드리즐', CosmeticSlot.topping, '7', 3),
  CosmeticDefinition('almond', '아몬드 슬라이스', CosmeticSlot.topping, '9', 5),
  CosmeticDefinition('sprinkle', '무지개 스프링클', CosmeticSlot.topping, '13', 8),
  // Stage 12: the vendor. Skin tones are free and always owned.
  CosmeticDefinition('skin1', '피부톤 1', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('skin2', '피부톤 2', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('skin3', '피부톤 3', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('short', '짧은 머리', CosmeticSlot.hair, '0', 1),
  CosmeticDefinition('ponytail', '묶은 머리', CosmeticSlot.hair, '5', 2),
  CosmeticDefinition('curly', '곱슬머리', CosmeticSlot.hair, '8', 5),
  CosmeticDefinition('apron', '기본 앞치마', CosmeticSlot.outfit, '0', 1),
  CosmeticDefinition('padding', '패딩 조끼', CosmeticSlot.outfit, '6', 3),
  CosmeticDefinition('stripe', '줄무늬 앞치마', CosmeticSlot.outfit, '9', 5),
  CosmeticDefinition('chefcoat', '요리사 복', CosmeticSlot.outfit, '12', 7),
  CosmeticDefinition('nohat', '모자 없음', CosmeticSlot.hat, '0', 1),
  CosmeticDefinition('beanie', '털 비니', CosmeticSlot.hat, '3', 2),
  CosmeticDefinition('earmuffs', '귀마개', CosmeticSlot.hat, '6', 3),
  CosmeticDefinition('chefhat', '요리사 모자', CosmeticSlot.hat, '10', 6),
  CosmeticDefinition('santa', '산타 모자', CosmeticSlot.hat, '14', 9),
  CosmeticDefinition('tongs', '붕어빵 집게', CosmeticSlot.tool, '0', 1),
  CosmeticDefinition('goldtongs', '황금 집게', CosmeticSlot.tool, '15', 9),
];
const defaultCosmetics = {
  CosmeticSlot.fish: 'redbean',
  CosmeticSlot.pattern: 'scales',
  CosmeticSlot.topping: 'plain',
  CosmeticSlot.skin: 'skin1',
  CosmeticSlot.hair: 'short',
  CosmeticSlot.outfit: 'apron',
  CosmeticSlot.hat: 'nohat',
  CosmeticSlot.tool: 'tongs',
  CosmeticSlot.background: 'night',
  CosmeticSlot.stove: 'iron',
  CosmeticSlot.decoration: 'none'
};

/// Slots added in save format v10; older saves get their defaults.
const stage12Slots = {
  CosmeticSlot.pattern,
  CosmeticSlot.topping,
  CosmeticSlot.skin,
  CosmeticSlot.hair,
  CosmeticSlot.outfit,
  CosmeticSlot.hat,
  CosmeticSlot.tool
};

/// Items with no artwork of their own ("nothing on top").
const blankCosmetics = {'none', 'plain', 'nohat'};

String cosmeticSlotLabel(CosmeticSlot slot) => switch (slot) {
      CosmeticSlot.fish => '맛',
      CosmeticSlot.pattern => '무늬',
      CosmeticSlot.topping => '토핑',
      CosmeticSlot.skin => '피부톤',
      CosmeticSlot.hair => '머리',
      CosmeticSlot.outfit => '옷',
      CosmeticSlot.hat => '모자',
      CosmeticSlot.tool => '도구',
      CosmeticSlot.background => '배경',
      CosmeticSlot.stove => '화로',
      CosmeticSlot.decoration => '장식'
    };

String cosmeticCategoryLabel(CosmeticCategory c) => switch (c) {
      CosmeticCategory.bungeoppang => '붕어빵',
      CosmeticCategory.avatar => '사장님',
      CosmeticCategory.stall => '가게',
    };

