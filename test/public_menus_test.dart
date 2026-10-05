import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/event_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/menu_rules.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/ranking.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;

void main() {
  late FakeTime clock;
  late MemoryGameRepository repo;
  late GameController c;
  final event = eventDefinitions.first;
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
      ..remove('events');
    final restored = GameState.fromJson(json);
    expect(restored.support.toJson(), c.state.support.toJson());
    expect(restored.invites.toJson(), c.state.invites.toJson());
    expect(restored.equippedSkin, 'custard');
    expect(restored.equippedCosmetic(CosmeticSlot.background), 'night');
    expect(restored.events[event.id]!.receipts, isEmpty);
  });
  test('전체·친구 순위는 BigInt 정렬, 공동 순위, 내 상태 반영', () {
    expect(rankingFor(BigInt.zero).last.isMe, isTrue);
    final tied = rankingFor(BigInt.parse(rankingFixtures.first.$3));
    expect(tied.where((e) => e.rank == 1).length, 2);
    expect(tied[2].rank, 3);
    expect(rankingFor(BigInt.parse('1${'0' * 100}')).first.isMe, isTrue);
    expect(rankingFor(BigInt.one, friendsOnly: true).length, 8);
  });
  test('이벤트 참여·선행 단계·중복·복원 후 재수령 방지', () async {
    expect(await c.claimEventReward(event.id, 'warmup'), isFalse);
    expect(await c.joinEvent(event.id), isTrue);
    expect(await c.joinEvent(event.id), isFalse);
    expect(await c.claimEventReward(event.id, 'final'), isFalse);
    for (final r in event.rewards) {
      expect(await c.claimEventReward(event.id, r.id), isTrue);
      expect(await c.claimEventReward(event.id, r.id), isFalse);
    }
    expect(c.state.support.coins, BigInt.from(120));
    final restored = GameController(repo, clock);
    await restored.initialize();
    expect(restored.state.events[event.id]!.receipts.length, 4);
    expect(await restored.claimEventReward(event.id, 'final'), isFalse);
    expect(restored.state.support.coins, BigInt.from(120));
    restored.dispose();
  });
  test('마지막 한 자리 동시 요청, 초과 소진, 음수 수량 방지', () async {
    await c.joinEvent(event.id);
    final r = event.rewards.first;
    await c.simulateEventClaims(
        event.id, r.id, eventRemaining(c.state, event, r) - BigInt.one);
    final results = await Future.wait([
      c.claimEventReward(event.id, r.id),
      c.claimEventReward(event.id, r.id)
    ]);
    expect(results.where((v) => v).length, 1);
    expect(eventRemaining(c.state, event, r), BigInt.zero);
    expect(
        await c.simulateEventClaims(event.id, r.id, BigInt.from(100)), isFalse);
    expect(
        await c.simulateEventClaims(event.id, 'final', -BigInt.one), isFalse);
    expect(
        await c.simulateEventClaims(
            event.id, 'final', BigInt.parse('9999999999999999999999')),
        isTrue);
    expect(eventRemaining(c.state, event, event.rewards.last), BigInt.zero);
  });
  test('이벤트 저장 실패는 원장·재고·수령 기록을 함께 롤백', () async {
    repo.failNextSave = true;
    expect(await c.joinEvent(event.id), isFalse);
    expect(c.state.events[event.id]!.joined, isFalse);
    await c.joinEvent(event.id);
    final before = c.state.events[event.id]!.toJson();
    repo.failNextSave = true;
    expect(await c.claimEventReward(event.id, 'warmup'), isFalse);
    expect(c.state.events[event.id]!.toJson(), before);
    expect(c.state.support.coins, BigInt.from(100));
    expect(await c.claimEventReward(event.id, 'warmup'), isTrue);
  });
  test('시작 포함·종료 미포함 및 시계 되돌리기로 종료 재개 불가', () async {
    expect(
        eventPhase(
            event, event.start.subtract(const Duration(microseconds: 1))),
        EventPhase.upcoming);
    expect(eventPhase(event, event.start), EventPhase.active);
    expect(eventPhase(event, event.end), EventPhase.ended);
    await c.joinEvent(event.id);
    clock.advance(event.end.difference(clock.now).inMilliseconds);
    c.tick();
    expect(await c.claimEventReward(event.id, 'warmup'), isFalse);
    clock.now = event.start;
    expect(await c.claimEventReward(event.id, 'warmup'), isFalse);
  });
  test('손상 재고 및 원장 없는 수령 기록 거부', () async {
    await c.joinEvent(event.id);
    await c.claimEventReward(event.id, 'warmup');
    final broken = c.state.toJson();
    broken['events'][event.id]['claimedCounts']['warmup'] = '10001';
    expect(() => GameState.fromJson(broken), throwsFormatException);
    c.state.support.ledger.remove('event:${event.id}:warmup');
    expect(() => GameState.fromJson(c.state.toJson()), throwsFormatException);
  });
}
