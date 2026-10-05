import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/game_events.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/prestige_config.dart';
import 'package:todays_bungeoppang/prestige_rules.dart';
import 'package:todays_bungeoppang/progress_state.dart';
import 'package:todays_bungeoppang/support_rules.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/fish_painter.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'controller_test.dart' show FakeTime;
import 'level_missions_test.dart' show setRate;
import 'level_missions_widget_test.dart' show tapVisible;
import 'stage8_progress_test.dart' show asVersion, plainJson, progressed;
import 'widget_test.dart' show mountGame;

final now = DateTime.utc(2026, 10, 5, 3);
final firstRunLifetime = BigInt.parse('2000000000000000000'); // ~2e18.

Future<GameController> atMaxLevel(
    {MemoryGameRepository? repo, BigInt? lifetime}) async {
  final r = repo ?? MemoryGameRepository();
  final c = GameController(r, FakeTime()..now = now);
  await c.initialize();
  c.state
    ..level = 10
    ..tutorialDone = true
    ..lifetime = lifetime ?? firstRunLifetime
    ..buns = BigInt.parse('123456789');
  c.state.missions = MissionState.forLevel(10, now);
  for (var l = 2; l <= 10; l++) {
    c.state.levelRewards[l] = LevelRewardRecord(
        level: l,
        seasonId: c.state.missions.seasonId,
        source: 'claim',
        amount: BigInt.from(3),
        claimedAtUtc: now);
  }
  c.state.upgradeCounts['auto_16'] = 15;
  c.state.upgradeCounts['tap_1'] = 30;
  c.state.support.transact('test:fund', BigInt.from(77), 'test', now);
  c.state.support.inventory['fairy'] = BigInt.from(4);
  c.state.ownedSkins.add('custard');
  c.state.equippedSkin = 'custard';
  c.state.records.bestAutoRate = autoRate(c.state);
  return c;
}

