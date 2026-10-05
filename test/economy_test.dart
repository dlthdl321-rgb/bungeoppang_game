import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/models.dart';

void main() {
  test('10개 가격은 개별 가격의 합이다', () {
    final u = upgrades.first;
    final expected = List.generate(10, (i) => priceAt(u, i))
        .fold(BigInt.zero, (a, b) => a + b);
    expect(bundlePrice(u, 0, 10), expected);
  });
  test('파생 생산량은 구매 수량의 덧셈이다', () {
    final s = GameState.initial(DateTime.utc(2026));
    s.upgradeCounts['tap_2'] = 2;
    s.upgradeCounts['auto_3'] = 3;
    expect(tapRate(s), BigInt.from(17));
    expect(autoRate(s), BigInt.from(300));
  });
  test('큰 수 축약 경계를 버림 표시한다', () {
    expect(compactNumber(BigInt.from(9999)), '9,999');
    expect(compactNumber(BigInt.from(10000)), '1만');
    expect(compactNumber(BigInt.from(10999)), '1.09만');
    expect(compactNumber(BigInt.from(100000000)), '1억');
    expect(compactNumber(BigInt.from(1000000000000)), '1조');
    expect(compactNumber(BigInt.from(10000000000000000)), '1경');
    // New Korean large units replace the v1 unbounded coefficient before 경.
    expect(compactNumber(BigInt.from(10).pow(30)), '100양');
  });
}
