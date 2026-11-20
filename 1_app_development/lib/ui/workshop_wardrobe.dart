import 'dart:ui' as ui;
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
import 'workshop_home_layout.dart';

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
/// G5·G8·G14·G15; 3차 피드백 H13~H16): bookmark tabs that share the width,
/// a preview with a small '입어 보는 중' chip in its top-left corner, one
/// slim row of small buttons under it ('모두 취소'·'모두 사기'·'모두 적용';
/// a hint while nothing is tried on), bookmark slot tabs, and square-cornered
/// item cards with the item's icon (시안 확인 2차: (나) 책갈피 탭 + 각진
/// 카드). Only the tile grid scrolls, so the buttons never leave the screen.
/// Picks are kept per slot across slots and tabs, all drawn together.
class WorkshopWardrobe extends StatefulWidget {
  final CosmeticMenuAccess access;
  final WardrobeMode mode;
  final WardrobeTab initialTab;
  final CosmeticSlot? initialSlot;
  final bool animate;
  /// Wear mode: opens the shop at [CosmeticSlot] ('상점에서 더 보기'). Since
  /// 3차 피드백 H15 the wardrobe lists what is for sale itself, so the tile
  /// shows only for a slot whose items for sale are not listed here.
  final void Function(CosmeticSlot slot)? onMore;
  /// Wear mode: closes the window once everything tried on is worn
  /// ('모두 적용'/'모두 사기', H15: no going back to wear it).
  final VoidCallback? onClose;
  const WorkshopWardrobe(
      {super.key,
      required this.access,
      this.mode = WardrobeMode.wear,
      this.initialTab = WardrobeTab.hair,
      this.initialSlot,
      this.animate = true,
      this.onMore,
      this.onClose});

  /// The preview's corner radius and the action row's height.
  static const previewRadius = 12.0, actionHeight = 34.0;
  /// The 배경 tab's preview box: this share of the panel's height, at most
  /// [stallPreviewMax] (4차 피드백 g10 ID5; other tabs .34, 140~210).
  static const stallPreviewShare = .44, stallPreviewMax = 300.0;

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
  /// Why some picks could not be worn or bought.
  String? message;
  bool working = false;

  CosmeticMenuAccess get a => widget.access;
  bool get shop => widget.mode == WardrobeMode.shop;

  bool _forSale(CosmeticDefinition d) => a.forSale?.call(d) ?? !a.owned(d);

  /// The items a slot's grid shows: in the wardrobe what is owned first,
  /// then what is for sale to try on and buy (3차 피드백 H15); in the shop
  /// only what is for sale.
  List<CosmeticDefinition> _items(CosmeticSlot s) => [
        for (final d in cosmeticDefinitions)
          if (d.slot == s && a.listed(d) && a.owned(d) && !shop) d,
        for (final d in cosmeticDefinitions)
          if (d.slot == s && a.listed(d) && !a.owned(d) && _forSale(d)) d,
      ];

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

  String _shown(CosmeticSlot s) {
    final picked = picks[s];
    if (picked != null) return picked;
    // Another character tried on: hair that is only the worn character's
    // own default shows as the new one's, as wearing it does (26번 3차 G).
    final character = picks[CosmeticSlot.character];
    if (s == CosmeticSlot.hair && character != null &&
        a.equipped(s) == defaultHairOf(a.equipped(CosmeticSlot.character))) {
      return defaultHairOf(character);
    }
    return a.equipped(s);
  }

  CosmeticDefinition _def(CosmeticSlot s, String id) => cosmeticDefinitions.firstWhere((d) => d.slot == s && d.id == id);

  List<CosmeticDefinition> get _picked => [for (final e in picks.entries) _def(e.key, e.value)];

  void _pick(CosmeticDefinition d) => setState(() {
        message = null;
        if (a.equipped(d.slot) == d.id) {
          picks.remove(d.slot);
        } else {
          picks[d.slot] = d.id;
        }
        if (shop) focus = d.id;
      });

  /// '모두 취소' (H13·H15, replacing the unclear '↺'): back to what is worn.
  void _cancelAll() => setState(() {
        picks.clear();
        focus = null;
        message = null;
      });

  /// Wears [items] one after another; what fails stays tried on. Returns
  /// the names that failed.
  Future<List<String>> _wear(Iterable<CosmeticDefinition> items) async {
    final failed = <String>[];
    for (final d in items.toList()) {
      if (await a.apply(d)) {
        picks.remove(d.slot);
      } else {
        failed.add(d.name);
      }
      if (!mounted) break;
    }
    return failed;
  }

