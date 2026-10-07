import 'balance.dart';
import 'cosmetic_config.dart';
import 'models.dart';
import 'support_config.dart';

// 황금 붕어빵: the paid currency, bought with Google Play Billing and kept on
// the server (firebase/functions). Coins stay the free currency.
//
// The server reads the same prices from firebase/functions/src/catalog.json,
// which test/premium_catalog_test.dart writes from this file.

const premiumConfigVersion = 'premium-v1';
const goldName = '황금 붕어빵';
const androidPackageName = 'com.todaybungeoppang.todays_bungeoppang';

/// A Play Console in-app product (consumable). [referencePriceKrw] is only
/// the planned price; the shop always shows Google Play's localized price.
class GoldProduct {
  final String id;
  final int gold, referencePriceKrw;
  const GoldProduct(this.id, this.gold, this.referencePriceKrw);
}

const goldProducts = [
  GoldProduct('gold_60', 60, 1200),
  GoldProduct('gold_330', 330, 5900),
  GoldProduct('gold_700', 700, 11000),
  GoldProduct('gold_2200', 2200, 33000),
  GoldProduct('gold_3800', 3800, 55000),
];

/// Gold per coin when a coin-priced thing is bought with gold.
const goldPerCoin = 5;

/// Gold to unlock the n-th skill of a line before its production goal
/// (tap_n / auto_n): n × this.
const goldPerSkillStep = 10;

/// Any cosmetic with a coin price can also be bought with gold, and gold
/// skips its level and production lock (먼저 해금). Free items: null.
int? cosmeticGoldPrice(CosmeticDefinition d) =>
    d.cost > BigInt.zero ? d.cost.toInt() * goldPerCoin : null;

/// Unlocking [u] early lets the player buy it with buns before reaching its
/// production goal. Skills open from the start: null.
int? skillUnlockGoldPrice(UpgradeDefinition u) {
  if (u.unlockTotal <= BigInt.zero) return null;
  final step = int.parse(u.id.substring(u.id.indexOf('_') + 1));
  return step * goldPerSkillStep;
}

/// Gold price of a [BoostKind.bought] boost (×3 for 10 minutes).
const boughtBoostGold = 20;

/// The price list the server enforces (catalog.json).
Map<String, Object> premiumCatalog() => {
      'version': premiumConfigVersion,
      'packageName': androidPackageName,
      'products': [
        for (final p in goldProducts) {'id': p.id, 'gold': p.gold}
      ],
      'spend': {
        'cosmetic': {
          for (final d in cosmeticDefinitions)
            if (cosmeticGoldPrice(d) case final price?) d.id: price
        },
        'skill': {
          for (final u in upgrades)
            if (skillUnlockGoldPrice(u) case final price?) u.id: price
        },
        'boost': {boostOf(BoostKind.bought).id: boughtBoostGold},
      },
    };
