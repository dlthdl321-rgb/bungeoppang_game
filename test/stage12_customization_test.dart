import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/achievement_config.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/game_events.dart';
import 'package:todays_bungeoppang/menu_state.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/progress_rules.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/fish_painter.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'controller_test.dart' show FakeTime;
import 'level_missions_widget_test.dart' show tapVisible;
import 'stage8_progress_test.dart' show now, plainJson, progressed;
import 'widget_test.dart' show mountGame;

Iterable<CosmeticDefinition> inSlot(CosmeticSlot slot) =>
    cosmeticDefinitions.where((d) => d.slot == slot);

/// The v9 JSON shape: no stage-12 slots in the wardrobe.
Map<String, dynamic> asV9(GameState s) {
  final json = plainJson(s)..['formatVersion'] = 9;
  final wardrobe = json['wardrobe'] as Map;
  final stage12Ids = {
    for (final d in cosmeticDefinitions)
      if (stage12Slots.contains(d.slot)) d.id
  };
  wardrobe['owned'] = [
    for (final id in wardrobe['owned'] as List)
      if (!stage12Ids.contains(id)) id
  ];
  (wardrobe['equipped'] as Map)
      .removeWhere((slot, _) => stage12Slots.any((s) => s.name == slot));
  return json;
}

void setLevel(GameState s, int level, DateTime at) => s
  ..level = level
  ..missions = MissionState.forLevel(level, at);

