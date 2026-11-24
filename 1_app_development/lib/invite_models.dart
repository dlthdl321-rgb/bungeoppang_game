/// Invitation records the server sends (29번). The old clicker's saved
/// invitation state and its coin rewards are gone (32번).

DateTime readUtc(Object? value) {
  final t = DateTime.tryParse('$value');
  if (t == null) throw const FormatException('잘못된 초대 시각');
  return t.toUtc();
}

enum InviteOrigin { mock, server }

enum InviteEventKind {
  clicked,
  classifiedNew,
  reachedLevelOne,
  existingParticipated,
  failed,
  duplicate
}

bool validInviteId(String id) => RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id);
String inviteId(Object? value) {
  if (value is! String || !validInviteId(value)) {
    throw const FormatException('잘못된 초대 ID');
  }
  return value;
}

Map<String, dynamic> inviteMap(Object? value) {
  if (value is! Map) throw const FormatException('초대 저장 구조 손상');
  return Map<String, dynamic>.from(value);
}

T inviteEnum<T extends Enum>(Iterable<T> values, Object? value) =>
    values.firstWhere((v) => v.name == value,
        orElse: () => throw const FormatException('잘못된 초대 상태'));

class InviteProfile {
  final String playerId, referralCode;
  final InviteOrigin origin;
  const InviteProfile(this.playerId, this.referralCode, this.origin);
  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'referralCode': referralCode,
        'origin': origin.name
      };
  factory InviteProfile.fromJson(Map<String, dynamic> m) => InviteProfile(
      inviteId(m['playerId']),
      inviteId(m['referralCode']),
      inviteEnum(InviteOrigin.values, m['origin']));
}

class InviteTicket {
  final String id, missionToken, url;
  final DateTime createdAtUtc;
  final InviteOrigin origin;
  const InviteTicket(
      this.id, this.missionToken, this.url, this.createdAtUtc, this.origin);
  Map<String, dynamic> toJson() => {
        'id': id,
        'missionToken': missionToken,
        'url': url,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'origin': origin.name
      };
  factory InviteTicket.fromJson(Map<String, dynamic> m) {
    final url = m['url'], token = m['missionToken'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        token is! String ||
        token.isEmpty) {
      throw const FormatException('잘못된 초대 링크');
    }
    return InviteTicket(
        inviteId(m['id']),
        token,
        url as String,
        readUtc(m['createdAtUtc']),
        inviteEnum(InviteOrigin.values, m['origin']));
  }
}

// Repository receipts require server authentication in a production adapter.
class InviteEvent {
  final String eventId, ticketId, visitId, playerId;
  final InviteEventKind kind;
  final DateTime atUtc;
  final InviteOrigin origin;
  const InviteEvent(
      {required this.eventId,
      required this.ticketId,
      required this.visitId,
      required this.playerId,
      required this.kind,
      required this.atUtc,
      required this.origin});
  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'ticketId': ticketId,
        'visitId': visitId,
        'playerId': playerId,
        'kind': kind.name,
        'atUtc': atUtc.toIso8601String(),
        'origin': origin.name
      };
  factory InviteEvent.fromJson(Map<String, dynamic> m) => InviteEvent(
      eventId: inviteId(m['eventId']),
      ticketId: inviteId(m['ticketId']),
      visitId: inviteId(m['visitId']),
      playerId: inviteId(m['playerId']),
      kind: inviteEnum(InviteEventKind.values, m['kind']),
      atUtc: readUtc(m['atUtc']),
      origin: inviteEnum(InviteOrigin.values, m['origin']));
}
