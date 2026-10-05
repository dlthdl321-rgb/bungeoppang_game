import 'cosmetic_config.dart';

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
