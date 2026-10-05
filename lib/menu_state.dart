import 'cosmetic_config.dart';
import 'event_config.dart';
import 'support_state.dart';

class WardrobeState {
  final Set<String> owned;
  final Map<CosmeticSlot, String> equipped;
  WardrobeState._(this.owned, this.equipped);
  factory WardrobeState.initial() => WardrobeState._(
      defaultCosmetics.entries
          .where((e) => e.key != CosmeticSlot.fish)
          .map((e) => e.value)
          .toSet(),
      Map.fromEntries(
          defaultCosmetics.entries.where((e) => e.key != CosmeticSlot.fish)));
  Map<String, dynamic> toJson() => {
        'owned': owned.toList(),
        'equipped': {for (final e in equipped.entries) e.key.name: e.value}
      };
  factory WardrobeState.fromJson(Map<String, dynamic> m) {
    if (m['owned'] is! List || m['equipped'] is! Map) {
      throw const FormatException('꾸미기 슬롯 저장 손상');
    }
    final raw = m['owned'] as List;
    final catalog =
        cosmeticDefinitions.where((d) => d.slot != CosmeticSlot.fish);
    if (raw.toSet().length != raw.length ||
        raw.any((id) => !catalog.any((d) => d.id == id))) {
      throw const FormatException('잘못된 꾸미기 보유 목록');
    }
    final s = WardrobeState._(raw.cast<String>().toSet(), {});
    for (final slot
        in CosmeticSlot.values.where((s) => s != CosmeticSlot.fish)) {
      final id = (m['equipped'] as Map)[slot.name];
      if (!s.owned.contains(id) ||
          !catalog.any((d) => d.slot == slot && d.id == id)) {
        throw const FormatException('꾸미기 장착 슬롯 불일치');
      }
      s.equipped[slot] = id as String;
    }
    return s;
  }
}

class LocalEventState {
  bool joined = false;
  BigInt participants;
  final Map<String, BigInt> claimedCounts;
  final Map<String, DateTime> receipts = {};
  LocalEventState._(this.participants, this.claimedCounts);
  factory LocalEventState.initial(EventDefinition d) => LocalEventState._(
      BigInt.parse(d.initialParticipants),
      {for (final r in d.rewards) r.id: BigInt.parse(r.initialClaimed)});
  Map<String, dynamic> toJson() => {
        'joined': joined,
        'participants': '$participants',
        'claimedCounts': {
          for (final e in claimedCounts.entries) e.key: '${e.value}'
        },
        'receipts': {
          for (final e in receipts.entries) e.key: e.value.toIso8601String()
        }
      };
  factory LocalEventState.fromJson(Map<String, dynamic> m, EventDefinition d) {
    if (m['joined'] is! bool ||
        m['claimedCounts'] is! Map ||
        m['receipts'] is! Map) {
      throw const FormatException('이벤트 저장 손상');
    }
    final s = LocalEventState._(readNatural(m['participants']), {})
      ..joined = m['joined'] as bool;
    if (s.participants <
        BigInt.parse(d.initialParticipants) +
            (s.joined ? BigInt.one : BigInt.zero)) {
      throw const FormatException('이벤트 참여 수 오류');
    }
    for (final r in d.rewards) {
      final n = readNatural((m['claimedCounts'] as Map)[r.id]);
      if (n < BigInt.parse(r.initialClaimed) || n > BigInt.parse(r.capacity)) {
        throw const FormatException('이벤트 수량 범위 오류');
      }
      s.claimedCounts[r.id] = n;
    }
    for (final e in (m['receipts'] as Map).entries) {
      final matches = d.rewards.where((r) => r.id == e.key);
      final at = readUtc(e.value);
      if (!s.joined ||
          matches.isEmpty ||
          at.isBefore(d.start) ||
          !at.isBefore(d.end)) {
        throw const FormatException('이벤트 수령 오류');
      }
      s.receipts[e.key as String] = at;
    }
    for (final r in d.rewards.where((r) => s.receipts.containsKey(r.id))) {
      if (!r.prerequisites.every(s.receipts.containsKey) ||
          s.claimedCounts[r.id]! <= BigInt.parse(r.initialClaimed)) {
        throw const FormatException('이벤트 수령 순서/수량 오류');
      }
    }
    return s;
  }
}
