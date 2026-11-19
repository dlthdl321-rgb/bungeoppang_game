import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import 'avatar_face.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'fish_painter.dart';
import 'lock_overlay.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'public_menus.dart';

/// What a Workshop wardrobe panel is for (26번 4-5단계, S45-Q1 B).
enum WardrobeMode {
  /// 꾸미기: try on what the player owns (free items included) and wear
  /// every changed slot at once with '모두 적용(N)'. Nothing is bought.
  wear,
  /// 상점 꾸미기 탭: the avatar items for sale (locked ones too, to try
  /// on), bought one at a time and worn at once ('사고 바로 입기').
  shop,
}

/// The Workshop's wardrobe and avatar shop (26번 4-5단계, F25~F36, G1·G2·
/// G5·G8·G14·G15): bookmark tabs, a preview with a '입어 보는 중' ribbon and
/// '↺' in its top-left corner and the action button in its bottom-right
/// corner (S45-Q3), bookmark slot tabs, and square-cornered item cards with
/// the item's icon (시안 확인 2차: (나) 책갈피 탭 + 각진 카드).
/// Only the tile grid scrolls, so the button never leaves the screen.
/// Picks are kept per slot across slots and tabs, all drawn together.
class WorkshopWardrobe extends StatefulWidget {
  final CosmeticMenuAccess access;
  final WardrobeMode mode;
  final WardrobeTab initialTab;
  final CosmeticSlot? initialSlot;
  final bool animate;
  /// Wear mode: opens the shop at [CosmeticSlot] ('상점에서 더 보기').
  final void Function(CosmeticSlot slot)? onMore;
  const WorkshopWardrobe(
      {super.key,
      required this.access,
      this.mode = WardrobeMode.wear,
      this.initialTab = WardrobeTab.hair,
      this.initialSlot,
      this.animate = true,
      this.onMore});

  @override
  State<WorkshopWardrobe> createState() => _WorkshopWardrobeState();
}

class _WorkshopWardrobeState extends State<WorkshopWardrobe> {
  late WardrobeTab tab;
  late CosmeticSlot slot;
  /// What the player is trying on, by slot (only slots that differ from
  /// what is worn).
  final picks = <CosmeticSlot, String>{};
  /// Shop mode: the item the buy button is for.
  String? focus;
  /// Why some picks could not be worn, after '모두 적용'.
  String? message;
  bool working = false;

  CosmeticMenuAccess get a => widget.access;
  bool get shop => widget.mode == WardrobeMode.shop;

  bool _forSale(CosmeticDefinition d) => a.forSale?.call(d) ?? !a.owned(d);

  /// The items a slot's grid shows: owned ones to wear, or the ones for
  /// sale in the shop.
  List<CosmeticDefinition> _items(CosmeticSlot s) => [
        for (final d in cosmeticDefinitions)
          if (d.slot == s && a.listed(d) && (shop ? _forSale(d) && !a.owned(d) : a.owned(d))) d
      ];

  /// Wear mode: whether the shop has more of [s] to buy.
  bool _more(CosmeticSlot s) => cosmeticDefinitions.any((d) => d.slot == s && a.listed(d) && _forSale(d) && !a.owned(d));

  List<CosmeticSlot> _slots(WardrobeTab t) => [
        for (final s in CosmeticSlot.values)
          if (s.shown && s.tab == t && (a.slotOpen?.call(s) ?? true) && (!shop || _items(s).isNotEmpty)) s
      ];

  List<WardrobeTab> get _tabs => [
        for (final t in WardrobeTab.values)
          if ((a.tabOpen?.call(t) ?? true) && _slots(t).isNotEmpty) t
      ];

  @override
  void initState() {
    super.initState();
    final tabs = _tabs;
    final start = widget.initialSlot?.tab ?? widget.initialTab;
    tab = tabs.contains(start) ? start : (tabs.isEmpty ? widget.initialTab : tabs.first);
    final slots = _slots(tab);
    slot = slots.contains(widget.initialSlot) ? widget.initialSlot! : (slots.isEmpty ? CosmeticSlot.hair : slots.first);
  }

