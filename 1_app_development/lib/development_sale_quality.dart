import 'development_balance.dart';

class SaleQualityPortion {
  final int variant, quantity, age, difficulty;
  final int? requestedVariant;
  final bool specialOrder;
  SaleQualityPortion({required this.variant, required this.quantity, required this.age,
      required this.difficulty, this.requestedVariant, this.specialOrder = false});
}
class SaleQualityQuote {
  final int scorePermille, stars;
  final BigInt provisionalOrdinaryBuns;
  SaleQualityQuote(this.scorePermille, this.stars, this.provisionalOrdinaryBuns);
}

/// Only quote quality/ordinary amount; full order match, stock reservation,
/// expiry race, atomic payment and server gold review remain separate commands.
SaleQualityQuote evaluateSaleQuality(DevelopmentBalance config, List<SaleQualityPortion> portions) {
  if (portions.isEmpty) throw const FormatException('빈 판매 품질 입력');
  final sale = config.section('ordinary_sale');
  final qualities = config.integers('ordinary_sale', 'quality_permille_by_doneness');
  final freshness = config.integers('ordinary_sale', 'freshness_satisfaction_permille_by_age');
  final prices = config.integers('ordinary_sale', 'freshness_price_permille_by_age');
  final weights = [DevelopmentBalance.integer(sale, 'quality_weight_permille'),
    DevelopmentBalance.integer(sale, 'freshness_weight_permille')];
  if (weights[0] + weights[1] != 1000 || qualities.length != 5 || freshness.length != 5 || prices.length != 5) {
    throw const FormatException('판매 품질 설정 오류');
  }
  final base = sale['base_buns_by_difficulty'];
  if (base is! List || base.length != 3) throw const FormatException('판매 기본값 누락');
  var weighted = BigInt.zero, count = BigInt.zero, buns = BigInt.zero;
  for (final p in portions) {
    if (p.quantity <= 0 || p.difficulty < 0 || p.difficulty >= 3 || p.age < 0 || p.age >= 5 ||
        p.variant < 0 || p.variant >= 4 || (p.requestedVariant != null && p.requestedVariant != p.variant) ||
        (p.variant == 0 && (!p.specialOrder || p.requestedVariant != 0))) {
      throw const FormatException('판매 불가 품질/신선도/익힘');
    }
    // Explicit requested doneness, including undercooked special orders, is not
    // downgraded as a failed recipe. General orders use the provisional quality.
    final quality = p.requestedVariant == p.variant ? 1000 : qualities[p.variant];
    final quantity = BigInt.from(p.quantity);
    weighted += (BigInt.from(quality) * BigInt.from(weights[0]) +
        BigInt.from(freshness[p.age]) * BigInt.from(weights[1])) * quantity;
    count += quantity;
    final unit = DevelopmentBalance.decimal({'base': base[p.difficulty]}, 'base') * BigInt.from(prices[p.age]) ~/ BigInt.from(1000);
    buns += unit * quantity; // Per-product rounding is independent of batch splits.
  }
  final score = (weighted ~/ (count * BigInt.from(1000))).toInt();
  final thresholds = config.integers('ordinary_sale', 'satisfaction_threshold_permille');
  if (thresholds.length != 5 || thresholds.first != 0 || thresholds.last > 1000 ||
      List.generate(4, (i) => thresholds[i] >= thresholds[i + 1]).any((v) => v)) {
    throw const FormatException('별점 경계 오류');
  }
  var stars = 1;
  for (var i = 1; i < thresholds.length; i++) { if (score >= thresholds[i]) stars = i + 1; }
  return SaleQualityQuote(score, stars, buns);
}
