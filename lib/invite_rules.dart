import 'invite_config.dart';
import 'invite_models.dart';
import 'mission_config.dart';
import 'missions.dart';
import 'models.dart';
import 'support_rules.dart';
import 'support_state.dart';

String inviteRewardKey(InviteOrigin origin, DateTime day, String playerId) =>
    'invite:${origin.name}:${dailyKey(day)}:$playerId';

// Returns whether a NEW event was consumed, not whether it earned a reward.
// Out-of-order events remain unacknowledged and can be redelivered after their
// prerequisites. Explicit failure/duplicate receipts are final and persisted.
bool applyInviteEvent(
    GameState s, InviteEvent event, DateTime now, InviteOrigin origin) {
  final invites = s.invites, ticket = s.invites.tickets[event.ticketId];
  if (![event.eventId, event.ticketId, event.visitId, event.playerId]
          .every(validInviteId) ||
      invites.events.containsKey(event.eventId) ||
      invites.events.length >= inviteEventLimit ||
      ticket == null ||
      ticket.origin != origin ||
      event.origin != origin ||
      invites.profile?.origin != origin ||
      event.playerId == invites.profile?.playerId ||
      event.atUtc.isAfter(now) ||
      event.atUtc.isBefore(ticket.createdAtUtc)) {
    return false;
  }
  var visit = invites.visits[event.visitId];
  if (event.kind == InviteEventKind.clicked) {
    if (visit != null || invites.visits.length >= inviteVisitLimit) {
      return false;
    }
    visit = InviteVisit(event.visitId, ticket.id, event.playerId, event.atUtc);
    invites.visits[visit.id] = visit;
  } else {
    if (visit == null ||
        visit.ticketId != ticket.id ||
        visit.playerId != event.playerId ||
        event.atUtc.isBefore(visit.lastAtUtc)) {
      return false;
    }
    if (visit.stage != InviteStage.clicked &&
        visit.stage != InviteStage.classifiedNew) {
      return false;
    }
    switch (event.kind) {
      case InviteEventKind.clicked:
        break;
      case InviteEventKind.classifiedNew:
        if (visit.stage != InviteStage.clicked) return false;
        if (invites.existingPlayers.contains(event.playerId) ||
            invites.newSuccessPlayers.contains(event.playerId) ||
            invites.legacyPlayers.contains(event.playerId)) {
          visit.stage = InviteStage.duplicate;
          visit.note = '이미 알려진 사용자 · 신규 판정 거절';
        } else {
          visit.stage = InviteStage.classifiedNew;
          visit.note = '신규 판정 · 레벨 1 달성 대기';
        }
      case InviteEventKind.reachedLevelOne:
        if (visit.stage != InviteStage.classifiedNew) return false;
        if (invites.newSuccessPlayers.contains(event.playerId) ||
            invites.existingPlayers.contains(event.playerId) ||
            invites.legacyPlayers.contains(event.playerId) ||
            s.missions.seenInvitePlayers.contains(event.playerId)) {
          visit.stage = InviteStage.duplicate;
          visit.note = '이미 처리한 신규 사용자 · 재지급 없음';
          break;
        }
        if (s.missions.seenInvitePlayers.length >= mockInviteHistoryLimit) {
          return false;
        }
        invites.newSuccessPlayers.add(event.playerId);
        s.missions.seenInvitePlayers.add(event.playerId);
        visit.stage = InviteStage.newSuccess;
        final m = s.missions, active = activeLevelMission(s);
        final goals = active?.missions
            .where((g) => g.kind == MissionKind.newPlayerInvites);
        if (m.activatedAtUtc != null &&
            ticket.missionToken == m.token &&
            !ticket.createdAtUtc.isBefore(m.activatedAtUtc!) &&
            !visit.clickedAtUtc.isBefore(m.activatedAtUtc!) &&
            goals != null &&
            goals.isNotEmpty &&
            BigInt.from(m.qualifiedInvitePlayers.length) < goals.first.target) {
          m.qualifiedInvitePlayers.add(event.playerId);
          visit.missionCounted = true;
        }
        _reward(s, visit, event, true, now);
      case InviteEventKind.existingParticipated:
        if (visit.stage != InviteStage.clicked) return false;
        invites.existingPlayers.add(event.playerId);
        visit.stage = InviteStage.existingSuccess;
        _reward(s, visit, event, false, now);
      case InviteEventKind.failed:
        visit.stage = InviteStage.failed;
        visit.note = '실패 · 보상/미션 반영 없음';
      case InviteEventKind.duplicate:
        visit.stage = InviteStage.duplicate;
        visit.note = '중복 초대 · 보상/미션 반영 없음';
    }
    visit.lastAtUtc = event.atUtc;
  }
  invites.events[event.eventId] = event;
  return true;
}

void _reward(GameState s, InviteVisit visit, InviteEvent event, bool fresh,
    DateTime now) {
  final key = inviteRewardKey(event.origin, event.atUtc, event.playerId);
  final granted = grantReward(
      s,
      key,
      fresh ? newInviteReward : existingInviteReward,
      now,
      fresh ? '신규 초대 성공 (추정)' : '기존 사용자 참여 (추정)');
  if (granted) visit.rewardId = key;
  visit.note =
      '${fresh ? '신규 레벨 1 달성' : '기존 사용자 참여'} · ${granted ? '보상 지급' : '오늘 이미 보상 · 재지급 없음'}'
      '${fresh ? (visit.missionCounted ? ' · 레벨 미션 반영' : ' · 현재 레벨 미션 조건 불일치') : ' · 신규 초대 미션 제외'}';
}

String invitationText(InviteProfile profile, InviteTicket ticket) =>
    '${ticket.origin == InviteOrigin.mock ? '[모의 초대 · 실제 서비스 연결 없음]\n' : ''}'
    '오늘의 붕어빵에 함께 놀러 오세요!\n추천 코드: ${profile.referralCode}\n${ticket.url}\n'
    '시제품이며 현금·상품 지급은 없습니다.${ticket.origin == InviteOrigin.mock ? '\n이 링크로 실제 상대를 확인하지 않습니다.' : ''}';