  void _finish(List<String> failed, String why) {
    if (!mounted) return;
    setState(() {
      working = false;
      picks.removeWhere((s, id) => a.equipped(s) == id);
      message = failed.isNotEmpty ? '${failed.join(', ')}$why' : null;
    });
    if (picks.isEmpty && failed.isEmpty) widget.onClose?.call();
  }

  /// '모두 적용': wears every owned pick; the window closes when nothing is
  /// left tried on. Picks not bought yet stay and say so.
  Future<void> _applyAll() async {
    setState(() => working = true);
    final failed = await _wear(_picked.where(a.owned));
    final unbought = _picked.where((d) => !a.owned(d)).map((d) => d.name).toList();
    _finish([...failed, ...unbought],
        unbought.isEmpty ? ' — 지금 입을 수 없어요' : ' — 사야 입을 수 있어요');
  }

  /// '모두 사기' (H15): one confirmation for every pick not bought yet,
  /// then they are bought and everything tried on is worn.
  Future<void> _buyAll() async {
    final buy = _picked.where((d) => !a.owned(d)).toList();
    if (buy.isEmpty) return;
    final sum = a.total?.call(buy);
    final locked = buy.any((d) => !a.unlocked(d));
    final ready = !locked && buy.every(a.canApply) && sum != null && !sum.missingBuns && !sum.missingGold;
    final note = locked
        ? '잠긴 꾸미기는 아직 살 수 없어요.'
        : sum != null && sum.missingGold
            ? '황금붕어빵력이 모자라요.'
            : sum != null && sum.missingBuns
                ? '붕어빵력이 모자라요.'
                : ready
                    ? '사면 계속 갖고, 입어 본 것을 모두 입어요.'
                    : '지금은 살 수 없어요. 로그인과 연결을 확인해 주세요.';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              key: const Key('wardrobe-buy-all-dialog'),
              title: Text(buy.length == 1 ? '${buy.single.name} 사기' : '${buy.length}개 모두 사기'),
              content: SizedBox(
                width: 320,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final d in buy)
                          WardrobeBuyRow(
                              item: d,
                              equipped: a.equipped,
                              price: a.cost?.call(d),
                              lock: a.unlocked(d) ? null : a.requirement?.call(d)),
                      ]),
                    ),
                  ),
                  if (sum != null && buy.length > 1) ...[
                    const Divider(height: 16, color: Cozy.tan),
                    Row(children: [
                      const Text('합계', style: TextStyle(fontWeight: FontWeight.w900, color: Cozy.ink)),
                      const Spacer(),
                      WardrobePriceLine(sum, key: const Key('wardrobe-buy-all-total'), size: 20, fontSize: 16),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Text(note,
                      key: const Key('wardrobe-buy-all-note'),
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: ready ? Cozy.inkSoft : Cozy.brick)),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                FilledButton(
                    key: const Key('wardrobe-buy-all-confirm'),
                    onPressed: ready ? () => Navigator.pop(ctx, true) : null,
                    child: const Text('사고 입기')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => working = true);
    final failed = await _wear(buy);
    if (!mounted) return;
    if (failed.isNotEmpty) return _finish(failed, ' — 사지 못했어요');
    _finish(await _wear(_picked.where(a.owned)), ' — 지금 입을 수 없어요');
  }

  Future<void> _buy(CosmeticDefinition d) async {
    final price = a.cost?.call(d);
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              key: const Key('wardrobe-buy-dialog'),
              title: Text('${d.name} 사기'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (price != null) WardrobePriceLine(price, size: 22, fontSize: 18),
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
      // The 배경 tab's whole-stall card is tall (4차 피드백 g10 ID5): its box
      // takes more of the height there.
      final stall = tab == WardrobeTab.stall;
      final previewHeight = (box.maxHeight.isFinite ? box.maxHeight * (stall ? WorkshopWardrobe.stallPreviewShare : .34) : 200.0)
          .clamp(140.0, stall ? WorkshopWardrobe.stallPreviewMax : 210.0);
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WardrobeTabRow(
            fill: true,
            children: [
              for (final t in tabs)
                WardrobePill(
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
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(height: previewHeight, child: _previewBox()),
          const SizedBox(height: 6),
          SizedBox(height: WorkshopWardrobe.actionHeight, child: _actions()),
          const SizedBox(height: 6),
          WardrobeTabRow(
            small: true,
            fill: true,
            children: [
              for (final s in slots)
                WardrobePill(
                    key: Key('cosmetic-slot-${s.name}'),
                    label: cosmeticSlotLabel(s),
                    small: true,
                    selected: s == slot,
                    changed: picks.containsKey(s),
                    onTap: () => setState(() => slot = s)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _grid()),
        ]),
      );
    });
  }

  /// The slim row under the preview (H14·H15): small buttons, no counts.
  Widget _actions() {
    final picked = _picked;
    final unbought = picked.where((d) => !a.owned(d)).toList();
    final focused = shop && focus != null ? picked.where((d) => d.id == focus).firstOrNull : null;
    final buttons = <Widget>[
      if (picked.isNotEmpty)
        WardrobeActionButton(
            key: const Key('wardrobe-cancel-all'),
            label: '모두 취소',
            kind: WardrobeActionKind.quiet,
            onPressed: working ? null : _cancelAll),
      if (shop && focused != null)
        WardrobeActionButton(
            key: Key('buy-cosmetic-${focused.id}'),
            label: a.unlocked(focused) ? '사고 바로 입기' : a.requirement?.call(focused) ?? '잠김',
            kind: WardrobeActionKind.buy,
            onPressed: working || !a.canApply(focused) ? null : () => _buy(focused)),
      if (!shop && unbought.isNotEmpty)
        WardrobeActionButton(
            key: const Key('wardrobe-buy-all'),
            label: '모두 사기',
            kind: WardrobeActionKind.buy,
            onPressed: working ? null : _buyAll),
      if (!shop && picked.length > unbought.length)
        WardrobeActionButton(
            key: const Key('wardrobe-apply-all'),
            label: '모두 적용',
            kind: WardrobeActionKind.apply,
            onPressed: working ? null : _applyAll),
    ];
    return Row(children: [
      Expanded(
        child: buttons.isEmpty
            ? Text(shop ? '눌러서 입어 보고, 마음에 들면 사요' : '눌러서 입어 보세요',
                key: const Key('wardrobe-hint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Cozy.inkSoft))
            : const SizedBox.shrink(),
      ),
      for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 6), b],
    ]);
  }

  Widget _grid() {
    final items = _items(slot);
    // Every listed item for sale is in the grid now (H15); the shop link
    // stays only for a slot with nothing listed here to buy.
    final more = !shop &&
        widget.onMore != null &&
        items.every(a.owned) &&
        cosmeticDefinitions.any((d) => d.slot == slot && !a.owned(d) && _forSale(d) && a.listed(d));
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
    final owned = a.owned(d);
    final price = owned ? null : a.cost?.call(d);
    final caption = a.requirement?.call(d) ?? '';
    final WardrobeTileState state = worn
        ? WardrobeTileState.worn
        : owned && !shop
            ? WardrobeTileState.owned
            : !a.unlocked(d)
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
    final changed = picks.isNotEmpty;
    return Semantics(
      label: '${wardrobeTabLabel(tab)} 꾸미기 미리보기',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WorkshopWardrobe.previewRadius),
          border: Border.all(color: changed ? Cozy.honeyDeep : Cozy.tan, width: changed ? 2.5 : 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WorkshopWardrobe.previewRadius - 1.5),
          child: Stack(fit: StackFit.expand, children: [
            _preview(),
            if (changed)
              const Positioned(
                left: 8,
                top: 8,
                child: WardrobeRibbon(key: Key('cosmetic-preview-status'), label: '입어 보는 중'),
              ),
            if (message != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  key: const Key('wardrobe-message'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Cozy.ink.withValues(alpha: .78), borderRadius: BorderRadius.circular(8)),
                  child: Text(message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cozy.cream, height: 1.25)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  /// Each tab previews its own subject: the pastry up close, the vendor in
  /// the shop's back room (25번 11번, no counter), or the whole stall as the
  /// home shows it, without the vendor and guests ([StallPreviewPainter],
  /// 4차 피드백 g10 ID5).
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
                  night: isNightTime(_shown(CosmeticSlot.time), sceneClock()),
                  stove: _shown(CosmeticSlot.stove),
                  decoration: _shown(CosmeticSlot.decoration),
                  lamp: _shown(CosmeticSlot.lamp),
                  lowStall: WorkshopHomeLayout.active))),
    };
  }
}

