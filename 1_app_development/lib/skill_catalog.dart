/// The skills' IDs and names, in shop order (32번 0단계, 2026-11-25).
/// Prices and effects live in `config/development_balance.json` (`skills`);
/// this list only names them. Moved unchanged from the old clicker's
/// `economy_config.dart` so that file can go.
enum SkillKind { tap, auto }

class SkillInfo {
  final String id, name;
  final SkillKind kind;
  const SkillInfo(this.id, this.name, this.kind);
}

const skillCatalog = <SkillInfo>[
  SkillInfo('tap_1', '반짝이는 틀', SkillKind.tap),
  SkillInfo('tap_2', '진한 반죽', SkillKind.tap),
  SkillInfo('tap_3', '노릇한 손놀림', SkillKind.tap),
  SkillInfo('tap_4', '정밀 반죽기', SkillKind.tap),
  SkillInfo('tap_5', '황동 빵틀', SkillKind.tap),
  SkillInfo('tap_6', '겹겹이 반죽', SkillKind.tap),
  SkillInfo('tap_7', '달빛 손길', SkillKind.tap),
  SkillInfo('tap_8', '숙련 뒤집기', SkillKind.tap),
  SkillInfo('tap_9', '별빛 빵틀', SkillKind.tap),
  SkillInfo('tap_10', '금빛 앙금', SkillKind.tap),
  SkillInfo('tap_11', '별무리 손길', SkillKind.tap),
  SkillInfo('tap_12', '유성 빵틀', SkillKind.tap),
  SkillInfo('tap_13', '오로라 반죽', SkillKind.tap),
  SkillInfo('tap_14', '태양의 반죽', SkillKind.tap),
  SkillInfo('tap_15', '우주의 손길', SkillKind.tap),
  SkillInfo('tap_16', '천년 빵틀', SkillKind.tap),
  SkillInfo('auto_1', '작은 화로', SkillKind.auto),
  SkillInfo('auto_2', '부지런한 집게', SkillKind.auto),
  SkillInfo('auto_3', '붕어빵 공방', SkillKind.auto),
  SkillInfo('auto_4', '회전 화로', SkillKind.auto),
  SkillInfo('auto_5', '연속 굽기', SkillKind.auto),
  SkillInfo('auto_6', '증기 공방', SkillKind.auto),
  SkillInfo('auto_7', '골목 제빵소', SkillKind.auto),
  SkillInfo('auto_8', '도시 제빵소', SkillKind.auto),
  SkillInfo('auto_9', '별빛 화로', SkillKind.auto),
  SkillInfo('auto_10', '황금 제빵소', SkillKind.auto),
  SkillInfo('auto_11', '성운 공방', SkillKind.auto),
  SkillInfo('auto_12', '유성 화로', SkillKind.auto),
  SkillInfo('auto_13', '찬란한 공방', SkillKind.auto),
  SkillInfo('auto_14', '태양 제빵소', SkillKind.auto),
  SkillInfo('auto_15', '우주 제빵소', SkillKind.auto),
  SkillInfo('auto_16', '천년 화로', SkillKind.auto),
];
