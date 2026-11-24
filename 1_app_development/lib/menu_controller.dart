part of 'game_controller.dart';

/// The old wardrobe (32번 2단계): owned items are only worn now; nothing is
/// bought with the old coins any more. The name stays for its callers.
extension MenuCommands on GameController {
  Future<bool> buyOrEquipCosmetic(String id) async {
    if (busy || _away) return false;
    final matches = cosmetics.where((d) => d.id == id);
    if (matches.isEmpty) return false;
    final d = matches.first, fish = d.slot == CosmeticSlot.fish;
    if (!state.ownsCosmetic(d)) return false;
    final before = state.copy();
    if (fish) {
      state.equippedSkin = id;
    } else {
      state.wardrobe.equipped[d.slot] = id;
    }
    return _commit(before);
  }
}