  String _shown(CosmeticSlot s) => picks[s] ?? a.equipped(s);

  CosmeticDefinition _def(CosmeticSlot s, String id) => cosmeticDefinitions.firstWhere((d) => d.slot == s && d.id == id);

  void _pick(CosmeticDefinition d) => setState(() {
        message = null;
        if (a.equipped(d.slot) == d.id) {
          picks.remove(d.slot);
        } else {
          picks[d.slot] = d.id;
        }
        if (shop) focus = d.id;
      });

  void _revert() => setState(() {
        picks.clear();
        focus = null;
        message = null;
      });

  /// Wears every changed slot, one after another; what fails stays tried
  /// on and is named.
  Future<void> _applyAll() async {
    setState(() => working = true);
    final failed = <String>[];
    for (final e in Map.of(picks).entries) {
      final d = _def(e.key, e.value);
      if (await a.apply(d)) {
        picks.remove(e.key);
      } else {
        failed.add(d.name);
      }
      if (!mounted) return;
    }
    setState(() {
      working = false;
      picks.removeWhere((s, id) => a.equipped(s) == id);
      message = failed.isEmpty ? null : '${failed.join(', ')}은(는) 지금 입을 수 없어요.';
    });
  }

  Future<void> _buy(CosmeticDefinition d) async {
    final price = a.cost?.call(d);
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              key: const Key('wardrobe-buy-dialog'),
              title: Text('${d.name} 사기'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (price != null)
                  Wrap(spacing: 12, children: [
                    CurrencyAmount(Currency.buns, price.buns, size: 22, fontSize: 18),
                    if (price.gold > BigInt.zero) CurrencyAmount(Currency.gold, price.gold, size: 22, fontSize: 18),
                  ]),
                const SizedBox(height: 8),
                const Text('사면 계속 갖고, 바로 입어요.'),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                FilledButton(
                    key: const Key('wardrobe-buy-confirm'),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('사고 바로 입기')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => working = true);
    final bought = await a.apply(d);
    if (!mounted) return;
    setState(() {
      working = false;
      if (bought) {
        picks.removeWhere((s, id) => a.equipped(s) == id);
        focus = null;
        message = null;
      } else {
        message = '${d.name}을(를) 사지 못했어요.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (!tabs.contains(tab) && tabs.isNotEmpty) tab = tabs.first;
    final slots = _slots(tab);
    if (!slots.contains(slot) && slots.isNotEmpty) slot = slots.first;
    if (tabs.isEmpty) {
      return const Center(
          key: Key('wardrobe-empty'),
          child: Padding(padding: EdgeInsets.all(24), child: Text('지금 살 수 있는 꾸미기를 모두 모았어요.', textAlign: TextAlign.center)));
    }
    return LayoutBuilder(builder: (context, box) {
      final previewHeight = (box.maxHeight.isFinite ? box.maxHeight * .36 : 200.0).clamp(150.0, 220.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WardrobeTabRow(
            children: [
              for (final t in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: WardrobePill(
                      key: Key('cosmetic-category-${t.name}'),
                      label: wardrobeTabLabel(t),
                      icon: switch (t) {
                        WardrobeTab.hair => 'tab_hair',
                        WardrobeTab.outfit => 'tab_outfit',
                        WardrobeTab.props => 'tab_acc',
                        WardrobeTab.bungeoppang => 'tab_fish',
                        WardrobeTab.stall => 'tab_stall',
                      },
                      selected: t == tab,
                      onTap: () => setState(() {
                            tab = t;
                            slot = _slots(t).first;
                          })),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: previewHeight, child: _previewBox()),
          const SizedBox(height: 8),
          WardrobeTabRow(
            small: true,
            children: [
              for (final s in slots)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: WardrobePill(
                      key: Key('cosmetic-slot-${s.name}'),
                      label: cosmeticSlotLabel(s),
                      small: true,
                      selected: s == slot,
                      changed: picks.containsKey(s),
                      onTap: () => setState(() => slot = s)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _grid()),
        ]),
      );
    });
  }

  Widget _grid() {
    final items = _items(slot);
    final more = !shop && widget.onMore != null && _more(slot);
    return LayoutBuilder(builder: (context, box) {
      const gap = 8.0;
      final w = (box.maxWidth - gap * 2) / 3;
      return SingleChildScrollView(
        key: const Key('wardrobe-grid'),
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: gap, runSpacing: gap, children: [
          for (final d in items) SizedBox(width: w, child: _tile(d)),
          if (more)
            SizedBox(
                width: w,
                child: WardrobeMoreTile(key: Key('wardrobe-more-${slot.name}'), onTap: () => widget.onMore!(slot))),
          if (items.isEmpty && !more)
            const Padding(padding: EdgeInsets.all(12), child: Text('이 칸에는 아직 고를 것이 없어요.')),
        ]),
      );
    });
  }

  Widget _tile(CosmeticDefinition d) {
    final worn = a.equipped(d.slot) == d.id;
    final tried = picks[d.slot] == d.id;
    final unlocked = a.unlocked(d);
    final price = shop ? a.cost?.call(d) : null;
    final caption = a.requirement?.call(d) ?? '';
    final WardrobeTileState state = worn
        ? WardrobeTileState.worn
        : !shop
            ? WardrobeTileState.owned
            : !unlocked
                ? WardrobeTileState.locked
                : price != null && (price.missingBuns || price.missingGold)
                    ? WardrobeTileState.short
                    : WardrobeTileState.buyable;
    return WardrobeTile(
      key: Key('preview-${d.id}'),
      name: d.name,
      state: state,
      selected: tried || (shop && focus == d.id && !worn),
      price: price,
      lockCaption: caption,
      picture: CosmeticThumb(d, a.equipped),
      onTap: () => _pick(d),
    );
  }

  Widget _previewBox() {
    final changed = picks.length;
    final focused = shop && focus != null ? cosmeticDefinitions.where((d) => d.id == focus && picks[d.slot] == d.id).firstOrNull : null;
    return Semantics(
      label: '${wardrobeTabLabel(tab)} 꾸미기 미리보기',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: changed > 0 ? Cozy.honeyDeep : Cozy.woodLight, width: changed > 0 ? 3 : 2),
          boxShadow: const [BoxShadow(color: Cozy.shadow, offset: Offset(0, 2), blurRadius: 3)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            _preview(),
            if (changed > 0)
              Positioned(
                left: 8,
                top: 8,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  WardrobeRibbon(key: const Key('cosmetic-preview-status'), label: '입어 보는 중'),
                  const SizedBox(width: 6),
                  Material(
                    color: Cozy.cream,
                    shape: const CircleBorder(side: BorderSide(color: Cozy.woodLight, width: 1.5)),
                    child: InkWell(
                      key: const Key('wardrobe-revert'),
                      customBorder: const CircleBorder(),
                      onTap: working ? null : _revert,
                      child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(Icons.undo_rounded, size: 20, color: Cozy.wood, semanticLabel: '되돌리기')),
                    ),
                  ),
                ]),
              ),
            if (message != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 58,
                child: Container(
                  key: const Key('wardrobe-message'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Cozy.cream.withValues(alpha: .94), borderRadius: BorderRadius.circular(10)),
                  child: Text(message!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cozy.brick)),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: shop
                  ? (focused == null
                      ? const SizedBox.shrink()
                      : CozyPrimaryButton(
                          key: Key('buy-cosmetic-${focused.id}'),
                          minHeight: 40,
                          fontSize: 16,
                          onPressed: working || !a.canApply(focused) ? null : () => _buy(focused),
                          label: a.unlocked(focused) ? '사고 바로 입기' : a.requirement?.call(focused) ?? '잠김'))
                  : CozyPrimaryButton(
                      key: const Key('wardrobe-apply-all'),
                      minHeight: 40,
                      fontSize: 16,
                      onPressed: working || changed == 0 ? null : _applyAll,
                      label: changed == 0 ? '모두 적용' : '모두 적용($changed)'),
            ),
          ]),
        ),
      ),
    );
  }

  /// Each tab previews its own subject: the pastry up close, the vendor in
  /// the shop's back room (25번 11번, no counter), or the stall itself
  /// (시안 확인 2차: no vendor, a wide stall scene where the stall items
  /// show — [StallPreviewPainter]).
  Widget _preview() {
    final fish = CustomPaint(
        painter: FishPainter(
            skin: _shown(CosmeticSlot.fish), pattern: _shown(CosmeticSlot.pattern), topping: _shown(CosmeticSlot.topping)));
    return switch (tab) {
      WardrobeTab.bungeoppang => ColoredBox(
          key: const Key('preview-bungeoppang'),
          color: Cozy.woodDark,
          child: Padding(padding: const EdgeInsets.fromLTRB(24, 30, 24, 24), child: fish)),
      WardrobeTab.hair || WardrobeTab.outfit || WardrobeTab.props => ColoredBox(
          key: const Key('preview-avatar'),
          color: Cozy.woodDark,
          child: Stack(fit: StackFit.expand, children: [
            FittedBox(
                key: const Key('preview-room'),
                fit: BoxFit.cover,
                child: PixelArt(PixelSprites.screenArt('wardrobe_room') ?? PixelSprites.screenArt('wardrobe_bg'),
                    width: 240, height: 144)),
            // Blinks by itself; tapping does not make it talk (G2).
            Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: AvatarFace(
                    animate: widget.animate,
                    builder: (context, face) => CustomPaint(
                        key: const Key('preview-avatar-face'), painter: AvatarPainter(AvatarLook.of(_shown), face: face)))),
          ])),
      WardrobeTab.stall => ColoredBox(
          key: const Key('preview-stall'),
          color: Cozy.woodDark,
          child: CustomPaint(
              key: const Key('preview-stall-scene'),
              size: Size.infinite,
              painter: StallPreviewPainter(
                  background: _shown(CosmeticSlot.background),
                  night: isNightTime(_shown(CosmeticSlot.time), DateTime.now()),
                  stove: _shown(CosmeticSlot.stove),
                  decoration: _shown(CosmeticSlot.decoration),
                  lamp: _shown(CosmeticSlot.lamp)))),
    };
  }
}

