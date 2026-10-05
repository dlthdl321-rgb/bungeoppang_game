import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;

/// Holds the next save open until [gate] completes, so a command can be
/// issued while a commit is in flight.
class GatedRepository extends MemoryGameRepository {
  Completer<void>? gate;
  @override
  Future<void> save(GameState state) async {
    final g = gate;
    if (g != null) {
      gate = null;
      await g.future;
    }
    await super.save(state);
  }
}

Map<String, dynamic> plainJson(GameState s) =>
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

GameState progressed(DateTime now) {
  final s = GameState.initial(now)
    ..buns = BigInt.parse('123456789012345678901234567890')
    ..lifetime = BigInt.parse('999999999999999999999')
    ..level = 3
    ..tutorialDone = true;
  s.missions = MissionState.forLevel(3, now);
  s.upgradeCounts['tap_1'] = 7;
  s.support.transact('test:fund', BigInt.from(42), 'test', now);
  s.support.inventory['butter'] = BigInt.from(3);
  s.ownedSkins.add('custard');
  s.equippedSkin = 'custard';
  s.wardrobe.owned.add('dusk');
  s.wardrobe.equipped[CosmeticSlot.background] = 'dusk';
  return s;
}

void expectProgressKept(GameState restored, GameState original) {
  expect(restored.buns, original.buns);
  expect(restored.lifetime, original.lifetime);
  expect(restored.level, original.level);
  expect(restored.support.coins, original.support.coins);
  expect(restored.support.inventory, original.support.inventory);
  expect(restored.upgradeCounts, original.upgradeCounts);
  expect(restored.ownedSkins, original.ownedSkins);
  expect(restored.equippedSkin, original.equippedSkin);
  expect(restored.wardrobe.toJson(), original.wardrobe.toJson());
}

