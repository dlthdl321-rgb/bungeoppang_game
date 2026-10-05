part of 'game_controller.dart';

extension MenuCommands on GameController {
  Future<bool> buyOrEquipCosmetic(String id) async {
    if (busy || _away) return false;
    final matches = cosmetics.where((d) => d.id == id);
    if (matches.isEmpty) return false;
    final d = matches.first, fish = d.slot == CosmeticSlot.fish;
    tick();
    // Every slot, fish included, must pass the same level/production unlock.
    if (!cosmeticUnlocked(state, d)) return false;
    final before = state.copy();
    final buying = !state.ownsCosmetic(d);
    if (buying) {
      // Fish keeps its historical `skin:` ledger ID so old receipts still match.
      if (!state.support.transact(fish ? 'skin:$id' : 'cosmetic:$id', -d.cost,
          '${d.name} 구매', gameNow)) {
        return false;
      }
      (fish ? state.ownedSkins : state.wardrobe.owned).add(id);
    }
    if (fish) {
      state.equippedSkin = id;
    } else {
      state.wardrobe.equipped[d.slot] = id;
    }
    if (!buying) return _commit(before);
    return _commitWith(before, GameEvent(GameEventKind.purchase, d.name));
  }
}