/// The 가게 tab's preview (시안 확인 2차, 2026-11-19: the tall home scene
/// squeezed into the wide box looked odd, with the vendor in front): a
/// wide stall scene made of the stall items themselves. The background's
/// street down to the counter fills the box (its towel row at
/// [counterShare] of the height), the decoration hangs from the top (string
/// kinds across the width, a pair of lanterns or chimes inward of the
/// lamps, the snowman standing at the right on the counter), the lamp
/// glass shows as the whole post lamp at both edges, and the griddle sits
/// on the counter a little left of the middle. No vendor.
class StallPreviewPainter extends CustomPainter {
  final String background, stove, decoration, lamp;
  final bool? night;
  const StallPreviewPainter(
      {required this.background, required this.night, required this.stove, required this.decoration, required this.lamp});

  /// Where the counter's top (the background's towel row) shows, as a
  /// share of the box height.
  static const counterShare = .68;
  /// The griddle's width as a share of the box width, its centre at
  /// [stoveCentre] of the width; it may take at most [stoveMaxHeight] of
  /// the height and its bottom sits [stoveBottom] above the box's bottom.
  static const stoveWidth = .5, stoveCentre = .45, stoveMaxHeight = .52, stoveBottom = 2.0;
  /// The post lamps at both edges: this share of the height, [edge] in.
  static const lampHeight = .42, edge = 2.0;
  /// Hanging decorations hang [hangTop] below the box's top; a pair hangs
  /// with its outer edges at [pairInset] of the width from each side.
  static const hangTop = 4.0, pairInset = .17;
  /// Decorations that stand on the counter at the right (their right edge
  /// at [standRight] of the width) instead of hanging.
  static const standing = {'snowman'};
  static const standRight = .86;
  /// A decoration this many scene units wide or more is a string across.
  static const stringWidth = 150.0;
  /// Where a background without a measured towel has its counter's top,
  /// as a share of its height (the concept backgrounds: 524 of 762).
  static const towelShare = .69;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cozy.woodDark);
    // Scene units (the 180-wide stall scene) to box pixels.
    final k = size.width / NightStallPainter.sceneSize.width;
    final low = PixelSprites.lowStallBackground(background, night);
    final (image, darken) = low.$1 != null ? low : PixelSprites.sceneBackground(background, night, clean: true);
    if (image != null) {
      final iw = image.width.toDouble(), ih = image.height.toDouble();
      var sw = iw, sh = iw * size.height / size.width;
      if (sh > ih) {
        sh = ih;
        sw = ih * size.width / size.height;
      }
      final path = PixelSprites.pathOf(image)?.replaceFirst('assets/images/', '').replaceFirst(RegExp(r'\.png$'), '');
      final towel = NightStallPainter.towelTops[path]?.toDouble() ?? ih * towelShare;
      final top = (towel - counterShare * sh).clamp(0.0, ih - sh);
      canvas.drawImageRect(image, Rect.fromLTWH((iw - sw) / 2, top, sw, sh), Offset.zero & size,
          Paint()..filterQuality = FilterQuality.medium);
      if (darken) {
        canvas.drawRect(
            Offset.zero & size,
            Paint()
              ..color = const Color(0xff4a4f8f)
              ..blendMode = BlendMode.multiply);
      }
    }
    final counterY = size.height * counterShare;
    final deco = PixelSprites.cosmetic(CosmeticSlot.decoration, decoration);
    final ds = deco == null
        ? Size.zero
        : Size(deco.width / NightStallPainter.decorationScale * k, deco.height / NightStallPainter.decorationScale * k);
    void drawDeco(Rect dst, {bool mirror = false}) {
      if (!mirror) return PixelSprites.draw(canvas, deco, dst);
      canvas.save();
      canvas.translate(dst.left + dst.right, 0);
      canvas.scale(-1, 1);
      PixelSprites.draw(canvas, deco, dst);
      canvas.restore();
    }

    final string = deco != null && ds.width / k >= stringWidth;
    final stands = deco != null && standing.contains(decoration);
    if (string) drawDeco(Offset(0, hangTop) & Size(size.width, ds.height * size.width / ds.width));
    if (stands) drawDeco(Offset(size.width * standRight - ds.width, counterY - ds.height) & ds);
    final lamps = cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.lamp);
    final lampArt = lamps.isEmpty
        ? null
        : PixelSprites.stallTile(lamps.firstWhere((d) => d.id == lamp, orElse: () => lamps.first));
    if (lampArt != null) {
      final h = size.height * lampHeight, w = h * lampArt.width / lampArt.height;
      PixelSprites.draw(canvas, lampArt, Rect.fromLTWH(edge, hangTop, w, h));
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      PixelSprites.draw(canvas, lampArt, Rect.fromLTWH(edge, hangTop, w, h));
      canvas.restore();
    }
    if (deco != null && !string && !stands) {
      final pair = NightStallPainter.decorationAt[decoration] ?? const <(Offset, bool)>[];
      for (final (i, (_, mirror)) in pair.indexed) {
        final left = i == 0 ? size.width * pairInset : size.width * (1 - pairInset) - ds.width;
        drawDeco(Offset(left, hangTop) & ds, mirror: mirror);
      }
    }
    final griddle = PixelSprites.cosmetic(CosmeticSlot.stove, stove);
    if (griddle != null) {
      var w = size.width * stoveWidth, h = w * griddle.height / griddle.width;
      if (h > size.height * stoveMaxHeight) {
        h = size.height * stoveMaxHeight;
        w = h * griddle.width / griddle.height;
      }
      PixelSprites.draw(
          canvas, griddle, Rect.fromLTWH(size.width * stoveCentre - w / 2, size.height - stoveBottom - h, w, h));
    }
  }

  @override
  bool shouldRepaint(StallPreviewPainter old) =>
      old.background != background ||
      old.night != night ||
      old.stove != stove ||
      old.decoration != decoration ||
      old.lamp != lamp;
}