void main() {
  final now = DateTime.utc(2026, 10, 5);

  // Stage 8 dropped the per-event save field, so bug (a) now means: whatever
  // a v6 save holds under 'events', it loads into v7 with progress intact.
  group('a. v6 저장의 이벤트 항목은 상태와 무관하게 읽힌다', () {
    for (final entry in <String, Object?>{
      '항목 누락': <String, Object?>{},
      '필드 없음': null,
      '맵이 아닌 값': 'broken',
    }.entries) {
      test('${entry.key}: 진행도 보존', () {
        final original = progressed(now);
        final json = plainJson(original)..['formatVersion'] = 6;
        for (final key in ['records', 'weekly', 'achievements']) {
          json.remove(key);
        }
        if (entry.value == null) {
          json.remove('events');
        } else {
          json['events'] = entry.value;
        }
        final restored = GameState.fromJson(json);
        expectProgressKept(restored, original);
      });
    }
  });

  group('b. 보유 붕어빵 외형은 카탈로그 fish 슬롯 기준으로 복원', () {
    const matcha =
        CosmeticDefinition('matcha', '말차 붕어빵', CosmeticSlot.fish, '9', 1);
    test('카탈로그에 새로 추가된 붕어빵 외형을 보존', () {
      final s = GameState.initial(now)
        ..ownedSkins.add('matcha')
        ..equippedSkin = 'matcha';
      final restored = GameState.fromJson(plainJson(s),
          cosmetics: [...cosmeticDefinitions, matcha]);
      expect(restored.ownedSkins, {'redbean', 'matcha'});
      expect(restored.equippedSkin, 'matcha');
    });
    test('fish 슬롯이 아닌 ID와 모르는 ID는 보유 목록에서 제외', () {
      final json = plainJson(GameState.initial(now))
        ..['ownedSkins'] = ['redbean', 'dusk', 'unknown'];
      expect(GameState.fromJson(json).ownedSkins, {'redbean'});
    });
    test('현재 카탈로그의 모든 붕어빵 외형은 왕복 저장 후 유지', () {
      final fish =
          cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.fish);
      final s = GameState.initial(now)
        ..ownedSkins.addAll(fish.map((d) => d.id))
        ..equippedSkin = fish.last.id;
      final restored = GameState.fromJson(plainJson(s));
      expect(restored.ownedSkins, fish.map((d) => d.id).toSet());
      expect(restored.equippedSkin, fish.last.id);
    });
  });

  group('d. 설정·튜토리얼 변경은 진행 중인 저장과 경합해도 보존', () {
    late FakeTime clock;
    late GatedRepository repo;
    late GameController c;
    setUp(() async {
      clock = FakeTime();
      repo = GatedRepository();
      c = GameController(repo, clock);
      await c.initialize();
      c.state.buns = BigInt.from(1000);
    });
    tearDown(() => c.dispose());

    test('commit 도중 updateSettings는 저장소에 반영된다', () async {
      repo.gate = Completer<void>();
      final gate = repo.gate!;
      final buy = c.buyUpgrade(upgrades.first, 1);
      expect(c.busy, isTrue);
      final settings = c.updateSettings(vibration: false);
      gate.complete();
      expect(await buy, isTrue);
      await settings;
      expect(c.state.settings.vibration, isFalse);
      expect((await repo.load())!.settings.vibration, isFalse);
    });
    test('commit 실패 롤백이 그 사이 바꾼 설정을 지우지 않는다', () async {
      repo
        ..gate = Completer<void>()
        ..failNextSave = true;
      final gate = repo.gate!;
      final buy = c.buyUpgrade(upgrades.first, 1);
      final settings = c.updateSettings(reduceMotion: true);
      gate.complete();
      expect(await buy, isFalse);
      await settings;
      expect(c.state.settings.reduceMotion, isTrue);
      expect((await repo.load())!.settings.reduceMotion, isTrue);
      expect(c.state.buns, BigInt.from(1000));
    });
    test('commit 도중 finishTutorial은 저장소에 반영되고 롤백되지 않는다', () async {
      repo
        ..gate = Completer<void>()
        ..failNextSave = true;
      final gate = repo.gate!;
      final buy = c.buyUpgrade(upgrades.first, 1);
      final tutorial = c.finishTutorial();
      gate.complete();
      await buy;
      await tutorial;
      expect(c.state.tutorialDone, isTrue);
      expect((await repo.load())!.tutorialDone, isTrue);
    });
  });

  group('e. 붕어빵 외형 구매도 누적 생산 해금 조건을 검사', () {
    const locked = CosmeticDefinition(
        'matcha', '말차 붕어빵', CosmeticSlot.fish, '1', 1, '1000000');
    test('누적 생산이 부족하면 코인을 쓰지 않고 거부', () async {
      final clock = FakeTime(), repo = MemoryGameRepository();
      final c = GameController(repo, clock,
          cosmetics: [...cosmeticDefinitions, locked]);
      await c.initialize();
      c.state.support
          .transact('test:fund', BigInt.from(100), 'test', clock.now);
      expect(await c.buyOrEquipCosmetic('matcha'), isFalse);
      expect(c.state.support.coins, BigInt.from(100));
      expect(c.state.ownedSkins.contains('matcha'), isFalse);
      expect(c.state.equippedSkin, 'redbean');
      c.dispose();
    });
    test('기존 붕어빵 구매 경로와 거래 ID는 유지', () async {
      final clock = FakeTime(), repo = MemoryGameRepository();
      final c = GameController(repo, clock);
      await c.initialize();
      c.state.level = 3;
      c.state.missions = MissionState.forLevel(3, clock.now);
      c.state.support
          .transact('test:fund', BigInt.from(100), 'test', clock.now);
      expect(await c.buyOrEquipCosmetic('custard'), isTrue);
      expect(c.state.support.ledger.containsKey('skin:custard'), isTrue);
      expect(c.state.support.coins, BigInt.from(94));
      expect(await c.buyOrEquip(skins.first), isTrue);
      expect(c.state.equippedSkin, 'redbean');
      expect(c.state.support.coins, BigInt.from(94));
      c.dispose();
    });
  });

  group('i. 설정 문자열 파싱과 랭킹 정렬 캐시', () {
    test('꾸미기 가격은 매번 다시 파싱하지 않는다', () {
      final d = cosmeticDefinitions.firstWhere((d) => d.id == 'custard');
      expect(identical(d.cost, d.cost), isTrue);
    });
    // Ranking cache test removed with the fictional ranking (stage 8).
  });
}
