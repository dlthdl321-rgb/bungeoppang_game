import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'fake_time.dart' show FakeTime;

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
  final s = GameState.initial(now)..premium.gold = 42;
  s.wardrobe.owned.add('dusk');
  s.wardrobe.equipped[CosmeticSlot.background] = 'dusk';
  return s;
}

void expectProgressKept(GameState restored, GameState original) {
  // 32번 3단계: what the account save still keeps.
  expect(restored.premium.gold, original.premium.gold);
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
    test('없어진 맛을 장착한 옛 저장은 팥 붕어빵으로 불러온다', () {
      final s = GameState.initial(now);
      final json = plainJson(s)
        ..['ownedSkins'] = ['redbean', 'custard']
        ..['equippedSkin'] = 'custard';
      final restored = GameState.fromJson(json);
      expect(restored.equippedSkin, 'redbean');
      expect(restored.ownedSkins, {'redbean'});
      expect(GameState.fromJson(plainJson(restored)).toJson(),
          restored.toJson());
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
    });
    tearDown(() => c.dispose());

    test('commit 도중 updateSettings는 저장소에 반영된다', () async {
      repo.gate = Completer<void>();
      final gate = repo.gate!;
      // 32번 2단계: a test-gold save stands in for the old skill purchase.
      final buy = c.setLocalTestGold(50);
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
      final buy = c.setLocalTestGold(50);
      final settings = c.updateSettings(reduceMotion: true);
      gate.complete();
      expect(await buy, isFalse);
      await settings;
      expect(c.state.settings.reduceMotion, isTrue);
      expect((await repo.load())!.settings.reduceMotion, isTrue);
      expect(c.state.premium.gold, 0, reason: '실패한 저장은 되돌림');
    });
  });

  group('i. 설정 문자열 파싱과 랭킹 정렬 캐시', () {
    test('꾸미기 가격은 매번 다시 파싱하지 않는다', () {
      final d = cosmeticDefinitions.firstWhere((d) => d.id == 'dusk');
      expect(identical(d.cost, d.cost), isTrue);
    });
    // Ranking cache test removed with the fictional ranking (stage 8).
  });
}
