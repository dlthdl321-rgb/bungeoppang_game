/// Background music by the mood of the stall background. Each mood is a 24 s
/// loop made by tools/generate_sounds.py (assets/audio/bgm_<mood>.wav).
const musicMoods = ['day', 'spring', 'dusk', 'rain', 'snow', 'night'];

/// The mood that plays over [background] (a CosmeticSlot.background id).
String musicMoodFor(String background) => switch (background) {
      'cherry' => 'spring',
      'autumn' || 'dusk' || 'forest' => 'dusk',
      'rain' => 'rain',
      'snow' || 'snowday' => 'snow',
      'night' || 'seaside' => 'night',
      _ => 'day', // clear and anything new
    };

/// Asset path (under assets/) of [mood]'s loop.
String musicAsset(String mood) => 'audio/bgm_$mood.wav';

/// Existing saves follow the background until the player explicitly selects a loop.
const defaultMusicSelection = 'auto';
const musicSelectionLabels = {
  'auto': '배경에 맞춤',
  'day': '포근한 낮',
  'spring': '봄바람',
  'dusk': '해질녘',
  'rain': '비 오는 날',
  'snow': '눈 오는 날',
  'night': '조용한 밤',
};

bool validMusicSelection(String value) =>
    value == defaultMusicSelection || musicMoods.contains(value);

String selectedMusicMood(String selection, String sceneMood) {
  if (!validMusicSelection(selection)) {
    throw const FormatException('알 수 없는 배경음 선택');
  }
  return selection == defaultMusicSelection ? sceneMood : selection;
}