/// A wardrobe price with what the player lacks marked.
class WardrobePrice {
  final BigInt buns, gold;
  final bool missingBuns, missingGold;
  const WardrobePrice(this.buns, this.gold, {this.missingBuns = false, this.missingGold = false});
}

/// The five looks of an item tile (F29).
enum WardrobeTileState { worn, owned, buyable, short, locked }

/// A row of [WardrobePill] bookmark tabs standing on a thin wooden line,
/// scrolling sideways when they do not fit (시안 확인 2차 (나)).
class WardrobeTabRow extends StatelessWidget {
  final List<Widget> children;
  final bool small;
  const WardrobeTabRow({super.key, required this.children, this.small = false});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: small ? Cozy.tan : Cozy.wood, width: small ? 1.5 : 2))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: children),
        ),
      );
}

/// A bookmark tab (시안 확인 2차 (나) 책갈피 탭, replacing the G8 pill):
/// rounded top corners and a flat bottom on the row's line; the chosen tab
/// is peach and [WardrobePill.raise] taller, the others cream. [changed]
/// puts a small honey dot on a slot that is being tried on. (The name is
/// kept from the pill it replaced.)
class WardrobePill extends StatelessWidget {
  final String label;
  final String? icon;
  final bool selected, small, changed;
  final VoidCallback onTap;
  const WardrobePill(
      {super.key, required this.label, required this.selected, required this.onTap, this.icon, this.small = false, this.changed = false});

