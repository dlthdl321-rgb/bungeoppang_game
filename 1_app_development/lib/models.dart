import 'music_config.dart';
import 'development_audio_defaults.dart';
import 'menu_state.dart';
import 'cosmetic_config.dart';
import 'premium_state.dart';

/// Flavours sold before stage 14; saves that wore one get redbean back.
const _removedFlavours = {'custard', 'cocoa', 'sweetpotato', 'matcha', 'strawberry'};


class GameSettings {
  bool vibration, holdToBake, reduceMotion, soundEffects, music;
  int sfxVolume, musicVolume; // Whole percents, 0..100.
  String musicSelection;
  bool cookingSound;
  int cookingVolume;
  /// Customer notifications (26번 5-1단계): regular guests off, named
  /// neighbors on, quiet 22:00~08:00 on, and whether the one-time question
  /// after the first-run guide was answered. Saves without them get these
  /// defaults; the save format stays v13.
  bool notifyRegularGuests, notifyNamedGuests, quietNightNotices, notificationPromptDone;
  /// 사용 통계 보내기(26번 5단계, DEC-046): on by default, no first-run
  /// notice; off stops Firebase Analytics collection. Saves without it get
  /// true; the save format stays v13.
  bool sendUsageStats;
  GameSettings(
      {this.vibration = true,
      this.holdToBake = false,
      this.reduceMotion = false,
      this.soundEffects = true,
      this.music = true,
      this.sfxVolume = provisionalDefaultSfxVolume,
      this.musicVolume = provisionalDefaultBgmVolume,
      this.musicSelection = defaultMusicSelection,
      this.cookingSound = provisionalDefaultCookingEnabled,
      this.cookingVolume = provisionalDefaultCookingVolume,
      this.notifyRegularGuests = false,
      this.notifyNamedGuests = true,
      this.quietNightNotices = true,
      this.notificationPromptDone = false,
      this.sendUsageStats = true});
  Map<String, dynamic> toJson() => {
        'vibration': vibration,
        'holdToBake': holdToBake,
        'reduceMotion': reduceMotion,
        'soundEffects': soundEffects,
        'music': music,
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
        'musicSelection': musicSelection,
        'cookingSound': cookingSound,
        'cookingVolume': cookingVolume,
        'notifyRegularGuests': notifyRegularGuests,
        'notifyNamedGuests': notifyNamedGuests,
        'quietNightNotices': quietNightNotices,
        'notificationPromptDone': notificationPromptDone,
        'sendUsageStats': sendUsageStats,
        musicDefaultKey: true,
      };

  /// 26번 3차 H7: 배경음 is on from the start. Saves written before this key
  /// existed (test devices only, before release) get 배경음 turned on once
  /// when read; from then on the player's own choice is kept. The save
  /// format stays v13 (an extra settings key, like the notification ones).
  static const musicDefaultKey = 'musicOnByDefault';

  /// Sound settings exist from v8; older saves get the defaults.
  factory GameSettings.fromJson(Object? raw,
      {bool withSound = false, bool withIndependentMusic = false}) {
    final m = raw is Map ? raw : const {};
    bool flag(String key, bool fallback) {
      final v = m[key];
      if (v != null && v is! bool) throw FormatException('잘못된 $key');
      return v as bool? ?? fallback;
    }
    final settings = GameSettings(
        vibration: m['vibration'] is bool ? m['vibration'] as bool : true,
        holdToBake: m['holdToBake'] == true,
        reduceMotion: m['reduceMotion'] == true,
        notifyRegularGuests: flag('notifyRegularGuests', false),
        notifyNamedGuests: flag('notifyNamedGuests', true),
        quietNightNotices: flag('quietNightNotices', true),
        notificationPromptDone: flag('notificationPromptDone', false),
        sendUsageStats: flag('sendUsageStats', true));
    if (!withSound) return settings;
    int volume(String key) {
      final v = m[key];
      if (v is! int || v < 0 || v > 100) {
        throw FormatException('잘못된 $key');
      }
      return v;
    }

    if (m['soundEffects'] is! bool || m['music'] is! bool) {
      throw const FormatException('잘못된 소리 설정');
    }
    if (withIndependentMusic) {
      final selection = m['musicSelection'];
      if (selection is! String || !validMusicSelection(selection)) {
        throw const FormatException('잘못된 배경음 선택');
      }
      if (m['cookingSound'] is! bool) {
        throw const FormatException('잘못된 굽기 소리 설정');
      }
      settings
        ..musicSelection = selection
        ..cookingSound = m['cookingSound'] as bool
        ..cookingVolume = volume('cookingVolume');
    }
    return settings
      ..soundEffects = m['soundEffects'] as bool
      ..music = m[musicDefaultKey] == true ? m['music'] as bool : true
      ..sfxVolume = volume('sfxVolume')
      ..musicVolume = volume('musicVolume');
  }
}