void main() {
  group('카탈로그', () {
    test('ID는 겹치지 않고 슬롯마다 무료·Lv.1 기본값이 있다', () {
      final ids = cosmeticDefinitions.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final slot in CosmeticSlot.values) {
        final d = inSlot(slot).firstWhere((d) => d.id == defaultCosmetics[slot]);
        expect((d.cost, d.unlockLevel), (BigInt.zero, 1), reason: slot.name);
        expect(d.collectible, isFalse);
      }
      // Paid items are exactly the collectible ones.
      for (final d in cosmeticDefinitions) {
        expect(d.cost > BigInt.zero, d.collectible, reason: d.id);
      }
    });

    test('분류는 붕어빵 3슬롯, 사장님 5슬롯(피부톤 포함), 가게 3슬롯', () {
      List<CosmeticSlot> slots(CosmeticCategory c) =>
          CosmeticSlot.values.where((s) => s.category == c).toList();
      expect(slots(CosmeticCategory.bungeoppang),
          [CosmeticSlot.fish, CosmeticSlot.pattern, CosmeticSlot.topping]);
      expect(slots(CosmeticCategory.avatar), [
        CosmeticSlot.skin,
        CosmeticSlot.hair,
        CosmeticSlot.outfit,
        CosmeticSlot.hat,
        CosmeticSlot.tool
      ]);
      expect(slots(CosmeticCategory.stall),
          [CosmeticSlot.background, CosmeticSlot.stove, CosmeticSlot.decoration]);
    });

    test('수집 대상은 35종(붕어빵 12, 사장님 10, 가게 13), 피부톤은 제외', () {
      expect(collectibleCosmeticCount, 35);
      expect(collectibleCount(CosmeticCategory.bungeoppang), 12);
      expect(collectibleCount(CosmeticCategory.avatar), 10);
      expect(collectibleCount(CosmeticCategory.stall), 13);
      expect(inSlot(CosmeticSlot.skin).every((d) => d.free), isTrue);
      final stage12Coins = cosmeticDefinitions
          .where((d) => stage12Slots.contains(d.slot))
          .fold(BigInt.zero, (a, d) => a + d.cost);
      expect(stage12Coins, BigInt.from(145));
    });
  });

  group('저장 v10', () {
    test('v9 세이브는 붕어빵 맛·가게를 유지하고 새 슬롯은 기본값을 받는다', () {
      final original = progressed();
      final restored = GameState.fromJson(asV9(original));
      expect(restored.equippedSkin, 'custard');
      expect(restored.equippedCosmetic(CosmeticSlot.background), 'dusk');
      for (final slot in stage12Slots) {
        expect(restored.equippedCosmetic(slot), defaultCosmetics[slot]);
      }
      for (final d in inSlot(CosmeticSlot.skin)) {
        expect(restored.ownsCosmetic(d), isTrue, reason: d.id);
      }
      expect(restored.wardrobe.owned, original.wardrobe.owned);
      expect(restored.wardrobe.equipped, original.wardrobe.equipped);
    });

    test('v10 저장·복원 왕복은 같다', () {
      final s = progressed();
      s.wardrobe.owned.addAll(['beanie', 'heartscale']);
      s.wardrobe.equipped[CosmeticSlot.hat] = 'beanie';
      s.wardrobe.equipped[CosmeticSlot.pattern] = 'heartscale';
      s.wardrobe.equipped[CosmeticSlot.skin] = 'skin3';
      final restored = GameState.fromJson(plainJson(s));
      expect(restored.wardrobe.toJson(), s.wardrobe.toJson());
      expect(plainJson(restored)['formatVersion'], 10);
    });

    test('v10은 엄격하다: 빠진 슬롯·미보유 장착·모르는 ID는 거부', () {
      final base = plainJson(progressed());
      Map<String, dynamic> broken(void Function(Map w) change) {
        final json = plainJson(GameState.fromJson(base));
        change(json['wardrobe'] as Map);
        return json;
      }

      for (final json in [
        broken((w) => (w['equipped'] as Map).remove('hat')),
        broken((w) => (w['equipped'] as Map)['hat'] = 'santa'),
        broken((w) => (w['owned'] as List).add('crown')),
        broken((w) => (w['equipped'] as Map)['hat'] = 'tongs'),
      ]) {
        expect(() => GameState.fromJson(json), throwsFormatException);
      }
      // A stage-12 slot missing from a *v9* save is filled instead.
      expect(() => WardrobeState.fromJson(
          (asV9(progressed())['wardrobe'] as Map).cast<String, dynamic>(),
          legacy: true), returnsNormally);
    });
  });

  group('구매·장착', () {
    late GameController c;
    setUp(() async {
      c = GameController(MemoryGameRepository(), FakeTime()..now = now);
      await c.initialize();
    });
    tearDown(() => c.dispose());

    var funds = 0; // Ledger IDs are single-use.
    void fund(int coins) => c.state.support.transact(
        'test:fund${funds++}', BigInt.from(coins), 'test', c.gameNow);

    test('레벨 미달·코인 부족이면 실패하고, 구매는 원장에 cosmetic:<id>로 남는다', () async {
      fund(2);
      expect(await c.buyOrEquipCosmetic('beanie'), isFalse); // Lv.2 item
      setLevel(c.state, 2, now);
      expect(await c.buyOrEquipCosmetic('beanie'), isFalse); // 3 coins
      fund(1);
      expect(await c.buyOrEquipCosmetic('beanie'), isTrue);
      expect(c.state.support.coins, BigInt.zero);
      expect(c.state.support.ledger, contains('cosmetic:beanie'));
      expect(c.state.equippedCosmetic(CosmeticSlot.hat), 'beanie');
      // Back to the free default and again: no second charge.
      expect(await c.buyOrEquipCosmetic('nohat'), isTrue);
      expect(await c.buyOrEquipCosmetic('beanie'), isTrue);
      expect(c.state.support.coins, BigInt.zero);
    });

    test('피부톤은 무료로 바로 바뀌고 수집 수에 들어가지 않는다', () async {
      final before = c.state.support.ledger.length;
      expect(await c.buyOrEquipCosmetic('skin3'), isTrue);
      expect(c.state.equippedCosmetic(CosmeticSlot.skin), 'skin3');
      expect(c.state.support.ledger.length, before);
      expect(cosmeticsOwnedCount(c.state), 0);
    });

    test('분류별 업적은 해당 분류만 센다', () async {
      AchievementDefinition def(String id) =>
          achievementDefinitions.firstWhere((d) => d.id == id);
      fund(200);
      setLevel(c.state, 10, now);
      for (final id in ['beanie', 'earmuffs', 'ponytail', 'padding']) {
        expect(await c.buyOrEquipCosmetic(id), isTrue);
      }
      expect(await c.buyOrEquipCosmetic('sugar'), isTrue);
      expect(await c.buyOrEquipCosmetic('dusk'), isFalse); // needs production
      expect(achievementProgress(c.state, def('avatar-5')), BigInt.from(4));
      expect(achievementProgress(c.state, def('fish-5')), BigInt.one);
      expect(achievementMet(c.state, def('avatar-5')), isFalse);
      expect(await c.buyOrEquipCosmetic('goldtongs'), isTrue);
      expect(achievementMet(c.state, def('avatar-5')), isTrue);
      expect(await c.claimAchievement('avatar-5'), isTrue);
      expect(achievementTarget(def('cosmetics-all')), BigInt.from(35));
    });

    test('레벨업 알림은 새로 열린 꾸미기를 분류별 한 줄로 알린다', () async {
      final events = <GameEvent>[];
      c.events.listen(events.add);
      c.state
        ..tutorialDone = true
        ..lifetime = BigInt.from(10);
      c.tick();
      expect(await c.claimLevelUp(2), isTrue);
      await pumpEventQueue();
      expect(events.last.kind, GameEventKind.levelUp);
      expect(events.last.details, [
        '새 붕어빵 꾸미기 · 하트 비늘, 슈가파우더',
        '새 사장님 꾸미기 · 묶은 머리, 털 비니',
        '새 가게 꾸미기 · 보랏빛 해질녘, 종이 등불, 무쇠 화로',
      ]);
    });
  });

  group('그리기', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await PixelSprites.load();
    });

    test('모든 붕어빵·사장님 조합이 예외 없이 그려진다', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      for (final f in inSlot(CosmeticSlot.fish)) {
        for (final p in inSlot(CosmeticSlot.pattern)) {
          for (final t in inSlot(CosmeticSlot.topping)) {
            FishPainter(skin: f.id, pattern: p.id, topping: t.id)
                .paint(canvas, const Size(128, 96));
          }
        }
      }
      for (final skin in inSlot(CosmeticSlot.skin)) {
        for (final hair in inSlot(CosmeticSlot.hair)) {
          for (final outfit in inSlot(CosmeticSlot.outfit)) {
            for (final hat in inSlot(CosmeticSlot.hat)) {
              for (final tool in inSlot(CosmeticSlot.tool)) {
                final look = AvatarLook(
                    skin: skin.id,
                    hair: hair.id,
                    outfit: outfit.id,
                    hat: hat.id,
                    tool: tool.id);
                AvatarPainter(look).paint(canvas, const Size(88, 120));
                NightStallPainter(avatar: look, lift: 1)
                    .paint(canvas, const Size(360, 800));
              }
            }
          }
        }
      }
    });
  });

  group('홈·꾸미기 화면', () {
    double lift(WidgetTester tester) => (tester
            .widget<CustomPaint>(find.byKey(const Key('stall-scene')))
            .painter! as NightStallPainter)
        .lift;

    testWidgets('붕어빵을 탭하면 사장님이 집게를 들고, 모션 감소면 가만히 있다',
        (tester) async {
      for (final reduced in [false, true]) {
        await mountGame(tester, const Size(390, 844), reduced: reduced);
        expect(lift(tester), 0);
        await tester.tap(find.byKey(const Key('fish-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: StallScene.liftMs ~/ 2));
        expect(lift(tester), reduced ? 0 : greaterThan(.5), reason: '$reduced');
        await tester.pump(const Duration(milliseconds: StallScene.liftMs));
        expect(lift(tester), 0);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('분류 탭마다 미리보기 대상이 다르고, 장착은 홈에 반영된다', (tester) async {
      final c = await mountGame(tester, const Size(390, 844));
      setLevel(c.state, 2, c.clock.utcNow);
      c.state.support
          .transact('test:fund', BigInt.from(10), 'test', c.gameNow);
      c.tick();
      await tester.pump();
      await tapVisible(tester, const Key('menu-skins'));
      expect(find.byKey(const Key('preview-bungeoppang')), findsOneWidget);
      expect(find.byKey(const Key('cosmetic-slot-hat')), findsNothing);
      await tapVisible(tester, const Key('cosmetic-category-avatar'));
      expect(find.byKey(const Key('preview-avatar')), findsOneWidget);
      expect(find.byKey(const Key('cosmetic-slot-fish')), findsNothing);
      await tapVisible(tester, const Key('cosmetic-slot-hat'));
      await tapVisible(tester, const Key('preview-beanie'));
      expect(find.text('미리보기 · 아직 장착되지 않았습니다'), findsOneWidget);
      expect(c.state.equippedCosmetic(CosmeticSlot.hat), 'nohat');
      await tapVisible(tester, const Key('buy-cosmetic-beanie'));
      await tapVisible(tester, const Key('confirm-support'));
      expect(c.state.equippedCosmetic(CosmeticSlot.hat), 'beanie');
      await tapVisible(tester, const Key('cosmetic-category-stall'));
      expect(find.byKey(const Key('preview-stall')), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      final home = tester
          .widget<CustomPaint>(find.byKey(const Key('stall-scene')))
          .painter! as NightStallPainter;
      expect(home.avatar!.hat, 'beanie');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
