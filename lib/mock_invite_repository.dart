import 'dart:math';
import 'invite_config.dart';
import 'invite_models.dart';
import 'invite_repository.dart';

class MockInvitationRepository
    implements InvitationRepository, InvitationSimulator {
  final Random _random;
  MockInvitationRepository({Random? random})
      : _random = random ?? Random.secure();
  String _id() => List.generate(
      16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  @override
  InviteOrigin get origin => InviteOrigin.mock;
  @override
  Future<InviteProfile> register() async {
    final id = _id();
    return InviteProfile('local-$id', 'BB${id.toUpperCase()}', origin);
  }

  @override
  Future<InviteTicket> createTicket(
      InviteProfile profile, String missionToken, DateTime now) async {
    final id = _id();
    final url = Uri.parse(mockInviteBaseUrl).replace(queryParameters: {
      'code': profile.referralCode,
      'invite': id,
      'mode': 'mock'
    });
    return InviteTicket(id, missionToken, '$url', now.toUtc(), origin);
  }

  @override
  Future<List<InviteEvent>> fetchEvents(
          InviteProfile profile, Set<String> committedEventIds) async =>
      [];
  @override
  InviteEvent simulate(InviteTicket ticket, String playerId,
          InviteEventKind kind, DateTime now, {String? visitId}) =>
      InviteEvent(
          eventId: _id(),
          ticketId: ticket.id,
          visitId: visitId ?? _id(),
          playerId: playerId,
          kind: kind,
          atUtc: now.toUtc(),
          origin: origin);
}
