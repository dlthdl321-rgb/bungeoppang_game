import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/premium_config.dart';

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
}
