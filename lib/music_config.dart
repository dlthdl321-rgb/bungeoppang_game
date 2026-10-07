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
