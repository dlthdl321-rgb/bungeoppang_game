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

  /// [legacy] (save v6..v9) lacks the stage-12 slots: those get their
  /// defaults and free items are granted. Later saves are checked strictly.
  factory WardrobeState.fromJson(Map<String, dynamic> m,
      {bool legacy = false}) {
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
    if (legacy) {
      s.owned.addAll([
        for (final d in _wardrobeCatalog)
          if (d.free && stage12Slots.contains(d.slot)) d.id
      ]);
    }
    for (final slot in _wardrobeSlots) {
      final id = equipped[slot.name] ??
          (legacy && stage12Slots.contains(slot)
              ? defaultCosmetics[slot]
              : null);
      if (!s.owned.contains(id) ||
          !_wardrobeCatalog.any((d) => d.slot == slot && d.id == id)) {
        throw const FormatException('꾸미기 장착 슬롯 불일치');
      }
      s.equipped[slot] = id as String;
    }
    return s;
  }
}