  /// Corner radius of the tab's top, and how much taller the chosen tab is.
  static const radius = 7.0, raise = 4.0;

  @override
  Widget build(BuildContext context) {
    const top = BorderRadius.vertical(top: Radius.circular(radius));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Cozy.peach : Cozy.cream,
        shape: RoundedRectangleBorder(
            borderRadius: top, side: BorderSide(color: selected ? Cozy.wood : Cozy.tan, width: selected ? 2 : 1.5)),
        child: InkWell(
          borderRadius: top,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (small ? 30 : 36) + (selected ? raise : 0)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[PixelIcon(icon!, size: 20), const SizedBox(width: 4)],
                Text(label,
                    style: TextStyle(
                        fontSize: small ? 14 : 15,
                        fontWeight: FontWeight.w900,
                        color: selected ? Cozy.ink : Cozy.wood)),
                if (changed) ...[
                  const SizedBox(width: 4),
                  Container(
                      key: const Key('slot-changed-dot'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: selected ? Cozy.brick : Cozy.honeyDeep, shape: BoxShape.circle)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small ribbon in the preview's corner (G15).
class WardrobeRibbon extends StatelessWidget {
  final String label;
  const WardrobeRibbon({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
        decoration: BoxDecoration(
          color: Cozy.honeyLight,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12), right: Radius.circular(6)),
          border: Border.all(color: Cozy.wood, width: 1.5),
          boxShadow: const [BoxShadow(color: Cozy.shadow, offset: Offset(0, 1.5), blurRadius: 1)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 14, color: Cozy.brick),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Cozy.ink)),
        ]),
      );
}

/// One item: a square-cornered card (시안 확인 2차 (나)) with its icon on a
/// square plate, its name and one state line (F28·F29). Locked items stay tappable to try on (the common lock with
/// 'Lv.N 해금' over the icon only, so the item still shows).
class WardrobeTile extends StatelessWidget {
  final String name, lockCaption;
  final WardrobeTileState state;
  final bool selected;
  final WardrobePrice? price;
  final Widget picture;
  final VoidCallback onTap;
  const WardrobeTile(
      {super.key,
      required this.name,
      required this.state,
      required this.picture,
      required this.onTap,
      this.selected = false,
      this.price,
      this.lockCaption = ''});

