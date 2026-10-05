/// One-shot notifications for sound and celebrations. Never saved; the state
/// itself is the source of truth.
enum GameEventKind { purchase, levelUp, missionReward, achievement, itemUsed }

class GameEvent {
  final GameEventKind kind;
  final String title;
  // Coins (rewards, level-up) or the item count left; null when nothing to count.
  final BigInt? amount;
  final String? unit;
  const GameEvent(this.kind, this.title, {this.amount, this.unit});
}
