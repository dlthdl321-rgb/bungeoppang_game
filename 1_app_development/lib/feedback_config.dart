// Juice/feedback tuning: effect caps, timings, sound and the optional combo
// economy bonus. Presentation values only, except [comboBonus].

// Tap effects. Caps bound work per frame no matter how fast players tap.
const maxFloatingGains = 8;
const maxCrumbParticles = 48;
const crumbsPerTap = 4; // small bungeoppang that pop up from the tap
const floatingGainMs = 700;
const crumbLifeMs = 650;
/// Tap pop of the centre bungeoppang: scale 1.0 -> 0.94 -> 1.06 -> 1.0.
const tapPopMs = 200;

// Celebrations (level-up, rewards, achievements, item use).
const celebrationMs = 2200;
const reducedCelebrationMs = 1600;
const countUpMs = 900;
const maxConfetti = 36;

/// Cosmetic names listed per category in the level-up banner; the rest are
/// counted ("외 N개") so the banner fits on small screens.
const levelUpNamesShown = 3;

/// The "다시 오셨네요!" screen shows only after this long away (real time,
/// not capped like the reward). Shorter absences still pay out silently.
const offlineWelcomeAfter = Duration(hours: 24);

/// Workshop welcome-back card (가게 복귀 안내): shown when the player comes
/// back after at least this long away, measured on the business clock.
/// Shorter absences settle silently.
const workshopWelcomeBackAfter = Duration(hours: 2);

/// First-run screens (로그인·이름·캐릭터·선택 정보, 26번 3차 H2): the lowered
/// home background drawn behind them, with its falling weather. A winter
/// night stall until 25번 37번 (a first-run illustration) arrives.
const firstRunBackground = 'snow';

/// After a failed automatic level-up save, wait this long before retrying.
const autoLevelRetryMs = 10000;

/// How long the "미션 달성!" notice stays when a goal becomes claimable.
const missionNoticeMs = 2600;

// Sound. Volumes are whole percents (stored as ints in the save).
const defaultSfxVolume = 70;
const defaultMusicVolume = 40;
const tapSoundMinIntervalMs = 60;

/// Optional extra production while a direct-tap combo is running.
class ComboBonus {
  final bool enabled;
  final int threshold, permille;
  const ComboBonus(
      {required this.enabled, required this.threshold, required this.permille});
}

// OFF by default: combos are a visual effect only unless this is enabled.
const comboBonus = ComboBonus(enabled: false, threshold: 20, permille: 1100);

/// 붕어빵 품질 별(26번 3차 피드백 H24): how many of [cookingStarsMax] stars
/// each bake grade (cooking_result_rules.dart `cookingGrade`) shows on the
/// result. Presentation only: grades, mastery and prices are unchanged.
const cookingStarsMax = 3;
const cookingStarsPerfect = 3;
const cookingStarsGood = 2;
const cookingStarsNear = 1;
const cookingStarsFail = 0;

/// 걸이 축 뒤집기(26번 3차 피드백 H21): the closed mold hangs on an axle
/// through its two side rings and the finger pushes it up (or down) around
/// it. One mold height of travel turns it [flipAxleDegreesPerHeight]; once
/// it has turned [flipAxleDoneDegrees] (past standing on edge) it falls
/// the rest of the way over on its own. Less than [flipAxleStartPx] of
/// travel is a touch, not a push.
const flipAxleDegreesPerHeight = 180.0;
const flipAxleDoneDegrees = 120.0;
const flipAxleStartPx = 6.0;

/// The axle's place in the mold picture (mold/*.png, 1200x880): the centres
/// of the two side rings' holes, where the brass pins of mold/axle_front.png
/// sit (25번 36번 art, measured on mold/closed.png; tools/apply_25_art.py
/// --only mold).
const flipAxleLeftRing = (118.0, 441.5);
const flipAxleRightRing = (1076.0, 441.5);
