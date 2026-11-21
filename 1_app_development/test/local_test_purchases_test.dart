import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/local_test_purchases.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;

// 4차 피드백 IC10 후속 (사용자 결정 2026-11-21): a build without the online
// settings levels up and buys cosmetics on this device, with the same price
// and conditions, and its save is marked as a test save.

void main() {
  late DevelopmentBalance config;
  late WorkshopController c;
  var gold = 0;
  late LocalTestPurchaseGateway gateway;
  setUp(() async {
    config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    gold = 0;
    gateway = LocalTestPurchaseGateway(gold: () => gold, setGold: (g) async {
      gold = g;
      return true;
    });
    c = WorkshopController(config, MemoryRepository(), purchaseGateway: gateway,
        now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.lifetime = BigInt.from(10000);
      c.state.buns = BigInt.from(5000);
    });
  });
  tearDown(() => c.dispose());

  test('스킬 레벨업이 서버 없이 같은 가격으로 되고, 저장은 시험용으로 표시된다', () async {
    expect(isLocalTestSave(c.state), isFalse);
    expect(await c.purchaseSkill(gateway, 'tap_1', quantity: 10), isTrue, reason: c.notice);
    expect(c.state.purchases.owned['tap_1'], 10);
    final price = (config.skill('tap_1'));
    expect(c.state.buns < BigInt.from(5000), isTrue, reason: '가격 $price만큼 붕어빵력이 빠짐');
    expect(c.state.purchases.journals.values.every((j) => j.settled), isTrue);
    expect(c.state.purchases.account, localTestAccount);
    expect(isLocalTestSave(c.state), isTrue);
  });

  test("'최대'(살 수 있는 만큼, 1·10·100이 아닌 개수)도 시험용 빌드에서 된다(4차 g13)", () async {
    final best = skillLevelUpQuote(config, 'tap_1', step: skillLevelUpMax, owned: 0,
        availableBuns: c.state.purchases.available(c.state.buns), availableGold: BigInt.zero)!;
    expect(best.quantity, isNot(anyOf(1, 10, 100)), reason: '${best.quantity}');
    expect(await c.purchaseSkill(gateway, 'tap_1', quantity: best.quantity), isTrue, reason: c.notice);
    expect(c.state.purchases.owned['tap_1'], best.quantity);
    expect(c.state.buns, BigInt.from(5000) - best.buns);
  });

  test('꾸미기는 시험용 황금을 쓰고, 모자라면 아무것도 빠지지 않는다', () async {
    // 4차 g7 prices (4차 병합): read the beanie's price from the settings.
    final price = config.section('cosmetic_purchase')['beanie'] as Map<String, dynamic>;
    final cost = BigInt.parse(price['buns'] as String), goldCost = price['gold'] as int;
    await c.command(() => c.state
      ..buns = cost * BigInt.two
      ..lifetime = cost * BigInt.two);
    final buns = c.state.buns;
    expect(await c.purchaseSkill(gateway, 'cosmetic:beanie'), isTrue);
    expect(c.ownsAvatar('beanie'), isFalse, reason: '황금 0이라 거절');
    expect(c.state.buns, buns, reason: '붕어빵력 그대로');
    expect(c.state.purchases.journals.values.every((j) => j.settled), isTrue, reason: '멈춘 거래 없음');
    gold = goldCost + 1;
    expect(await c.purchaseSkill(gateway, 'cosmetic:beanie'), isTrue, reason: c.notice);
    expect(c.ownsAvatar('beanie'), isTrue);
    expect(gold, 1, reason: '황금 $goldCost 사용');
    expect(c.state.buns, buns - cost);
  });

  test('조건(누적·레벨)은 서버가 없어도 똑같이 검사한다', () async {
    // An unlock production total far above this save's lifetime.
    final locked = config.section('skill_purchase')['entries'] as Map<String, dynamic>;
    final id = locked.entries.firstWhere((e) =>
        BigInt.parse((e.value as Map)['unlock_total'] as String) > BigInt.from(10000)).key;
    expect(await c.purchaseSkill(gateway, id), isFalse);
    expect(c.state.purchases.owned[id], isNull);
  });
}
