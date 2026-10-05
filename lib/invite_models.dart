import 'invite_config.dart';
import 'support_state.dart' show readUtc;

enum InviteOrigin { mock, server }

enum InviteEventKind {
  clicked,
  classifiedNew,
  reachedLevelOne,
  existingParticipated,
  failed,
  duplicate
}

enum InviteStage {
  clicked,
  classifiedNew,
  newSuccess,
  existingSuccess,
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

class InviteVisit {
  final String id, ticketId, playerId;
  final DateTime clickedAtUtc;
  DateTime lastAtUtc;
  InviteStage stage;
  bool missionCounted;
  String note;
  String? rewardId;
  InviteVisit(this.id, this.ticketId, this.playerId, this.clickedAtUtc,
      {DateTime? lastAtUtc,
      this.stage = InviteStage.clicked,
      this.missionCounted = false,
      this.note = '링크 클릭 확인',
      this.rewardId})
      : lastAtUtc = lastAtUtc ?? clickedAtUtc;
  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'playerId': playerId,
        'clickedAtUtc': clickedAtUtc.toIso8601String(),
        'lastAtUtc': lastAtUtc.toIso8601String(),
        'stage': stage.name,
        'missionCounted': missionCounted,
        'note': note,
        'rewardId': rewardId
      };
  factory InviteVisit.fromJson(Map<String, dynamic> m) {
    if (m['missionCounted'] is! bool ||
        m['note'] is! String ||
        (m['rewardId'] != null && m['rewardId'] is! String)) {
      throw const FormatException('잘못된 초대 결과');
    }
    final start = readUtc(m['clickedAtUtc']), end = readUtc(m['lastAtUtc']);
    if (end.isBefore(start)) throw const FormatException('초대 시각 역전');
    return InviteVisit(inviteId(m['id']), inviteId(m['ticketId']),
        inviteId(m['playerId']), start,
        lastAtUtc: end,
        stage: inviteEnum(InviteStage.values, m['stage']),
        missionCounted: m['missionCounted'] as bool,
        note: m['note'] as String,
        rewardId: m['rewardId'] as String?);
  }
}

class InviteState {
  InviteProfile? profile;
  final Map<String, InviteTicket> tickets = {};
  final Map<String, InviteVisit> visits = {};
  final Map<String, InviteEvent> events = {};
  final Set<String> newSuccessPlayers = {},
      existingPlayers = {},
      legacyPlayers = {};
  InviteState();
  InviteState.migrate(Iterable<String> seen) {
    legacyPlayers.addAll(seen);
  }
  InviteTicket? get latestTicket =>
      tickets.isEmpty ? null : tickets.values.last;
  Map<String, dynamic> toJson() => {
        'configVersion': inviteConfigVersion,
        'profile': profile?.toJson(),
        'tickets': tickets.values.map((t) => t.toJson()).toList(),
        'visits': visits.values.map((v) => v.toJson()).toList(),
        'events': events.values.map((e) => e.toJson()).toList(),
        'newSuccessPlayers': newSuccessPlayers.toList(),
        'existingPlayers': existingPlayers.toList(),
        'legacyPlayers': legacyPlayers.toList()
      };
  factory InviteState.fromJson(Map<String, dynamic> m) {
    if (m['configVersion'] != inviteConfigVersion) {
      throw const FormatException('초대 설정 버전 불명');
    }
    final s = InviteState();
    if (m['profile'] != null) {
      s.profile = InviteProfile.fromJson(inviteMap(m['profile']));
    }
    void rows(String key, int limit, void Function(Map<String, dynamic>) load) {
      final raw = m[key];
      if (raw is! List || raw.length > limit) {
        throw const FormatException('초대 기록 한도/구조 오류');
      }
      for (final row in raw) {
        load(inviteMap(row));
      }
    }

    rows('tickets', inviteTicketLimit, (m) {
      final t = InviteTicket.fromJson(m);
      if (s.tickets.containsKey(t.id) || t.origin != s.profile?.origin) {
        throw const FormatException('초대 링크 중복/출처 오류');
      }
      s.tickets[t.id] = t;
    });
    rows('visits', inviteVisitLimit, (m) {
      final v = InviteVisit.fromJson(m), ticket = s.tickets[m['ticketId']];
      if (s.visits.containsKey(v.id) ||
          ticket == null ||
          v.clickedAtUtc.isBefore(ticket.createdAtUtc)) {
        throw const FormatException('초대 방문 중복/시각 오류');
      }
      s.visits[v.id] = v;
    });
    rows('events', inviteEventLimit, (m) {
      final e = InviteEvent.fromJson(m), v = s.visits[m['visitId']];
      if (s.events.containsKey(e.eventId) ||
          e.origin != s.profile?.origin ||
          v == null ||
          v.playerId != e.playerId ||
          v.ticketId != e.ticketId) {
        throw const FormatException('초대 이벤트 중복/참조 오류');
      }
      s.events[e.eventId] = e;
    });
    for (final entry in {
      'newSuccessPlayers': s.newSuccessPlayers,
      'existingPlayers': s.existingPlayers,
      'legacyPlayers': s.legacyPlayers
    }.entries) {
      final raw = m[entry.key];
      if (raw is! List ||
          raw.length > inviteVisitLimit ||
          raw.toSet().length != raw.length ||
          raw.any((e) => e is! String || e.isEmpty || e.length > 128)) {
        throw const FormatException('초대 사용자 기록 오류');
      }
      entry.value.addAll(raw.cast<String>());
    }
    return s;
  }
}
