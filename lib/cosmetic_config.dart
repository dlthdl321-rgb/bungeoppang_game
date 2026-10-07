import 'config_values.dart';

// All prices/unlocks are estimated. Artwork is drawn locally, not extracted.
// Slots are listed in display order, grouped by category.
enum CosmeticSlot {
  fish, // Flavour. Name kept for saves, ledgers and test keys.
  pattern,
  topping,
  character,
  skin,
  hair,
  top,
  bottom,
  shoes,
  outfit,
  hat,
  accessory,
  tool,
  background,
  stove,
  decoration,
  lamp, // Glass colour of the stall's post lamps (stage 14).
  time // Day or night for the background's season (stage 14).
}

/// What a slot dresses up: the pastry, the vendor (avatar) or the stall.
enum CosmeticCategory { bungeoppang, avatar, stall }

/// Tabs of the wardrobe screen (approved stage 14, D3): the vendor's
/// 헤어 / 의상 / 소품, then the pastry and the stall.
enum WardrobeTab { hair, outfit, props, bungeoppang, stall }

extension CosmeticSlotCategory on CosmeticSlot {
  CosmeticCategory get category => switch (this) {
        CosmeticSlot.fish ||
        CosmeticSlot.pattern ||
        CosmeticSlot.topping =>
          CosmeticCategory.bungeoppang,
        CosmeticSlot.character ||
        CosmeticSlot.skin ||
        CosmeticSlot.hair ||
        CosmeticSlot.top ||
        CosmeticSlot.bottom ||
        CosmeticSlot.shoes ||
        CosmeticSlot.outfit ||
        CosmeticSlot.hat ||
        CosmeticSlot.accessory ||
        CosmeticSlot.tool =>
          CosmeticCategory.avatar,
        CosmeticSlot.background ||
        CosmeticSlot.stove ||
        CosmeticSlot.decoration ||
        CosmeticSlot.lamp ||
        CosmeticSlot.time =>
          CosmeticCategory.stall,
      };

  /// Wardrobe tab of the concept art (꾸미기 화면) that lists this slot.
  WardrobeTab get tab => switch (this) {
        CosmeticSlot.character ||
        CosmeticSlot.skin ||
        CosmeticSlot.hair ||
        CosmeticSlot.hat =>
          WardrobeTab.hair,
        CosmeticSlot.top ||
        CosmeticSlot.bottom ||
        CosmeticSlot.shoes ||
        CosmeticSlot.outfit =>
          WardrobeTab.outfit,
        CosmeticSlot.accessory || CosmeticSlot.tool => WardrobeTab.props,
        CosmeticSlot.fish ||
        CosmeticSlot.pattern ||
        CosmeticSlot.topping =>
          WardrobeTab.bungeoppang,
        CosmeticSlot.background ||
        CosmeticSlot.stove ||
        CosmeticSlot.decoration ||
        CosmeticSlot.lamp ||
        CosmeticSlot.time =>
          WardrobeTab.stall,
      };

  /// Slots the wardrobe lists. The flavour slot has only redbean left.
  bool get shown => this != CosmeticSlot.fish;

  /// Character and skin tone are free personal choices, never priced or
  /// collected.
  bool get collectible =>
      this != CosmeticSlot.character &&
      this != CosmeticSlot.skin &&
      this != CosmeticSlot.time;
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

  /// Counts toward the collection: not a slot default, character or skin tone.
  bool get collectible => slot.collectible && defaultCosmetics[slot] != id;

  /// Owned from the start without a purchase.
  bool get free => !collectible;
}