void main() {
  group('명성 별 공식', () {
    test('정수 세제곱근은 정확한 바닥값', () {
      final r = math.Random(5);
      for (var i = 0; i < 300; i++) {
        final x = BigInt.from(r.nextInt(1 << 30)) *
            BigInt.from(r.nextInt(1 << 30)) *
            BigInt.from(1 + r.nextInt(1000));
        final c = bigCbrt(x);
        expect(c * c * c <= x, isTrue);
        final n = c + BigInt.one;
        expect(n * n * n > x, isTrue);
      }
      final huge = BigInt.from(10).pow(90) + BigInt.one;
      expect(bigCbrt(huge), BigInt.from(10).pow(30));
      expect(bigCbrt(BigInt.zero), BigInt.zero);
    });
    test('누적 생산 1경·8경·200경에서 별 1·2·5개', () {
      expect(totalStarsFor(BigInt.parse(prestigeStarUnit) - BigInt.one),
          BigInt.zero);
      expect(totalStarsFor(BigInt.parse(prestigeStarUnit)), BigInt.one);
      expect(totalStarsFor(BigInt.parse('80000000000000000')), BigInt.two);
      expect(totalStarsFor(firstRunLifetime), BigInt.from(5));
    });
  });

  group('새 노점 열기', () {
    test('Lv.10 전에는 열 수 없다', () async {
      final c = await atMaxLevel();
      c.state.level = 9;
      c.state.missions = MissionState.forLevel(9, now);
      expect(canPrestige(c.state), isFalse);
      expect(await c.prestige(), isFalse);
      c.dispose();
    });

    test('이번 회차만 초기화하고 나머지는 유지, 레벨업 코인은 다시 주지 않는다', () async {
      final repo = MemoryGameRepository();
      final c = await atMaxLevel(repo: repo);
      c.state.achievements.claimed.add('bake-1');
      c.state.support
          .transact('achievement:bake-1', BigInt.one, 'test', now); // 78 coins.
      final events = <GameEvent>[];
      c.events.listen(events.add);
      final keep = (
        coins: c.state.support.coins,
        lifetime: c.state.lifetime,
        fairy: c.state.support.inventory['fairy'],
        skins: Set.of(c.state.ownedSkins),
        best: c.state.records.bestAutoRate,
      );
      expect(await c.prestige(), isTrue);
      final s = c.state;
      expect(s.prestige.stars, 5);
      expect(s.prestige.count, 1);
      expect(s.level, 1);
      expect(s.buns, BigInt.zero);
      expect(s.upgradeCounts.values.every((n) => n == 0), isTrue);
      expect(s.missions.targetLevel, 2);
      expect(s.support.coins, keep.coins);
      expect(s.lifetime, keep.lifetime);
      expect(s.support.inventory['fairy'], keep.fairy);
      expect(s.ownedSkins, keep.skins);
      expect(s.equippedSkin, 'custard');
      expect(s.achievements.claimed, contains('bake-1'));
      expect(s.records.bestAutoRate, keep.best);
      expect(s.levelRewards.length, 9);
      // Saved, and immediately offering no second prestige.
      expect((await repo.load())!.prestige.stars, 5);
      expect(canPrestige(s), isFalse);
      // Re-climbing pays no level coins a second time.
      s.lifetime += BigInt.from(10);
      expect(await c.claimLevelUp(2), isTrue);
      expect(s.support.coins, keep.coins);
      await pumpEventQueue();
      expect(events.first.kind, GameEventKind.prestige);
      expect(events.first.amount, BigInt.from(5));
      expect(events.last.kind, GameEventKind.levelUp);
      expect(events.last.amount, isNull);
      expect(await c.claimAchievement('prestige-1'), isTrue);
      expect(s.achievements.titles, contains('노점 개척자'));
      c.dispose();
    });

    test('저장 실패 시 별과 진행을 함께 되돌린다', () async {
      final repo = MemoryGameRepository();
      final c = await atMaxLevel(repo: repo);
      final before = plainJson(c.state);
      repo.failNextSave = true;
      expect(await c.prestige(), isFalse);
      final after = plainJson(c.state);
      for (final key in ['prestige', 'level', 'buns', 'upgradeCounts']) {
        expect(after[key], before[key], reason: key);
      }
      c.dispose();
    });

    test('별 1개당 생산 +5%: 클릭·자동·표시 속도, 분할 정산 일치', () async {
      final c = await atMaxLevel();
      expect(await c.prestige(), isTrue);
      setRate(c.state, BigInt.from(1000000));
      c.state.upgradeCounts['tap_1'] = 99; // tapRate 100.
      expect(prestigePermille(c.state), 1250);
      expect(c.currentAutoRate, BigInt.from(1250000));
      expect(c.currentTapRate, BigInt.from(125));
      expect(c.tap(), BigInt.from(125));
      final a = c.state.copy(), b = c.state.copy();
      final start = c.state.lastSettledUtc;
      var gainA = BigInt.zero;
      for (var i = 0; i < 10; i++) {
        gainA += settleFor(a, start.add(Duration(milliseconds: i * 100)), 100);
      }
      final gainB = settleFor(b, start, 1000);
      expect(gainA, gainB);
      expect(gainB, BigInt.from(1250000)); // One active second, +25%.
      c.dispose();
    });

    test('두 번째 개업은 누적 생산이 더 쌓여야 한다', () async {
      final c = await atMaxLevel();
      expect(await c.prestige(), isTrue);
      c.state
        ..level = 10
        ..missions = MissionState.forLevel(10, now);
      expect(canPrestige(c.state), isFalse);
      c.state.lifetime = BigInt.parse('6400000000000000000'); // cbrt(640)=8.
      expect(prestigeStarsAvailable(c.state), BigInt.from(3));
      expect(await c.prestige(), isTrue);
      expect(c.state.prestige.stars, 8);
      expect(c.state.prestige.count, 2);
      c.dispose();
    });
  });

  group('저장 v9', () {
    test('v2~v8 저장은 진행도를 잃지 않고 프레스티지 0으로 이전', () {
      final original = progressed();
      for (var version = 2; version <= 8; version++) {
        final json = version >= 7
            ? (plainJson(original)
              ..['formatVersion'] = version
              ..remove('prestige'))
            : asVersion(original, version);
        if (version == 7) {
          (json['settings'] as Map)
            ..remove('soundEffects')
            ..remove('music')
            ..remove('sfxVolume')
            ..remove('musicVolume');
        }
        final restored = GameState.fromJson(json);
        expect(restored.buns, original.buns, reason: 'v$version');
        expect(restored.level, original.level, reason: 'v$version');
        expect(restored.support.coins, BigInt.from(42), reason: 'v$version');
        expect(restored.ownedSkins, original.ownedSkins);
        if (version >= 4) {
          expect(restored.support.inventory, original.support.inventory);
        }
        if (version >= 6) {
          expect(restored.wardrobe.toJson(), original.wardrobe.toJson());
        }
        expect(restored.prestige.toJson(), PrestigeState().toJson());
      }
    });
    test('v9 왕복과 손상 거부', () async {
      final c = await atMaxLevel();
      expect(await c.prestige(), isTrue);
      final json = plainJson(c.state);
      expect(plainJson(GameState.fromJson(json)), json);
      final tooMany = plainJson(c.state);
      (tooMany['prestige'] as Map)['stars'] = 6;
      expect(() => GameState.fromJson(tooMany), throwsFormatException);
      final noCount = plainJson(c.state);
      (noCount['prestige'] as Map)
        ..['count'] = 0
        ..['lastAtUtc'] = null;
      expect(() => GameState.fromJson(noCount), throwsFormatException);
      c.dispose();
    });
  });

  group('새 꾸미기 11종', () {
    const added = {
      'sweetpotato': (CosmeticSlot.fish, '8', 4),
      'matcha': (CosmeticSlot.fish, '10', 5),
      'strawberry': (CosmeticSlot.fish, '14', 7),
      'snow': (CosmeticSlot.background, '7', 3),
      'cherry': (CosmeticSlot.background, '10', 6),
      'seaside': (CosmeticSlot.background, '14', 8),
      'castiron': (CosmeticSlot.stove, '6', 2),
      'golden': (CosmeticSlot.stove, '15', 9),
      'starlights': (CosmeticSlot.decoration, '5', 3),
      'windchime': (CosmeticSlot.decoration, '9', 5),
      'snowman': (CosmeticSlot.decoration, '12', 7),
    };
    test('승인된 가격·해금으로 구매·장착·저장 복원', () async {
      final repo = MemoryGameRepository();
      final c = await atMaxLevel(repo: repo);
      c.state.support.transact('test:more', BigInt.from(200), 'test', now);
      for (final e in added.entries) {
        final d = cosmeticDefinitions.firstWhere((d) => d.id == e.key);
        expect((d.slot, d.price, d.unlockLevel), e.value, reason: e.key);
        expect(await c.buyOrEquipCosmetic(e.key), isTrue, reason: e.key);
        expect(c.state.equippedCosmetic(d.slot), e.key);
      }
      final restored = (await repo.load())!;
      for (final id in added.keys) {
        expect(
            restored.ownsCosmetic(
                cosmeticDefinitions.firstWhere((d) => d.id == id)),
            isTrue);
      }
      c.dispose();
    });
    test('붕어빵 외형마다 겉면·속 색이 다르다', () {
      final fish = cosmeticDefinitions
          .where((d) => d.slot == CosmeticSlot.fish)
          .map((d) => FishPainter(skin: d.id));
      expect(fish.map((p) => p.filling).toSet().length, fish.length);
      expect(fish.map((p) => p.crust.first).toSet().length, fish.length);
    });
    testWidgets('모든 배경·화로·장식 조합을 예외 없이 그린다', (tester) async {
      await tester.runAsync(PixelSprites.load);
      for (final bg in cosmeticDefinitions
          .where((d) => d.slot == CosmeticSlot.background)) {
        for (final stove
            in cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.stove)) {
          for (final deco in cosmeticDefinitions
              .where((d) => d.slot == CosmeticSlot.decoration)) {
            await tester.pumpWidget(SizedBox(
                width: 390,
                height: 600,
                child: CustomPaint(
                    painter: NightStallPainter(
                        background: bg.id,
                        stove: stove.id,
                        decoration: deco.id))));
            expect(tester.takeException(), isNull,
                reason: '${bg.id}/${stove.id}/${deco.id}');
          }
        }
      }
    });
  });

  for (final size in const [Size(360, 800), Size(390, 844), Size(412, 915)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('새 노점 카드·확인·새 꾸미기 ${size.width}/$scale overflow 없음',
          (tester) async {
        final c = await mountGame(tester, size,
            textScale: scale, maxLevel: true, developerTools: false);
        c.state.lifetime = firstRunLifetime;
        for (var l = 2; l <= 10; l++) {
          c.state.levelRewards[l] = LevelRewardRecord(
              level: l,
              seasonId: c.state.missions.seasonId,
              source: 'claim',
              amount: BigInt.from(3),
              claimedAtUtc: now);
        }
        c.state.support
            .transact('test:fund', BigInt.from(200), 'test', c.gameNow);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-skins'));
        for (final slot in CosmeticSlot.values) {
          await tapVisible(
              tester, Key('cosmetic-category-${slot.category.name}'));
          await tapVisible(tester, Key('cosmetic-slot-${slot.name}'));
          final last = cosmeticDefinitions.lastWhere((d) => d.slot == slot);
          await tapVisible(tester, Key('preview-${last.id}'));
          expect(tester.takeException(), isNull, reason: last.id);
        }
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tapVisible(tester, const Key('level-mission-entry'));
        expect(find.byKey(const Key('prestige-card')), findsOneWidget);
        await tapVisible(tester, const Key('prestige-open'));
        expect(tester.takeException(), isNull);
        await tapVisible(tester, const Key('confirm-support'));
        await tester.pumpAndSettle();
        expect(c.state.level, 1);
        expect(c.state.prestige.stars, 5);
        while (find.byTooltip('닫기').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const Key('home-prestige')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

/// Settles [ms] of active production from [from] on a detached state copy.
BigInt settleFor(GameState s, DateTime from, int ms) => settleProduction(
    s, from, from.add(Duration(milliseconds: ms)), autoRate(s));
