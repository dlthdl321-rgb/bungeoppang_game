import '../cosmetic_config.dart';
import 'avatar_painter.dart';

/// 32번 0단계: moved unchanged from `boost_effects.dart`.
/// A look from the server (slot name -> item id) as an [AvatarLook]; unknown
/// or missing slots fall back to the defaults.
AvatarLook lookFromServer(Map<String, String> look) {
  String pick(CosmeticSlot slot) {
    final id = look[slot.name];
    return id != null &&
            cosmeticDefinitions.any((d) => d.slot == slot && d.id == id)
        ? id
        // Hair not sent: the character's own default (26번 3차 G).
        : slot == CosmeticSlot.hair
            ? defaultHairOf(pick(CosmeticSlot.character))
            : defaultCosmetics[slot]!;
  }

  return AvatarLook.of(pick);
}