  /// The card's and the plate's corner radius ('각진 카드').
  static const radius = 4.0;

  String get _stateLabel => switch (state) {
        WardrobeTileState.worn => '입는 중',
        WardrobeTileState.owned => '보유',
        WardrobeTileState.buyable => '살 수 있어요',
        WardrobeTileState.short => price?.missingBuns == true ? '붕어빵력 모자람' : '황금붕어빵력 모자람',
        WardrobeTileState.locked => lockCaption,
      };

  @override
  Widget build(BuildContext context) {
    final worn = state == WardrobeTileState.worn;
    final border = worn ? Cozy.woodDark : selected ? Cozy.honeyDeep : Cozy.tan;
    final plate = LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth * .68;
      final icon = Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: selected ? Cozy.peach : Cozy.creamDeep,
          borderRadius: BorderRadius.circular(WardrobeTile.radius),
        ),
        padding: EdgeInsets.all(side * .1),
        child: picture,
      );
      return Center(
          child: state == WardrobeTileState.locked
              ? SizedBox(
                  width: side,
                  height: side,
                  child: LockedOverlay(caption: lockCaption, showCaption: false, maxLock: side * .5, onTap: onTap, child: icon))
              : icon);
    });
    return Semantics(
      button: true,
      selected: selected,
      label: '$name $_stateLabel',
      excludeSemantics: true,
      child: Material(
        color: Cozy.cream,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WardrobeTile.radius),
            side: BorderSide(color: border, width: worn || selected ? 2.5 : 1.2)),
        elevation: selected ? 2 : .5,
        shadowColor: Cozy.shadow,
        child: InkWell(
          borderRadius: BorderRadius.circular(WardrobeTile.radius),
          onTap: onTap,
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Column(children: [
                plate,
                const SizedBox(height: 4),
                Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Cozy.ink, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                SizedBox(height: 20, child: _status()),
              ]),
            ),
            if (worn)
              Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                      key: const Key('tile-worn'),
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Cozy.woodDark, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 14, color: Cozy.cream))),
          ]),
        ),
      ),
    );
  }

  Widget _status() {
    final p = price;
    if ((state == WardrobeTileState.buyable || state == WardrobeTileState.short) && p != null) {
      // One line, always (F28): shrinks rather than wraps.
      return FittedBox(
          key: const Key('tile-price'),
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CurrencyAmount(Currency.buns, p.buns, missing: p.missingBuns, size: 16, fontSize: 13),
            if (p.gold > BigInt.zero) ...[
              const SizedBox(width: 6),
              CurrencyAmount(Currency.gold, p.gold, missing: p.missingGold, size: 16, fontSize: 13),
            ],
          ]));
    }
    final colour = switch (state) {
      WardrobeTileState.worn => Cozy.wood,
      WardrobeTileState.locked => Cozy.brick,
      _ => Cozy.inkSoft,
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        key: Key('tile-state-${state.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: state == WardrobeTileState.owned || state == WardrobeTileState.worn
            ? BoxDecoration(
                color: state == WardrobeTileState.worn ? Cozy.honeyLight : Cozy.creamDeep,
                borderRadius: BorderRadius.circular(10))
            : null,
        child: Text(_stateLabel,
            maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colour)),
      ),
    );
  }
}

/// The last wardrobe tile: more of this slot in the shop (S45-Q1 B).
class WardrobeMoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const WardrobeMoreTile({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Cozy.creamDeep,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WardrobeTile.radius),
            side: const BorderSide(color: Cozy.woodLight, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(WardrobeTile.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Column(children: [
              LayoutBuilder(
                  builder: (context, box) => SizedBox(
                      height: box.maxWidth * .68,
                      child: const Center(child: PixelIcon('shop', size: 40)))),
              const SizedBox(height: 4),
              const Text('상점에서\n더 보기',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.w900, color: Cozy.wood)),
            ]),
          ),
        ),
      );
}
