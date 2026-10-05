// Juice/feedback tuning: effect caps, timings, sound and the optional combo
// economy bonus. Presentation values only, except [comboBonus].

// Tap effects. Caps bound work per frame no matter how fast players tap.
const maxFloatingGains = 8;
const maxCrumbParticles = 48;
const crumbsPerTap = 6;
const floatingGainMs = 700;
const crumbLifeMs = 650;
const squashMs = 240;

// Celebrations (level-up, rewards, achievements, item use).
const celebrationMs = 2200;
const reducedCelebrationMs = 1600;
const countUpMs = 900;
const maxConfetti = 36;

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
