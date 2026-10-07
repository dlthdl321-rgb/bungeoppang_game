import 'invite_models.dart';
import 'invite_repository.dart';
import 'online_backend.dart';

/// Invitations through the Firebase backend: the production adapter for
/// [InvitationRepository]. Signs in to Play Games first when needed.
class ServerInvitationRepository implements InvitationRepository {
  final OnlineBackend backend;
  const ServerInvitationRepository(this.backend);

  @override
  InviteOrigin get origin => InviteOrigin.server;

  Future<void> _ready() async {
    if (!backend.configured) {
      throw const OnlineException(OnlineFailure.unavailable);
    }
    if (!backend.signedIn && !await backend.signIn()) {
      throw const OnlineException(OnlineFailure.signedOut);
    }
  }

  @override
  Future<InviteProfile> register() async {
    await _ready();
    return backend.inviteRegister();
  }

  @override
  Future<InviteTicket> createTicket(
      InviteProfile profile, String missionToken, DateTime now) async {
    await _ready();
    return backend.inviteCreateTicket(missionToken);
  }

  @override
  Future<List<InviteEvent>> fetchEvents(
      InviteProfile profile, Set<String> committedEventIds) async {
    await _ready();
    return backend.inviteFetchEvents(committedEventIds);
  }
}
