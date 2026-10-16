import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/invite_models.dart';
import 'package:todays_bungeoppang/invite_repository.dart';
import 'package:todays_bungeoppang/invite_rules.dart';
import 'package:todays_bungeoppang/mock_invite_repository.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;
import 'economy_persistence_test.dart' show JsonRepository;
import 'economy_simulation_test.dart' show SlowRepository;
import 'level_missions_test.dart' show atLevel;

Future<String> click(GameController c, String player) async {
  expect(await c.simulateInvitation(InviteEventKind.clicked, player), isTrue);
  return c.state.invites.visits.values.last.id;
}

Future<void> step(GameController c, String visit, InviteEventKind kind) async {
  final v = c.state.invites.visits[visit]!;
  expect(
      await c.simulateInvitation(kind, v.playerId,
          visitId: visit, ticketId: v.ticketId),
      isTrue);
}

Future<String> succeed(GameController c, String player,
    {bool fresh = true}) async {
  final id = await click(c, player);
  if (fresh) await step(c, id, InviteEventKind.classifiedNew);
  await step(
      c,
      id,
      fresh
          ? InviteEventKind.reachedLevelOne
          : InviteEventKind.existingParticipated);
  return id;
}

class ServerContractRepository implements InvitationRepository {
  List<InviteEvent> receipts = [];
  Set<String> acknowledged = {};
  Completer<void>? delay;
  bool fail = false;
  @override
  InviteOrigin get origin => InviteOrigin.server;
  @override
  Future<InviteProfile> register() async =>
      const InviteProfile('server-player', 'SERVER-CODE', InviteOrigin.server);
  @override
  Future<InviteTicket> createTicket(
          InviteProfile profile, String token, DateTime now) async =>
      InviteTicket(
          'server-ticket', token, 'https://invite.example/test', now, origin);
  @override
  Future<List<InviteEvent>> fetchEvents(
      InviteProfile profile, Set<String> committedEventIds) async {
    acknowledged = committedEventIds;
    if (delay != null) await delay!.future;
    if (fail) throw StateError('offline');
    return receipts;
  }
}

