import 'invite_models.dart';

// Stable application port. A server adapter owns authenticated identity,
// signed links, user classification, causal ordering and durable redelivery.
// Only IDs committed to GameRepository may be acknowledged to the server.
abstract class InvitationRepository {
  InviteOrigin get origin;
  Future<InviteProfile> register();
  Future<InviteTicket> createTicket(
      InviteProfile profile, String missionToken, DateTime now);
  Future<List<InviteEvent>> fetchEvents(
      InviteProfile profile, Set<String> committedEventIds);
}

// Separate capability: production repositories do NOT implement this port.
abstract class InvitationSimulator {
  InviteEvent simulate(
      InviteTicket ticket, String playerId, InviteEventKind kind, DateTime now,
      {String? visitId});
}
