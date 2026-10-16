import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/balance.dart';

void main() {
  test('BigInt는 십진 문자열로 저장하고 정확히 복원한다', () {
    final s = GameState.initial(DateTime.utc(2026));
    s.buns = BigInt.from(10).pow(30);
    s.lifetime = s.buns;
    final encoded = jsonEncode(s.toJson());
    expect(encoded, contains('1000000000000000000000000000000'));
    final restored = GameState.fromJson(jsonDecode(encoded));
    expect(restored.buns, s.buns);
  });
  test('범위를 벗어난 업그레이드는 거부한다', () {
    final json = GameState.initial(DateTime.utc(2026)).toJson();
    (json['upgradeCounts'] as Map<String, int>)['tap_1'] = maxUpgradeCount + 1;
    expect(() => GameState.fromJson(json), throwsFormatException);
  });
  test('v1의 기존 25개 한도를 넘은 저장은 여전히 거부한다', () {
    final json = GameState.initial(DateTime.utc(2026)).toJson()
      ..['formatVersion'] = 1;
    (json['upgradeCounts'] as Map<String, int>)['tap_1'] = 26;
    expect(() => GameState.fromJson(json), throwsFormatException);
  });
}