const cosmeticDefinitions = [
  // Flavours were removed in stage 14 (they will come back as level skills):
  // redbean is the only bungeoppang, kept as the base of every pattern and
  // topping image. The slot stays for saves and is not shown anywhere.
  CosmeticDefinition('redbean', '팥 붕어빵', CosmeticSlot.fish, '0', 1),
  CosmeticDefinition('clear', '맑은 날', CosmeticSlot.background, '0', 1),
  CosmeticDefinition('night', '야간 골목', CosmeticSlot.background, '3', 1),
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
  // Stage 13: the vendor's character. Free and always owned.
  CosmeticDefinition('girl', '여자 사장님', CosmeticSlot.character, '0', 1),
  CosmeticDefinition('boy', '남자 사장님', CosmeticSlot.character, '0', 1),
  // Stage 12: the vendor. Skin tones are free and always owned.
  CosmeticDefinition('skin1', '피부톤 1', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('skin2', '피부톤 2', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('skin3', '피부톤 3', CosmeticSlot.skin, '0', 1),
  CosmeticDefinition('long', '긴 생머리', CosmeticSlot.hair, '0', 1),
  CosmeticDefinition('short', '짧은 머리', CosmeticSlot.hair, '3', 1),
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
  // Stage 14: the concept art (개발에셋 261006_1905_01). Prices estimated.
  CosmeticDefinition('tee', '흰 티셔츠', CosmeticSlot.top, '0', 1),
  CosmeticDefinition('creamlong', '크림 긴팔', CosmeticSlot.top, '3', 2),
  CosmeticDefinition('pinksweater', '분홍 니트', CosmeticSlot.top, '6', 3),
  CosmeticDefinition('sagesweater', '세이지 니트', CosmeticSlot.top, '6', 4),
  CosmeticDefinition('creamsweater', '꽈배기 니트', CosmeticSlot.top, '8', 5),
  CosmeticDefinition('cardigan', '카디건', CosmeticSlot.top, '10', 6),
  CosmeticDefinition('shorts', '베이지 반바지', CosmeticSlot.bottom, '0', 1),
  CosmeticDefinition('skirt', '주름치마', CosmeticSlot.bottom, '4', 2),
  CosmeticDefinition('widepants', '와이드 바지', CosmeticSlot.bottom, '6', 3),
  CosmeticDefinition('brownpants', '갈색 바지', CosmeticSlot.bottom, '7', 4),
  CosmeticDefinition('flats', '갈색 단화', CosmeticSlot.shoes, '0', 1),
  CosmeticDefinition('sneakers', '흰 운동화', CosmeticSlot.shoes, '4', 2),
  CosmeticDefinition('boots', '앵클부츠', CosmeticSlot.shoes, '7', 4),
  CosmeticDefinition('furboots', '털 부츠', CosmeticSlot.shoes, '10', 7),
  CosmeticDefinition('darkapron', '초코 앞치마', CosmeticSlot.outfit, '5', 2),
  CosmeticDefinition('creamapron', '크림 앞치마', CosmeticSlot.outfit, '7', 4),
  CosmeticDefinition('waistapron', '허리 앞치마', CosmeticSlot.outfit, '9', 5),
  CosmeticDefinition('bandana', '크림 두건', CosmeticSlot.hat, '4', 2),
  CosmeticDefinition('redbandana', '빨간 두건', CosmeticSlot.hat, '6', 3),
  CosmeticDefinition('ballcap', '크림 야구모자', CosmeticSlot.hat, '7', 4),
  CosmeticDefinition('newsboy', '헌팅캡', CosmeticSlot.hat, '8', 4),
  CosmeticDefinition('blackcap', '검정 야구모자', CosmeticSlot.hat, '9', 6),
  CosmeticDefinition('noacc', '소품 없음', CosmeticSlot.accessory, '0', 1),
  CosmeticDefinition('ribbon', '분홍 리본', CosmeticSlot.accessory, '4', 2),
  CosmeticDefinition('fishpin', '붕어빵 머리핀', CosmeticSlot.accessory, '5', 3),
  CosmeticDefinition('glasses', '동그란 안경', CosmeticSlot.accessory, '6', 3),
  CosmeticDefinition('scarf', '분홍 목도리', CosmeticSlot.accessory, '8', 5),
  CosmeticDefinition('mittens', '털장갑', CosmeticSlot.accessory, '9', 6),
  CosmeticDefinition('crossbag', '크로스백', CosmeticSlot.accessory, '11', 7),
  CosmeticDefinition('paperbag', '붕어빵 봉투', CosmeticSlot.tool, '8', 5),
  CosmeticDefinition('fishhold', '갓 구운 붕어빵', CosmeticSlot.tool, '12', 8),
  CosmeticDefinition('rain', '비 오는 날', CosmeticSlot.background, '6', 2),
  CosmeticDefinition('autumn', '가을 골목', CosmeticSlot.background, '9', 4),
  CosmeticDefinition('snowday', '눈 오는 낮', CosmeticSlot.background, '11', 6),
  CosmeticDefinition(
      'paperlanterns', '종이 초롱 줄', CosmeticSlot.decoration, '10', 6),
  // Post lamp glass (stall/postlamp*.png). Prices estimated.
  CosmeticDefinition('amberlamp', '기본 등불', CosmeticSlot.lamp, '0', 1),
  CosmeticDefinition('roselamp', '분홍 등불', CosmeticSlot.lamp, '4', 2),
  CosmeticDefinition('mintlamp', '민트 등불', CosmeticSlot.lamp, '6', 3),
  CosmeticDefinition('lilaclamp', '라일락 등불', CosmeticSlot.lamp, '8', 4),
  // Day or night for every season, free like the character and skin tone.
  CosmeticDefinition('scenetime', '배경 그대로', CosmeticSlot.time, '0', 1),
  CosmeticDefinition('day', '낮', CosmeticSlot.time, '0', 1),
  CosmeticDefinition('night_time', '밤', CosmeticSlot.time, '0', 1),
  CosmeticDefinition('clock', '기기 시간 따라', CosmeticSlot.time, '0', 1),
];
const defaultCosmetics = {
  CosmeticSlot.fish: 'redbean',
  CosmeticSlot.pattern: 'scales',
  CosmeticSlot.topping: 'plain',
  CosmeticSlot.character: 'girl',
  CosmeticSlot.skin: 'skin1',
  CosmeticSlot.hair: 'long',
  CosmeticSlot.top: 'tee',
  CosmeticSlot.bottom: 'shorts',
  CosmeticSlot.shoes: 'flats',
  CosmeticSlot.outfit: 'apron',
  CosmeticSlot.hat: 'nohat',
  CosmeticSlot.accessory: 'noacc',
  CosmeticSlot.tool: 'tongs',
  CosmeticSlot.background: 'clear',
  CosmeticSlot.stove: 'iron',
  CosmeticSlot.decoration: 'none',
  CosmeticSlot.lamp: 'amberlamp',
  CosmeticSlot.time: 'scenetime'
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

/// Slots added in save format v11; older saves get their defaults.
const stage13Slots = {CosmeticSlot.character};

/// Slots added in save format v12; older saves get their defaults.
const stage14Slots = {
  CosmeticSlot.lamp,
  CosmeticSlot.time,
  CosmeticSlot.top,
  CosmeticSlot.bottom,
  CosmeticSlot.shoes,
  CosmeticSlot.accessory
};

/// Save format version that introduced [slot]; older saves fill it in.
int cosmeticSlotSince(CosmeticSlot slot) => stage14Slots.contains(slot)
    ? 12
    : stage13Slots.contains(slot)
        ? 11
        : stage12Slots.contains(slot)
            ? 10
            : 6;

/// Items with no artwork of their own ("nothing on top").
/// amberlamp keeps the lamps drawn in the background itself.
const blankCosmetics = {
  'none',
  'plain',
  'nohat',
  'noacc',
  'amberlamp',
  'scenetime',
  'day',
  'night_time',
  'clock',
};

/// Whether the [time] choice shows the night, or null to keep each
/// background's own time ('scenetime'). 'clock' follows the device: night
/// from 19:00 to 6:00.
bool? isNightTime(String time, DateTime local) => switch (time) {
      'night_time' => true,
      'day' => false,
      'clock' => local.hour >= 19 || local.hour < 6,
      _ => null,
    };

/// The background picture for [background] at night: its own `<id>_night`
/// art when there is some (the snow theme pairs 눈 오는 낮 with 겨울밤).
String nightBackground(String background) => switch (background) {
      'snowday' => 'snow',
      _ => '${background}_night',
    };

/// The daytime picture: 겨울밤 by day is 눈 오는 낮.
String dayBackground(String background) =>
    background == 'snow' ? 'snowday' : background;

String cosmeticSlotLabel(CosmeticSlot slot) => switch (slot) {
      CosmeticSlot.fish => '맛',
      CosmeticSlot.pattern => '무늬',
      CosmeticSlot.topping => '토핑',
      CosmeticSlot.character => '캐릭터',
      CosmeticSlot.skin => '피부톤',
      CosmeticSlot.hair => '머리',
      CosmeticSlot.top => '상의',
      CosmeticSlot.bottom => '하의',
      CosmeticSlot.shoes => '신발',
      CosmeticSlot.outfit => '앞치마',
      CosmeticSlot.hat => '모자',
      CosmeticSlot.accessory => '액세서리',
      CosmeticSlot.tool => '도구',
      CosmeticSlot.background => '배경',
      CosmeticSlot.stove => '화로',
      CosmeticSlot.decoration => '장식',
      CosmeticSlot.lamp => '등불',
      CosmeticSlot.time => '밤낮'
    };

String cosmeticCategoryLabel(CosmeticCategory c) => switch (c) {
      CosmeticCategory.bungeoppang => '붕어빵',
      CosmeticCategory.avatar => '사장님',
      CosmeticCategory.stall => '가게',
    };

String wardrobeTabLabel(WardrobeTab t) => switch (t) {
      WardrobeTab.hair => '헤어',
      WardrobeTab.outfit => '의상',
      WardrobeTab.props => '소품',
      WardrobeTab.bungeoppang => '붕어빵',
      WardrobeTab.stall => '가게',
    };
