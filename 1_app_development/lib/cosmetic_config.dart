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
/// 헤어 / 의상 / 소품, then the pastry and the stall (shown as '배경' since
/// 4차 피드백 g10).
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

  /// Counts toward the collection: not a slot default, a free extra choice
  /// ([freeChoiceCosmetics]), character or skin tone.
  bool get collectible =>
      slot.collectible &&
      defaultCosmetics[slot] != id &&
      !freeChoiceCosmetics.contains(id);

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
  CosmeticDefinition('scales', '기본 모양', CosmeticSlot.pattern, '0', 1),
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
  // Stage 26 4-4: the default apron is drawn now; this takes it off.
  CosmeticDefinition('noapron', '앞치마 없음', CosmeticSlot.outfit, '0', 1),
  CosmeticDefinition('stripe', '줄무늬 앞치마', CosmeticSlot.outfit, '9', 5),
  CosmeticDefinition('nohat', '모자 없음', CosmeticSlot.hat, '0', 1),
  CosmeticDefinition('beanie', '털 비니', CosmeticSlot.hat, '3', 2),
  CosmeticDefinition('earmuffs', '귀마개', CosmeticSlot.hat, '6', 3),
  CosmeticDefinition('chefhat', '요리사 모자', CosmeticSlot.hat, '10', 6),
  CosmeticDefinition('santa', '산타 모자', CosmeticSlot.hat, '14', 9),
  // 26번 3차 H8: the tongs in the vendor's hand are gone ("집게를 지워"):
  // the tool default keeps its id for saves but draws nothing.
  CosmeticDefinition('tongs', '도구 없음', CosmeticSlot.tool, '0', 1),
  // 26번 3차 AV (25번 41번, DEC-146 갱신): drawn again as a golden turner;
  // same id, price and unlock, owners keep it.
  CosmeticDefinition('goldtongs', '황금 뒤집개', CosmeticSlot.tool, '15', 9),
  // Stage 14: the concept art (개발에셋 261006_1905_01). Prices estimated.
  CosmeticDefinition('tee', '흰 티셔츠', CosmeticSlot.top, '0', 1),
  CosmeticDefinition('creamlong', '크림 긴팔', CosmeticSlot.top, '3', 2),
  CosmeticDefinition('pinksweater', '분홍 니트', CosmeticSlot.top, '6', 3),
  CosmeticDefinition('sagesweater', '세이지 니트', CosmeticSlot.top, '6', 4),
  CosmeticDefinition('creamsweater', '꽈배기 니트', CosmeticSlot.top, '8', 5),
  CosmeticDefinition('cardigan', '카디건', CosmeticSlot.top, '10', 6),
  // 26번 4-5단계(G12): tops now, not aprons (saves move them, see
  // [movedToTop]); the apron can go over them.
  CosmeticDefinition('padding', '패딩 조끼', CosmeticSlot.top, '6', 3),
  CosmeticDefinition('chefcoat', '요리사 복', CosmeticSlot.top, '12', 7),
  CosmeticDefinition('shorts', '베이지 반바지', CosmeticSlot.bottom, '0', 1),
  CosmeticDefinition('skirt', '주름치마', CosmeticSlot.bottom, '4', 2),
  CosmeticDefinition('widepants', '와이드 바지', CosmeticSlot.bottom, '6', 3),
  CosmeticDefinition('brownpants', '갈색 바지', CosmeticSlot.bottom, '7', 4),
  // 26번 4-7단계 (G11): bottoms 4 -> 10. Drawn only for the v2 vendor
  // (avatar_v2/), so the wardrobe hides them until avatarV2Ready.
  CosmeticDefinition('jeans', '연청 청바지', CosmeticSlot.bottom, '5', 2),
  CosmeticDefinition('denimshorts', '데님 반바지', CosmeticSlot.bottom, '5', 3),
  CosmeticDefinition('joggers', '회색 조거 바지', CosmeticSlot.bottom, '6', 3),
  CosmeticDefinition('checkskirt', '빨강 체크 치마', CosmeticSlot.bottom, '7', 4),
  CosmeticDefinition('cargopants', '카키 카고 바지', CosmeticSlot.bottom, '8', 5),
  CosmeticDefinition('longskirt', '크림 롱스커트', CosmeticSlot.bottom, '9', 6),
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
  // Day or night for every season (4차 피드백 g10, ID9, 2026-11-21): the
  // device's clock by default and free; a fixed day or night is sold in the
  // Workshop like the special backgrounds (avatar_catalog slot `time`). The
  // old '배경 그대로' (scenetime) is gone ([retiredCosmetics]).
  CosmeticDefinition('clock', '기기 시간 따라', CosmeticSlot.time, '0', 1),
  CosmeticDefinition('day', '낮 고정', CosmeticSlot.time, '0', 1),
  CosmeticDefinition('night_time', '밤 고정', CosmeticSlot.time, '0', 1),
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
  CosmeticSlot.time: 'clock'
};

