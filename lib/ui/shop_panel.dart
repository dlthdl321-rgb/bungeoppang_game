import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../menu_rules.dart';
import '../online_backend.dart';
import 'cozy_style.dart';
import 'gold_widgets.dart';
import 'pixel_sprites.dart';
import 'public_menus.dart';
import 'support_panels.dart';

/// Shop tabs of the concept art (07_UI/상점): gear (griddle, tongs), the
/// vendor and pastry cosmetics, and stall themes.
enum ShopTab { gear, cosmetics, theme, gold }

/// The concept art's shop (07_UI/상점): tabs 장비 / 꾸미기 / 테마 and item
/// cards (picture, name, price, 구매). Buying a cosmetic also wears it.
class ShopPanel extends StatefulWidget {
  final GameController controller;

  /// Opens another sheet (the item and coin details).
  final void Function(String destination) onOpen;
  const ShopPanel({super.key, required this.controller, required this.onOpen});
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  ShopTab tab = ShopTab.gear;
  GameController get c => widget.controller;

  static String _label(ShopTab t) => switch (t) {
        ShopTab.gear => '장비',
        ShopTab.cosmetics => '꾸미기',
        ShopTab.theme => '테마',
        ShopTab.gold => '충전',
      };

  /// 장비: the griddle and tongs; 테마: backgrounds and decorations;
  /// 꾸미기: everything else the vendor and the pastry wear.
  static ShopTab _tabOf(CosmeticSlot slot) => switch (slot) {
        CosmeticSlot.stove || CosmeticSlot.tool => ShopTab.gear,
        CosmeticSlot.background ||
        CosmeticSlot.decoration ||
        CosmeticSlot.lamp =>
          ShopTab.theme,
        _ => ShopTab.cosmetics,
      };

  static Iterable<CosmeticDefinition> _catalog(ShopTab t) =>
      cosmeticDefinitions
          .where((d) => d.collectible && d.slot.shown && _tabOf(d.slot) == t);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final t in ShopTab.values)
            ChoiceChip(
                key: Key('shop-tab-${t.name}'),
                avatar: PixelIcon(switch (t) {
                  ShopTab.gear => 'tab_gear',
                  ShopTab.cosmetics => 'tab_outfit',
                  ShopTab.theme => 'theme',
                  ShopTab.gold => 'coin',
                }, size: 18),
                label: Text(_label(t)),
                selected: t == tab,
                selectedColor: Cozy.orange,
                onSelected: (_) => setState(() => tab = t)),
        ]),
        const SizedBox(height: 8),
        saveError(c),
        if (tab == ShopTab.gold)
          GoldChargeTab(controller: c)
        else
        LayoutBuilder(builder: (context, box) {
          const gap = 8.0;
          final w = (box.maxWidth - gap) / 2;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final d in _catalog(tab))
              SizedBox(width: w, child: _cosmeticCard(context, d)),
          ]);
        }),
        if (tab == ShopTab.gear) ...[
          const SizedBox(height: 8),
          OutlinedButton(
              key: const Key('support-entry'),
              onPressed: () => widget.onOpen('support'),
              child: const Text('코인 · 부스트 보기')),
        ],
      ]));

  Widget _cosmeticCard(BuildContext context, CosmeticDefinition d) {
    final s = c.state.support;
    final owned = c.state.ownsCosmetic(d);
    final unlocked = cosmeticUnlocked(c.state, d);
    return CozyPanel(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 64,
            child: Opacity(
                opacity: unlocked ? 1 : .45,
                child: CosmeticThumb(d, c.state.equippedCosmetic))),
        const SizedBox(height: 4),
        Text(d.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          PixelIcon(owned ? 'check' : unlocked ? 'coin' : 'lock', size: 16),
          const SizedBox(width: 3),
          Flexible(
              child: Text('${cosmeticSlotLabel(d.slot)} · ${d.cost} 코인',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Cozy.inkSoft, fontSize: 12))),
        ]),
        const SizedBox(height: 4),
        FilledButton(
            key: Key('shop-buy-${d.id}'),
            style: FilledButton.styleFrom(
                backgroundColor: Cozy.orange, foregroundColor: Cozy.ink),
            onPressed: !c.busy && !owned && unlocked && s.coins >= d.cost
                ? () async {
                    if (await confirmAction(
                        context,
                        '${d.name} 구매',
                        '가격 ${d.cost} 코인\n코인 ${exactNumber(s.coins)} → ${exactNumber(s.coins - d.cost)}\n영구 보유 · 바로 장착',
                        '구매')) {
                      await c.buyOrEquipCosmetic(d.id);
                    }
                  }
                : null,
            child: FittedBox(
                child: Text(owned
                    ? '보유 중'
                    : unlocked
                        ? '구매'
                        : 'Lv.${d.unlockLevel} 해금'))),
        if (!owned)
          GoldPriceButton(
              controller: c,
              kind: PremiumKind.cosmetic,
              itemId: d.id,
              title: '${d.name} 구매',
              effect: unlocked ? '영구 보유' : '영구 보유 · 레벨 잠금 없이 바로'),
      ]),
    );
  }
}
