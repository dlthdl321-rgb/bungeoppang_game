import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../game_controller.dart';
import 'cozy_style.dart';
import 'gold_widgets.dart';
import 'pixel_sprites.dart';
import 'public_menus.dart';
import 'support_panels.dart';

/// Shop tabs of the concept art (3.5_completed_game_mockups/상점): gear (griddle, tongs), the
/// vendor and pastry cosmetics, and stall themes.
/// 재료 타이쿤 C: [ingredients] (the Workshop's '재료' tab, between 꾸미기
/// and 충전) only when [ShopPanel.ingredients] is given.
enum ShopTab { gear, cosmetics, ingredients, theme, gold }

/// The Workshop shop (32번 2단계: the old clicker's 장비·테마 coin shop is gone):
/// 꾸미기 (the wardrobe with avatar items for sale), 재료 and 충전.
class ShopPanel extends StatefulWidget {
  final GameController controller;
  final CosmeticMenuAccess access;

  /// Opens another sheet (the item and coin details).
  final void Function(String destination) onOpen;
  /// The Workshop shop opens its 꾸미기 tab at this slot (from the
  /// wardrobe's '상점에서 더 보기').
  final CosmeticSlot? initialSlot;
  /// A build without the online settings: the charge tab hands out free
  /// test gold instead of Play packs (4차 피드백 IC10 후속).
  final bool localTestGold;
  /// The '재료' tab's content (재료 타이쿤 C, lib/ui/pantry_shop.dart); the
  /// Workshop passes it, the old clicker has no such tab.
  final WidgetBuilder? ingredients;
  const ShopPanel({super.key, required this.controller, required this.onOpen,required this.access,this.initialSlot,
    this.localTestGold=false,this.ingredients});
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  /// The workshop opens on 꾸미기, where gold buys avatar items (26번 3단계).
  ShopTab tab = ShopTab.cosmetics;
  GameController get c => widget.controller;

  static String _label(ShopTab t) => switch (t) {
        ShopTab.gear => '장비',
        ShopTab.cosmetics => '꾸미기',
        ShopTab.ingredients => '재료',
        ShopTab.theme => '테마',
        ShopTab.gold => '충전',
      };

  /// The Workshop sells avatar items only, all in 꾸미기 (26번 4-5단계).
  List<ShopTab> get _tabs => [ShopTab.cosmetics, if (widget.ingredients != null) ShopTab.ingredients, ShopTab.gold];

  Widget _tabChips(List<ShopTab> tabs, ShopTab tab) => Wrap(spacing: 6, runSpacing: 4, children: [
        for (final t in tabs)
          ChoiceChip(
              key: Key('shop-tab-${t.name}'),
              avatar: PixelIcon(switch (t) {
                ShopTab.gear => 'tab_gear',
                ShopTab.cosmetics => 'tab_outfit',
                ShopTab.ingredients => 'tab_ingredients',
                ShopTab.theme => 'theme',
                ShopTab.gold => 'gold_bun',
              }, size: 28),
              // 4차 피드백 ID4: a chip keeps its avatar at 18 unless told.
              avatarBoxConstraints: const BoxConstraints.tightFor(width: 28, height: 28),
              // Less padding above and below, so the bigger icon does not
              // make the chip taller than before.
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              // The label is as tall as the icon: a chip's content must not be
              // shorter than its avatar.
              label: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: Center(
                      widthFactor: 1,
                      child: Text(_label(t), style: const TextStyle(fontWeight: FontWeight.w900)))),
              showCheckmark: false,
              // H41: a hairline pill; the picked one honey (no wooden outline).
              shape: StadiumBorder(side: BorderSide(color: t == tab ? Cozy.honeyDeep : Cozy.line)),
              backgroundColor: Cozy.cream,
              selected: t == tab,
              selectedColor: Cozy.honey,
              onSelected: (_) => setState(() => this.tab = t)),
      ]);

  /// The Workshop shop (26번 4-5단계, S45-Q1 B): 꾸미기 is the wardrobe's
  /// look with the avatar items for sale (locked ones to try on), bought
  /// and worn at once; 충전 is the gold tab.
  Widget _workshop(BuildContext context, CosmeticMenuAccess access) {
    final tabs = _tabs;
    final tab = tabs.contains(this.tab) ? this.tab : tabs.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: _tabChips(tabs, tab)),
      saveError(c),
      Expanded(
          child: tab == ShopTab.ingredients
              ? widget.ingredients!(context)
              : tab == ShopTab.gold
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GoldChargeTab(controller: c, localTestGold: widget.localTestGold))
              : WardrobePanel(
                  key: const Key('shop-wardrobe'),
                  controller: c,
                  access: access,
                  mode: WardrobeMode.shop,
                  initialSlot: widget.initialSlot)),
    ]);
  }

  @override
  Widget build(BuildContext context) => _workshop(context, widget.access);
}
