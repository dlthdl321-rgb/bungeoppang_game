import 'cosmetic_config.dart';
import 'event_config.dart';
import 'models.dart';

bool cosmeticUnlocked(GameState s, CosmeticDefinition d) =>
    s.level >= d.unlockLevel && s.lifetime >= BigInt.parse(d.unlockProduction);

enum EventPhase { upcoming, active, ended }

EventPhase eventPhase(EventDefinition d, DateTime now) => now.isBefore(d.start)
    ? EventPhase.upcoming
    : !now.isBefore(d.end)
        ? EventPhase.ended
        : EventPhase.active;
BigInt eventRemaining(GameState s, EventDefinition d, EventRewardDefinition r) {
  final remaining =
      BigInt.parse(r.capacity) - s.events[d.id]!.claimedCounts[r.id]!;
  return remaining.isNegative ? BigInt.zero : remaining;
}

bool canClaimEvent(
    GameState s, EventDefinition d, EventRewardDefinition r, DateTime now) {
  final saved = s.events[d.id]!;
  return eventPhase(d, now) == EventPhase.active &&
      saved.joined &&
      !saved.receipts.containsKey(r.id) &&
      !s.support.ledger.containsKey('event:${d.id}:${r.id}') &&
      eventRemaining(s, d, r) > BigInt.zero &&
      s.level >= r.requiredLevel &&
      s.lifetime >= BigInt.parse(r.requiredProduction) &&
      r.prerequisites.every(saved.receipts.containsKey);
}
