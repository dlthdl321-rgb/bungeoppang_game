
// 황금 붕어빵: the paid currency, bought with Google Play Billing and kept on
// the server (firebase/functions).
//
// The server reads the same prices from firebase/functions/src/catalog.json,
// which test/premium_catalog_test.dart writes from this file.

const premiumConfigVersion = 'premium-v1';
const goldName = '황금붕어빵력';
const androidPackageName = 'com.todaybungeoppang.app';

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

/// The old clicker's gold prices (cosmetics, early skill unlocks, the
/// bought boost) the deployed server still lists. Frozen as they were
/// (32번 5단계): the app no longer spends gold this way; they go from
/// catalog.json with the server cleanup (32번 6단계).
const legacySpendCatalog = <String, Map<String, int>>{
  'cosmetic': {
    'night': 15,
    'dusk': 25,
    'forest': 45,
    'copper': 35,
    'lantern': 20,
    'bunting': 40,
    'snow': 35,
    'cherry': 50,
    'seaside': 70,
    'castiron': 30,
    'golden': 75,
    'starlights': 25,
    'windchime': 45,
    'snowman': 60,
    'heartscale': 25,
    'starmark': 40,
    'crispgrid': 55,
    'sugar': 20,
    'choco': 35,
    'almond': 45,
    'sprinkle': 65,
    'short': 15,
    'ponytail': 25,
    'lowponytail': 25,
    'curly': 40,
    'stripe': 45,
    'beanie': 15,
    'earmuffs': 30,
    'chefhat': 50,
    'santa': 70,
    'goldtongs': 75,
    'creamlong': 15,
    'pinksweater': 30,
    'sagesweater': 30,
    'creamsweater': 40,
    'cardigan': 50,
    'padding': 30,
    'chefcoat': 60,
    'skirt': 20,
    'widepants': 30,
    'brownpants': 35,
    'jeans': 25,
    'denimshorts': 25,
    'joggers': 30,
    'checkskirt': 35,
    'cargopants': 40,
    'longskirt': 45,
    'sneakers': 20,
    'boots': 35,
    'furboots': 50,
    'darkapron': 25,
    'creamapron': 35,
    'waistapron': 45,
    'bandana': 20,
    'redbandana': 30,
    'ballcap': 35,
    'newsboy': 40,
    'blackcap': 45,
    'ribbon': 20,
    'fishpin': 25,
    'glasses': 30,
    'scarf': 40,
    'mittens': 45,
    'crossbag': 55,
    'paperbag': 40,
    'fishhold': 60,
    'rain': 30,
    'autumn': 45,
    'snowday': 55,
    'paperlanterns': 50,
    'roselamp': 20,
    'mintlamp': 30,
    'lilaclamp': 40,
  },
  'skill': {
    'tap_2': 20,
    'tap_3': 30,
    'tap_4': 40,
    'tap_5': 50,
    'tap_6': 60,
    'tap_7': 70,
    'tap_8': 80,
    'tap_9': 90,
    'tap_10': 100,
    'tap_11': 110,
    'tap_12': 120,
    'tap_13': 130,
    'tap_14': 140,
    'tap_15': 150,
    'tap_16': 160,
    'auto_2': 20,
    'auto_3': 30,
    'auto_4': 40,
    'auto_5': 50,
    'auto_6': 60,
    'auto_7': 70,
    'auto_8': 80,
    'auto_9': 90,
    'auto_10': 100,
    'auto_11': 110,
    'auto_12': 120,
    'auto_13': 130,
    'auto_14': 140,
    'auto_15': 150,
    'auto_16': 160,
  },
  'boost': {
    'bought': 20,
  },
};

/// The price list the server enforces (catalog.json).
Map<String, Object> premiumCatalog() => {
      'version': premiumConfigVersion,
      'packageName': androidPackageName,
      'products': [
        for (final p in goldProducts) {'id': p.id, 'gold': p.gold}
      ],
      'spend': legacySpendCatalog,
    };