/// Items taken out, worn in older saves, and what a save wearing one wears
/// now (4차 피드백 g10, ID9: '배경 그대로' became the device's clock). An
/// older save that owns one just drops it.
const retiredCosmetics = {'scenetime': 'clock'};

/// Each character's own default hair (26번 3차 G, 2026-11-20 사용자 결정:
/// "남자 사장님 기본 머리는 짧은 머리"). A shop that has the character has
/// its default hair without buying it, and a vendor whose hair was never
/// picked wears it. The girl keeps [defaultCosmetics]' long hair.
const characterDefaultHair = {'girl': 'long', 'boy': 'short'};

/// v1 vendor only (26번 3차 G): the hair style drawn as the base's own hair
/// while a hat is on. v1 hats were cut from pictures of the base hair under
/// them, so the boy's short hair (his default, close to his base hair) and
/// a hat left loose strands; under a hat he shows the base hair instead.
/// Goes away with the 25번 43~44번 art.
const v1HatHairAsBase = {'boy': 'short'};

/// The hair [character] wears until another is picked.
String defaultHairOf(String character) =>
    characterDefaultHair[character] ?? defaultCosmetics[CosmeticSlot.hair]!;

/// The item [character] wears in [slot] until another is picked: its own
/// default hair, else the slot default.
String defaultAvatarItem(CosmeticSlot slot, String character) =>
    slot == CosmeticSlot.hair ? defaultHairOf(character) : defaultCosmetics[slot]!;

/// Free choices besides the slot defaults, owned from the start and not
/// collected: taking off the default apron (stage 26 4-4).
const freeChoiceCosmetics = {'noapron'};

/// Items that were aprons ([CosmeticSlot.outfit]) before 26번 4-5단계 and
/// are tops now. An older save wearing one wears it as the top and takes
/// the apron off ('noapron'), so the vendor looks the same (account save
/// v14, Workshop schema 9).
const movedToTop = {'chefcoat', 'padding'};

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
  'tongs',
  'plain',
  'nohat',
  'noacc',
  'noapron',
  'amberlamp',
  'day',
  'night_time',
  'clock',
};

/// Avatar items taken out of the shop and the wardrobe on that character
/// (26번 3차 녹화 피드백 H8·H10): the golden tongs ("집게를 지워"), and any
/// item whose art is broken. No one can buy or pick them, a save that owns
/// one keeps it (ownership is not touched), and the vendor wearing one is
/// drawn without it. A redraw goes to 25번 and the entry comes out.
const withdrawnAvatarItems = <String, Set<String>>{
  // 26번 3차 AV: the golden tongs came back as the golden turner (25번 41번).
  'girl': {},
  'boy': {},
};

bool avatarItemWithdrawn(String character, String id) =>
    withdrawnAvatarItems[character]?.contains(id) ?? false;

/// The clock the day/night choice 'clock' follows on screen: the device's
/// (4차 피드백 g10, ID9: the default for every shop). Tests fix it
/// (test/flutter_test_config.dart) so pictures do not change with the hour.
DateTime Function() sceneClock = DateTime.now;

/// Whether the [time] choice shows the night: 'clock' (the default) follows
/// the device, night from 19:00 to 6:00; 'day' and 'night_time' are fixed.
/// Null (each background's own time) only for an unknown choice.
bool? isNightTime(String time, DateTime local) => switch (time) {
      'night_time' => true,
      'day' => false,
      'clock' => local.hour >= 19 || local.hour < 6,
      _ => null,
    };

/// The background picture for [background] at night: its own `<id>_night`
/// art when there is some (the snow theme pairs 눈 오는 낮 with 겨울밤;
/// 야간 골목 is a night scene already, so it is not darkened again).
String nightBackground(String background) => switch (background) {
      'snowday' => 'snow',
      'night' => 'night',
      _ => '${background}_night',
    };

/// The daytime picture: 겨울밤 by day is 눈 오는 낮.
String dayBackground(String background) =>
    background == 'snow' ? 'snowday' : background;

String cosmeticSlotLabel(CosmeticSlot slot) => switch (slot) {
      CosmeticSlot.fish => '맛',
      CosmeticSlot.pattern => '틀',
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
      // 4차 피드백 g10(ID8): the tab is 배경 now, its pictures 풍경.
      CosmeticSlot.background => '풍경',
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
      // 4차 피드백 g10(ID8): '가게' → '배경' (풍경·등불·밤낮 칸).
      WardrobeTab.stall => '배경',
    };