/// The 배경 (예전 '가게') tab's preview (4차 피드백 g10, ID5, 2026-11-21:
/// "가게 전체 모양을 확인할 수 있게"; reverses 시안 확인 2차's cropped
/// counter scene): the whole stall as the home screen draws it — the
/// background picture, its counter, the decoration, the awning with both
/// post lamps and the griddle — shrunk into a [homeSize] card in the
/// middle of the box. No vendor and no guests. Beside the card the same
/// background fills the box, blurred under a dark veil ([blur], [veil]), so the card stands
/// out without empty bars.
class StallPreviewPainter extends CustomPainter {
  final String background, stove, decoration, lamp;
  final bool? night;
  /// The lowered stall pictures of the home (WorkshopHomeLayout.active).
  final bool lowStall;
  const StallPreviewPainter(
      {required this.background,
      required this.night,
      required this.stove,
      required this.decoration,
      required this.lamp,
      this.lowStall = true});

  /// The home screen the card copies (a 390×844 phone).
  static const homeSize = Size(390, 844);
  /// The card's margin inside the box and its corner radius.
  static const margin = 6.0, radius = 6.0;
  /// The griddle on the home: the screen width less [griddleSide] at each
  /// side, its bottom [griddleBottom] above the screen's bottom (the bottom
  /// bar's height less 10, as NightHome lays it out).
  static const griddleSide = 8.0, griddleBottom = 56.0;
  /// How blurred and how dark the background beside the card is.
  static const blur = 6.0, veil = .5;

