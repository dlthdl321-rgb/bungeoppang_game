import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/premium_config.dart';
import 'package:todays_bungeoppang/support_config.dart';

const catalogPath = 'firebase/functions/src/catalog.json';

void main() {
  test('서버 가격표(catalog.json)가 앱 설정과 같다', () {
    final expected =
        '${const JsonEncoder.withIndent('  ').convert(premiumCatalog())}\n';
    final file = File(catalogPath);
    // UPDATE_PREMIUM_CATALOG=1 flutter test test/premium_catalog_test.dart
    if (Platform.environment['UPDATE_PREMIUM_CATALOG'] == '1') {
      file.writeAsStringSync(expected);
    }
    expect(file.readAsStringSync(), expected,
        reason: '가격을 바꿨다면 UPDATE_PREMIUM_CATALOG=1로 다시 쓰고 서버를 배포하세요');
  });

  test('상품 id는 겹치지 않고 큰 묶음일수록 1원당 황금 붕어빵이 많다', () {
    expect(goldProducts.map((p) => p.id).toSet().length, goldProducts.length);
    for (var i = 1; i < goldProducts.length; i++) {
      final a = goldProducts[i - 1], b = goldProducts[i];
      expect(b.gold / b.referencePriceKrw,
          greaterThanOrEqualTo(a.gold / a.referencePriceKrw),
          reason: b.id);
    }
  });

  test('코인 가격이 있는 꾸미기는 황금 붕어빵으로도 살 수 있다', () {
    for (final d in cosmeticDefinitions) {
      expect(cosmeticGoldPrice(d) != null, d.cost > BigInt.zero, reason: d.id);
    }
    expect(boughtBoostGold, greaterThan(0));
  });

  test('처음부터 열린 스킬은 먼저 해금 가격이 없고, 뒤 스킬일수록 비싸다', () {
    for (final u in upgrades) {
      final price = skillUnlockGoldPrice(u);
      expect(price == null, u.unlockTotal <= BigInt.zero, reason: u.id);
    }
    expect(skillUnlockGoldPrice(upgrades.firstWhere((u) => u.id == 'tap_16')),
        greaterThan(
            skillUnlockGoldPrice(upgrades.firstWhere((u) => u.id == 'tap_4'))!));
  });
}
