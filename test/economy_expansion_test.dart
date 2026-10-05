import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/economy_config.dart';
import 'package:todays_bungeoppang/models.dart';

void main() {
  test('전체 스킬 가격은 양수이며 반복 구매마다 엄격히 증가한다', () {
    for (final u in upgrades) {
      var previous = BigInt.zero;
      for (var count = 0; count < maxUpgradeCount; count++) {
        final price = priceAt(u, count);
        expect(price > previous, isTrue, reason: '${u.id} #$count');
        previous = price;
      }
    }
  });

  test('후속 단계 효과와 기본 가격은 커지고 마지막 자동 생산은 20조 목표를 넘는다', () {
    expect(skillValuesEvidence, 'estimated');
    expect(upgrades.map((u) => u.id).toSet().length, upgrades.length);
    for (final kind in UpgradeKind.values) {
      final series = upgrades.where((u) => u.kind == kind).toList();
      expect(series.length, 16);
      for (var i = 1; i < series.length; i++) {
        expect(
            series[i].effect >= series[i - 1].effect * BigInt.from(5), isTrue);
        expect(series[i].baseCost > series[i - 1].baseCost, isTrue);
        expect(series[i].unlockTotal >= series[i - 1].unlockTotal, isTrue);
      }
    }
    expect(upgrades.last.effect >= levels.last.autoPerSecond, isTrue);
    expect(levels.last.autoPerSecond, BigInt.parse('20000000000000'));
  });

  test('누적 가격은 원래 유리수 공식으로 각각 올림한 값의 합과 일치한다', () {
    for (final u in [upgrades.first, upgrades[2], upgrades.last]) {
      for (final owned in [0, 17, 103, 997]) {
        final amount = (maxUpgradeCount - owned).clamp(0, 10);
        var oracle = BigInt.zero;
        for (var i = owned; i < owned + amount; i++) {
          final n = u.baseCost * BigInt.from(u.ratioNumerator).pow(i);
          final d = BigInt.from(u.ratioDenominator).pow(i);
          oracle += n ~/ d + (n % d == BigInt.zero ? BigInt.zero : BigInt.one);
        }
        expect(bundlePrice(u, owned, amount), oracle);
      }
    }
  });

  test('최대 구매는 정확한 경계 바로 아래와 위에서 일치하고 잔액이 음수가 되지 않는다', () {
    for (final u in [upgrades.first, upgrades[8], upgrades.last]) {
      for (final owned in [0, 9, 330, 999]) {
        for (final amount in [1, 10, 51]) {
          if (owned + amount > maxUpgradeCount) continue;
          final cost = bundlePrice(u, owned, amount);
          expect(maxAffordable(u, owned, cost), amount);
          expect(maxAffordable(u, owned, cost - BigInt.one), amount - 1);
          final count = maxAffordable(u, owned, cost + BigInt.one);
          expect(cost + BigInt.one - bundlePrice(u, owned, count),
              greaterThanOrEqualTo(BigInt.zero));
          if (owned + count < maxUpgradeCount) {
            expect(bundlePrice(u, owned, count + 1),
                greaterThan(cost + BigInt.one));
          }
        }
      }
    }
  });

  test('0원·한도·거대 잔액과 잘못된 인자도 유한하고 안전하게 처리한다', () {
    final u = upgrades.first;
    expect(maxAffordable(u, 0, BigInt.zero), 0);
    expect(maxAffordable(u, maxUpgradeCount, BigInt.from(10).pow(1000)), 0);
    expect(maxAffordable(u, 0, BigInt.from(10).pow(1000)), maxUpgradeCount);
    expect(bundlePrice(u, maxUpgradeCount, 0), BigInt.zero);
    expect(() => priceAt(u, -1), throwsRangeError);
    expect(() => bundlePrice(u, 0, -1), throwsRangeError);
    expect(() => bundlePrice(u, maxUpgradeCount, 1), throwsRangeError);
    expect(() => maxAffordable(u, 0, -BigInt.one), throwsArgumentError);
  });

  test('최대 구매 견적의 잠금, 현재 효과, 구매 후 효과와 마지막 잔여 수량', () {
    final s = GameState.initial(DateTime.utc(2026))
      ..buns = BigInt.from(10).pow(50);
    final locked = quoteUpgrade(s, upgrades.last, PurchaseMode.maximum);
    expect(locked.unlocked, isFalse);
    expect(locked.affordable, isFalse);
    expect(locked.amount, 0);
    final u = upgrades.first;
    s.upgradeCounts[u.id] = maxUpgradeCount - 3;
    final q = quoteUpgrade(s, u, PurchaseMode.ten);
    expect(q.amount, 3);
    expect(q.currentRate, tapRate(s));
    expect(q.afterRate - q.currentRate, u.effect * BigInt.from(3));
    expect(q.cost, bundlePrice(u, maxUpgradeCount - 3, 3));
  });

  test('한국식 단위의 모든 4자리 경계와 초대형 안전 대체 표기', () {
    for (var group = 1; group < koreanLargeUnits.length; group++) {
      final value = BigInt.from(10000).pow(group);
      expect(compactNumber(value), '1${koreanLargeUnits[group]}');
      expect(compactNumber(-value), '-1${koreanLargeUnits[group]}');
      expect(compactNumber(value * BigInt.from(10999) ~/ BigInt.from(10000)),
          '1.09${koreanLargeUnits[group]}');
      if (group > 1) {
        expect(compactNumber(value - BigInt.one),
            '9999.99${koreanLargeUnits[group - 1]}');
      }
    }
    expect(compactNumber(BigInt.from(10).pow(52)), '1.00e52');
    expect(compactNumber(BigInt.from(10).pow(1000)), '1.00e1000');
    expect(compactNumber(-BigInt.from(10).pow(1000)), '-1.00e1000');
    expect(exactNumber(BigInt.parse('12345678901234567890')),
        '12,345,678,901,234,567,890');
  });
}
