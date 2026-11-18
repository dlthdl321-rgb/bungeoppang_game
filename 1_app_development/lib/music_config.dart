/// Background music. 26번 4-6단계 (S46-Q1): every mood plays the same song,
/// 'Warm Bungeoppang Stall' (Suno, paid plan, 2026-10-17), made into a 171 s
/// seamless OGG loop by tools/prepare_bgm.py. The mood structure stays so a
/// later update can give moods their own songs again without a save change.
const musicMoods = ['day', 'spring', 'dusk', 'rain', 'snow', 'night'];

/// The one background song (under assets/).
const warmStallMusicAsset = 'audio/bgm_warm_stall.ogg';

/// The mood that plays over [background] (a CosmeticSlot.background id).
String musicMoodFor(String background) => switch (background) {
      'cherry' => 'spring',
      'autumn' || 'dusk' || 'forest' => 'dusk',
      'rain' => 'rain',
      'snow' || 'snowday' => 'snow',
      'night' || 'seaside' => 'night',
      _ => 'day', // clear and anything new
    };

/// Asset path (under assets/) of [mood]'s loop. All moods share one song.
String musicAsset(String mood) => warmStallMusicAsset;

/// Existing saves follow the background until the player explicitly selected
/// a loop. The settings screen no longer offers a choice (one song), but saved
/// mood ids stay valid so old saves load unchanged.
const defaultMusicSelection = 'auto';

bool validMusicSelection(String value) =>
    value == defaultMusicSelection || musicMoods.contains(value);

String selectedMusicMood(String selection, String sceneMood) {
  if (!validMusicSelection(selection)) {
    throw const FormatException('알 수 없는 배경음 선택');
  }
  return selection == defaultMusicSelection ? sceneMood : selection;
}
