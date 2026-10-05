// Balance v2. All skill prices, effects, ratios, unlock thresholds and the
// purchase cap are ESTIMATES, not extracted or verified source-game values.
// Decimal strings are parsed directly as BigInt (including on Flutter web).
const economyBalanceVersion = 2;
const skillValuesEvidence = 'estimated';
const skillCountLimit = 1000;
const legacySkillCountLimit = 25;
const lateSkillRatioNumerator = 115;
const lateSkillRatioDenominator = 100;

typedef SkillRow = (
  String id,
  String name,
  String cost,
  String effect,
  String unlockTotal,
  int numerator,
  int denominator
);

// The first three skills of each kind preserve the v1 IDs and numeric values.
const tapSkillConfig = <SkillRow>[
  ('tap_1', '반짝이는 틀', '15', '1', '0', 115, 100),
  ('tap_2', '진한 반죽', '250', '8', '500', 118, 100),
  ('tap_3', '장인의 손길', '4000', '60', '10000', 120, 100),
];
const autoSkillConfig = <SkillRow>[
  ('auto_1', '작은 화로', '50', '1', '0', 115, 100),
  ('auto_2', '자동 뒤집개', '600', '10', '1000', 118, 100),
  ('auto_3', '붕어빵 공방', '8000', '100', '20000', 120, 100),
];

// Each row explicitly specifies a new tier; prices/effects can be tuned alone.
typedef LateSkillRow = (String name, String cost, String effect, String unlock);
const lateTapSkillConfig = <LateSkillRow>[
  ('정밀 반죽기', '10000', '600', '10000'),
  ('황동 빵틀', '100000', '6000', '100000'),
  ('겹겹이 반죽', '1000000', '60000', '1000000'),
  ('달빛 손길', '10000000', '600000', '10000000'),
  ('명인의 비법', '100000000', '6000000', '100000000'),
  ('별빛 빵틀', '1000000000', '60000000', '1000000000'),
  ('황금 반죽', '10000000000', '600000000', '10000000000'),
  ('은하의 손길', '100000000000', '6000000000', '100000000000'),
  ('유성 빵틀', '1000000000000', '60000000000', '1000000000000'),
  ('찬란한 비법', '10000000000000', '600000000000', '10000000000000'),
  ('태양의 반죽', '100000000000000', '6000000000000', '100000000000000'),
  ('우주의 손길', '1000000000000000', '60000000000000', '1000000000000000'),
  ('전설의 빵틀', '10000000000000000', '600000000000000', '10000000000000000'),
];
const lateAutoSkillConfig = <LateSkillRow>[
  ('회전 화로', '20000', '1000', '20000'),
  ('연속 굽기', '200000', '10000', '200000'),
  ('증기 공방', '2000000', '100000', '2000000'),
  ('골목 제빵소', '20000000', '1000000', '20000000'),
  ('도시 제빵소', '200000000', '10000000', '200000000'),
  ('별빛 화로', '2000000000', '100000000', '2000000000'),
  ('황금 제빵소', '20000000000', '1000000000', '20000000000'),
  ('은하 공방', '200000000000', '10000000000', '200000000000'),
  ('유성 화로', '2000000000000', '100000000000', '2000000000000'),
  ('찬란한 공방', '20000000000000', '1000000000000', '20000000000000'),
  ('태양 제빵소', '200000000000000', '10000000000000', '200000000000000'),
  ('우주 제빵소', '2000000000000000', '100000000000000', '2000000000000000'),
  ('전설의 화로', '20000000000000000', '1000000000000000', '20000000000000000'),
];

// Level missions and their evidence are defined in mission_config.dart.

const koreanLargeUnits = [
  '',
  '만',
  '억',
  '조',
  '경',
  '해',
  '자',
  '양',
  '구',
  '간',
  '정',
  '재',
  '극'
];
