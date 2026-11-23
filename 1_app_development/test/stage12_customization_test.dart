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
import 'package:todays_bungeoppang/ui/cook_cut.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'controller_test.dart' show FakeTime;
import 'stage8_progress_test.dart' show now, plainJson, progressed;

Iterable<CosmeticDefinition> inSlot(CosmeticSlot slot) =>
    cosmeticDefinitions.where((d) => d.slot == slot);

/// The v11 JSON shape: no stage-14 slots, and night/short were the free
/// defaults that every save owned.
Map<String, dynamic> asV11(GameState s) {
  final json = plainJson(s)..['formatVersion'] = 11;
  final wardrobe = json['wardrobe'] as Map;
  final stage14Ids = {
    for (final d in cosmeticDefinitions)
      if (stage14Slots.contains(d.slot) || {'clear', 'long'}.contains(d.id))
        d.id
  };
  final equipped = wardrobe['equipped'] as Map
    ..removeWhere((slot, _) => stage14Slots.any((s) => s.name == slot));
  if (equipped['background'] == 'clear') equipped['background'] = 'night';
  if (equipped['hair'] == 'long') equipped['hair'] = 'short';
  wardrobe['owned'] = {
    for (final id in wardrobe['owned'] as List)
      if (!stage14Ids.contains(id)) id,
    'night',
    'short',
  }.toList();
  return json;
}

/// The v10 JSON shape: no character slot in the wardrobe.
Map<String, dynamic> asV10(GameState s) {
  final json = asV11(s)..['formatVersion'] = 10;
  final wardrobe = json['wardrobe'] as Map;
  wardrobe['owned'] = [
    for (final id in wardrobe['owned'] as List)
      if (!inSlot(CosmeticSlot.character).any((d) => d.id == id)) id
  ];
  (wardrobe['equipped'] as Map).remove(CosmeticSlot.character.name);
  return json;
}

