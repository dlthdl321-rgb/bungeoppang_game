import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;

void main() {
  late FakeTime clock;
  late MemoryGameRepository repo;
  late GameController c;
  setUp(() async {
    clock = FakeTime()..now = DateTime.utc(2026, 10, 5);
    repo = MemoryGameRepository();
    c = GameController(repo, clock);
    await c.initialize();
    c.state.level = 10;
    c.state.missions = MissionState.forLevel(10, clock.now);
    c.state.lifetime = BigInt.parse('20000000000000');
    c.state.support.transact('test:fund', BigInt.from(100), 'test', clock.now);
  });
  tearDown(() => c.dispose());
  test('독립 장착 슬롯과 재장착 무과금 및 저장 복원', () async {
    for (final id in ['cocoa', 'dusk', 'copper', 'lantern']) {
      expect(await c.buyOrEquipCosmetic(id), isTrue);
    }
    expect(c.state.support.coins, BigInt.from(72));
    expect(await c.buyOrEquipCosmetic('night'), isTrue);
    expect(await c.buyOrEquipCosmetic('dusk'), isTrue);
    expect(c.state.support.coins, BigInt.from(72));
    final restored = (await repo.load())!;
    expect(restored.equippedCosmetic(CosmeticSlot.fish), 'cocoa');
    expect(restored.equippedCosmetic(CosmeticSlot.background), 'dusk');
    expect(restored.equippedCosmetic(CosmeticSlot.stove), 'copper');
    expect(restored.equippedCosmetic(CosmeticSlot.decoration), 'lantern');
  });
  test('해금, 잔액, 저장 실패 및 부정 슬롯 검증', () async {
    c.state.level = 1;
    c.state.missions = MissionState.forLevel(1, clock.now);
    expect(await c.buyOrEquipCosmetic('dusk'), isFalse);
    c.state.level = 10;
    c.state.missions = MissionState.forLevel(10, clock.now);
    repo.failNextSave = true;
    expect(await c.buyOrEquipCosmetic('dusk'), isFalse);
    expect(c.state.support.coins, BigInt.from(100));
    expect(c.state.wardrobe.owned.contains('dusk'), isFalse);
    c.state.support
        .transact('test:spend', -BigInt.from(100), 'test', clock.now);
    expect(await c.buyOrEquipCosmetic('dusk'), isFalse);
    final json = c.state.toJson();
    (json['wardrobe'] as Map)['equipped']['stove'] = 'night';
    expect(() => GameState.fromJson(json), throwsFormatException);
  });
  test('v5 마이그레이션은 기존 재화와 외형을 보존하고 슬롯 기본값만 추가', () {
    c.state.ownedSkins.add('custard');
    c.state.equippedSkin = 'custard';
    final json = c.state.toJson()
      ..['formatVersion'] = 5
      ..remove('wardrobe')
      ..remove('records')
      ..remove('weekly')
      ..remove('achievements');
    final restored = GameState.fromJson(json);
    expect(restored.support.toJson(), c.state.support.toJson());
    expect(restored.invites.toJson(), c.state.invites.toJson());
    expect(restored.equippedSkin, 'custard');
    expect(restored.equippedCosmetic(CosmeticSlot.background), 'night');
    expect(restored.achievements.claimed, isEmpty);
  });
  // Stage 8 removed the fictional ranking and the fixed mock event season;
  // records/weekly/achievement tests live in stage8_progress_test.dart.
}
