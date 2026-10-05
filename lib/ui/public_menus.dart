import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../menu_rules.dart';
import 'avatar_painter.dart';
import 'fish_painter.dart';
import 'night_stall_painter.dart';
import 'support_panels.dart';

class WardrobePanel extends StatefulWidget {
  final GameController controller;
  final CosmeticCategory initialCategory;
  const WardrobePanel(
      {super.key,
      required this.controller,
      this.initialCategory = CosmeticCategory.bungeoppang});
  @override
  State<WardrobePanel> createState() => _WardrobePanelState();
}

class _WardrobePanelState extends State<WardrobePanel> {
  late CosmeticCategory category = widget.initialCategory;
  late CosmeticSlot slot = _slots(category).first;
  String? preview;

  static List<CosmeticSlot> _slots(CosmeticCategory c) =>
      CosmeticSlot.values.where((s) => s.category == c).toList();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    String equipped(CosmeticSlot s) =>
        s == slot && preview != null ? preview! : c.state.equippedCosmetic(s);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('모습만 바뀌어요 (생산 효과 없음)'),
          const SizedBox(height: 8),
          SegmentedButton<CosmeticCategory>(
              showSelectedIcon: false,
              segments: [
                for (final cat in CosmeticCategory.values)
                  ButtonSegment(
                      value: cat,
                      label: Text(cosmeticCategoryLabel(cat),
                          key: Key('cosmetic-category-${cat.name}'))),
              ],
              selected: {category},
              onSelectionChanged: (picked) => setState(() {
                    category = picked.single;
                    slot = _slots(category).first;
                    preview = null;
                  })),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in _slots(category))
              ChoiceChip(
                  key: Key('cosmetic-slot-${s.name}'),
                  label: Text(cosmeticSlotLabel(s)),
                  selected: s == slot,
                  onSelected: (_) => setState(() {
                        slot = s;
                        preview = null;
                      }))
          ]),
          const SizedBox(height: 12),
          Semantics(
              label:
                  '${cosmeticCategoryLabel(category)} 꾸미기 미리보기',
              child: SizedBox(
                  height: 180,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _preview(equipped)))),
          Text(preview == null ? '현재 장착 모습' : '미리보기 · 미장착',
              key: const Key('cosmetic-preview-status')),
          for (final d in cosmeticDefinitions.where((d) => d.slot == slot))
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(d.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(d.free
                              ? '무료'
                              : '${compactNumber(d.cost)} 코인'),
                          Text(
                              '해금 Lv.${d.unlockLevel} · 누적 ${compactNumber(d.unlockProductionAmount)}개'),
                          Text(
                              '현재 ${cosmeticDefinitions.firstWhere((item) => item.id == c.state.equippedCosmetic(slot)).name} → ${d.name}'),
                          Wrap(spacing: 8, children: [
                            TextButton(
                                key: Key('preview-${d.id}'),
                                onPressed: () => setState(() => preview = d.id),
                                child: const Text('미리보기')),
                            FilledButton.tonal(
                                key: Key('buy-cosmetic-${d.id}'),
                                onPressed: !c.busy &&
                                        cosmeticUnlocked(c.state, d) &&
                                        c.state.equippedCosmetic(slot) !=
                                            d.id &&
                                        (c.state.ownsCosmetic(d) ||
                                            c.state.support.coins >= d.cost)
                                    ? () async {
                                        if (c.state.ownsCosmetic(d) ||
                                            await confirmAction(
                                                context,
                                                '${d.name} 구매',
                                                '가격 ${d.cost} 코인\n코인 ${exactNumber(c.state.support.coins)} → ${exactNumber(c.state.support.coins - d.cost)}\n영구 보유 · 바로 장착',
                                                '구매')) {
                                          final ok =
                                              await c.buyOrEquipCosmetic(d.id);
                                          if (mounted && ok) {
                                            setState(() => preview = null);
                                          }
                                        }
                                      }
                                    : null,
                                child:
                                    Text(c.state.equippedCosmetic(slot) == d.id
                                        ? '장착 중'
                                        : !cosmeticUnlocked(c.state, d)
                                            ? '잠김'
                                            : c.state.ownsCosmetic(d)
                                                ? '장착'
                                                : '구매')),
                          ]),
                        ]))),
          if (c.error != null) Text(c.error!),
        ]));
  }

  /// Each category previews its own subject: the pastry up close, the vendor
  /// alone, or the whole stall with vendor and pastry.
  Widget _preview(String Function(CosmeticSlot) equipped) {
    final fish = CustomPaint(
        painter: FishPainter(
            skin: equipped(CosmeticSlot.fish),
            pattern: equipped(CosmeticSlot.pattern),
            topping: equipped(CosmeticSlot.topping)));
    return switch (category) {
      CosmeticCategory.bungeoppang => ColoredBox(
          key: const Key('preview-bungeoppang'),
          color: const Color(0xff1e2140),
          child: Padding(padding: const EdgeInsets.all(12), child: fish)),
      CosmeticCategory.avatar => ColoredBox(
          key: const Key('preview-avatar'),
          color: const Color(0xff1e2140),
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                  painter: AvatarPainter(AvatarLook.of(equipped))))),
      CosmeticCategory.stall => CustomPaint(
          key: const Key('preview-stall'),
          painter: NightStallPainter(
              background: equipped(CosmeticSlot.background),
              stove: equipped(CosmeticSlot.stove),
              decoration: equipped(CosmeticSlot.decoration),
              avatar: AvatarLook.of(equipped)),
          child: Center(child: SizedBox(width: 120, height: 90, child: fish))),
    };
  }
}
