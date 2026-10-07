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