  /// Where the card sits in a [size] box.
  static Rect cardIn(Size size) {
    final h = size.height - margin * 2;
    final w = h * homeSize.width / homeSize.height;
    return Rect.fromLTWH((size.width - w) / 2, margin, w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Cozy.woodDark);
    final scene = NightStallPainter(
        background: background, night: night, stove: null, decoration: decoration, lowStall: lowStall);
    // The backdrop: the same scene covering the box, blurred and veiled.
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.saveLayer(Offset.zero & size, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur));
    final cover = Size(size.width, size.width * homeSize.height / homeSize.width);
    canvas.translate(0, (size.height - cover.height) * .5);
    scene.paint(canvas, cover);
    canvas.restore();
    canvas.restore();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black.withValues(alpha: veil));
    // The card: the home's stall layers at the phone's size, scaled down.
    final card = cardIn(size);
    final k = card.width / homeSize.width;
    final clip = RRect.fromRectAndRadius(card, const Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.translate(card.left, card.top);
    canvas.scale(k);
    scene.paint(canvas, homeSize);
    StallFramePainter(lamp: lamp).paint(canvas, homeSize);
    final griddle = PixelSprites.cosmetic(CosmeticSlot.stove, stove);
    if (griddle != null) {
      final w = homeSize.width - griddleSide * 2, h = w * griddle.height / griddle.width;
      canvas.save();
      canvas.translate(griddleSide, homeSize.height - griddleBottom - h);
      GriddlePainter(stove).paint(canvas, Size(w, h));
      canvas.restore();
    }
    canvas.restore();
    canvas.drawRRect(
        clip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Cozy.cream.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(StallPreviewPainter old) =>
      old.background != background ||
      old.night != night ||
      old.stove != stove ||
      old.decoration != decoration ||
      old.lamp != lamp ||
      old.lowStall != lowStall;
}

/// A wardrobe price with what the player lacks marked.
class WardrobePrice {
  final BigInt buns, gold;
  final bool missingBuns, missingGold;
  const WardrobePrice(this.buns, this.gold, {this.missingBuns = false, this.missingGold = false});
}

/// The five looks of an item tile (F29).
enum WardrobeTileState { worn, owned, buyable, short, locked }

/// A row of [WardrobePill] bookmark tabs standing on a thin line (시안 확인
/// 2차 (나)). With [fill] the tabs share the width (3차 피드백 H16: all of
/// them show at 360 wide, no tab hidden past the edge); otherwise the row
/// scrolls sideways when they do not fit.
class WardrobeTabRow extends StatelessWidget {
  final List<Widget> children;
  final bool small, fill;
  const WardrobeTabRow({super.key, required this.children, this.small = false, this.fill = false});

  /// The gap between two tabs.
  static const gap = 3.0;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: small ? Cozy.tan : Cozy.woodLight, width: small ? 1 : 1.5))),
        child: fill
            ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final (i, c) in children.indexed) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(child: c),
                ],
              ])
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final c in children) Padding(padding: const EdgeInsets.only(right: gap), child: c),
                ]),
              ),
      );
}

