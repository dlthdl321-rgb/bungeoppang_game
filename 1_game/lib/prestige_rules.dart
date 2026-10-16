import 'config_values.dart';
import 'models.dart';
import 'prestige_config.dart';

/// Integer cube root (floor) for non-negative BigInt.
BigInt bigCbrt(BigInt n) {
  if (n < BigInt.two) return n;
  var low = BigInt.zero, high = BigInt.one << (n.bitLength ~/ 3 + 1);
  while (low < high) {
    final mid = (low + high + BigInt.one) >> 1;
    if (mid * mid * mid <= n) {
      low = mid;
    } else {
      high = mid - BigInt.one;
    }
  }
  return low;
}

BigInt totalStarsFor(BigInt lifetime) =>
    bigCbrt(lifetime ~/ configBigInt(prestigeStarUnit));

/// Stars a prestige would grant right now.
BigInt prestigeStarsAvailable(GameState s) {
  final more = totalStarsFor(s.lifetime) - BigInt.from(s.prestige.stars);
  return more.isNegative ? BigInt.zero : more;
}

bool canPrestige(GameState s) =>
    s.level >= prestigeUnlockLevel && prestigeStarsAvailable(s) > BigInt.zero;

/// Production multiplier in permille (1000 = no bonus).
int prestigePermille(GameState s) =>
    1000 + prestigeBonusPermillePerStar * s.prestige.stars;
int prestigePermilleWith(int stars) =>
    1000 + prestigeBonusPermillePerStar * stars;
