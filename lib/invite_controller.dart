part of 'game_controller.dart';

extension InvitationCommands on GameController {
  bool get invitesBusy => busy || _inviteLoading;
  bool get canSimulateInvites =>
      invitationRepository.origin == InviteOrigin.mock &&
      invitationRepository is InvitationSimulator;
  bool get canQuickInvite {
    final active = activeLevelMission(state);
    return canSimulateInvites &&
        !invitesBusy &&
        active != null &&
        missionProgress(state, active).any((p) =>
            p.definition.kind == MissionKind.newPlayerInvites && !p.complete);
  }

  String? get inviteShareText {
    final profile = state.invites.profile, ticket = state.invites.latestTicket;
    if (profile == null || ticket == null) return null;
    return invitationText(profile, ticket);
  }

  // Network waiting does not pause production. Responses from a reset/disposed
  // session or an inactive app are discarded, not applied to a different save.
  Future<bool> _inviteRequest(Future<bool Function()> Function() load) async {
    if (invitesBusy || _away || _disposed) return false;
    _inviteLoading = true;
    inviteError = null;
    final owner = state.invites;
    _notifyInviteChanged();
    try {
      final apply = await load();
      if (_disposed || _away || busy || !identical(owner, state.invites)) {
        return false;
      }
      tick();
      final before = state.copy();
      try {
        if (!apply()) {
          state = before;
          return false;
        }
        return await _commit(before);
      } catch (_) {
        state = before;
        rethrow;
      }
    } catch (_) {
      if (!_disposed) inviteError = '초대 정보를 처리하지 못했습니다. 다시 시도해 주세요.';
      return false;
    } finally {
      _inviteLoading = false;
      if (!_disposed) _notifyInviteChanged();
    }
  }

  Future<InviteProfile> _profile() async {
    final profile =
        state.invites.profile ?? await invitationRepository.register();
    final validated = InviteProfile.fromJson(profile.toJson());
    if (validated.origin != invitationRepository.origin) {
      throw const FormatException('모의/운영 사용자 혼합 금지');
    }
    return validated;
  }

  Future<bool> ensureInviteProfile() => _inviteRequest(() async {
        final profile = await _profile();
        return () {
          state.invites.profile = profile;
          return true;
        };
      });

  Future<bool> prepareInvitation() => _inviteRequest(() async {
        final token = state.missions.token, now = gameNow;
        final profile = await _profile();
        final ticket = InviteTicket.fromJson(
            (await invitationRepository.createTicket(profile, token, now))
                .toJson());
        return () {
          if (state.invites.tickets.length >= inviteTicketLimit ||
              state.invites.tickets.containsKey(ticket.id) ||
              ticket.origin != profile.origin ||
              ticket.missionToken != token ||
              ticket.createdAtUtc.isAfter(gameNow)) {
            return false;
          }
          state.invites.profile = profile;
          state.invites.tickets[ticket.id] = ticket;
          return true;
        };
      });

  Future<bool> refreshInvitations() => _inviteRequest(() async {
        final profile = await _profile();
        final events = await invitationRepository.fetchEvents(
            profile, Set.unmodifiable(state.invites.events.keys));
        return () {
          state.invites.profile = profile;
          for (final event in events) {
            applyInviteEvent(
                state, event, gameNow, invitationRepository.origin);
          }
          return true;
        };
      });

  Future<bool> simulateInvitation(InviteEventKind kind, String playerId,
      {String? visitId, String? ticketId}) async {
    if (!canSimulateInvites || invitesBusy || _away) return false;
    tick();
    final ticket = ticketId == null
        ? state.invites.latestTicket
        : state.invites.tickets[ticketId];
    if (ticket == null) return false;
    final event = (invitationRepository as InvitationSimulator)
        .simulate(ticket, playerId, kind, gameNow, visitId: visitId);
    return _applyMockEvents([event]);
  }

  Future<bool> replayMockEvent(String eventId) async {
    final event = state.invites.events[eventId];
    if (!canSimulateInvites || event == null) return false;
    return _applyMockEvents([event]);
  }

  Future<bool> _applyMockEvents(List<InviteEvent> events) async {
    if (invitesBusy || _away || !canSimulateInvites) return false;
    tick();
    final before = state.copy();
    var applied = false;
    for (final event in events) {
      applied =
          applyInviteEvent(state, event, gameNow, InviteOrigin.mock) || applied;
    }
    if (!applied) return false;
    return _commit(before);
  }

  // Compatibility adapter for previous regression/simulation callers. It uses
  // the same event reducer, reward ledger and atomic commit as the staged UI.
  Future<bool> importMockSuccess(MockInviteSuccess receipt) async {
    if (!canSimulateInvites ||
        invitesBusy ||
        _away ||
        !validInviteId(receipt.playerId) ||
        !receipt.reachedLevelOne ||
        receipt.completedAtUtc.isAfter(clock.utcNow) ||
        receipt.completedAtUtc.isBefore(receipt.invitedAtUtc) ||
        state.missions.seenInvitePlayers.contains(receipt.playerId) ||
        state.missions.seenInvitePlayers.length >= mockInviteHistoryLimit) {
      return false;
    }
    return _inviteRequest(() async {
      final profile = await _profile();
      final ticket = await invitationRepository.createTicket(
          profile, receipt.activationToken, receipt.invitedAtUtc);
      final simulator = invitationRepository as InvitationSimulator;
      final click = simulator.simulate(ticket, receipt.playerId,
          InviteEventKind.clicked, receipt.invitedAtUtc);
      final events = [
        click,
        if (receipt.isNewPlayer)
          simulator.simulate(ticket, receipt.playerId,
              InviteEventKind.classifiedNew, receipt.completedAtUtc,
              visitId: click.visitId),
        simulator.simulate(
            ticket,
            receipt.playerId,
            receipt.isNewPlayer
                ? InviteEventKind.reachedLevelOne
                : InviteEventKind.existingParticipated,
            receipt.completedAtUtc,
            visitId: click.visitId)
      ];
      return () {
        if (state.invites.tickets.length >= inviteTicketLimit) return false;
        state.invites.profile = profile;
        state.invites.tickets[ticket.id] = ticket;
        for (final event in events) {
          if (!applyInviteEvent(state, event, gameNow, InviteOrigin.mock)) {
            return false;
          }
        }
        // Previous compatibility receipts consumed existing players too.
        state.missions.seenInvitePlayers.add(receipt.playerId);
        return true;
      };
    });
  }
}
