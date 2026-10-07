import 'package:flutter/material.dart';
import '../balance.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../models.dart';
import '../online_backend.dart';
import 'gold_widgets.dart';
import 'pixel_sprites.dart';

class SkillShop extends StatefulWidget {
  final GameController controller;
  const SkillShop({super.key, required this.controller});
  @override
  State<SkillShop> createState() => _SkillShopState();
}

class _SkillShopState extends State<SkillShop> {
  UpgradeKind _kind = UpgradeKind.tap;
  PurchaseMode _mode = PurchaseMode.one;

  @override
  Widget build(BuildContext context) {
    final skills = upgrades.where((u) => u.kind == _kind).toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final kind in UpgradeKind.values)
              ChoiceChip(
                  key: Key('kind-${kind.name}'),
                  avatar: PixelIcon(
                      kind == UpgradeKind.tap ? 'tab_tap' : 'tab_auto',
                      size: 18),
                  label: Text(kind == UpgradeKind.tap ? '클릭 생산' : '자동 생산'),
                  selected: kind == _kind,
                  onSelected: (_) => setState(() => _kind = kind)),
          ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final item in const [
              (PurchaseMode.one, '1개'),
              (PurchaseMode.ten, '10개'),
              (PurchaseMode.maximum, '최대')
            ])
              ChoiceChip(
                  key: Key('quantity-${item.$1.name}'),
                  avatar: item.$1 == PurchaseMode.ten
                      ? const PixelIcon('buy10', size: 18)
                      : null,
                  label: Text(item.$2),
                  selected: _mode == item.$1,
                  onSelected: (_) => setState(() => _mode = item.$1)),
          ])),
      Expanded(
          child: ListView.builder(
              key: ValueKey('skills-${_kind.name}'),
              padding: const EdgeInsets.all(12),
              itemCount: skills.length,
              itemBuilder: (_, index) => _card(skills[index], index + 1))),
    ]);
  }

  Widget _card(UpgradeDefinition u, int tier) {
    final c = widget.controller;
    final q = quoteUpgrade(c.state, u, _mode, at: c.gameNow);
    final owned = c.state.upgradeCounts[u.id] ?? 0;
    final canBuy = q.affordable && !c.busy;
    final unit = u.kind == UpgradeKind.tap ? '클릭당' : '초당';
    final nextPrice = q.maxed ? BigInt.zero : priceAt(u, owned);
    final status = !q.unlocked
        ? '잠김 · 누적 ${compactNumber(u.unlockTotal)}개 해금'
        : q.maxed
            ? '최대 강화'
            : canBuy
                ? '구매 가능'
                : '재화 부족';
    final amountLabel =
        _mode == PurchaseMode.maximum ? '최대 ${q.amount}개' : '${q.amount}개';
    return Card(
      key: Key('skill-${u.id}'),
      color: canBuy ? const Color(0xffecfbf0) : null, // palette mint0
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: canBuy ? const Color(0xff63ba8c) : const Color(0xffddd6ea),
              width: canBuy ? 2 : 1)),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                PixelImage(PixelSprites.skill(u.id), size: 48),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('$tier단계 · ${u.name}',
                        style: Theme.of(context).textTheme.titleMedium)),
              ]),
              Text(
                  '$owned/$maxUpgradeCount · 1개마다 $unit +${compactNumber(u.effect)}'),
              if (!q.unlocked)
                const Align(
                    alignment: Alignment.centerLeft,
                    child: PixelIcon('lock', size: 18)),
              Text(status,
                  key: Key('status-${u.id}'),
                  style: TextStyle(
                      color: canBuy ? const Color(0xff235f37) : null,
                      fontWeight: FontWeight.w700)),
              if (!q.unlocked)
                Align(
                    alignment: Alignment.centerLeft,
                    child: GoldPriceButton(
                        controller: c,
                        kind: PremiumKind.skill,
                        itemId: u.id,
                        title: '${u.name} 먼저 해금',
                        effect: '누적 생산 조건 없이 지금 붕어빵으로 살 수 있어요')),
              const SizedBox(height: 8),
              Text('현재 $unit ${compactNumber(q.currentRate)}',
                  key: Key('current-${u.id}')),
              Text('$amountLabel 구매 후 $unit ${compactNumber(q.afterRate)}',
                  key: Key('after-${u.id}')),
              if (q.amount == 0 && !q.maxed)
                Text('다음 1개 가격 ${compactNumber(nextPrice)}'),
              const SizedBox(height: 8),
              FilledButton(
                  key: Key('buy-${u.id}'),
                  onPressed: canBuy
                      ? () async {
                          final ok = _mode == PurchaseMode.maximum
                              ? await c.buyMaximum(u)
                              : await c.buyUpgrade(u, q.amount);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(c.error ??
                                    '구매 조건이 바뀌었어요. 다시 확인해 주세요.')));
                          }
                        }
                      : null,
                  child: Text(q.maxed
                      ? '최대 강화'
                      : '$amountLabel · ${compactNumber(q.cost)}')),
              TextButton(
                  onPressed: () => _details(u, q),
                  child: const Text('자세히 보기')),
            ],
          )),
    );
  }

  Future<void> _details(UpgradeDefinition u, UpgradeQuote q) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(u.name),
          content: SelectableText('수량 ${q.amount}개\n가격 ${exactNumber(q.cost)}\n'
              '현재 효과 ${exactNumber(q.currentRate)}\n구매 후 효과 ${exactNumber(q.afterRate)}\n'
              '해금: 누적 ${exactNumber(u.unlockTotal)}개\n가격은 개당 가격 올림 합계'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('확인'))
          ],
        ),
      );
}
