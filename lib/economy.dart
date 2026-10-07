import 'balance.dart';
import 'economy_config.dart';
import 'models.dart';
import 'support_config.dart';

BigInt ceilDiv(BigInt a, BigInt b) {
  if (a.isNegative || b <= BigInt.zero) {
    throw ArgumentError('Expected a >= 0 and b > 0');
  }
  return (a + b - BigInt.one) ~/ b;
}

/// Exact rounded per-item prices, cached lazily in a bounded prefix table.
/// Rounding a geometric sum once is NOT equivalent to rounding each purchase.
class _PriceTable {
  final UpgradeDefinition skill;
  final totals = <BigInt>[BigInt.zero];
  late BigInt numerator = skill.baseCost;
  BigInt denominator = BigInt.one;
  _PriceTable(this.skill) {
    if (skill.baseCost <= BigInt.zero ||
        skill.effect <= BigInt.zero ||
        skill.ratioDenominator <= 0 ||
        skill.ratioNumerator <= skill.ratioDenominator ||
        skill.unlockTotal.isNegative) {
      throw ArgumentError('Invalid skill balance: ${skill.id}');
    }
  }
  void ensure(int count) {
    while (totals.length <= count) {
      totals.add(totals.last + ceilDiv(numerator, denominator));
      numerator *= BigInt.from(skill.ratioNumerator);
      denominator *= BigInt.from(skill.ratioDenominator);
    }
  }
}

final _prices = Expando<_PriceTable>();
_PriceTable _table(UpgradeDefinition u) => _prices[u] ??= _PriceTable(u);

BigInt priceAt(UpgradeDefinition u, int owned) {
  RangeError.checkValueInInterval(owned, 0, maxUpgradeCount - 1, 'owned');
  final table = _table(u)..ensure(owned + 1);
  return table.totals[owned + 1] - table.totals[owned];
}

BigInt bundlePrice(UpgradeDefinition u, int owned, int amount) {
  RangeError.checkValueInInterval(owned, 0, maxUpgradeCount, 'owned');
  RangeError.checkValueInInterval(amount, 0, maxUpgradeCount - owned, 'amount');
  if (amount == 0) return BigInt.zero;
  final table = _table(u)..ensure(owned + amount);
  return table.totals[owned + amount] - table.totals[owned];
}

/// Exponential bound then binary search, entirely with integral currency.
/// The upper bound prevents runaway loops even for a balance of 10^1000.
int maxAffordable(UpgradeDefinition u, int owned, BigInt budget) {
  RangeError.checkValueInInterval(owned, 0, maxUpgradeCount, 'owned');
  if (budget.isNegative) throw ArgumentError.value(budget, 'budget');
  final remaining = maxUpgradeCount - owned;
  if (remaining == 0 || budget < priceAt(u, owned)) return 0;
  var low = 1, high = 1;
  while (high < remaining && bundlePrice(u, owned, high) <= budget) {
    low = high;
    high = (high * 2).clamp(1, remaining);
  }
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (bundlePrice(u, owned, middle) <= budget) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}

enum PurchaseMode { one, ten, maximum }

class UpgradeQuote {
  final int amount;
  final BigInt cost, currentRate, afterRate;
  final bool unlocked, affordable, maxed;
  const UpgradeQuote(
      {required this.amount,
      required this.cost,
      required this.currentRate,
      required this.afterRate,
      required this.unlocked,
      required this.affordable,
      required this.maxed});
}

UpgradeQuote quoteUpgrade(GameState s, UpgradeDefinition u, PurchaseMode mode,
    {DateTime? at}) {
  final owned = s.upgradeCounts[u.id] ?? 0;
  final remaining = maxUpgradeCount - owned;
  final unlocked = skillUnlocked(s, u);
  final amount = switch (mode) {
    PurchaseMode.one => remaining > 0 ? 1 : 0,
    PurchaseMode.ten => remaining.clamp(0, 10),
    PurchaseMode.maximum => unlocked ? maxAffordable(u, owned, s.buns) : 0,
  };
  final cost = bundlePrice(u, owned, amount);
  final rate = u.kind == UpgradeKind.tap ? tapRate(s) : autoRate(s);
  final factor = at == null
      ? BigInt.from(effectScale)
      : s.support.multiplier(at);
  return UpgradeQuote(
      amount: amount,
      cost: cost,
      currentRate: rate * factor ~/ BigInt.from(effectScale),
      afterRate: (rate + u.effect * BigInt.from(amount)) *
          factor ~/
          BigInt.from(effectScale),
      unlocked: unlocked,
      affordable: unlocked && amount > 0 && s.buns >= cost,
      maxed: remaining == 0);
}

BigInt tapRate(GameState s) =>
    BigInt.one +
    upgrades.where((u) => u.kind == UpgradeKind.tap).fold(BigInt.zero,
        (v, u) => v + u.effect * BigInt.from(s.upgradeCounts[u.id] ?? 0));
BigInt autoRate(GameState s) =>
    upgrades.where((u) => u.kind == UpgradeKind.auto).fold(BigInt.zero,
        (v, u) => v + u.effect * BigInt.from(s.upgradeCounts[u.id] ?? 0));

String exactNumber(BigInt n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Truncates display only; never converts currency to double or platform int.
String compactNumber(BigInt n) {
  final sign = n.isNegative ? '-' : '';
  final magnitude = n.abs();
  if (magnitude < BigInt.from(10000)) return exactNumber(n);
  final digits = magnitude.toString();
  final group = (digits.length - 1) ~/ 4;
  if (group >= koreanLargeUnits.length) {
    return '$sign${digits[0]}.${digits.substring(1, 3)}e${digits.length - 1}';
  }
  final unit = BigInt.from(10000).pow(group);
  final hundredths = magnitude * BigInt.from(100) ~/ unit;
  final whole = hundredths ~/ BigInt.from(100);
  final fraction = (hundredths % BigInt.from(100))
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole${fraction.isEmpty ? '' : '.$fraction'}${koreanLargeUnits[group]}';
}

/// A skill can be bought once lifetime production reaches its goal, or
/// earlier if it was unlocked with 황금 붕어빵.
bool skillUnlocked(GameState s, UpgradeDefinition u) =>
    s.lifetime >= u.unlockTotal || s.premium.skillUnlocks.contains(u.id);