/// A bookmark tab (시안 확인 2차 (나) 책갈피 탭, replacing the G8 pill):
/// rounded top corners and a flat bottom on the row's line; the chosen tab
/// is peach and [WardrobePill.raise] taller, the others cream. [changed]
/// puts a small honey dot on a slot that is being tried on. The icon shows
/// only when the tab is wide enough for it ([iconWidth]). (The name is
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
  /// A tab narrower than this drops its icon and keeps the label.
  static const iconWidth = 74.0;

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
            borderRadius: top,
            side: BorderSide(color: selected ? Cozy.woodLight : Cozy.tan, width: selected ? 1.5 : 1)),
        child: InkWell(
          borderRadius: top,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (small ? 30 : 34) + (selected ? raise : 0)),
            child: LayoutBuilder(builder: (context, box) {
              final withIcon = icon != null && box.maxWidth >= iconWidth;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (withIcon) ...[PixelIcon(icon!, size: 18), const SizedBox(width: 3)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: small ? 13.5 : 14.5,
                              fontWeight: FontWeight.w900,
                              color: selected ? Cozy.ink : Cozy.taupe)),
                    ),
                  ),
                  if (changed) ...[
                    const SizedBox(width: 3),
                    Container(
                        key: const Key('slot-changed-dot'),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Cozy.amber, shape: BoxShape.circle)),
                  ],
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// The small chip in the preview's corner (G15; 3차 피드백 H13: a plain
/// rounded chip that keeps its shape, dark and see-through over the room).
class WardrobeRibbon extends StatelessWidget {
  final String label;
  const WardrobeRibbon({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Cozy.ink.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome, size: 12, color: Cozy.honeyLight),
          const SizedBox(width: 4),
          Text(label,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, height: 1.1, fontWeight: FontWeight.w800, color: Cozy.cream)),
        ]),
      );
}

/// The three looks of the wardrobe's small buttons (H14·H15).
enum WardrobeActionKind {
  /// '모두 취소': outline only.
  quiet,
  /// '모두 사기', '사고 바로 입기': honey.
  buy,
  /// '모두 적용': dark wood.
  apply,
}

/// A small flat button for the row under the preview (H14: small, no
/// count; no thick border or raised face).
class WardrobeActionButton extends StatelessWidget {
  final String label;
  final WardrobeActionKind kind;
  final VoidCallback? onPressed;
  const WardrobeActionButton({super.key, required this.label, required this.kind, required this.onPressed});

  static const height = 32.0, radius = 8.0;

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null;
    final (fill, text, edge) = switch (kind) {
      WardrobeActionKind.quiet => (Colors.transparent, Cozy.inkSoft, Cozy.tan),
      WardrobeActionKind.buy => (Cozy.honeyLight, Cozy.ink, Cozy.honeyDeep),
      WardrobeActionKind.apply => (Cozy.wood, Cozy.cream, Cozy.wood),
    };
    return Semantics(
      button: true,
      enabled: !off,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: off ? .45 : 1,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius), side: BorderSide(color: edge, width: 1.2)),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A price as icons and numbers on one line.
class WardrobePriceLine extends StatelessWidget {
  final WardrobePrice price;
  final double size, fontSize;
  const WardrobePriceLine(this.price, {super.key, this.size = 16, this.fontSize = 13});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        CurrencyAmount(Currency.buns, price.buns, missing: price.missingBuns, size: size, fontSize: fontSize),
        if (price.gold > BigInt.zero) ...[
          SizedBox(width: size * .4),
          CurrencyAmount(Currency.gold, price.gold, missing: price.missingGold, size: size, fontSize: fontSize),
        ],
      ]);
}

/// One line of the '모두 사기' confirmation: icon, name, price (or lock).
class WardrobeBuyRow extends StatelessWidget {
  final CosmeticDefinition item;
  final String Function(CosmeticSlot) equipped;
  final WardrobePrice? price;
  final String? lock;
  const WardrobeBuyRow({super.key, required this.item, required this.equipped, this.price, this.lock});
  @override
  Widget build(BuildContext context) => Padding(
        key: Key('wardrobe-buy-row-${item.id}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Cozy.creamDeep, borderRadius: BorderRadius.circular(WardrobeTile.radius)),
            child: CosmeticThumb(item, equipped),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Cozy.ink))),
          if (lock != null)
            Text(lock!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Cozy.brick))
          else if (price != null)
            WardrobePriceLine(price!),
        ]),
      );
}

// One item: a square-cornered card (시안 확인 2차 (나)) with its icon on a
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
