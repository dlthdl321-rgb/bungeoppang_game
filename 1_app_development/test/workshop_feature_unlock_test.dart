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
import 'package:todays_bungeoppang/ui/center_toast.dart';
import 'workshop_controller_test.dart' show Gateway;
import 'test_support.dart' show setUpAccount;

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
  /// Completes 팥's 도감 through real practice bakes (closed stall), like
  /// workshop_full_flow_test: every doneness baked its count (4차 g6).
  Future<void> award(WorkshopController c) async {
    const takeOutMs = [5000, 12000, 15000, 19000, 25000];
    for (var i = 0; i < 40 && !c.state.collection(config, 'redbean').collected; i++) {
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
    expect(c.state.collection(config, 'redbean').collected, isTrue);
    expect(c.state.masteryAwards, isEmpty, reason: '숙련 확정은 더 만들지 않음(도감으로 대신)');
  }

  group('해금 표', () {
    test('설정: skill_shop 2, 도감 3, 레시피 4, 특별 주문·붕어빵 꾸미기 5, 가게 꾸미기 8', () {
      expect(featureUnlockLevel(config, WorkshopFeature.skills), 2);
      expect(featureUnlockLevel(config, WorkshopFeature.collection), 3);
      expect(featureUnlockLevel(config, WorkshopFeature.recipes), 4);
      expect(featureUnlockLevel(config, WorkshopFeature.specialOrders), 5);
      expect(featureUnlockLevel(config, WorkshopFeature.fishCosmetics), 5);
      expect(featureUnlockLevel(config, WorkshopFeature.stallCosmetics), 8);
      expect(featureUnlockLevel(config, WorkshopFeature.griddle), 1, reason: '6구는 레벨이 아니라 도감 완성으로 연다');
    });

    test('새 설치: 안내 중에는 꾸미기·상점도 잠기고, 안내가 끝나면 레벨별로 하나씩 열린다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(c.state.tutorialActive, isTrue);
      for (final f in WorkshopFeature.values) {
        expect(c.featureIsOpen(f), isFalse, reason: f.name);
      }
      expect(c.featureLock(WorkshopFeature.wardrobe), '첫 영업 안내가 끝나면 열려요');
      expect(c.featureLock(WorkshopFeature.skills), 'Lv.2 달성하면 열려요');
      expect(c.featureLock(WorkshopFeature.griddle), '팥 도감을 완성하면 열려요 (0/5)');
      expect(c.pendingIntro, isNull, reason: '안내 중에는 소개 카드 없음');
      expect(await c.skipTutorial(), isTrue);
      expect(c.featureIsOpen(WorkshopFeature.wardrobe), isTrue);
      // 4차 g5: the guide's end brings the 꾸미기·상점·오늘 card.
      expect(c.pendingIntro, WorkshopFeature.wardrobe);
      expect(await c.markIntroSeen(WorkshopFeature.wardrobe), isTrue);
      expect(c.pendingIntro, isNull);
      final opened = <int, Set<WorkshopFeature>>{};
      for (var level = 1; level <= 8; level++) {
        expect(await setLevel(c, level), isTrue);
        opened[level] = {for (final f in WorkshopFeature.values) if (c.featureIsOpen(f)) f};
      }
      // 26번 3차 H42: 배경 테마 opens with the wardrobe.
      expect(opened[1], {WorkshopFeature.wardrobe, WorkshopFeature.stallBackground});
      expect(opened[2]!.difference(opened[1]!), {WorkshopFeature.skills, WorkshopFeature.pantry}, reason: '재료 타이쿤 E: 재료 준비도 Lv.2');
      expect(opened[3]!.difference(opened[2]!), {WorkshopFeature.collection});
      expect(opened[4]!.difference(opened[3]!), {WorkshopFeature.recipes});
      expect(opened[5]!.difference(opened[4]!), {WorkshopFeature.specialOrders, WorkshopFeature.fishCosmetics});
      expect(opened[8]!.difference(opened[7]!), {WorkshopFeature.stallCosmetics});
      expect(opened[8]!.contains(WorkshopFeature.griddle), isFalse);
      await award(c);
      expect(c.featureIsOpen(WorkshopFeature.griddle), isTrue);
      expect(c.featureLock(WorkshopFeature.griddle), isNull);
    });

    test('잠금 글은 팥 도감 완성 칸 수를 보여 주고, 핵심 진행은 레벨로 잠그지 않는다', () async {
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
      expect(m.practices, 1);
      // One medium of five: not complete yet.
      expect(c.state.collection(config, 'redbean').counts, [0, 0, 1, 0, 0]);
      expect(c.featureLock(WorkshopFeature.griddle), '팥 도감을 완성하면 열려요 (0/5)');
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
      // 4차 IA3: the 붕어빵 요정 story card is not what this test is about.
      await c.command(() => c.state.featureIntros.add('fairy'));
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
      expect(await c.markIntroSeen(WorkshopFeature.wardrobe), isTrue);
      expect(c.pendingIntro, WorkshopFeature.freshness);
    });
  });

  group('팔 것이 없는 꾸미기 소개 (4차 g15)', () {
    test('화로·장식(틀·토핑)을 팔지 않으면 가게(붕어빵) 꾸미기 카드는 기다리고, 팔기 시작하면 뜬다', () async {
      final c = await open();
      addTearDown(c.dispose);
      await c.skipTutorial();
      expect(featureAvailable(c.config, WorkshopFeature.stallCosmetics), isFalse);
      expect(featureAvailable(c.config, WorkshopFeature.fishCosmetics), isFalse);
      expect(featureAvailable(c.config, WorkshopFeature.skills), isTrue);
      await c.command(() => c.state.featureIntros.addAll(
          [for (final f in workshopIntroFeatures) if (f != WorkshopFeature.stallCosmetics && f != WorkshopFeature.fishCosmetics) f.name]));
      expect(await setLevel(c, 8, seen: false), isTrue);
      expect(c.featureIsOpen(WorkshopFeature.stallCosmetics), isTrue);
      expect(c.pendingIntro, isNull, reason: '팔 것이 없으면 카드 없음');
      expect(c.state.featureIntros.contains('stallCosmetics'), isFalse, reason: '본 것으로 치지 않아 나중에 뜰 수 있음');
      final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
      (raw['avatar_catalog'] as Map<String, dynamic>)['copper'] =
          {'label': '구리 화로', 'slot': 'stove', 'free': false, 'unlock_level': 8, 'unlock_total': '0'};
      final selling = DevelopmentBalance.fromJson(raw);
      expect(featureAvailable(selling, WorkshopFeature.stallCosmetics), isTrue);
      expect(pendingFeatureIntro(c.state, selling), WorkshopFeature.stallCosmetics);
    });
  });

  group('소개 카드 저장 (schema 8)', () {
    test('한 번 본 카드는 저장되어 다시 열어도 안 뜬다', () async {
      final repository = MemoryRepository();
      final c = await open(repository);
      await c.skipTutorial();
      expect(await setLevel(c, 3), isTrue);
      expect(c.pendingIntro, WorkshopFeature.wardrobe, reason: '여러 개면 정한 순서대로');
      expect(await c.markIntroSeen(WorkshopFeature.wardrobe), isTrue);
      expect(c.pendingIntro, WorkshopFeature.skills);
      expect(await c.markIntroSeen(WorkshopFeature.skills), isTrue);
      expect(c.pendingIntro, WorkshopFeature.pantry, reason: '재료 타이쿤 E: 스킬 다음');
      expect(await c.markIntroSeen(WorkshopFeature.pantry), isTrue);
      expect(c.pendingIntro, WorkshopFeature.collection);
      expect(await c.markIntroSeen(WorkshopFeature.collection), isTrue);
      expect(c.pendingIntro, isNull);
      expect(await c.markIntroSeen(WorkshopFeature.collection), isTrue, reason: '두 번 눌러도 그대로');
      expect(repository.saved!['schema'], workshopSchema);
      expect(repository.saved!['featureIntros'], ['collection', 'pantry', 'skills', 'wardrobe']);
      c.dispose();
      final again = await open(repository);
      addTearDown(again.dispose);
      expect(again.state.featureIntros, {'skills', 'pantry', 'collection', 'wardrobe'});
      expect(again.pendingIntro, isNull);
    });

    test('schema 7 저장: 이미 열린 기능은 본 것으로 채워 고레벨 기존 저장은 카드 0장', () async {
      final c = await open();
      addTearDown(c.dispose);
      await c.skipTutorial();
      expect(await setLevel(c, 12), isTrue);
      await award(c);
      final old = c.state.toJson()..['schema'] = 7..remove('featureIntros')..remove('daily')..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales');
      final migrated = WorkshopState.fromJson(old, config);
      expect(migrated.featureIntros, containsAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders',
          'fishCosmetics', 'stallCosmetics']));
      // 재료 타이쿤 E: 재료 준비는 모두에게 새 기능이라 이전 저장도 카드 한 장.
      expect(migrated.featureIntros, isNot(contains('pantry')));
      expect(pendingFeatureIntro(migrated, config), WorkshopFeature.pantry);
      migrated.featureIntros.add('pantry');
      expect(pendingFeatureIntro(migrated, config), isNull);
      expect(migrated.toJson()['schema'], workshopSchema);
      // A low-level old save still gets the cards still to come.
      final low = await open();
      addTearDown(low.dispose);
      await low.skipTutorial();
      final lowOld = low.state.toJson()..['schema'] = 7..remove('featureIntros')..remove('daily')..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales');
      final lowMigrated = WorkshopState.fromJson(lowOld, config)..level = 2;
      expect(pendingFeatureIntro(lowMigrated, config), WorkshopFeature.skills);
    });

    test('4차 IA3: 붕어빵 요정 이야기 카드는 안내 뒤 요정이 나와 있을 때 한 번', () async {
      final c = await open();
      addTearDown(c.dispose);
      // During the guide: never.
      await c.openBusiness();
      expect(c.pendingIntro, isNull);
      await c.skipTutorial();
      // 4차 g5: the 꾸미기·상점·오늘 card comes first right after the guide.
      expect(c.pendingIntro, WorkshopFeature.wardrobe);
      expect(await c.markIntroSeen(WorkshopFeature.wardrobe), isTrue);
      expect(c.pendingIntro, WorkshopFeature.fairy);
      expect(featureLockReason(c.state, config, WorkshopFeature.fairy), isNull);
      // A guest waiting: the fairy is hiding, so the card waits too.
      await c.command(() => c.state.customers.add(CustomerOrder(id: 'g', customerId: 'anonymous_g',
          remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
      expect(c.pendingIntro, isNull);
      await c.command(() => c.state.customers.clear());
      expect(c.pendingIntro, WorkshopFeature.fairy);
      expect(await c.markIntroSeen(WorkshopFeature.fairy), isTrue);
      expect(c.pendingIntro, isNull);
      expect(c.state.toJson()['featureIntros'], ['fairy', 'wardrobe']);
      expect(WorkshopState.fromJson(c.state.toJson(), config).featureIntros, {'fairy', 'wardrobe'});
      // An old save (schema 7) still meets the fairy once.
      final old = c.state.toJson()..['schema'] = 7..remove('featureIntros')..remove('daily')..remove('pantry')..remove('pendingSales')..remove('archivedSales')..remove('archivedSalesBuns')..remove('archivedNamedSales');
      expect(WorkshopState.fromJson(old, config).featureIntros, isNot(contains('fairy')));
      expect(featureIntro(WorkshopFeature.fairy).title, '붕어빵 요정을 만났어요');
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
      final account = await setUpAccount(tester, size, reduced: true);
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
      await c.initialize();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await tester.pump();
      return c;
    }

    testWidgets('새 설치 첫 화면: 스킬·꾸미기·상점은 빗금 자물쇠, 초당·클릭당 숫자는 숨김', (tester) async {
      final c = await mount(tester);
      // 26번 3차 H6: a new install opens with the welcome story; end it first.
      await tester.tap(find.byKey(const Key('story-skip')));
      await tester.pump();
      await tester.pump(); // the guide card measures the menu after its first frame
      for (final id in ['skills', 'skins', 'shop']) {
        expect(find.byKey(Key('menu-$id-locked')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const Key('menu-menubar')), findsOneWidget, reason: '메뉴는 늘 열림');
      expect(find.byKey(const Key('auto-rate')), findsNothing);
      expect(find.byKey(const Key('tap-rate')), findsNothing);
      // 4차 g5: the '오늘' slip is listed locked during the guide too.
      expect(find.byKey(const Key('daily-ticket-locked')), findsOneWidget);
      expect(find.byKey(const Key('daily-ticket')), findsNothing);
      expect(find.byKey(const Key('lock-hatch')), findsNWidgets(4));
      // A tap on a locked button tells why and opens nothing.
      await tester.tap(find.byKey(const Key('menu-skills-locked')));
      await tester.pump();
      expect(find.text('스킬: Lv.2 달성하면 열려요'), findsOneWidget);
      expect(find.byType(WorkshopSkillShop), findsNothing);
      // The centre notice (H23) is cleared by hand.
      CenterToast.hide();
      await tester.pumpAndSettle();

      // After the guide: 꾸미기·상점 open, the skills wait for Lv.2.
      expect(await c.skipTutorial(), isTrue);
      await tester.pump();
      expect(find.byKey(const Key('menu-skins-locked')), findsNothing);
      expect(find.byKey(const Key('menu-shop-locked')), findsNothing);
      expect(find.byKey(const Key('menu-skills-locked')), findsOneWidget);
      // 4차 g5: the guide's end brings the 꾸미기·상점·오늘 card, then a short
      // tour pointing at the real buttons; '건너뛰기' ends it.
      await tester.pump();
      expect(find.byKey(const Key('feature-intro-wardrobe')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(c.state.featureIntros, {'wardrobe'});
      expect(find.text('꾸미기·상점·오늘 안내 1/3'), findsOneWidget);
      expect(find.byKey(const Key('tutorial-ring')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      expect(find.text('꾸미기·상점·오늘 안내 2/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial-card')), findsNothing);

      // Lv.2: the skill card once, then the window and the numbers.
      expect(await setLevel(c, 2), isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('feature-intro-skills')), findsOneWidget);
      expect(find.textContaining('카카오 로그인 후 레벨업'), findsOneWidget);
      // 25번 22번 그림이 들어와 기존 아이콘 대신 160×120 그림이 1:1로 보인다.
      expect(find.byKey(const Key('feature-intro-standin')), findsNothing);
      expect(tester.getSize(find.byKey(const Key('feature-intro-art'))), const Size(160, 120));
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature-intro-skills')), findsNothing);
      expect(c.state.featureIntros, {'wardrobe', 'skills'});
      // The skills tour: two steps, the last one says '알겠어요'.
      expect(find.text('스킬 안내 1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      expect(find.text('스킬 안내 2/2'), findsOneWidget);
      expect(find.text('알겠어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-next')));
      await tester.pumpAndSettle();
      // 재료 타이쿤 E: the 재료 준비 card comes right after the skills tour.
      expect(find.byKey(const Key('feature-intro-pantry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(find.text('재료 준비 안내 1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      expect(find.byKey(const Key('menu-skills-locked')), findsNothing);
      expect(find.byKey(const Key('auto-rate')), findsOneWidget);
      expect(find.byKey(const Key('tap-rate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-skills')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkshopSkillShop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('6구는 도감 완성 전 빗금 자물쇠와 남은 칸 수, 굽는 중인 칸은 꺼낼 수 있다', (tester) async {
      final c = await mount(tester);
      await c.skipTutorial();
      expect(await c.markIntroSeen(WorkshopFeature.wardrobe), isTrue);
      // 4차 IA3: the 붕어빵 요정 story card is not what this test is about.
      await c.command(() => c.state.featureIntros.add('fairy'));
      expect(await c.openBusiness(), isTrue);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('griddle-locked')), findsOneWidget);
      // A tap on the lock tells the mastery still to go.
      await tester.tap(find.byKey(const Key('griddle-locked')));
      await tester.pump();
      expect(find.textContaining('숙련된 붕어빵 틀: 팥 도감을 완성하면'), findsOneWidget);
      CenterToast.hide();
      await tester.pumpAndSettle();
      expect(tester.widget(find.byKey(const Key('griddle-locked'))), isA<LockedOverlay>());
      expect(find.descendant(of: find.byKey(const Key('griddle-locked')), matching: find.byKey(const Key('lock-hatch'))),
          findsOneWidget);
      expect(find.text('팥 도감을 완성하면 열려요 (0/5)'), findsOneWidget);
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

    // 26번 3차 H42: 배경 테마 is back as soon as the guide ends (it was hidden until Lv.8).
    testWidgets('메뉴: 도감은 Lv.3 전에도 자물쇠와 함께 보이고 누르면 조건 알림, 배경 테마는 안내가 끝나면 바로 (3차 H32·H36·H42, 4차 g5)', (tester) async {
      final c = await mount(tester);
      await tester.tap(find.byKey(const Key('story-skip')));
      await tester.pump();
      await tester.pump();
      // During the guide 배경 테마 is listed locked too (4차 g5), not hidden.
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-theme')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('menu-lock-skins:stall'))).data, '첫 영업 안내가 끝나면 열려요');
      await tester.tap(find.byKey(const Key('menu-theme')));
      await tester.pump();
      expect(find.text('배경 테마: 첫 영업 안내가 끝나면 열려요'), findsOneWidget);
      CenterToast.hide();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-theme')), findsOneWidget, reason: '잠긴 줄을 눌러도 메뉴는 그대로');
      Navigator.of(tester.element(find.byKey(const Key('menu-theme')))).pop();
      await tester.pumpAndSettle();
      await c.skipTutorial();
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-collection')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('menu-lock-achievements:collection'))).data, 'Lv.3 달성하면 열려요');
      expect(find.byKey(const Key('menu-locked-achievements:collection')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('menu-locked-achievements:collection')),
          matching: find.byKey(const Key('lock-badge'))), findsOneWidget);
      expect(find.byKey(const Key('menu-theme')), findsOneWidget);
      expect(find.byKey(const Key('menu-lock-skins:stall')), findsNothing);
      // 일일 미션·주간 도전 moved to the '오늘' window.
      expect(find.byKey(const Key('menu-daily')), findsNothing);
      expect(find.byKey(const Key('event-entry')), findsNothing);
      // A locked 도감 says when it opens and opens nothing (4차 g5).
      await tester.tap(find.byKey(const Key('menu-collection')));
      await tester.pump();
      expect(find.text('도감: Lv.3 달성하면 열려요'), findsOneWidget);
      expect(find.byKey(const Key('collection-locked')), findsNothing);
      CenterToast.hide();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byKey(const Key('menu-collection')))).pop();
      await tester.pumpAndSettle();
      expect(await setLevel(c, 8, seen: true), isTrue);
      await tester.pump();
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-collection')), findsOneWidget);
      expect(find.byKey(const Key('menu-lock-achievements:collection')), findsNothing);
      expect(find.byKey(const Key('menu-theme')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('설정 > 튜토리얼 다시 보기: 열린 기능은 소개와 안내를 다시, 잠긴 기능은 자물쇠와 조건 (4차 g5)', (tester) async {
      final c = await mount(tester);
      await tester.tap(find.byKey(const Key('story-skip')));
      await tester.pump();
      await tester.pump();
      expect(await setLevel(c, 2, seen: true), isTrue);
      await c.command(() => c.state.tutorial = 'done');
      await tester.pump();
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('settings-tours')));
      await tester.tap(find.byKey(const Key('settings-tours')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tour-list')), findsOneWidget);
      // 4차 g15: 붕어빵·가게 꾸미기 are left out while nothing is sold there.
      for (final f in workshopIntroFeatures) {
        expect(find.byKey(Key('tour-replay-${f.name}')), featureAvailable(c.config, f) ? findsOneWidget : findsNothing,
            reason: f.name);
      }
      expect(find.byKey(const Key('tour-replay-stallCosmetics')), findsNothing);
      expect(find.byKey(const Key('tour-replay-fishCosmetics')), findsNothing);
      // 도감 waits for Lv.3: the row says so and a tap only tells why.
      await tester.ensureVisible(find.byKey(const Key('tour-replay-collection')));
      expect(find.descendant(of: find.byKey(const Key('tour-replay-collection')), matching: find.text('Lv.3 달성하면 열려요')),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-replay-collection')));
      await tester.pump();
      expect(find.text('도감: Lv.3 달성하면 열려요'), findsOneWidget);
      CenterToast.hide();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tour-list')), findsOneWidget);
      // 스킬 is open: its card again, then its two-step tour.
      await tester.ensureVisible(find.byKey(const Key('tour-replay-skills')));
      await tester.tap(find.byKey(const Key('tour-replay-skills')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feature-intro-skills')), findsOneWidget);
      await tester.tap(find.byKey(const Key('feature-intro-ok')));
      await tester.pumpAndSettle();
      expect(find.text('스킬 안내 1/2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tour-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('기능마다 소개 카드와 1~3단계 안내가 있다 (4차 g5)', (tester) async {
      for (final f in workshopIntroFeatures) {
        final intro = featureIntro(f);
        expect(intro.title, isNotEmpty, reason: f.name);
        expect(intro.body, isNotEmpty, reason: f.name);
        expect(featureTour(f).length, inInclusiveRange(1, 3), reason: f.name);
      }
    });

    testWidgets('첫 판매 칭찬: 말풍선·큰 별·반짝 2초 뒤 사라지고 저장하지 않는다', (tester) async {
      final account = await setUpAccount(tester, const Size(390, 844));
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
