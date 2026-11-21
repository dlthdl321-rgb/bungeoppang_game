import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart' show CookingDirection;
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'usage_stats_test.dart' show RecordingSink;
import 'workshop_controller_test.dart' show Gateway, Repository;

/// 재료 타이쿤 B — 생산 연결: 탭 10번·자동 10초·스페셜 틀·6구가 반죽 1인분 +
/// 속 1인분을 쓰고, 떨어지면 멈춤·안내, 특제 선택과 보너스, 맛 바꾸기,
/// 24시간 버림, 사용 통계 `ingredient_out` (사용자 결정 2026-11-21).
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final c = PantryConfig.of(config);
  var clock = DateTime.utc(2026, 11, 21, 3);
  var mono = 0;
  late RecordingSink sink;
  int at() => clock.millisecondsSinceEpoch;

  Future<WorkshopController> open([Repository? repository]) async {
    clock = DateTime.utc(2026, 11, 21, 3);
    mono = 0;
    sink = RecordingSink();
    final shop = WorkshopController(config, repository ?? Repository(), now: () => clock, random: Random(11),
        monotonicMs: () => mono, usage: UsageStats(sink, now: () => clock));
    addTearDown(shop.dispose);
    await shop.initialize();
    return shop;
  }

  /// Leaves [batter] portions of batter and [filling] of 팥소 (used up, as
  /// the ledger counts it), taking the oldest tubs.
  Future<void> drainTo(WorkshopController shop, {int batter = 300, int filling = 300}) async {
    expect(await shop.command(() {
      final p = shop.state.pantry;
      for (final (kind, left) in [('batter', batter), ('redbean', filling)]) {
        var extra = p.portions(kind) - left;
        for (final lot in p.lots.where((l) => l.kind == kind)) {
          final take = min(extra, lot.portions);
          lot.portions -= take;
          p.ledger[kind]!.used += take;
          extra -= take;
        }
        p.lots.removeWhere((l) => l.portions == 0);
      }
    }), isTrue, reason: shop.notice);
  }

  group('큰 붕어빵(요정) 탭', () {
    test('탭 10번에 1인분, 떨어지면 탭을 세지 않고 안내는 한 번, 사용 통계는 하루 한 번', () async {
      final shop = await open();
      expect(await shop.openBusiness(), isTrue);
      await drainTo(shop, batter: 1, filling: 1);
      final taps = shop.state.taps, buns = shop.state.buns;
      for (var i = 0; i < 10; i++) {
        expect(shop.tap(), shop.tapRate);
      }
      expect(shop.state.taps, taps + 10);
      expect(shop.state.buns, buns + shop.tapRate * BigInt.from(10));
      expect(shop.state.pantry.usable(c, 'batter', at()), 0);
      expect(shop.state.pantry.tapCredit, 0);
      expect(shop.tap(), isNull, reason: '재료가 없으면 탭이 아님');
      expect(shop.state.taps, taps + 10);
      expect(shop.state.buns, buns + shop.tapRate * BigInt.from(10));
      expect(shop.notice, pantryEmptyText);
      shop.notice = null;
      expect(shop.tap(), isNull);
      expect(shop.notice, isNull, reason: '안내는 한 번');
      await pumpEventQueue();
      expect(sink.lines.where((l) => l.startsWith('ingredient_out')), ['ingredient_out {what: batter}']);
      expect(shop.productionShortage, PantryShortage.batter);
    });

    test('남은 탭 수와 꺼내 둔 1인분은 저장되어 다시 열어도 이어 쓴다', () async {
      final repository = Repository();
      final shop = await open(repository);
      expect(await shop.openBusiness(), isTrue);
      for (var i = 0; i < 3; i++) {
        shop.tap();
      }
      expect(await shop.command(() {}), isTrue);
      final saved = PantryState.fromJson(repository.stored!['pantry'], c);
      expect(saved.tapCredit, 7);
      expect(saved.usable(c, 'batter', at()), 299);
    });
  });

  group('자동 생산', () {
    Future<WorkshopController> withAuto() async {
      final shop = await open();
      expect(await shop.command(() {
        shop.state.buns = BigInt.from(1000000);
        shop.state.lifetime = BigInt.from(1000000);
      }), isTrue);
      expect(await shop.purchaseSkill(Gateway(), 'auto_1'), isTrue, reason: shop.notice);
      expect(shop.autoRate, greaterThan(BigInt.zero));
      expect(await shop.openBusiness(), isTrue);
      return shop;
    }

    test('10초마다 1인분, 떨어진 시간은 만들지 않고 HUD 초당 옆에 멈춤', () async {
      final shop = await withAuto();
      await drainTo(shop, batter: 1, filling: 1);
      expect(shop.autoStopped, isFalse);
      final buns = shop.state.buns;
      mono += 10000;
      expect(await shop.command(() {}), isTrue);
      expect(shop.state.buns, buns + shop.autoRate * BigInt.from(10));
      expect(shop.state.pantry.usable(c, 'batter', at()), 0);
      expect(shop.autoStopped, isTrue);
      mono += 30000;
      expect(await shop.command(() {}), isTrue);
      expect(shop.state.buns, buns + shop.autoRate * BigInt.from(10), reason: '재료가 없는 30초는 생산 없음');
      expect(shop.notice, isNull, reason: '자동 생산은 안내 대신 HUD 멈춤');
      await pumpEventQueue();
      expect(sink.lines.where((l) => l.startsWith('ingredient_out')), ['ingredient_out {what: batter}']);
    });

    test('앱을 닫아 둔 동안(부재 정산)은 재료를 쓰지 않는다', () async {
      final shop = await withAuto();
      final before = shop.state.pantry.usable(c, 'batter', at());
      final buns = shop.state.buns;
      await shop.setForeground(false);
      clock = clock.add(const Duration(hours: 2));
      await shop.setForeground(true);
      expect(shop.state.buns, greaterThan(buns), reason: '부재 정산은 지금처럼');
      expect(shop.state.pantry.usable(c, 'batter', at()), before);
    });
  });

  group('특제 선택과 맛 바꾸기', () {
    Future<void> makePremium(WorkshopController shop) async {
      expect(await shop.command(() {
        final p = shop.state.pantry;
        p.buyPremium(c, 'cultured_butter', 1, 5);
        p.buyPremium(c, 'fresh_adzuki', 1, 5);
        p.make(c, 'batter', 1, 5, at(), shop.state.recipes, premium: true);
        p.make(c, 'redbean', 1, 5, at(), shop.state.recipes, premium: true);
      }), isTrue, reason: shop.notice);
    }

    // 4차 병합 3 사용자 결정: 특제 덤은 손님 판매 대금에만 — 탭·자동은 배율
    // 없이 일반 재료를 쓰고, 스페셜 틀·6구가 특제를 먼저 씀.
    test("특제 팥을 골라도 탭은 배율 없이 일반 재료, 특제가 떨어지면 일반으로 바꾸고 안내", () async {
      final shop = await open();
      expect(shop.premiumFlavors, isEmpty);
      expect(await shop.selectFlavor('redbean', premium: true), isFalse);
      expect(shop.notice, '특제 팥소가 없어요. 재료를 준비하세요');
      await makePremium(shop);
      expect(shop.premiumFlavors, {'redbean'});
      expect(await shop.selectFlavor('redbean', premium: true), isTrue);
      expect(shop.state.selectedPremium, isTrue);
      expect(await shop.openBusiness(), isTrue);
      expect(shop.tap(), shop.tapRate, reason: '탭에는 특제 덤이 없음');
      expect(shop.state.pantry.portions('redbean', premium: true), 100, reason: '탭은 특제를 아낌');
      expect(shop.state.pantry.portions('batter', premium: true), 100);
      // The 특제 filling runs out (used by the mold or the six cells).
      expect(await shop.command(() {
        while (shop.state.pantry.portions('redbean', premium: true) > 0) {
          shop.state.pantry.takePortion(c, 'redbean', at(), premium: true);
        }
      }), isTrue);
      shop.notice = null;
      for (var i = 0; i < 9; i++) {
        expect(shop.tap(), shop.tapRate);
      }
      expect(shop.notice, '특제 팥소가 떨어져 팥소로 바꿨어요');
      expect(shop.state.selectedPremium, isFalse);
      expect(WorkshopState.fromJson(shop.state.toJson(), config).selectedPremium, isFalse);
    });

    test('특제 팥을 고르면 스페셜 틀이 특제 반죽·속을 먼저 쓰고, 그 붕어빵을 팔면 대금이 2배', () async {
      final shop = await open();
      await makePremium(shop);
      expect(await shop.selectFlavor('redbean', premium: true), isTrue);
      expect(await shop.startPractice(), isTrue);
      final use = shop.state.sessionPortion!;
      expect((use.batterPremium, use.fillingPremium), (true, true));
      expect(shop.state.pantry.bonusPermille(c, use), 2000);
      expect(shop.state.pantry.portions('redbean', premium: true), 99);
      // 일반 팥이면 특제를 꺼내지 않음.
      expect(await shop.cookingCommand(shop.state.session!.cancel()), isTrue);
      expect(await shop.selectFlavor('redbean'), isTrue);
      expect(await shop.startPractice(), isTrue);
      expect(shop.state.sessionPortion!.fillingPremium, isFalse);
      expect(shop.state.sessionPortion!.batterPremium, isFalse);
    });

    test('일반 팥이면 일반 반죽·속을 먼저 쓴다(특제는 아껴 둠)', () async {
      final shop = await open();
      await makePremium(shop);
      expect(await shop.openBusiness(), isTrue);
      expect(shop.tap(), shop.tapRate);
      expect(shop.state.pantry.portions('redbean', premium: true), 100);
    });

    test('일반 팥을 골랐는데 팥소가 떨어지면 같은 맛 특제 대신 다른 맛 일반 속으로 바꾼다', () async {
      final shop = await open();
      await makePremium(shop);
      expect(await shop.command(() {
        shop.state.recipes.add('custard');
        shop.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: shop.difficulty('custard'));
        shop.state.pantry.grantRecipeGift(c, 'custard', at());
        final p = shop.state.pantry;
        for (final lot in p.lots.where((l) => l.kind == 'redbean' && !l.premium)) {
          p.ledger['redbean']!.used += lot.portions;
          lot.portions = 0;
        }
        p.lots.removeWhere((l) => l.portions == 0);
      }), isTrue);
      expect(shop.state.pantry.premiumLeft(c, 'redbean', at()), 100);
      expect(await shop.openBusiness(), isTrue);
      shop.notice = null;
      expect(shop.tap(), shop.tapRate);
      expect(shop.notice, '팥소가 떨어져 슈크림으로 바꿨어요');
      expect(shop.state.selectedFlavor, 'custard');
      expect(shop.state.selectedPremium, isFalse);
      expect(shop.state.pantry.premiumLeft(c, 'redbean', at()), 100, reason: '특제 팥소는 그대로');
      // 스페셜 틀도 일반 팥이면 특제 팥소를 쓰지 않음.
      expect(await shop.closeBusiness(), isTrue);
      expect(await shop.selectFlavor('redbean'), isTrue);
      expect(await shop.startPractice(), isFalse);
      expect(shop.notice, '팥소가 없어요. 재료를 준비하세요');
    });

    test('영업 중에도 맛을 바꿀 수 있고, 틀에서 굽는 붕어빵은 제 맛과 꺼낸 1인분을 지킨다', () async {
      final shop = await open();
      expect(await shop.command(() {
        shop.state.recipes.add('custard');
        shop.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: shop.difficulty('custard'));
        shop.state.pantry.grantRecipeGift(c, 'custard', at());
      }), isTrue);
      expect(await shop.startPractice(), isTrue);
      final portion = shop.state.sessionPortion!;
      expect(await shop.selectFlavor('custard'), isFalse, reason: '영업 준비 중 굽는 동안은 못 바꿈');
      expect(await shop.cookingCommand(shop.state.session!.cancel()), isTrue);
      expect(await shop.openBusiness(), isTrue);
      expect(await shop.selectFlavor('custard'), isTrue, reason: '영업 중에는 바꿈');
      expect(shop.tap(), shop.tapRate);
      expect(shop.state.pantry.tapPortion?.flavor ?? 'custard', 'custard');
      expect(portion.flavor, 'redbean');
      // An order's bake in the mold during business: the flavor still changes,
      // the bake keeps its own flavor and portion, and the save reads back.
      expect(await shop.command(() {
        shop.state.session = CookingSession.start(id: 'order-bake', flavor: 'redbean', practice: false,
            fillingSequence: const [CookingDirection.left, CookingDirection.right]);
        shop.state.sessionPortion = shop.state.pantry.takePortion(c, 'redbean', at());
      }), isTrue);
      expect(await shop.selectFlavor('redbean'), isTrue);
      expect(await shop.selectFlavor('custard'), isTrue);
      expect(shop.state.session!.flavor, 'redbean');
      expect(shop.state.sessionPortion!.flavor, 'redbean');
      final read = WorkshopState.fromJson(shop.state.toJson(), config);
      expect((read.selectedFlavor, read.session!.flavor), ('custard', 'redbean'));
    });

    test('대표 맛의 속이 떨어지면 남은 맛으로 바꾸고 안내, 모든 속이 떨어지면 멈춤', () async {
      final shop = await open();
      expect(await shop.command(() {
        shop.state.recipes.add('custard');
        shop.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: shop.difficulty('custard'));
        shop.state.pantry.grantRecipeGift(c, 'custard', at());
      }), isTrue);
      await drainTo(shop, batter: 300, filling: 0);
      expect(await shop.openBusiness(), isTrue);
      shop.notice = null;
      expect(shop.tap(), shop.tapRate);
      expect(shop.notice, '팥소가 떨어져 슈크림으로 바꿨어요');
      expect(shop.state.selectedFlavor, 'custard');
      expect(shop.state.pantry.usable(c, 'custard', at()), 99);
    });
  });

  group('스페셜 붕어빵 틀', () {
    test('제작 시작에 1인분, 결과 전 취소하면 돌려받고, 꺼낸 1인분은 저장된다', () async {
      final repository = Repository();
      final shop = await open(repository);
      expect(await shop.startPractice(), isTrue);
      expect(shop.state.pantry.usable(c, 'batter', at()), 299);
      expect(shop.state.pantry.usable(c, 'redbean', at()), 299);
      final saved = WorkshopState.fromJson(repository.stored!, config);
      expect(saved.sessionPortion?.flavor, 'redbean');
      expect(await shop.cookingCommand(shop.state.session!.cancel()), isTrue);
      expect(shop.state.session, isNull);
      expect(shop.state.sessionPortion, isNull);
      expect(shop.state.pantry.usable(c, 'batter', at()), 300);
      expect(shop.state.pantry.usable(c, 'redbean', at()), 300);
      expect(shop.state.pantry.ledger['redbean']!.used, 0);
    });

    test('속이 없으면 시작하지 않고 안내', () async {
      final shop = await open();
      await drainTo(shop, batter: 300, filling: 0);
      expect(await shop.startPractice(), isFalse);
      expect(shop.notice, '팥소가 없어요. 재료를 준비하세요');
      expect(shop.state.session, isNull);
    });
  });

  group('숙련된 붕어빵 6구', () {
    Future<WorkshopController> griddleShop() async {
      final shop = await open();
      expect(await shop.openBusiness(), isTrue);
      final rule = config.mastery(0);
      final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
      expect(await shop.command(() {
        var mastery = shop.state.mastery;
        for (var i = 0; i < count; i++) {
          mastery = mastery.record(MasteryResult(id: 'practice-$i', flavor: 'redbean', variant: i < 5 ? i : 2,
              completed: true, practice: true, techniquePassed: i >= 5));
        }
        shop.state.mastery = mastery;
        shop.state.masteryAward = {'revision': config.revision, 'resultId': 'practice-0',
          'practiceRequired': DevelopmentBalance.integer(rule, 'practice_required'),
          'techniqueRequired': DevelopmentBalance.integer(rule, 'technique_passes_required')};
      }), isTrue);
      return shop;
    }

    test('칸 하나에 1인분, 속이 없으면 넣지 않고 안내', () async {
      final shop = await griddleShop();
      expect(await shop.startCell(0), isTrue);
      expect(shop.state.pantry.usable(c, 'redbean', at()), 299);
      await drainTo(shop, batter: 299, filling: 0);
      expect(await shop.startCell(1), isFalse);
      expect(shop.notice, '팥소가 없어요. 재료를 준비하세요');
      expect(shop.state.grid.cells[1].cooking, isFalse);
    });

    test("특제 팥을 고르면 6구 칸도 특제를 먼저 쓰고, 그 칸의 붕어빵에 특제 배율이 붙는다", () async {
      final shop = await griddleShop();
      expect(await shop.command(() {
        final p = shop.state.pantry;
        p.buyPremium(c, 'cultured_butter', 1, 5);
        p.buyPremium(c, 'fresh_adzuki', 1, 5);
        p.make(c, 'redbean', 1, 5, at(), shop.state.recipes, premium: true);
      }), isTrue, reason: shop.notice);
      expect(await shop.selectFlavor('redbean', premium: true), isTrue);
      expect(await shop.startCell(0), isTrue);
      expect(shop.state.grid.cells[0].bonusPermille, 1500, reason: '특제 팥소 + 일반 반죽(특제 반죽 없음)');
      expect(shop.state.pantry.premiumLeft(c, 'redbean', at()), 99);
      final read = WorkshopState.fromJson(shop.state.toJson(), config);
      expect(read.grid.cells[0].bonusPermille, 1500);
      final harvest = shop.state.grid.advanceActive(600000).harvest(0, config, businessIndex: 1);
      expect(harvest.product?.bonusPermille ?? 1500, 1500);
      expect(await shop.selectFlavor('redbean'), isTrue);
      expect(await shop.startCell(1), isTrue);
      expect(shop.state.grid.cells[1].bonusPermille, 1000, reason: '일반 팥이면 특제를 쓰지 않음');
    });
  });

  group('24시간', () {
    test('만든 통은 24시간 뒤 명령마다 버리고 안내, 처음 재료는 상하지 않는다', () async {
      final shop = await open();
      expect(await shop.command(() => shop.state.pantry.make(c, 'batter', 1, 1, at(), shop.state.recipes)), isTrue);
      expect(shop.state.pantry.usable(c, 'batter', at()), 400);
      clock = clock.add(const Duration(hours: 24));
      expect(await shop.command(() {}), isTrue);
      // 4차 병합 3: E's centre notice (`pantryNews`), not the notice line.
      expect(shop.takePantryNews(), ['만든 지 24시간이 지난 반죽 1통을 버렸어요.']);
      expect(shop.state.pantry.usable(c, 'batter', at()), 300, reason: '처음 재료 3통은 그대로');
      clock = clock.add(const Duration(days: 30));
      expect(await shop.command(() {}), isTrue);
      expect(shop.state.pantry.usable(c, 'redbean', at()), 300);
    });

    test('상하는 통을 먼저 쓰고 처음 재료는 나중에 쓴다', () async {
      final shop = await open();
      expect(await shop.command(() => shop.state.pantry.make(c, 'batter', 1, 1, at(), shop.state.recipes)), isTrue);
      final use = shop.state.pantry.takePortion(c, 'redbean', at())!;
      expect(use.batterMadeAtMs, at());
      expect(use.fillingMadeAtMs, pantryKeepMs);
    });
  });
}
