import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/lock_overlay.dart';
import 'package:todays_bungeoppang/ui/workshop_guide.dart';
import 'package:todays_bungeoppang/ui/workshop_windows.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'workshop_controller_test.dart' show Gateway;
import 'widget_test.dart' show mountGame;

/// 26번 2단계: 처음 5분 단순화 (DEC-043 A. 하나씩 열기). 레벨·숙련별 잠금,
/// 잠금 글, 소개 카드 한 번, 기존 저장 호환, 첫 판매 칭찬.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  Future<WorkshopController> open([MemoryRepository? repository]) async {
    final c = WorkshopController(config, repository ?? MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
    await c.initialize();
    return c;
  }
  final manual = config.section('manual_cooking');
  /// A level with its level-up claims (the save checks they match).
  Future<bool> setLevel(WorkshopController c, int level, {bool seen = false}) => c.command(() {
        c.state.level = level;
        c.state.claimedLevels..clear()..addAll([for (var n = 2; n <= level; n++) n]);
        if (seen) c.state.featureIntros.addAll(workshopIntroIds);
      });
  /// Masters 팥 through real practice bakes (closed stall), like
  /// workshop_full_flow_test: five doneness grades, enough practices.
  Future<void> award(WorkshopController c) async {
    const takeOutMs = [5000, 12000, 15000, 19000, 25000];
    for (var i = 0; i < 20 && !c.state.masteryAwards.containsKey('redbean'); i++) {
      expect(await c.startPractice(), isTrue, reason: '${c.notice}');
      var s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.squeezeFilling(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'lid_close_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.close(s.token)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'flip_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.flip(s.token)), isTrue);
      final out = takeOutMs[i % takeOutMs.length];
      await c.command(() => c.state.phaseMs = out);
      s = c.state.session!;
      expect(await c.cookingCommand(s.takeOut(s.token, out)), isTrue);
      expect(await c.storeResult(false), isTrue);
    }
    expect(c.state.masteryAwards.containsKey('redbean'), isTrue);
  }

  group('해금 표', () {
    test('설정: skill_shop 2, 도감 3, 레시피 4, 특별 주문·붕어빵 꾸미기 5, 가게 꾸미기 8', () {
      expect(featureUnlockLevel(config, WorkshopFeature.skills), 2);
      expect(featureUnlockLevel(config, WorkshopFeature.collection), 3);
      expect(featureUnlockLevel(config, WorkshopFeature.recipes), 4);
      expect(featureUnlockLevel(config, WorkshopFeature.specialOrders), 5);
      expect(featureUnlockLevel(config, WorkshopFeature.fishCosmetics), 5);
      expect(featureUnlockLevel(config, WorkshopFeature.stallCosmetics), 8);
      expect(featureUnlockLevel(config, WorkshopFeature.griddle), 1, reason: '6구는 레벨이 아니라 숙련으로 연다');
    });

    test('새 설치: 안내 중에는 꾸미기·상점도 잠기고, 안내가 끝나면 레벨별로 하나씩 열린다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(c.state.tutorialActive, isTrue);
      for (final f in WorkshopFeature.values) {
        expect(c.featureIsOpen(f), isFalse, reason: f.name);
      }
      expect(c.featureLock(WorkshopFeature.wardrobe), '첫 영업 안내가 끝나면 열려요');
      expect(c.featureLock(WorkshopFeature.skills), 'Lv.2에 열려요');
      expect(c.featureLock(WorkshopFeature.griddle), '팥을 숙련하면 열려요 (연습 0/8 · 손기술 0/3)');
      expect(c.pendingIntro, isNull, reason: '안내 중에는 소개 카드 없음');
      expect(await c.skipTutorial(), isTrue);
      expect(c.featureIsOpen(WorkshopFeature.wardrobe), isTrue);
      expect(c.pendingIntro, isNull, reason: '꾸미기는 소개 카드 없이 열림');
      final opened = <int, Set<WorkshopFeature>>{};
      for (var level = 1; level <= 8; level++) {
        expect(await setLevel(c, level), isTrue);
        opened[level] = {for (final f in WorkshopFeature.values) if (c.featureIsOpen(f)) f};
      }
      expect(opened[1], {WorkshopFeature.wardrobe});
      expect(opened[2]!.difference(opened[1]!), {WorkshopFeature.skills});
      expect(opened[3]!.difference(opened[2]!), {WorkshopFeature.collection});
      expect(opened[4]!.difference(opened[3]!), {WorkshopFeature.recipes});
      expect(opened[5]!.difference(opened[4]!), {WorkshopFeature.specialOrders, WorkshopFeature.fishCosmetics});
      expect(opened[8]!.difference(opened[7]!), {WorkshopFeature.stallCosmetics});
      expect(opened[8]!.contains(WorkshopFeature.griddle), isFalse);
      await award(c);
      expect(c.featureIsOpen(WorkshopFeature.griddle), isTrue);
      expect(c.featureLock(WorkshopFeature.griddle), isNull);
    });

    test('잠금 글은 연습·손기술 진행을 보여 주고, 핵심 진행은 레벨로 잠그지 않는다', () async {
      final c = await open();
      addTearDown(c.dispose);
      // One real practice moves the count shown on the lock.
      expect(await c.startPractice(), isTrue);
      var s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.squeezeFilling(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'lid_close_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.close(s.token)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'flip_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.flip(s.token)), isTrue);
      await c.command(() => c.state.phaseMs = 15000);
      s = c.state.session!;
      expect(await c.cookingCommand(s.takeOut(s.token, 15000)), isTrue);
      expect(await c.storeResult(false), isTrue);
      final m = c.state.flavorMasteries['redbean']!;
      expect(c.featureLock(WorkshopFeature.griddle), '팥을 숙련하면 열려요 (연습 ${m.practices}/8 · 손기술 ${m.techniquePasses}/3)');
      expect(m.practices, 1);
      for (final key in ['manual_practice', 'core_business', 'core_sales', 'mastery_progress', 'six_slot_access']) {
        expect(config.section('feature_unlock_levels')[key], 1, reason: key);
      }
    });

    test('스킬을 이미 샀거나 정산 중인 거래가 있으면 Lv.1이어도 스킬 창은 열린다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(c.featureIsOpen(WorkshopFeature.skills), isFalse);
      // A skill bought before this stage (or at a higher level) keeps it open.
      await c.command(() { c.state.buns = BigInt.from(1000); c.state.lifetime = BigInt.from(1000); });
      expect(await c.purchaseSkill(Gateway(), 'auto_1'), isTrue, reason: '${c.notice} ${c.error}');
      expect(c.state.level, 1);
      expect(c.featureIsOpen(WorkshopFeature.skills), isTrue);
    });

    test('재고가 영업일을 넘기면 신선도 소개가 열린다(아무것도 잠그지 않음)', () async {
      var clock = DateTime.utc(2026, 10, 18, 3);
      final c = WorkshopController(config, MemoryRepository(), now: () => clock);
      await c.initialize();
      addTearDown(c.dispose);
      await c.skipTutorial();
      expect(await c.openBusiness(), isTrue);
      expect(await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'old',
          flavor: 'redbean', variant: 2, quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true)),
          isTrue, reason: '${c.notice}');
      expect(c.featureIsOpen(WorkshopFeature.freshness), isFalse);
      expect(c.featureLock(WorkshopFeature.freshness), isNull);
      expect(await c.closeBusiness(), isTrue);
      clock = clock.add(const Duration(days: 1));
      expect(await c.openBusiness(), isTrue, reason: '${c.notice}');
      expect(c.featureIsOpen(WorkshopFeature.freshness), isTrue);
      expect(c.pendingIntro, WorkshopFeature.freshness);
    });
  });

  group('소개 카드 저장 (schema 8)', () {
    test('한 번 본 카드는 저장되어 다시 열어도 안 뜬다', () async {
      final repository = MemoryRepository();
      final c = await open(repository);
      await c.skipTutorial();
      expect(await setLevel(c, 3), isTrue);
      expect(c.pendingIntro, WorkshopFeature.skills, reason: '여러 개면 정한 순서대로');
      expect(await c.markIntroSeen(WorkshopFeature.skills), isTrue);
      expect(c.pendingIntro, WorkshopFeature.collection);
      expect(await c.markIntroSeen(WorkshopFeature.collection), isTrue);
      expect(c.pendingIntro, isNull);
      expect(await c.markIntroSeen(WorkshopFeature.collection), isTrue, reason: '두 번 눌러도 그대로');
      expect(repository.saved!['schema'], 10);
      expect(repository.saved!['featureIntros'], ['collection', 'skills']);
      c.dispose();
      final again = await open(repository);
      addTearDown(again.dispose);
      expect(again.state.featureIntros, {'skills', 'collection'});
      expect(again.pendingIntro, isNull);
    });

    test('schema 7 저장: 이미 열린 기능은 본 것으로 채워 고레벨 기존 저장은 카드 0장', () async {
      final c = await open();
      addTearDown(c.dispose);
      await c.skipTutorial();
      expect(await setLevel(c, 12), isTrue);
      await award(c);
      final old = c.state.toJson()..['schema'] = 7..remove('featureIntros')..remove('daily');
      final migrated = WorkshopState.fromJson(old, config);
      expect(migrated.featureIntros, containsAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders',
          'fishCosmetics', 'stallCosmetics']));
      expect(pendingFeatureIntro(migrated, config), isNull);
      expect(migrated.toJson()['schema'], 10);
      // A low-level old save still gets the cards still to come.
      final low = await open();
      addTearDown(low.dispose);
      await low.skipTutorial();
      final lowOld = low.state.toJson()..['schema'] = 7..remove('featureIntros')..remove('daily');
      final lowMigrated = WorkshopState.fromJson(lowOld, config)..level = 2;
      expect(pendingFeatureIntro(lowMigrated, config), WorkshopFeature.skills);
    });

    test('잘못된 기록은 거절한다', () async {
      final c = await open();
      addTearDown(c.dispose);
      final saved = c.state.toJson();
      for (final bad in [
        ['unknown'],
        ['skills', 'skills'],
        'skills',
        [3],
      ]) {
        expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['featureIntros'] = bad, config),
            throwsFormatException, reason: '$bad');
      }
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..remove('featureIntros'), config),
          throwsFormatException, reason: 'schema 8에 기록 없음');
      expect(() => WorkshopState.fromJson(Map<String, dynamic>.from(saved)..['schema'] = 7, config),
          throwsFormatException, reason: '구형 저장에 새 필드');
    });
  });

  group('화면', () {
    Future<WorkshopController> mount(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      final account = await mountGame(tester, size, reduced: true);
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
      await c.initialize();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await tester.pump();
      return c;
    }

    testWidgets('새 설치 첫 화면: 스킬·꾸미기·상점은 빗금 자물쇠, 초당·클릭당 숫자는 숨김', (tester) async {
      final c = await mount(tester);
      for (final id in ['skills', 'skins', 'shop']) {
        expect(find.byKey(Key('menu-$id-locked')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const Key('menu-menubar')), findsOneWidget, reason: '메뉴는 늘 열림');
      expect(find.byKey(const Key('auto-rate')), findsNothing);
      expect(find.byKey(const Key('tap-rate')), findsNothing);
      expect(find.byKey(const Key('lock-hatch')), findsNWidgets(3));
      // A tap on a locked button tells why and opens nothing.
      await tester.tap(find.byKey(const Key('menu-skills-locked')));
      await tester.pump();
      expect(find.text('스킬: Lv.2에 열려요'), findsOneWidget);
      expect(find.byType(WorkshopSkillShop), findsNothing);
      // Screen-reader navigation keeps snack bars up: clear it by hand.
      ScaffoldMessenger.of(tester.element(find.byKey(const Key('home-nav')))).clearSnackBars();
      await tester.pumpAndSettle();

      // After the guide: 꾸미기·상점 open, the skills wait for Lv.2.
      expect(await c.skipTutorial(), isTrue);
      await tester.pump();
      expect(find.byKey(const Key('menu-skins-locked')), findsNothing);
      expect(find.byKey(const Key('menu-shop-locked')), findsNothing);
      expect(find.byKey(const Key('menu-skills-locked')), findsOneWidget);

      // Lv.2: the skill card once, then the window and the numbers.
      expect(await setLevel(c, 2), isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('feature-intro-skills')), findsOneWidget);
      expect(find.textContaining('카카오 로그인 후 레벨업'), findsOneWidget);
      expect(find.byKey(const Key('feature-intro-standin')), findsOneWidget, reason: '그림 전에는 기존 아이콘');
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature-intro-skills')), findsNothing);
      expect(c.state.featureIntros, {'skills'});
      expect(find.byKey(const Key('menu-skills-locked')), findsNothing);
      expect(find.byKey(const Key('auto-rate')), findsOneWidget);
      expect(find.byKey(const Key('tap-rate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-skills')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkshopSkillShop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('6구는 숙련 전 빗금 자물쇠와 남은 숙련, 굽는 중인 칸은 꺼낼 수 있다', (tester) async {
      final c = await mount(tester);
      await c.skipTutorial();
      expect(await c.openBusiness(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('griddle-locked')), findsOneWidget);
      // A tap on the lock tells the mastery still to go.
      await tester.tap(find.byKey(const Key('griddle-locked')));
      await tester.pump();
      expect(find.textContaining('숙련된 붕어빵 틀: 팥을 숙련하면'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byKey(const Key('home-nav')))).clearSnackBars();
      await tester.pumpAndSettle();
      expect(tester.widget(find.byKey(const Key('griddle-locked'))), isA<LockedOverlay>());
      expect(find.descendant(of: find.byKey(const Key('griddle-locked')), matching: find.byKey(const Key('lock-hatch'))),
          findsOneWidget);
      expect(find.text('팥을 숙련하면 열려요 (연습 0/8 · 손기술 0/3)'), findsOneWidget);
      expect(find.byKey(const Key('workshop-cell-0')), findsNothing);
      // Practice happens with the stall closed (DEC-035).
      expect(await c.closeBusiness(), isTrue);
      await award(c);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('feature-intro-griddle')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(await c.openBusiness(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('griddle-locked')), findsNothing);
      expect(tester.widget<InkWell>(find.byKey(const Key('workshop-cell-0'))).onTap, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('메뉴: 도감은 Lv.3, 배경 테마는 Lv.8 전까지 숨김', (tester) async {
      final c = await mount(tester);
      await c.skipTutorial();
      await tester.pump();
      await tester.tap(find.byKey(const Key('menu-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-collection')), findsNothing);
      expect(find.byKey(const Key('menu-theme')), findsNothing);
      expect(find.byKey(const Key('menu-daily')), findsOneWidget);
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
      expect(await setLevel(c, 8, seen: true), isTrue);
      await tester.pump();
      await tester.tap(find.byKey(const Key('menu-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-collection')), findsOneWidget);
      expect(find.byKey(const Key('menu-theme')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('첫 판매 칭찬: 말풍선·큰 별·반짝 2초 뒤 사라지고 저장하지 않는다', (tester) async {
      final account = await mountGame(tester, const Size(390, 844));
      final repository = MemoryRepository();
      final c = WorkshopController(config, repository, now: () => DateTime.utc(2026, 10, 18));
      await c.initialize();
      await c.command(() => c.state.tutorial = 'sell');
      expect(await c.openBusiness(), isTrue);
      await c.command(() {
        c.state.customers.add(CustomerOrder(id: 'first', customerId: 'anonymous_first', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'ready', flavor: 'redbean', variant: 2,
            quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
      });
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      expect(await c.sellToCustomer('first'), isTrue);
      await tester.pump();
      expect(find.byKey(const Key('sale-praise')), findsOneWidget);
      expect(find.byKey(const Key('sale-praise-star')), findsOneWidget);
      expect(find.byKey(const Key('sale-praise-sparkle')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('sale-praise-stars'))).data, matches(RegExp(r'^별 [1-5]개!$')));
      expect(find.byKey(const Key('sale-praise-speech')), findsOneWidget);
      expect(repository.saved!.containsKey('salePraise'), isFalse);
      await tester.pump(WorkshopSalePraiseBanner.duration + const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byKey(const Key('sale-praise')), findsNothing);
      expect(c.salePraise, isNull);
      // Later sales keep the small counter line only.
      await c.command(() {
        c.state.customers.add(CustomerOrder(id: 'second', customerId: 'anonymous_first', remainingMs: 100000,
            lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
        c.state.inventory = c.state.inventory.recordResult(ProductBatch(id: 'ready2', flavor: 'redbean', variant: 2,
            quantity: 1, madeOnBusinessIndex: c.state.business.businessIndex), keep: true);
      });
      expect(await c.sellToCustomer('second'), isTrue);
      expect(c.salePraise, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('모션 줄이기면 칭찬은 반짝임 없이 멈춘 채로 보인다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WorkshopSalePraiseBanner(
          praise: const WorkshopSalePraise('도윤', 3, '와, 따끈해요!'), reduceMotion: true, onDone: () {}))));
      expect(find.byKey(const Key('sale-praise-sparkle')), findsNothing);
      expect(find.text('별 3개!'), findsOneWidget);
      await tester.pump(WorkshopSalePraiseBanner.duration);
    });
  });
}
