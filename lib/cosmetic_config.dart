import 'config_values.dart';

// All prices/unlocks are estimated. Artwork is drawn locally, not extracted.
enum CosmeticSlot { fish, background, stove, decoration }

class CosmeticDefinition {
  final String id, name, price, unlockProduction;
  final CosmeticSlot slot;
  final int unlockLevel;
  const CosmeticDefinition(
      this.id, this.name, this.slot, this.price, this.unlockLevel,
      [this.unlockProduction = '0']);
  BigInt get cost => configBigInt(price);
  BigInt get unlockProductionAmount => configBigInt(unlockProduction);
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
  // Stage 11 additions, all drawn in code (CustomPainter).
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
];
const defaultCosmetics = {
  CosmeticSlot.fish: 'redbean',
  CosmeticSlot.background: 'night',
  CosmeticSlot.stove: 'iron',
  CosmeticSlot.decoration: 'none'
};
String cosmeticSlotLabel(CosmeticSlot slot) => switch (slot) {
      CosmeticSlot.fish => '붕어빵',
      CosmeticSlot.background => '배경',
      CosmeticSlot.stove => '화로',
      CosmeticSlot.decoration => '장식'
    };