/// The v9 JSON shape: no stage-12 slots in the wardrobe.
Map<String, dynamic> asV9(GameState s) {
  final json = asV10(s)..['formatVersion'] = 9;
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

    test('분류는 붕어빵 3슬롯, 사장님 10슬롯(캐릭터·피부톤 포함), 가게 5슬롯(밤낮 포함)', () {
      List<CosmeticSlot> slots(CosmeticCategory c) =>
          CosmeticSlot.values.where((s) => s.category == c).toList();
      expect(slots(CosmeticCategory.bungeoppang),
          [CosmeticSlot.fish, CosmeticSlot.pattern, CosmeticSlot.topping]);
      expect(slots(CosmeticCategory.avatar), [
        CosmeticSlot.character,
        CosmeticSlot.skin,
        CosmeticSlot.hair,
        CosmeticSlot.top,
        CosmeticSlot.bottom,
        CosmeticSlot.shoes,
        CosmeticSlot.outfit,
        CosmeticSlot.hat,
        CosmeticSlot.accessory,
        CosmeticSlot.tool
      ]);
      expect(slots(CosmeticCategory.stall), [
        CosmeticSlot.background,
        CosmeticSlot.stove,
        CosmeticSlot.decoration,
        CosmeticSlot.lamp,
        CosmeticSlot.time
      ]);
    });

    test('꾸미기 탭은 헤어·의상·소품·붕어빵·가게 (승인 D3)', () {
      List<CosmeticSlot> slots(WardrobeTab t) =>
          CosmeticSlot.values.where((s) => s.tab == t).toList();
      expect(slots(WardrobeTab.hair), [
        CosmeticSlot.character,
        CosmeticSlot.skin,
        CosmeticSlot.hair,
        CosmeticSlot.hat
      ]);
      expect(slots(WardrobeTab.outfit), [
        CosmeticSlot.top,
        CosmeticSlot.bottom,
        CosmeticSlot.shoes,
        CosmeticSlot.outfit
      ]);
      expect(slots(WardrobeTab.props),
          [CosmeticSlot.accessory, CosmeticSlot.tool]);
      for (final s in CosmeticSlot.values) {
        if (s.tab == WardrobeTab.bungeoppang || s.tab == WardrobeTab.stall) {
          expect(s.tab.name, s.category.name, reason: s.name);
        }
      }
    });

    test('수집 대상은 73종(붕어빵 7, 사장님 45, 가게 21), 캐릭터·피부톤은 제외', () {
      // 26번 4-7단계: 하의 6종 추가(v2 그림 전에는 꾸미기 창에서 숨김).
      // 26번 3차 AV3: 낮게 묶은 머리 추가(그림 전에는 숨김).
      expect(collectibleCosmeticCount, 73);
      expect(collectibleCount(CosmeticCategory.bungeoppang), 7); // No flavours.
      expect(collectibleCount(CosmeticCategory.avatar), 45);
      expect(collectibleCount(CosmeticCategory.stall), 21); // + 등불 3
      expect(
          cosmeticDefinitions.fold(BigInt.zero, (a, d) => a + d.cost),
          BigInt.from(550)); // + 하의 6종 5+5+6+7+8+9, 낮게 묶은 머리 5 (AV3)
      expect(inSlot(CosmeticSlot.skin).every((d) => d.free), isTrue);
      expect(inSlot(CosmeticSlot.character).map((d) => d.id), ['girl', 'boy']);
      expect(inSlot(CosmeticSlot.character).every((d) => d.free), isTrue);
      final stage12Coins = cosmeticDefinitions
          .where((d) => stage12Slots.contains(d.slot))
          .fold(BigInt.zero, (a, d) => a + d.cost);
      // 145 at stage 12, plus stage 14's items in those slots and short,
      // less the chef coat and padded vest (18), tops since 26번 4-5단계.
      // 26번 3차 AV3: + 낮게 묶은 머리 5.
      expect(stage12Coins, BigInt.from(210));
    });
  });

  group('저장 v12', () {
    test('v9 세이브는 붕어빵·가게를 유지하고 새 슬롯은 기본값을 받는다', () {
      final original = progressed();
      final restored = GameState.fromJson(asV9(original));
      expect(restored.equippedSkin, original.equippedSkin);
      expect(restored.equippedCosmetic(CosmeticSlot.background), 'dusk');
      for (final slot in stage12Slots) {
        expect(restored.equippedCosmetic(slot), defaultCosmetics[slot]);
      }
      for (final d in inSlot(CosmeticSlot.skin)) {
        expect(restored.ownsCosmetic(d), isTrue, reason: d.id);
      }
      // Nothing is lost compared with the same save at v11, except the old
      // hair default: v9 had no hair slot, so it gets today's default.
      final v11 = GameState.fromJson(asV11(original));
      expect(restored.wardrobe.owned, v11.wardrobe.owned.difference({'short'}));
      for (final slot in CosmeticSlot.values.where(
          (s) => s != CosmeticSlot.fish && !stage12Slots.contains(s))) {
        expect(restored.equippedCosmetic(slot), v11.equippedCosmetic(slot),
            reason: slot.name);
      }
    });

    test('v10 세이브는 사장님 꾸미기를 유지하고 캐릭터는 기본값을 받는다', () {
      final original = progressed();
      original.wardrobe.owned.add('beanie');
      original.wardrobe.equipped[CosmeticSlot.hat] = 'beanie';
      original.wardrobe.equipped[CosmeticSlot.skin] = 'skin2';
      original.wardrobe.owned.add('skin2');
      final restored = GameState.fromJson(asV10(original));
      expect(restored.equippedCosmetic(CosmeticSlot.hat), 'beanie');
      // 26번 3차 AV3: skin tones 2·3 are gone; skin1 instead.
      expect(restored.equippedCosmetic(CosmeticSlot.skin), 'skin1');
      expect(restored.wardrobe.owned, isNot(contains('skin2')));
      expect(restored.equippedCosmetic(CosmeticSlot.character), 'girl');
      for (final d in inSlot(CosmeticSlot.character)) {
        expect(restored.ownsCosmetic(d), isTrue, reason: d.id);
      }
      final v11 = GameState.fromJson(asV11(original));
      expect(restored.wardrobe.owned, v11.wardrobe.owned);
      expect(restored.wardrobe.equipped, v11.wardrobe.equipped);
    });

    test('v11 세이브는 야간 골목·짧은 머리를 유지하고 새 기본값과 새 슬롯을 받는다', () {
      final original = progressed();
      original.wardrobe.owned.add('beanie');
      original.wardrobe.equipped[CosmeticSlot.hat] = 'beanie';
      final v11 = asV11(original);
      final restored = GameState.fromJson(v11);
      expect(restored.equippedCosmetic(CosmeticSlot.hat), 'beanie');
      expect(restored.equippedCosmetic(CosmeticSlot.background),
          (v11['wardrobe'] as Map)['equipped']['background']);
      expect(restored.equippedCosmetic(CosmeticSlot.hair), 'short');
      for (final slot in stage14Slots) {
        expect(restored.equippedCosmetic(slot), defaultCosmetics[slot]);
      }
      // Old free defaults stay owned (and now count as collected); the new
      // defaults are granted.
      for (final id in ['night', 'short', 'clear', 'long', 'tee', 'noacc']) {
        expect(restored.wardrobe.owned, contains(id));
      }
      expect(cosmeticsOwnedCount(restored),
          cosmeticsOwnedCount(original) + 2);
      expect(plainJson(restored)['formatVersion'], GameState.formatVersion);
    });

    test('v12 저장·복원 왕복은 같다', () {
      final s = progressed();
      s.wardrobe.owned.addAll(['beanie', 'heartscale']);
      s.wardrobe.equipped[CosmeticSlot.hat] = 'beanie';
      s.wardrobe.equipped[CosmeticSlot.pattern] = 'heartscale';
      s.wardrobe.equipped[CosmeticSlot.character] = 'boy';
      final restored = GameState.fromJson(plainJson(s));
      expect(restored.wardrobe.toJson(), s.wardrobe.toJson());
      expect(plainJson(restored)['formatVersion'], GameState.formatVersion);
    });

    test('v12는 엄격하다: 빠진 슬롯·미보유 장착·모르는 ID는 거부', () {
      final base = plainJson(progressed());
      Map<String, dynamic> broken(void Function(Map w) change) {
        final json = plainJson(GameState.fromJson(base));
        change(json['wardrobe'] as Map);
        return json;
      }

      for (final json in [
        broken((w) => (w['equipped'] as Map).remove('hat')),
        broken((w) => (w['equipped'] as Map).remove('character')),
        broken((w) => (w['equipped'] as Map).remove('accessory')),
        broken((w) => (w['equipped'] as Map)['top'] = 'cardigan'),
        broken((w) => (w['equipped'] as Map)['hat'] = 'santa'),
        broken((w) => (w['owned'] as List).add('crown')),
        broken((w) => (w['equipped'] as Map)['hat'] = 'tongs'),
      ]) {
        expect(() => GameState.fromJson(json), throwsFormatException);
      }
      // A slot missing from an older save is filled instead.
      expect(() => WardrobeState.fromJson(
          (asV9(progressed())['wardrobe'] as Map).cast<String, dynamic>(),
          version: 9), returnsNormally);
      expect(() => WardrobeState.fromJson(
          (asV10(progressed())['wardrobe'] as Map).cast<String, dynamic>(),
          version: 10), returnsNormally);
      expect(() => WardrobeState.fromJson(
          (asV11(progressed())['wardrobe'] as Map).cast<String, dynamic>(),
          version: 11), returnsNormally);
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

    test('피부톤은 1만 있고(26번 3차 AV3) 수집 수에 들어가지 않는다', () async {
      final before = c.state.support.ledger.length;
      expect(await c.buyOrEquipCosmetic('skin1'), isTrue);
      expect(c.state.equippedCosmetic(CosmeticSlot.skin), 'skin1');
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
      expect(achievementTarget(def('cosmetics-all')), BigInt.from(73));
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
        '새 사장님 꾸미기 · 묶은 머리, 털 비니, 크림 긴팔 외 6개',
        '새 가게 꾸미기 · 보랏빛 해질녘, 종이 등불, 무쇠 화로 외 2개',
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
      // Every avatar item once per character, over the defaults.
      final avatarSlots = CosmeticSlot.values
          .where((s) => s.category == CosmeticCategory.avatar);
      for (final character in inSlot(CosmeticSlot.character)) {
        for (final slot in avatarSlots) {
          for (final item in inSlot(slot)) {
            String equipped(CosmeticSlot s) => s == slot
                ? item.id
                : s == CosmeticSlot.character
                    ? character.id
                    : defaultCosmetics[s]!;
            final look = AvatarLook.of(equipped);
            AvatarPainter(look).paint(canvas, const Size(88, 120));
            NightStallPainter(avatar: look).paint(canvas, const Size(360, 800));
            CookCutPainter(look: look, lift: 1)
                .paint(canvas, const Size(120, 100));
          }
        }
      }
    });
  });
}