void main() {
  test('기기별 고정 코드·링크 문구·URL 인코딩·저장 재실행 동일 코드', () async {
    final clock = FakeTime(), disk = <String, String>{};
    final a = atLevel(4, clock, JsonRepository(disk)),
        b = atLevel(4, FakeTime());
    expect(await a.prepareInvitation(), isTrue);
    expect(await b.prepareInvitation(), isTrue);
    final code = a.state.invites.profile!.referralCode;
    expect(b.state.invites.profile!.referralCode, isNot(code));
    final url = Uri.parse(a.state.invites.latestTicket!.url);
    expect(url.host, 'example.invalid');
    expect(url.queryParameters['code'], code);
    expect(a.inviteShareText, contains('모의 초대'));
    expect(a.inviteShareText, contains('현금·상품 지급은 없습니다'));
    final oldLink = a.state.invites.latestTicket!.id;
    expect(await a.prepareInvitation(), isTrue);
    expect(a.state.invites.profile!.referralCode, code);
    expect(a.state.invites.latestTicket!.id, isNot(oldLink));
    final snapshot = a.state.toJson();
    a.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.state.toJson(), snapshot);
    restart.dispose();
    b.dispose();
  });
  test('클릭→신규 판정→레벨1만 성공, 역순·위조 상대·자기 초대·미래 이벤트 제외', () async {
    final c = atLevel(9, FakeTime());
    await c.prepareInvitation();
    expect(
        await c.simulateInvitation(
            InviteEventKind.clicked, c.state.invites.profile!.playerId),
        isFalse);
    final id = await click(c, 'friend');
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(
        await c.simulateInvitation(InviteEventKind.reachedLevelOne, 'friend',
            visitId: id),
        isFalse);
    expect(
        await c.simulateInvitation(InviteEventKind.classifiedNew, 'other',
            visitId: id),
        isFalse);
    final ticket = c.state.invites.latestTicket!;
    final future = InviteEvent(
        eventId: 'future',
        ticketId: ticket.id,
        visitId: id,
        playerId: 'friend',
        kind: InviteEventKind.classifiedNew,
        atUtc: c.gameNow.add(const Duration(seconds: 1)),
        origin: InviteOrigin.mock);
    expect(applyInviteEvent(c.state, future, c.gameNow, InviteOrigin.mock),
        isFalse);
    await step(c, id, InviteEventKind.classifiedNew);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    await step(c, id, InviteEventKind.reachedLevelOne);
    expect(c.state.missions.qualifiedInvitePlayers, {'friend'});
    expect(c.state.invites.visits[id]!.stage, InviteStage.newSuccess);
    expect(c.state.support.coins, BigInt.from(5));
    expect(c.state.invites.events.length, 3);
    c.dispose();
  });
  test('동일 eventId 재전송과 새 eventId의 동일 사용자 성공 모두 중복 보상 없음', () async {
    final c = atLevel(9, FakeTime());
    await c.prepareInvitation();
    await succeed(c, 'friend');
    final before = c.state.toJson();
    expect(await c.replayMockEvent(c.state.invites.events.keys.last), isFalse);
    expect(c.state.toJson(), before);
    final retry = await click(c, 'friend');
    await step(c, retry, InviteEventKind.classifiedNew);
    expect(c.state.invites.visits[retry]!.stage, InviteStage.duplicate);
    expect(c.state.missions.qualifiedInvitePlayers, {'friend'});
    expect(c.state.support.coins, BigInt.from(5));
    expect(c.state.support.ledger.length, 1);
    c.dispose();
  });
  test('기존 참여는 미션 제외, 같은 날 여러 방문·신규/기존 전환에도 일일 한번', () async {
    final c = atLevel(9, FakeTime());
    await c.prepareInvitation();
    await succeed(c, 'old', fresh: false);
    await succeed(c, 'old', fresh: false);
    expect(c.state.support.coins, BigInt.from(2));
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    final disguised = await click(c, 'old');
    await step(c, disguised, InviteEventKind.classifiedNew);
    expect(c.state.invites.visits[disguised]!.stage, InviteStage.duplicate);
    await succeed(c, 'new');
    await succeed(c, 'new', fresh: false);
    expect(c.state.support.coins, BigInt.from(7));
    expect(c.state.support.ledger.length, 2);
    c.dispose();
  });
  test('한국 자정은 기존 참여 보상만 갱신, 과거 eventId·신규 성공은 영구 보존', () async {
    final clock = FakeTime()..now = DateTime.utc(2026, 1, 1, 14, 59, 59);
    final c = atLevel(9, clock);
    await c.prepareInvitation();
    await succeed(c, 'old', fresh: false);
    await succeed(c, 'new');
    final oldEvent = c.state.invites.events.keys.last;
    clock.advance(1000);
    c.tick();
    await succeed(c, 'old', fresh: false);
    await succeed(c, 'new', fresh: false);
    expect(c.state.support.coins, BigInt.from(11));
    expect(await c.replayMockEvent(oldEvent), isFalse);
    clock.now = clock.now.subtract(const Duration(days: 1));
    c.tick();
    await succeed(c, 'old', fresh: false);
    expect(c.state.support.coins, BigInt.from(11));
    expect(c.state.missions.qualifiedInvitePlayers, {'new'});
    c.dispose();
  });
  test('이전 레벨의 링크·시각은 늦게 완료해도 다음 활성 미션에 미반영', () async {
    final c = atLevel(5, FakeTime());
    await c.prepareInvitation();
    final id = await click(c, 'early'), old = c.state.invites.latestTicket!;
    c.state.level = 6;
    c.state.missions = c.state.missions.advance(6, c.gameNow);
    await step(c, id, InviteEventKind.classifiedNew);
    await step(c, id, InviteEventKind.reachedLevelOne);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(c.state.invites.visits[id]!.missionCounted, isFalse);
    expect(
        await c.simulateInvitation(InviteEventKind.clicked, 'late',
            ticketId: old.id),
        isTrue);
    final late = c.state.invites.visits.values.last.id;
    await step(c, late, InviteEventKind.classifiedNew);
    await step(c, late, InviteEventKind.reachedLevelOne);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    await c.prepareInvitation();
    await succeed(c, 'current');
    expect(c.state.missions.qualifiedInvitePlayers, {'current'});
    c.dispose();
  });
  test('실패·중복 판정은 영구 기록하되 지급/미션 반영 없음', () async {
    final c = atLevel(4, FakeTime());
    await c.prepareInvitation();
    for (final kind in [InviteEventKind.failed, InviteEventKind.duplicate]) {
      final id = await click(c, kind.name);
      await step(c, id, kind);
      expect(
          await c.simulateInvitation(InviteEventKind.classifiedNew, kind.name,
              visitId: id),
          isFalse);
    }
    expect(c.state.support.ledger, isEmpty);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(c.state.invites.events.length, 4);
    c.dispose();
  });
  test('중간 단계·보상·eventId 재실행 복원, 저장 실패 시 이벤트/코인/미션 전부 롤백', () async {
    final clock = FakeTime(), repo = SlowRepository();
    final c = atLevel(4, clock, repo);
    await c.prepareInvitation();
    final id = await click(c, 'retry');
    await step(c, id, InviteEventKind.classifiedNew);
    final before = c.state.toJson();
    repo.pending = Completer<void>();
    repo.failNextSave = true;
    final saving = c.simulateInvitation(
        InviteEventKind.reachedLevelOne, 'retry',
        visitId: id);
    expect(
        await c.simulateInvitation(InviteEventKind.reachedLevelOne, 'retry',
            visitId: id),
        isFalse);
    repo.pending!.complete();
    expect(await saving, isFalse);
    expect(c.state.toJson(), before);
    final disk = {'current': jsonEncode(repo.current!.toJson())};
    c.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.state.toJson(), before);
    await step(restart, id, InviteEventKind.reachedLevelOne);
    final eventId = restart.state.invites.events.keys.last,
        done = restart.state.toJson();
    restart.dispose();
    final again = GameController(JsonRepository(disk), clock);
    await again.initialize();
    expect(again.state.toJson(), done);
    expect(await again.replayMockEvent(eventId), isFalse);
    expect(again.state.support.coins, BigInt.from(5));
    again.dispose();
  });
  test('v4 원장·진행 보존, 이전 초대 사용자 마이그레이션은 소급 보상 없음', () {
    final c = atLevel(9, FakeTime());
    c.state.missions.seenInvitePlayers.add('legacy');
    c.state.missions.qualifiedInvitePlayers.add('legacy');
    c.state.support
        .transact('old', BigInt.from(10).pow(100), 'fixture', c.gameNow);
    final json = c.state.toJson()
      ..['formatVersion'] = 4
      ..remove('invites');
    final restored = GameState.fromJson(json);
    expect(restored.support.toJson(), c.state.support.toJson());
    expect(restored.invites.legacyPlayers, {'legacy'});
    // Stage 8: pre-v7 saves move to the offline season. Everything else in
    // the mission record is kept; 1 of 3 invites waives nothing.
    expect(restored.missions.toJson(),
        c.state.missions.toJson()..['seasonId'] = currentMissionSeason);
    expect(restored.copy().toJson(), restored.toJson());
    c.dispose();
  });
  test('운영 repository 대체 계약: 서버 이벤트 적용·재전송 ACK·모의 입력 격리', () async {
    final clock = FakeTime(), remote = ServerContractRepository();
    final c = GameController(MemoryGameRepository(), clock,
        invitationRepository: remote)
      ..state = (GameState.initial(clock.utcNow)
        ..level = 4
        ..missions = MissionState.forLevel(4, clock.utcNow,
            seasonId: legacyInviteMissionSeason));
    expect(await c.prepareInvitation(), isTrue);
    expect(c.canSimulateInvites, isFalse);
    final ticket = c.state.invites.latestTicket!;
    remote.receipts = [
      for (final kind in [
        InviteEventKind.clicked,
        InviteEventKind.classifiedNew,
        InviteEventKind.reachedLevelOne
      ])
        InviteEvent(
            eventId: kind.name,
            ticketId: ticket.id,
            visitId: 'visit',
            playerId: 'remote',
            kind: kind,
            atUtc: clock.utcNow,
            origin: InviteOrigin.server)
    ];
    expect(await c.refreshInvitations(), isTrue);
    expect(c.state.missions.qualifiedInvitePlayers, {'remote'});
    expect(await c.createMockInvite(), isFalse);
    expect(await c.refreshInvitations(), isTrue);
    expect(remote.acknowledged.length, 3);
    expect(c.state.support.coins, BigInt.from(5));
    final mock = MockInvitationRepository()
        .simulate(ticket, 'forged', InviteEventKind.clicked, clock.utcNow);
    expect(applyInviteEvent(c.state, mock, clock.utcNow, InviteOrigin.server),
        isFalse);
    remote.fail = true;
    final before = c.state.toJson();
    expect(await c.refreshInvitations(), isFalse);
    expect(c.state.toJson(), before);
    expect(c.inviteError, isNotNull);
    c.dispose();
  });
  test('느린 서버 응답 동안 초기화된 게임에는 옛 이벤트를 적용하지 않는다', () async {
    final clock = FakeTime(), remote = ServerContractRepository();
    final c = GameController(MemoryGameRepository(), clock,
        invitationRepository: remote)
      ..state = GameState.initial(clock.utcNow);
    await c.prepareInvitation();
    remote.delay = Completer<void>();
    final fetching = c.refreshInvitations();
    await Future<void>.delayed(Duration.zero);
    await c.reset();
    remote.delay!.complete();
    expect(await fetching, isFalse);
    expect(c.state.invites.profile, isNull);
    expect(c.state.invites.events, isEmpty);
    c.dispose();
  });
}
