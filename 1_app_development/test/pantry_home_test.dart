import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/pantry_home.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/ui/center_toast.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_guide.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'usage_stats_test.dart' show RecordingSink;
import 'workshop_controller_test.dart' show Repository;
import 'widget_test.dart' show mountGame;

/// 재료 타이쿤 E — 홈 재료 표시·'재료 준비' 버튼·떨어짐 말풍선·24시간 안내,
/// 처음 재료(상하지 않음)·레시피 선물·빈털터리 꾸러미, Lv.2 소개 카드와 안내.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final p = PantryConfig.of(config);
  // 레시피 미션의 판매 수만 0으로 (판매 원장을 만들지 않고 레시피를 받음).
  final recipeConfig = DevelopmentBalance.fromJson((jsonDecode(File('config/development_balance.json').readAsStringSync())
      as Map<String, dynamic>)..['additional_recipe_acquisition_tiers'] = [
        for (final t in (jsonDecode(File('config/development_balance.json').readAsStringSync())
            as Map<String, dynamic>)['additional_recipe_acquisition_tiers'] as List) {...t as Map<String, dynamic>, 'mission_sales': 0}]);

  /// Throws away every tub of [kind] (as used), keeping the ledger right.
  void drain(PantryState pantry, String kind) {
    for (final lot in pantry.lots.where((l) => l.kind == kind)) {
      pantry.ledger[kind]!.used += lot.portions;
    }
    pantry.lots.removeWhere((l) => l.kind == kind);
  }

  var clock = DateTime.utc(2026, 11, 21, 3);
  Future<WorkshopController> open({UsageStats? usage}) async {
    clock = DateTime.utc(2026, 11, 21, 3);
    final c = WorkshopController(config, MemoryRepository(), now: () => clock, usage: usage);
    await c.initialize();
    return c;
  }
  Future<bool> grown(WorkshopController c, int level, {Iterable<String> seen = const []}) => c.command(() {
        c.state.tutorial = 'done';
        c.state.level = level;
        c.state.claimedLevels..clear()..addAll([for (var n = 2; n <= level; n++) n]);
        c.state.featureIntros.addAll(seen);
      });

  group('홈 표시 규칙', () {
    test('통은 소수 첫째 자리까지 올려서, 0이면 0통', () {
      expect(pantryTubsShort(p, 300), '3통');
      expect(pantryTubsShort(p, 137), '1.4통');
      expect(pantryTubsShort(p, 1), '0.1통');
      expect(pantryTubsShort(p, 0), '0통');
    });
    test('20% 아래 주황, 0 빨강 (Lv.1 보관 10통)', () {
      final pantry = PantryState.starting(p, 0);
      expect(pantryStockLevel(p, pantry, 'batter', 1, 1), PantryStockLevel.ok);
      drain(pantry, 'batter');
      expect(pantryStockLevel(p, pantry, 'batter', 1, 1), PantryStockLevel.out);
      pantry.basic.addAll({'flour': 2, 'milk': 1, 'egg': 1, 'sugar': 1, 'salt': 1});
      pantry.make(p, 'batter', 1, 1, 1000, {'redbean'});
      expect(pantryStockLevel(p, pantry, 'batter', 1, 1000), PantryStockLevel.low, reason: '1통 < 2통');
    });
    test('문구', () {
      expect(recipeGiftNotice(p, 'custard'), '슈크림 레시피 선물로 슈크림 1통과 1통 더 만들 재료를 받았어요.');
      expect(recipeGiftNotice(p, 'cocoa'), '초코 레시피 선물로 초코 크림 1통과 1통 더 만들 재료를 받았어요.');
      expect(pantryOutTitle(p, PantryShortage.batter, 'redbean'), '반죽이 떨어졌어요');
      expect(pantryOutTitle(p, PantryShortage.filling, 'redbean'), '팥소가 떨어졌어요');
      expect(pantryOutTitle(p, PantryShortage.filling, 'cocoa'), '초코 크림이 떨어졌어요');
      expect(rescueNotice(p, 1), endsWith('(오늘 1/3)'));
    });
  });

  group('컨트롤러', () {
    test('새 가게의 처음 재료는 하루가 지나도 상하지 않고, 만든 통은 24시간 뒤 버리며 안내한다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await c.command(() {
        c.state.pantry.basic.addAll({'flour': 2, 'milk': 1, 'egg': 1, 'sugar': 1, 'salt': 1});
        c.state.pantry.make(p, 'batter', 1, 1, clock.millisecondsSinceEpoch, c.state.recipes);
      }), isTrue);
      c.takePantryNews();
      clock = clock.add(const Duration(hours: 24));
      expect(await c.command(() {}), isTrue);
      expect(c.takePantryNews(), ['만든 지 24시간이 지난 반죽 1통을 버렸어요.']);
      expect(c.state.pantry.usable(p, 'batter', clock.millisecondsSinceEpoch), 300, reason: '처음 재료 3통은 그대로');
      clock = clock.add(const Duration(days: 30));
      expect(await c.command(() {}), isTrue);
      expect(c.takePantryNews(), isEmpty);
    });

    test('버린 뒤 명령이 실패하면 버림과 안내도 되돌린다', () async {
      final c = await open();
      addTearDown(c.dispose);
      await c.command(() {
        c.state.pantry.basic.addAll({'flour': 2, 'milk': 1, 'egg': 1, 'sugar': 1, 'salt': 1});
        c.state.pantry.make(p, 'batter', 1, 1, clock.millisecondsSinceEpoch, c.state.recipes);
      });
      clock = clock.add(const Duration(hours: 25));
      expect(await c.command(() => throw const FormatException('실패')), isFalse);
      expect(c.pantryNews, isEmpty);
      expect(c.state.pantry.portions('batter'), 400);
    });

    test('새 레시피를 받으면 그 속 1통과 1통 더 만들 재료, 한 번만', () async {
      final c = WorkshopController(recipeConfig, MemoryRepository(), now: () => clock);
      await c.initialize();
      addTearDown(c.dispose);
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = 4;
        c.state.claimedLevels.addAll([2, 3, 4]);
      });
      final milk = c.state.pantry.basic['milk'] ?? 0;
      expect(await c.claimRecipeFromMission('custard'), isTrue, reason: '${c.notice} ${c.error}');
      expect(c.takePantryNews(), ['슈크림 레시피 선물로 슈크림 1통과 1통 더 만들 재료를 받았어요.']);
      expect(c.state.pantry.usable(p, 'custard', clock.millisecondsSinceEpoch), 100);
      expect(c.state.pantry.basic['milk'], milk + 2);
      expect(c.state.pantry.gifts, contains('recipe:custard'));
    });

    test('재료가 생기기 전 저장은 이미 얻은 레시피의 선물도 함께 받는다', () async {
      final repository = Repository();
      final c = WorkshopController(recipeConfig, repository, now: () => clock);
      await c.initialize();
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = 4;
        c.state.claimedLevels.addAll([2, 3, 4]);
      });
      expect(await c.claimRecipeFromMission('custard'), isTrue);
      final old = jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>..['schema'] = 11..remove('pantry');
      c.dispose();
      final reopened = WorkshopController(recipeConfig, Repository()..stored = old, now: () => clock);
      addTearDown(reopened.dispose);
      await reopened.initialize();
      final at = clock.millisecondsSinceEpoch;
      expect(reopened.state.pantry.usable(p, 'batter', at), 300);
      expect(reopened.state.pantry.usable(p, 'custard', at), 100);
      expect(reopened.state.pantry.gifts, {'start', 'recipe:custard'});
    });

    test('빈털터리: 반죽·속이 다 떨어지고 붕어빵력으로 1통도 못 사면 꾸러미, 하루 3번', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await grown(c, 2), isTrue);
      for (var n = 1; n <= 3; n++) {
        expect(await c.command(() {
          drain(c.state.pantry, 'batter');
          drain(c.state.pantry, 'redbean');
          c.state.pantry.basic.clear();
          c.state.buns = BigInt.zero;
        }), isTrue);
        expect(c.takePantryNews(), [rescueNotice(p, n)]);
        expect(c.state.pantry.basic, isNotEmpty);
      }
      await c.command(() => c.state.pantry.basic.clear());
      expect(c.takePantryNews(), isEmpty, reason: '하루 3번');
      expect(c.state.pantry.basic, isEmpty);
      clock = clock.add(const Duration(days: 1));
      await c.command(() {});
      expect(c.takePantryNews(), [rescueNotice(p, 1)]);
    });

    test('붕어빵력이 있으면 꾸러미를 주지 않는다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await grown(c, 2), isTrue);
      await c.command(() {
        drain(c.state.pantry, 'batter');
        c.state.pantry.basic.clear();
        c.state.buns = BigInt.from(1000000000);
        c.state.lifetime = c.state.buns;
      });
      expect(c.takePantryNews(), isEmpty);
    });

    test('생산 멈춤은 영업 중에만: 반죽이 없거나 얻은 속이 모두 없을 때', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await grown(c, 2), isTrue);
      expect(c.pantryOut, PantryShortage.none);
      await c.command(() => drain(c.state.pantry, 'redbean'));
      expect(c.pantryOut, PantryShortage.none, reason: '영업 준비 중');
      expect(await c.openBusiness(), isTrue);
      expect(c.pantryOut, PantryShortage.filling);
      await c.command(() => drain(c.state.pantry, 'batter'));
      expect(c.pantryOut, PantryShortage.batter);
    });
  });

  group('기능 열기', () {
    test('재료 준비는 Lv.2(설정 pantry_prep), 스킬 카드 다음, 예전 저장도 새로 소개', () async {
      expect(featureUnlockLevel(config, WorkshopFeature.pantry), 2);
      final c = await open();
      addTearDown(c.dispose);
      expect(await grown(c, 1), isTrue);
      expect(c.featureLock(WorkshopFeature.pantry), 'Lv.2 달성하면 열려요');
      expect(await grown(c, 2), isTrue);
      expect(c.featureLock(WorkshopFeature.pantry), isNull);
      expect(c.pendingIntro, WorkshopFeature.skills);
      await c.markIntroSeen(WorkshopFeature.skills);
      expect(c.pendingIntro, WorkshopFeature.pantry);
      expect(openedIntroIds(c.state, config), isNot(contains('pantry')));
      expect(featureName(WorkshopFeature.pantry), '재료 준비');
      expect(featureTour(WorkshopFeature.pantry).map((s) => s.target), ['pantry-stock', 'pantry-prep']);
      for (final text in [featureIntro(WorkshopFeature.pantry).body, ...featureTour(WorkshopFeature.pantry).map((s) => s.text)]) {
        expect(text.contains('·'), isFalse, reason: 'Jua에 없는 가운뎃점');
      }
    });
  });

  group('홈 화면', () {
    Future<WorkshopController> mount(WidgetTester tester, {int level = 2, UsageStats? usage}) async {
      final account = await mountGame(tester, const Size(390, 844), reduced: true);
      final c = await open(usage: usage);
      await grown(c, level, seen: workshopIntroIds);
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await tester.pump();
      return c;
    }

    testWidgets('간판 아래 반죽·속 통, 영업 준비 중에는 제작 시작 옆 재료 준비', (tester) async {
      final c = await mount(tester);
      expect(find.byKey(const Key('pantry-stock')), findsOneWidget);
      expect(find.text('3통'), findsNWidgets(2));
      expect(find.byKey(const Key('pantry-prep')), findsOneWidget);
      expect(find.byKey(const Key('workshop-mold-action')), findsOneWidget);
      final prep = tester.getRect(find.byKey(const Key('pantry-prep')));
      final start = tester.getRect(find.byKey(const Key('workshop-mold-action')));
      expect(prep.right, lessThanOrEqualTo(start.left), reason: '왼쪽 옆');
      expect((prep.center.dy - start.center.dy).abs(), lessThan(4));
      await tester.tap(find.byKey(const Key('pantry-prep')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pantry-summary')), findsOneWidget);
      expect(c.state.business.open, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Lv.1: 재료 준비는 자물쇠, 누르면 조건', (tester) async {
      await mount(tester, level: 1);
      expect(find.descendant(of: find.byKey(const Key('pantry-prep')), matching: find.byKey(const Key('lock-hatch'))),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('pantry-prep')));
      await tester.pump();
      expect(find.textContaining('Lv.2 달성하면 열려요'), findsOneWidget);
      expect(find.byKey(const Key('pantry-summary')), findsNothing);
      CenterToast.hide();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('영업 중: 재료 표시를 누르면 알림, 떨어지면 말풍선 한 번과 빨간 표시, 사용 통계 하루 1번', (tester) async {
      final sink = RecordingSink();
      final c = await mount(tester, usage: UsageStats(sink, now: () => clock));
      await c.openBusiness();
      await tester.pump();
      expect(find.byKey(const Key('pantry-prep')), findsNothing, reason: '영업 중에는 없음');
      await tester.tap(find.byKey(const Key('pantry-stock')));
      await tester.pump();
      expect(find.text(pantryOpenOnlyText), findsOneWidget);
      CenterToast.hide();
      await tester.pumpAndSettle();
      await c.command(() {
        drain(c.state.pantry, 'redbean');
        c.state.buns = BigInt.from(1000000000);
        c.state.lifetime = c.state.buns;
      });
      await tester.pump();
      expect(find.byKey(const Key('pantry-out-bubble')), findsOneWidget);
      expect(find.text('팥소가 떨어졌어요'), findsOneWidget);
      expect(find.text('0통'), findsOneWidget);
      expect(sink.lines.where((l) => l.startsWith('ingredient_out')), ['ingredient_out {what: filling}']);
      await tester.tap(find.byKey(const Key('pantry-out-bubble')));
      await tester.pump();
      expect(find.byKey(const Key('pantry-out-bubble')), findsNothing);
      await c.command(() {});
      await tester.pump();
      expect(find.byKey(const Key('pantry-out-bubble')), findsNothing, reason: '한 번만');
      expect(sink.lines.where((l) => l.startsWith('ingredient_out')).length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('말풍선은 잠시 뒤 저절로 사라진다', (tester) async {
      final c = await mount(tester);
      await c.openBusiness();
      await c.command(() {
        drain(c.state.pantry, 'batter');
        c.state.buns = BigInt.from(1000000000);
        c.state.lifetime = c.state.buns;
      });
      await tester.pump();
      expect(find.text('반죽이 떨어졌어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      expect(find.byKey(const Key('pantry-out-bubble')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Lv.2 소개 카드 뒤 두 단계 안내가 재료 표시와 재료 준비를 가리킨다', (tester) async {
      final account = await mountGame(tester, const Size(390, 844), reduced: true);
      final c = await open();
      await grown(c, 2, seen: workshopIntroIds.difference({'pantry'}));
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature-intro-pantry')), findsOneWidget);
      expect(find.text('재료 준비가 열렸어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(c.state.featureIntros, contains('pantry'));
      expect(find.text('재료 준비 안내 1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      expect(find.text('재료 준비 안내 2/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      expect(find.byType(WorkshopFeatureIntroCard), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
