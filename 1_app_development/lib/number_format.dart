/// Number display (32번 0단계): moved unchanged from the old clicker's
/// `economy.dart`/`economy_config.dart`.
const koreanLargeUnits = [
  '',
  '만',
  '억',
  '조',
  '경',
  '해',
  '자',
  '양',
  '구',
  '간',
  '정',
  '재',
  '극',
  '항하사',
  '아승기',
  '나유타',
  '불가사의',
  '무량대수'
];

String exactNumber(BigInt n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Truncates display only; never converts currency to double or platform int.
/// Korean units 만·억·조·경 … 무량대수(10^68), 2 decimals truncated
/// ('1.09만', '9999.99억'). Past 9999.99무량대수 the part above 무량대수
/// is written the same way and joined ('1만 무량대수', '9870재 무량대수'),
/// so the screen never shows scientific notation like '9.87e115'.
String compactNumber(BigInt n) {
  final sign = n.isNegative ? '-' : '';
  final magnitude = n.abs();
  if (magnitude < BigInt.from(10000)) return exactNumber(n);
  final top = koreanLargeUnits.length - 1;
  final topUnit = BigInt.from(10000).pow(top);
  if (magnitude >= topUnit * BigInt.from(10000)) {
    return '$sign${compactNumber(magnitude ~/ topUnit)} ${koreanLargeUnits[top]}';
  }
  final digits = magnitude.toString();
  final group = (digits.length - 1) ~/ 4;
  final unit = BigInt.from(10000).pow(group);
  final hundredths = magnitude * BigInt.from(100) ~/ unit;
  final whole = hundredths ~/ BigInt.from(100);
  final fraction = (hundredths % BigInt.from(100))
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$sign$whole${fraction.isEmpty ? '' : '.$fraction'}${koreanLargeUnits[group]}';
}
