import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'workshop_controller_test.dart' show Repository;

/// 재료 타이쿤 A — 설정 `ingredients`, 규칙 `lib/pantry_rules.dart`, 가게 저장
/// schema 12 `pantry` (사용자 결정 2026-11-21).
Map<String, dynamic> _raw() =>
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;

const _hour = 3600000;
const _t0 = 1795000000000; // a fixed UTC ms

void main() {
  final config = DevelopmentBalance.fromJson(_raw());
  final c = PantryConfig.of(config);
  const owned = {'redbean'};
  const all = {'redbean', 'custard', 'cocoa'};

  group('설정', () {
    test('같은 설정이면 한 번만 읽고, 숫자는 설정 파일 그대로', () {
      expect(identical(PantryConfig.of(config), c), isTrue);
      expect(c.portionsPerTub, 100);
      expect(c.batchTubs, [1, 3, 5]);
      expect(c.buySteps, [1, 10, 100]);
      expect(c.expiryMs, 24 * _hour);
      expect(c.tapsPerPortion, 10);
      expect(c.autoMsPerPortion, 10000);
      expect(c.basic.keys, ['flour', 'milk', 'egg', 'sugar', 'salt', 'adzuki', 'cocoa_powder']);
      expect(c.premium.length, 4);
      expect(c.prepared.keys, ['batter', 'redbean', 'custard', 'cocoa']);
      expect(c.kind('custard').minigame, 'whisk');
    });

    test('가격 = R × 초(최저 1), R = 탭 힘 × 2 + 자동/초', () {
      final r = c.incomeRate(tapRate: BigInt.from(131), autoRate: BigInt.from(95));
      expect(r, BigInt.from(357));
      expect(c.basicPrice('flour', r), BigInt.from(1071));
      expect(c.basicPrice('salt', r), BigInt.from(357));
      expect(c.basicPrice('cocoa_powder', r), BigInt.from(1785));
      expect(c.basicCost('sugar', 10, r), BigInt.from(7140));
      expect(c.basicPrice('salt', BigInt.zero), BigInt.one, reason: '최저 가격');
      expect(c.basicPrice('flour', BigInt.two), BigInt.from(6), reason: 'Lv.1 R=2');
    });

    test('반죽 + 팥소 100인분 재료비 = 26 × R → 붕어빵 100개 수입(약 333 × R)의 약 8%', () {
      final r = BigInt.from(1000);
      BigInt tub(String kind) => c.kind(kind).recipe.entries
          .fold(BigInt.zero, (sum, e) => sum + c.basicCost(e.key, e.value, r));
      expect(tub('batter'), BigInt.from(15000));
      expect(tub('redbean'), BigInt.from(11000));
      expect(tub('custard'), BigInt.from(14000));
      expect(tub('cocoa'), BigInt.from(15000));
      // 1분에 탭 120번(12개) + 자동 6개 = 18개, 수입 60 × R → 1개 ≈ 3.33 × R.
      final per100 = r * BigInt.from(60) * BigInt.from(100) ~/ BigInt.from(18);
      final ratio = (tub('batter') + tub('redbean')) * BigInt.from(1000) ~/ per100;
      expect(ratio.toInt(), inInclusiveRange(70, 90));
    });

    test('보관 한도: Lv.1~9 10통, Lv.10~19 15통, Lv.20부터 20통', () {
      expect(c.stockLimitTubs(1), 10);
      expect(c.stockLimitTubs(9), 10);
      expect(c.stockLimitTubs(10), 15);
      expect(c.stockLimitTubs(19), 15);
      expect(c.stockLimitTubs(20), 20);
      expect(c.stockLimitTubs(50), 20);
    });

    test('잘못된 설정은 읽지 않는다', () {
      void bad(void Function(Map<String, dynamic> s) edit) {
        final raw = _raw();
        edit(raw['ingredients'] as Map<String, dynamic>);
        expect(() => DevelopmentBalance.fromJson(raw), throwsFormatException);
      }
      bad((s) => s['prepared']['batter']['recipe']['butter'] = 1);
      bad((s) => (s['prepared'] as Map).remove('cocoa'));
      bad((s) => s['prepared']['custard']['flavor'] = 'cocoa');
      bad((s) => s['premium']['items']['vanilla_bean']['prepared'] = 'redbean');
      bad((s) => s['stock_limit_tubs'][1]['tubs'] = 5);
      bad((s) => s['batch_tubs'] = [3, 1]);
      bad((s) => s['min_price_buns'] = '0');
      bad((s) => s['starting_stock']['tubs']['custard'] = 1);
      bad((s) => s['starting_stock']['tubs']['batter'] = 11);
      bad((s) => s['basic']['cocoa_powder']['requires_recipe'] = 'mint');
      bad((s) => s['filling_fallback_order'] = ['redbean', 'custard']);
      bad((s) => s['prepared']['batter']['minigame'] = 'quick');
    });
  });

  group('처음 재료', () {
    test('반죽 3통 + 팥소 3통 + 반죽 1통·팥소 1통 재료', () {
      final p = PantryState.starting(c, _t0);
      expect(p.usable(c, 'batter', _t0), 300);
      expect(p.usable(c, 'redbean', _t0), 300);
      expect(p.basic, {'flour': 2, 'milk': 1, 'egg': 1, 'sugar': 2, 'salt': 2, 'adzuki': 2});
      expect(p.gifts, {'start'});
      expect(p.canMake(c, 'batter', 1, 1, _t0, owned), isTrue);
      expect(p.canMake(c, 'redbean', 1, 1, _t0, owned), isTrue);
    });
  });

  group('만들기', () {
    test('재료를 줄이고 통을 늘림, 성공이면 1통당 덤 10인분', () {
      final p = PantryState.starting(c, _t0);
      final made = p.make(c, 'batter', 1, 1, _t0 + 1000, owned, success: true);
      expect(made.portions, 110);
      expect(made.bonus, 10);
      expect(p.usable(c, 'batter', _t0 + 1000), 410);
      expect(p.basic, {'sugar': 1, 'salt': 1, 'adzuki': 2});
      final plain = p.make(c, 'redbean', 1, 1, _t0 + 2000, owned);
      expect(plain.bonus, 0);
      expect(p.usable(c, 'redbean', _t0 + 2000), 400);
      expect(p.basic, isEmpty);
    });

    test('보관 한도를 넘게 만들 수 없고, 덤은 한도까지만', () {
      final p = PantryState.starting(c, _t0);
      for (final e in c.kind('batter').recipe.entries) {
        p.basic[e.key] = e.value * 10;
      }
      final made = p.make(c, 'batter', 5, 1, _t0, owned, success: true);
      expect(made.portions, 550);
      expect(p.usable(c, 'batter', _t0), 850);
      expect(p.makeBlocker(c, 'batter', 3, 1, _t0, owned), '반죽은 10통까지 보관할 수 있어요.');
      expect(p.makeBlocker(c, 'batter', 3, 10, _t0, owned), isNull, reason: 'Lv.10 15통');
      expect(() => p.make(c, 'batter', 3, 1, _t0, owned), throwsFormatException);
      // 895 + 100 = 995: the bonus stops at the limit (5 of 10).
      final near = PantryState()..lots.add(PantryLot('batter', false, _t0, 895));
      near.ledger['batter'] = PantryLedger(895);
      for (final e in c.kind('batter').recipe.entries) {
        near.basic[e.key] = e.value;
      }
      expect(near.make(c, 'batter', 1, 1, _t0 + 1, owned, success: true).bonus, 5);
      expect(near.usable(c, 'batter', _t0 + 1), 1000);
    });

    test('재료가 모자라거나 통 수·레시피가 틀리면 못 만든다', () {
      final p = PantryState.starting(c, _t0);
      expect(p.makeBlocker(c, 'batter', 3, 1, _t0, owned), '재료가 모자라요.');
      expect(p.makeBlocker(c, 'batter', 2, 1, _t0, owned), '만들 통 수를 골라 주세요.');
      expect(p.makeBlocker(c, 'custard', 1, 1, _t0, owned), '슈크림 레시피를 아직 얻지 못했어요.');
      expect(p.makeBlocker(c, 'cocoa', 1, 1, _t0, owned), '초코 레시피를 아직 얻지 못했어요.');
      final before = jsonEncode(p.toJson());
      expect(() => p.make(c, 'batter', 3, 1, _t0, owned), throwsFormatException);
      expect(jsonEncode(p.toJson()), before, reason: '실패하면 아무것도 줄지 않음');
    });

    test('특제: Lv.5부터, 특별한 재료 1통에 1개', () {
      final p = PantryState.starting(c, _t0);
      expect(p.makeBlocker(c, 'batter', 1, 4, _t0, owned, premium: true), '특제는 Lv.5부터 만들 수 있어요.');
      expect(p.makeBlocker(c, 'batter', 1, 5, _t0, owned, premium: true), '발효 버터가 모자라요.');
      expect(() => p.buyPremium(c, 'cultured_butter', 1, 4), throwsFormatException);
      p.buyPremium(c, 'cultured_butter', 1, 5);
      expect(p.premium['cultured_butter'], 2, reason: '황금 1 = 2개 묶음');
      final made = p.make(c, 'batter', 1, 5, _t0 + 5, owned, premium: true);
      expect(made.premium, isTrue);
      expect(p.premium['cultured_butter'], 1);
      expect(p.portions('batter', premium: true), 100);
    });
  });

  group('쓰기', () {
    test('탭 10번마다 1인분: 첫 탭에 꺼내고 남은 탭 수를 기억', () {
      final p = PantryState.starting(c, _t0);
      for (var i = 0; i < 10; i++) {
        expect(p.tap(c, 'redbean', _t0), isNotNull);
      }
      expect(p.usable(c, 'batter', _t0), 299);
      expect(p.usable(c, 'redbean', _t0), 299);
      expect(p.tapCredit, 0);
      expect(p.tap(c, 'redbean', _t0), isNotNull);
      expect(p.tapCredit, 9);
      expect(p.usable(c, 'batter', _t0), 298);
    });

    test('재료가 없으면 탭을 세지 않는다', () {
      final p = PantryState()..lots.add(PantryLot('batter', false, _t0, 1));
      p.ledger['batter'] = PantryLedger(1);
      expect(p.tap(c, 'redbean', _t0), isNull);
      expect(p.shortage(c, 'redbean', _t0), PantryShortage.filling);
      expect(PantryState().shortage(c, 'redbean', _t0), PantryShortage.batter);
    });

    test('자동 생산 10초마다 1인분, 재료가 떨어지면 그 뒤 시간은 생산 없음', () {
      final p = PantryState.starting(c, _t0);
      final run = p.runAuto(c, 'redbean', 25000, _t0);
      expect(run.fold(0, (n, s) => n + s.ms), 25000);
      expect(p.usable(c, 'redbean', _t0), 297);
      expect(p.autoCreditMs, 5000);
      final small = PantryState()..lots.addAll([PantryLot('batter', false, _t0, 1), PantryLot('redbean', false, _t0, 1)]);
      small.ledger..['batter'] = PantryLedger(1)..['redbean'] = PantryLedger(1);
      final covered = small.runAuto(c, 'redbean', 60000, _t0);
      expect(covered.fold(0, (n, s) => n + s.ms), 10000);
      expect(small.shortage(c, 'redbean', _t0), PantryShortage.batter);
    });

    test('특제 배율: 특제 하나 +50%, 둘 다 +100%', () {
      final p = PantryState()
        ..lots.addAll([PantryLot('batter', true, _t0, 1), PantryLot('redbean', true, _t0, 1),
          PantryLot('batter', false, _t0 + 1, 1), PantryLot('redbean', false, _t0 + 1, 1)]);
      p.ledger..['batter'] = PantryLedger(2)..['redbean'] = PantryLedger(2);
      // 묶음 B: 특제를 고르면 특제부터, 아니면 일반부터.
      final first = p.takePortion(c, 'redbean', _t0 + 2, premium: true)!;
      expect(p.bonusPermille(c, first), 2000);
      final second = p.takePortion(c, 'redbean', _t0 + 2, premium: true)!;
      expect(p.bonusPermille(c, second), 1000);
    });

    test('스페셜 틀: 1인분 꺼내고 결과 전 취소면 같은 통으로 돌려받음', () {
      final p = PantryState.starting(c, _t0);
      final use = p.takePortion(c, 'redbean', _t0 + 10)!;
      expect(p.usable(c, 'redbean', _t0 + 10), 299);
      p.refund(use);
      expect(p.usable(c, 'redbean', _t0 + 10), 300);
      expect(p.lots.length, 2);
      expect(p.ledger['redbean']!.used, 0);
      expect(PantryState.fromJson(jsonDecode(jsonEncode(p.toJson())), c).toJson(), p.toJson());
      expect(() => PantryState().refund(use), throwsFormatException);
    });

    test('대표 맛의 속이 떨어지면 팥소 → 슈크림 → 초코 크림 순으로, 반죽이 없으면 멈춤', () {
      final p = PantryState()
        ..lots.addAll([PantryLot('batter', false, _t0, 5), PantryLot('cocoa', false, _t0, 5)]);
      p.ledger..['batter'] = PantryLedger(5)..['cocoa'] = PantryLedger(5);
      expect(p.productionFlavor(c, 'redbean', all, _t0), 'cocoa');
      expect(p.productionFlavor(c, 'redbean', owned, _t0), isNull);
      expect(p.productionFlavor(c, 'cocoa', all, _t0), 'cocoa');
      expect(p.griddleFlavors(c, ['redbean', 'cocoa'], _t0), ['cocoa']);
      expect(fallbackNotice(c, 'redbean', 'custard'), '팥소가 떨어져 슈크림으로 바꿨어요');
      expect(fallbackNotice(c, 'custard', 'cocoa'), '슈크림이 떨어져 초코 크림으로 바꿨어요');
      expect(fallbackNotice(c, 'cocoa', 'redbean'), '초코 크림이 떨어져 팥소로 바꿨어요');
      expect(missingFillingText(c, 'redbean', _t0, p), '팥소가 없어요. 재료를 준비하세요');
      expect(missingFillingText(c, 'redbean', _t0, PantryState()), '반죽이 없어요. 재료를 준비하세요');
    });
  });

  group('24시간 지나면 버림', () {
    // 묶음 B (사용자 결정 2026-11-21): 처음 재료는 상하지 않고, 상하는 통을 먼저 씀.
    test('상하는 통을 오래된 것부터 먼저 쓰고, 지난 통은 쓰지 않으며 expire가 버리고 안내한다. 처음 재료는 상하지 않는다', () {
      final p = PantryState.starting(c, _t0);
      expect(p.lots.every((l) => l.keeps), isTrue);
      p.make(c, 'batter', 1, 1, _t0 + 2 * _hour, owned);
      p.make(c, 'redbean', 1, 1, _t0 + 3 * _hour, owned);
      final use = p.takePortion(c, 'redbean', _t0 + 4 * _hour)!;
      expect(use.batterMadeAtMs, _t0 + 2 * _hour, reason: '상하는 통부터');
      expect(use.fillingMadeAtMs, _t0 + 3 * _hour);
      final late = _t0 + 27 * _hour;
      expect(p.usable(c, 'batter', late), 300, reason: '만든 통은 24시간이 지나 못 씀, 처음 재료 3통은 그대로');
      expect(p.usable(c, 'redbean', late), 300);
      expect(p.takePortion(c, 'redbean', late)!.batterMadeAtMs, pantryKeepMs);
      final gone = p.expire(c, late);
      expect(gone.length, 2);
      expect(expiredNotice(c, gone), '만든 지 24시간이 지난 반죽 99인분, 팥소 99인분을 버렸어요.');
      expect(p.portions('batter'), 299);
      expect(p.ledger['batter']!.expired, 99);
      expect(p.expire(c, late + 365 * 24 * _hour), isEmpty, reason: '처음 재료는 1년 뒤에도');
      expect(p.basic['flour'], isNull, reason: '처음 재료 1벌을 다 씀');
      expect(PantryState.fromJson(jsonDecode(jsonEncode(p.toJson())), c).toJson(), p.toJson());
      expect(expiredNotice(c, const []), isNull);
      expect(expiredNotice(c, [PantryLot('redbean', true, 0, 300)]), '만든 지 24시간이 지난 특제 팥소 3통을 버렸어요.');
    });
  });

  group('특제 고르기 (묶음 B)', () {
    test('특제를 고르면 특제 반죽·속을 먼저, 아니면 일반을 먼저 쓰고 없으면 다른 쪽으로 이어 쓴다', () {
      final p = PantryState.starting(c, _t0)
        ..buyPremium(c, 'cultured_butter', 1, 5)
        ..buyPremium(c, 'fresh_adzuki', 1, 5);
      p.make(c, 'redbean', 1, 5, _t0, owned, premium: true);
      final plain = p.takePortion(c, 'redbean', _t0)!;
      expect((plain.batterPremium, plain.fillingPremium), (false, false));
      final premium = p.takePortion(c, 'redbean', _t0, premium: true)!;
      expect((premium.batterPremium, premium.fillingPremium), (false, true), reason: '특제 반죽이 없으면 일반 반죽');
      expect(p.bonusPermille(c, premium), 1500);
      final tap = p.tap(c, 'redbean', _t0, premium: true)!;
      expect(tap.fillingPremium, isTrue);
      expect(p.runAuto(c, 'redbean', 10000, _t0, premium: true).single.bonusPermille, 1500);
    });
  });

  group('사기', () {
    test('기본 재료: 보관 99개, 코코아 가루는 초코 레시피 뒤', () {
      final p = PantryState();
      expect(p.basicVisible(c, 'cocoa_powder', owned), isFalse);
      expect(() => p.buyBasic(c, 'cocoa_powder', 1, owned),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', '코코아 가루는 초코 레시피를 얻으면 살 수 있어요.')));
      p.buyBasic(c, 'cocoa_powder', 10, all);
      p.buyBasic(c, 'flour', 99, owned);
      expect(p.basicRoom(c, 'flour'), 0);
      expect(() => p.buyBasic(c, 'flour', 1, owned),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', '밀가루는 99개까지 보관할 수 있어요.')));
      expect(() => p.buyBasic(c, 'flour', 0, owned), throwsFormatException);
    });

    test('모자란 재료 한 번에 사기', () {
      final p = PantryState.starting(c, _t0);
      expect(p.shortfall(c, 'batter', 1), isEmpty);
      expect(p.shortfall(c, 'batter', 3), {'flour': 4, 'milk': 2, 'egg': 2, 'sugar': 1, 'salt': 1});
      final r = BigInt.from(10);
      expect(p.shortfallCost(c, 'batter', 3, r), BigInt.from(4 * 30 + 2 * 30 + 2 * 30 + 20 + 10));
      expect(p.buyShortfall(c, 'batter', 3, r, owned), BigInt.from(270));
      expect(p.canMake(c, 'batter', 3, 1, _t0, owned), isTrue);
      expect(() => p.buyShortfall(c, 'batter', 3, r, owned), throwsFormatException);
    });
  });

  group('선물·꾸러미', () {
    test('새 레시피: 그 속 1통 + 1통분 재료, 한 번만', () {
      final p = PantryState.starting(c, _t0);
      expect(p.grantRecipeGift(c, 'custard', _t0), isTrue);
      expect(p.grantRecipeGift(c, 'custard', _t0), isFalse);
      expect(p.usable(c, 'custard', _t0), 100);
      expect(p.basic['milk'], 1 + 2);
      expect(p.gifts, {'start', 'recipe:custard'});
    });

    test('빈털터리 방지: 다 떨어지고 살 수 없을 때 하루 3번', () {
      final p = PantryState();
      final r = BigInt.from(10);
      const day = '2026-11-21';
      expect(p.rescueAvailable(c, day, _t0, owned, BigInt.zero, r), isTrue);
      expect(p.rescueAvailable(c, day, _t0, owned, BigInt.from(1000000), r), isFalse, reason: '살 수 있음');
      p.grantRescue(c, day);
      expect(p.canMake(c, 'batter', 1, 1, _t0, owned), isTrue);
      expect(p.rescueAvailable(c, day, _t0, owned, BigInt.zero, r), isFalse, reason: '가진 재료로 만들 수 있음');
      p.basic.clear();
      p.grantRescue(c, day);
      p.basic.clear();
      p.grantRescue(c, day);
      p.basic.clear();
      expect(p.rescueAvailable(c, day, _t0, owned, BigInt.zero, r), isFalse, reason: '하루 3번');
      expect(() => p.grantRescue(c, day), throwsFormatException);
      expect(p.rescueAvailable(c, '2026-11-22', _t0, owned, BigInt.zero, r), isTrue);
    });
  });

  group('저장', () {
    test('왕복과 잘못된 기록 거절', () {
      final p = PantryState.starting(c, _t0)..tap(c, 'redbean', _t0)..runAuto(c, 'redbean', 3000, _t0);
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(PantryState.fromJson(json, c).toJson(), p.toJson());
      void bad(void Function(Map<String, dynamic> j) edit) {
        final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        edit(copy);
        expect(() => PantryState.fromJson(copy, c), throwsFormatException);
      }
      bad((j) => j['basic']['butter'] = 1);
      bad((j) => j['basic']['flour'] = -1);
      bad((j) => (j['lots'] as List).first['portions'] = 500);
      bad((j) => (j['lots'] as List).first['kind'] = 'mint');
      bad((j) => j['ledger']['batter'][1] = 0);
      bad((j) => j['tapPortion'] = null);
      bad((j) => j['autoCreditMs'] = 0);
      bad((j) => j['gifts'] = ['start', 'start']);
      bad((j) => j['gifts'] = ['recipe:batter']);
      bad((j) => j['rescueCount'] = 1);
      bad((j) => j['extra'] = 1);
    });

    test('설정이 바뀌어 남은 탭 수가 한도를 넘으면 줄여 읽음', () {
      final raw = _raw();
      raw['ingredients']['consume']['taps_per_portion'] = 5;
      final small = PantryConfig.of(DevelopmentBalance.fromJson(raw));
      final p = PantryState.starting(c, _t0)..tap(c, 'redbean', _t0);
      expect(p.tapCredit, 9);
      final read = PantryState.fromJson(jsonDecode(jsonEncode(p.toJson())), small);
      expect(read.tapCredit, 4);
    });
  });

  group('가게 저장 schema 12', () {
    final start = DateTime.utc(2026, 11, 21, 3);
    test('새 가게는 처음 재료로, schema 12에 pantry가 함께 저장된다', () async {
      final repository = Repository();
      final shop = WorkshopController(config, repository, now: () => start, random: Random(3));
      addTearDown(shop.dispose);
      await shop.initialize();
      final saved = repository.stored!;
      expect(saved['schema'], workshopSchema);
      expect(pantrySchema, 12, reason: '재료는 schema 12부터 저장');
      final pantry = PantryState.fromJson(saved['pantry'], c);
      expect(pantry.usable(c, 'batter', start.millisecondsSinceEpoch), 300);
      expect(pantry.lots.first.madeAtMs, pantryKeepMs, reason: '처음 재료는 상하지 않음 (묶음 B)');
      expect(shop.pantryRate, c.incomeRate(tapRate: shop.tapRate, autoRate: shop.autoRate));
    });

    test('schema 11 저장은 처음 열 때 한 번 처음 재료를 받고(지금 만든 것으로), 진행은 그대로', () async {
      final repository = Repository();
      final shop = WorkshopController(config, repository, now: () => start, random: Random(4));
      addTearDown(shop.dispose);
      await shop.initialize();
      await shop.command(() { shop.state.buns = BigInt.from(77); shop.state.lifetime = BigInt.from(77); });
      final old = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>
        ..['schema'] = 11..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales');
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(repository.stored!)..['schema'] = 11, config),
          throwsFormatException, reason: '11에 재료 기록');
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(repository.stored!)..remove('pantry'), config),
          throwsFormatException, reason: '12에 재료 기록 없음');
      final later = start.add(const Duration(days: 3));
      final reopenedRepository = Repository()..stored = old;
      final reopened = WorkshopController(config, reopenedRepository, now: () => later, random: Random(5));
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.state.buns, BigInt.from(77), reason: '경제 초기화 없음');
      expect(reopened.notice, isNot(economyResetNotice));
      final pantry = reopened.state.pantry;
      expect(pantry.usable(c, 'batter', later.millisecondsSinceEpoch), 300, reason: '처음 재료는 상하지 않음');
      expect(pantry.gifts, {'start'});
      expect(reopenedRepository.stored!['schema'], workshopSchema);
    });

    test('schema 10 이하는 경제 초기화 새 가게로, 처음 재료를 받는다', () async {
      final repository = Repository();
      final shop = WorkshopController(config, repository, now: () => start, random: Random(6));
      addTearDown(shop.dispose);
      await shop.initialize();
      final old = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>
        ..['schema'] = 10..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales');
      final reopened = WorkshopController(config, Repository()..stored = old, now: () => start, random: Random(7));
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.notice, economyResetNotice);
      expect(reopened.state.pantry.usable(c, 'redbean', start.millisecondsSinceEpoch), 300);
    });

    test('얻지 않은 맛의 속은 거절, 명령이 실패하면 재료도 되돌린다', () async {
      final repository = Repository();
      final shop = WorkshopController(config, repository, now: () => start, random: Random(8));
      addTearDown(shop.dispose);
      await shop.initialize();
      final forged = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>;
      (forged['pantry']['lots'] as List).add({'kind': 'custard', 'premium': false, 'madeAtMs': 1, 'portions': 5});
      forged['pantry']['ledger']['custard'] = [5, 0, 0];
      expect(() => WorkshopState.fromJson(forged, config), throwsFormatException);
      final before = jsonEncode(shop.state.pantry.toJson());
      expect(await shop.command(() {
        shop.state.pantry.tap(c, 'redbean', start.millisecondsSinceEpoch);
        throw const FormatException('실패');
      }), isFalse);
      expect(jsonEncode(shop.state.pantry.toJson()), before);
      expect(await shop.command(() => shop.state.pantry.tap(c, 'redbean', start.millisecondsSinceEpoch)), isTrue);
      expect(PantryState.fromJson(repository.stored!['pantry'], c).tapCredit, 9);
    });
  });
}
