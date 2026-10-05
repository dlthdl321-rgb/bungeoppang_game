import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../menu_rules.dart';
import 'fish_painter.dart';
import 'night_stall_painter.dart';
import 'support_panels.dart';

class WardrobePanel extends StatefulWidget {
  final GameController controller;
  const WardrobePanel({super.key, required this.controller});
  @override
  State<WardrobePanel> createState() => _WardrobePanelState();
}

class _WardrobePanelState extends State<WardrobePanel> {
  CosmeticSlot slot = CosmeticSlot.fish;
  String? preview;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    String equipped(CosmeticSlot s) =>
        s == slot && preview != null ? preview! : c.state.equippedCosmetic(s);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('노점과 붕어빵의 모습을 바꿉니다. 생산 효과는 없습니다.'),
          Wrap(spacing: 8, children: [
            for (final s in CosmeticSlot.values)
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
              label: '꾸미기 미리보기, 구매 전에는 저장되지 않음',
              child: SizedBox(
                  height: 180,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                          painter: NightStallPainter(
                              background: equipped(CosmeticSlot.background),
                              stove: equipped(CosmeticSlot.stove),
                              decoration: equipped(CosmeticSlot.decoration)),
                          child: Center(
                              child: SizedBox(
                                  width: 180,
                                  height: 135,
                                  child: CustomPaint(
                                      painter: FishPainter(
                                          skin: equipped(
                                              CosmeticSlot.fish))))))))),
          Text(preview == null ? '현재 장착 모습' : '미리보기 · 아직 장착되지 않았습니다',
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
                          Text('가격 ${compactNumber(d.cost)} 코인 · 생산 효과 없음'),
                          Text(
                              '해금: 레벨 ${d.unlockLevel} · 누적 ${compactNumber(d.unlockProductionAmount)}개'),
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
                                                '가격 ${d.cost} 코인\n현재 ${exactNumber(c.state.support.coins)} → 구매 후 ${exactNumber(c.state.support.coins - d.cost)} 코인\n미보유 → 영구 보유·장착\n생산 효과 없음',
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
}
