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
    if (!state.ownsCosmetic(d)) {
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
    return _commit(before);
  }

  Future<bool> joinEvent(String eventId) async {
    if (busy || _away) return false;
    tick();
    final matches = eventDefinitions.where((d) => d.id == eventId);
    if (matches.isEmpty ||
        eventPhase(matches.first, gameNow) != EventPhase.active ||
        state.events[eventId]!.joined) {
      return false;
    }
    final before = state.copy(), saved = state.events[eventId]!;
    saved.joined = true;
    saved.participants += BigInt.one;
    return _commit(before);
  }

  Future<bool> claimEventReward(String eventId, String rewardId) async {
    if (busy || _away) return false;
    tick();
    final events = eventDefinitions.where((d) => d.id == eventId);
    if (events.isEmpty) return false;
    final d = events.first,
        rewards = events.first.rewards.where((r) => r.id == rewardId);
    if (rewards.isEmpty || !canClaimEvent(state, d, rewards.first, gameNow)) {
      return false;
    }
    final before = state.copy(), saved = state.events[eventId]!;
    if (!grantReward(state, 'event:$eventId:$rewardId', rewards.first.reward,
        gameNow, '모의 이벤트 ${rewards.first.title}')) {
      return false;
    }
    saved.claimedCounts[rewardId] = saved.claimedCounts[rewardId]! + BigInt.one;
    saved.receipts[rewardId] = gameNow;
    return _commit(before);
  }

  // Local simulator only: no global stock reservation is claimed here.
  Future<bool> simulateEventClaims(
      String eventId, String rewardId, BigInt amount) async {
    if (busy || _away || amount <= BigInt.zero) return false;
    tick();
    final events = eventDefinitions.where((d) => d.id == eventId);
    if (events.isEmpty ||
        eventPhase(events.first, gameNow) != EventPhase.active) {
      return false;
    }
    final d = events.first,
        rewards = events.first.rewards.where((r) => r.id == rewardId);
    if (rewards.isEmpty) return false;
    final remaining = eventRemaining(state, d, rewards.first);
    if (remaining == BigInt.zero) return false;
    final taken = amount < remaining ? amount : remaining;
    final before = state.copy(), saved = state.events[eventId]!;
    saved.claimedCounts[rewardId] = saved.claimedCounts[rewardId]! + taken;
    saved.participants += taken;
    return _commit(before);
  }
}
