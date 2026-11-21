import 'pantry_rules.dart';

/// 재료 타이쿤 E — what the home shows about the pantry (no widgets): the
/// stock line under the business sign, the words of the gift, rescue and
/// out-of-ingredients notices. The numbers come from [PantryConfig]
/// (`config/development_balance.json` `ingredients`).

/// How full one stock is on the home line: [low] below 20% of the stock
/// limit (orange), [out] none left (red).
enum PantryStockLevel { ok, low, out }

PantryStockLevel pantryStockLevel(PantryConfig c, PantryState pantry, String kind, int level, int nowMs) {
  if (pantry.usable(c, kind, nowMs) < 1) return PantryStockLevel.out;
  return pantry.lowStock(c, kind, level, nowMs) ? PantryStockLevel.low : PantryStockLevel.ok;
}

/// Tubs on the home line: '3통', '1.4통' (rounded up to a tenth, so a
/// little left never reads as none), '0통'.
String pantryTubsShort(PantryConfig c, int portions) {
  if (portions <= 0) return '0통';
  final tenths = (portions * 10 + c.portionsPerTub - 1) ~/ c.portionsPerTub;
  return tenths % 10 == 0 ? '${tenths ~/ 10}통' : '${tenths ~/ 10}.${tenths % 10}통';
}

/// Tapping the stock line or the bubble while open (재료 준비 is only
/// during 영업 준비, DEC-TBD-tA-2).
const pantryOpenOnlyText = '재료 준비는 영업 준비 중에 할 수 있어요.';

/// The out-of-ingredients bubble (once per run-out, in business).
const pantryOutHint = '영업을 마치고 ‘재료 준비’에서 만들어요';

/// What ran out, for the bubble's first line and `ingredient_out`'s `what`.
String pantryOutTitle(PantryConfig c, PantryShortage shortage, String flavor) => switch (shortage) {
      PantryShortage.batter => '반죽이 떨어졌어요',
      PantryShortage.filling => '${c.kind(flavor).label}${_subject(c.kind(flavor).label)} 떨어졌어요',
      PantryShortage.none => pantryEmptyText,
    };

/// '슈크림 레시피 선물로 슈크림 1통과 1통 더 만들 재료를 받았어요.'
String recipeGiftNotice(PantryConfig c, String flavor) {
  final recipe = c.recipeLabels[flavor] ?? flavor, filling = c.kind(flavor).label;
  return '$recipe 레시피 선물로 $filling ${c.recipeGiftTubs}통과 ${c.recipeGiftSets}통 더 만들 재료를 받았어요.';
}

/// The free 기본 재료 꾸러미 (when every stock is out and 붕어빵력 cannot buy
/// one tub): '... (오늘 1/3)'.
String rescueNotice(PantryConfig c, int givenToday) =>
    '재료도 붕어빵력도 모자라 기본 재료 꾸러미를 드렸어요. 영업 준비 때 ‘재료 준비’에서 만들어요. (오늘 $givenToday/${c.rescueDailyLimit})';

String _subject(String word) {
  for (var i = word.length - 1; i >= 0; i--) {
    final code = word.codeUnitAt(i);
    if (code >= 0xac00 && code <= 0xd7a3) return (code - 0xac00) % 28 == 0 ? '가' : '이';
  }
  return '이';
}