class GameState {
  /// 15 (32번 3단계, 2026-11-25): the old clicker's progress is gone; the
  /// account save keeps settings, the 황금 balance, the old wardrobe and
  /// fish skins. Saves 1~14 still load (their old keys are ignored).
  static const formatVersion = 15;
  int snapshotSequence;
  WardrobeState wardrobe;

  /// 황금 붕어빵 wallet copy (the server owns the balance).
  PremiumState premium;
  Set<String> ownedSkins;
  String equippedSkin;
  GameSettings settings;
  GameState(
      {required this.snapshotSequence,
      required this.wardrobe,
      required this.premium,
      required this.ownedSkins,
      required this.equippedSkin,
      required this.settings});
  factory GameState.initial([DateTime? now]) => GameState(
      snapshotSequence: 0,
      wardrobe: WardrobeState.initial(),
      premium: PremiumState(),
      ownedSkins: {'redbean'},
      equippedSkin: 'redbean',
      settings: GameSettings());
  GameState copy() => GameState.fromJson(toJson());
  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'snapshotSequence': snapshotSequence,
        'wardrobe': wardrobe.toJson(),
        'premium': premium.toJson(),
        'ownedSkins': ownedSkins.toList(),
        'equippedSkin': equippedSkin,
        'settings': settings.toJson(),
      };
  // [cosmetics] lets catalog-evolution tests load saves against a future catalog.
  factory GameState.fromJson(Map<String, dynamic> m,
      {Iterable<CosmeticDefinition> cosmetics = cosmeticDefinitions}) {
    final version = m['formatVersion'];
    if (version is! int || version < 1 || version > formatVersion) {
      throw const FormatException('지원하지 않는 저장 버전');
    }
    final fishIds = {
      for (final d in cosmetics)
        if (d.slot == CosmeticSlot.fish) d.id
    };
    // Removed flavours (stage 14) fall back to redbean; unreleased, so
    // nothing is refunded.
    final saved = '${m['equippedSkin']}';
    final equipped = fishIds.contains(saved) || !_removedFlavours.contains(saved)
        ? saved
        : 'redbean';
    final owned = (m['ownedSkins'] as List?)
            ?.whereType<String>()
            .where(fishIds.contains)
            .toSet() ??
        {'redbean'};
    if (!owned.contains(equipped)) {
      throw const FormatException('장착 외형을 보유하지 않음');
    }
    final premium = m['premium'];
    if (m.containsKey('premium') && premium is! Map) {
      throw const FormatException('황금 붕어빵 저장 손상');
    }
    return GameState(
        snapshotSequence:
            m['snapshotSequence'] is int ? m['snapshotSequence'] as int : 0,
        wardrobe: version >= 6
            ? WardrobeState.fromJson(_map(m['wardrobe']), version: version)
            : WardrobeState.initial(),
        // Added without a format bump: saves before stage 15 have none.
        premium: PremiumState.fromJson(
            premium is Map ? Map<String, dynamic>.from(premium) : null),
        ownedSkins: owned,
        equippedSkin: equipped,
        settings: GameSettings.fromJson(m['settings'],
            withSound: version >= 8, withIndependentMusic: version >= 13));
  }

  String equippedCosmetic(CosmeticSlot slot) =>
      slot == CosmeticSlot.fish ? equippedSkin : wardrobe.equipped[slot]!;
  bool ownsCosmetic(CosmeticDefinition item) => item.slot == CosmeticSlot.fish
      ? ownedSkins.contains(item.id)
      : wardrobe.owned.contains(item.id);
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('저장 항목 손상');
  return Map<String, dynamic>.from(value);
}
