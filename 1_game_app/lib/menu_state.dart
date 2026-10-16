import 'cosmetic_config.dart';

/// Every slot but fish, which still lives in the legacy skin fields.
Iterable<CosmeticSlot> get _wardrobeSlots =>
    CosmeticSlot.values.where((s) => s != CosmeticSlot.fish);
Iterable<CosmeticDefinition> get _wardrobeCatalog =>
    cosmeticDefinitions.where((d) => d.slot != CosmeticSlot.fish);

class WardrobeState {
  final Set<String> owned;
  final Map<CosmeticSlot, String> equipped;
  WardrobeState._(this.owned, this.equipped);
  factory WardrobeState.initial() => WardrobeState._(
      {
        for (final d in _wardrobeCatalog)
          if (d.free) d.id
      },
      {for (final s in _wardrobeSlots) s: defaultCosmetics[s]!});
  Map<String, dynamic> toJson() => {
        'owned': owned.toList(),
        'equipped': {for (final e in equipped.entries) e.key.name: e.value}
      };

  /// A save of [version] lacks slots added later ([cosmeticSlotSince]):
  /// those get their defaults. Every item that is free now is granted, so a
  /// changed default (v12: clear, long) is owned while the old defaults stay
  /// owned. Slots the save already knew are checked strictly.
  factory WardrobeState.fromJson(Map<String, dynamic> m,
      {required int version}) {
    if (m['owned'] is! List || m['equipped'] is! Map) {
      throw const FormatException('꾸미기 슬롯 저장 손상');
    }
    final raw = m['owned'] as List;
    if (raw.toSet().length != raw.length ||
        raw.any((id) => !_wardrobeCatalog.any((d) => d.id == id))) {
      throw const FormatException('잘못된 꾸미기 보유 목록');
    }
    final s = WardrobeState._(raw.cast<String>().toSet(), {});
    final equipped = m['equipped'] as Map;
    bool added(CosmeticSlot slot) => cosmeticSlotSince(slot) > version;
    s.owned.addAll([
      for (final d in _wardrobeCatalog)
        if (d.free) d.id
    ]);
    for (final slot in _wardrobeSlots) {
      final id = equipped[slot.name] ??
          (added(slot) ? defaultCosmetics[slot] : null);
      if (!s.owned.contains(id) ||
          !_wardrobeCatalog.any((d) => d.slot == slot && d.id == id)) {
        throw const FormatException('꾸미기 장착 슬롯 불일치');
      }
      s.equipped[slot] = id as String;
    }
    return s;
  }
}
