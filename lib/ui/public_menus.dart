import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../home_presentation.dart';
import '../menu_rules.dart';
import '../mission_alerts.dart';
import '../weekly_config.dart';
import 'avatar_painter.dart';
import 'count_badge.dart';
import 'cozy_style.dart';
import 'fish_painter.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'support_panels.dart';

/// The concept art's wardrobe (07_UI/꾸미기): tabs 헤어 / 의상 / 소품 /
/// 붕어빵 / 가게 (approved D3), a preview on top, a 3-column grid of items and
/// an '적용' button for the picked one. Picking only previews; nothing is
/// bought or equipped until '적용'.
class WardrobePanel extends StatefulWidget {
  final GameController controller;
  final WardrobeTab initialTab;
  const WardrobePanel(
      {super.key,
      required this.controller,
      this.initialTab = WardrobeTab.hair});
  @override
  State<WardrobePanel> createState() => _WardrobePanelState();
}

class _WardrobePanelState extends State<WardrobePanel> {
  late WardrobeTab tab = widget.initialTab;
  late CosmeticSlot slot = _slots(tab).first;
  String? preview;

  static List<CosmeticSlot> _slots(WardrobeTab t) =>
      CosmeticSlot.values.where((s) => s.shown && s.tab == t).toList();

  GameController get c => widget.controller;

  /// What [s] shows: the picked item in its own slot, else what is worn.
  String _shown(CosmeticSlot s) =>
      s == slot && preview != null ? preview! : c.state.equippedCosmetic(s);

  @override
  Widget build(BuildContext context) {
    final picked = cosmeticDefinitions
        .firstWhere((d) => d.slot == slot && d.id == _shown(slot));
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('모습만 바뀌어요 (생산 효과 없음)'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final t in WardrobeTab.values)
              ChoiceChip(
                  key: Key('cosmetic-category-${t.name}'),
                  avatar: PixelIcon(
                      switch (t) {
                        WardrobeTab.hair => 'tab_hair',
                        WardrobeTab.outfit => 'tab_outfit',
                        WardrobeTab.props => 'tab_acc',
                        WardrobeTab.bungeoppang => 'tab_fish',
                        WardrobeTab.stall => 'tab_stall',
                      },
                      size: 18),
                  label: Text(wardrobeTabLabel(t)),
                  selected: t == tab,
                  selectedColor: Cozy.orange,
                  onSelected: (_) => setState(() {
                        tab = t;
                        slot = _slots(t).first;
                        preview = null;
                      })),
          ]),
          const SizedBox(height: 8),
          Semantics(
              label: '${wardrobeTabLabel(tab)} 꾸미기 미리보기',
              child: SizedBox(
                  height: 180,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _preview()))),
          Text(preview == null ? '현재 장착 모습' : '미리보기 · 미장착',
              key: const Key('cosmetic-preview-status')),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final s in _slots(tab))
              ChoiceChip(
                  key: Key('cosmetic-slot-${s.name}'),
                  label: Text(cosmeticSlotLabel(s)),
                  selected: s == slot,
                  onSelected: (_) => setState(() {
                        slot = s;
                        preview = null;
                      })),
          ]),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, box) {
            const gap = 8.0;
            final w = (box.maxWidth - gap * 2) / 3;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final d in cosmeticDefinitions.where((d) => d.slot == slot))
                SizedBox(width: w, child: _tile(d, d.id == picked.id)),
            ]);
          }),
          const SizedBox(height: 12),
          _apply(context, picked),
          if (c.error != null) Text(c.error!),
        ]));
  }

  Widget _tile(CosmeticDefinition d, bool selected) {
    final worn = c.state.equippedCosmetic(slot) == d.id;
    final unlocked = cosmeticUnlocked(c.state, d);
    final status = worn
        ? '장착 중'
        : !unlocked
            ? 'Lv.${d.unlockLevel} 해금'
            : c.state.ownsCosmetic(d)
                ? '보유'
                : d.free
                    ? '무료'
                    : '${d.cost} 코인';
    return Semantics(
      button: true,
      selected: selected,
      label: '${d.name} $status',
      excludeSemantics: true,
      child: Material(
        color: selected ? Cozy.orange : Cozy.woodLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('preview-${d.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => preview = d.id),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            decoration: BoxDecoration(
                color: selected ? Cozy.creamDeep : Cozy.cream,
                borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              SizedBox(
                  height: 52,
                  child: Opacity(
                      opacity: unlocked ? 1 : .45,
                      child: CosmeticThumb(d, c.state.equippedCosmetic))),
              const SizedBox(height: 4),
              Text(d.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Cozy.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (worn || !unlocked)
                  PixelIcon(worn ? 'check' : 'lock', size: 14),
                Flexible(
                    child: Text(status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: worn ? Cozy.brick : Cozy.inkSoft,
                            fontSize: 11))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _apply(BuildContext context, CosmeticDefinition d) {
    final worn = c.state.equippedCosmetic(slot) == d.id;
    final unlocked = cosmeticUnlocked(c.state, d);
    final owned = c.state.ownsCosmetic(d);
    final current = cosmeticDefinitions
        .firstWhere((item) => item.id == c.state.equippedCosmetic(slot));
    return CozyPanel(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(d.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        Text(d.free ? '무료' : '${compactNumber(d.cost)} 코인'),
        Text(
            '해금 Lv.${d.unlockLevel} · 누적 ${compactNumber(d.unlockProductionAmount)}개'),
        Text('현재 ${current.name} → ${d.name}'),
        const SizedBox(height: 6),
        FilledButton(
            key: Key('buy-cosmetic-${d.id}'),
            style: FilledButton.styleFrom(
                backgroundColor: Cozy.orange, foregroundColor: Cozy.ink),
            onPressed: !c.busy &&
                    unlocked &&
                    !worn &&
                    (owned || c.state.support.coins >= d.cost)
                ? () async {
                    if (owned ||
                        await confirmAction(
                            context,
                            '${d.name} 구매',
                            '가격 ${d.cost} 코인\n코인 ${exactNumber(c.state.support.coins)} → ${exactNumber(c.state.support.coins - d.cost)}\n영구 보유 · 바로 장착',
                            '구매')) {
                      final ok = await c.buyOrEquipCosmetic(d.id);
                      if (mounted && ok) setState(() => preview = null);
                    }
                  }
                : null,
            child: Text(worn
                ? '장착 중'
                : !unlocked
                    ? '잠김'
                    : owned
                        ? '적용'
                        : '구매하고 적용')),
      ]),
    );
  }

  /// Each tab previews its own subject: the pastry up close, the vendor
  /// alone, or the whole stall with vendor and pastry.
  Widget _preview() {
    final fish = CustomPaint(
        painter: FishPainter(
            skin: _shown(CosmeticSlot.fish),
            pattern: _shown(CosmeticSlot.pattern),
            topping: _shown(CosmeticSlot.topping)));
    return switch (tab) {
      WardrobeTab.bungeoppang => ColoredBox(
          key: const Key('preview-bungeoppang'),
          color: Cozy.woodDark,
          child: Padding(padding: const EdgeInsets.all(12), child: fish)),
      WardrobeTab.hair || WardrobeTab.outfit || WardrobeTab.props => ColoredBox(
          key: const Key('preview-avatar'),
          color: Cozy.woodDark,
          child: Stack(fit: StackFit.expand, children: [
            // The shop interior of the concept art's 꾸미기 screen.
            FittedBox(
                fit: BoxFit.cover,
                child: PixelArt(PixelSprites.screenArt('wardrobe_bg'),
                    width: 120, height: 72)),
            Padding(
                padding: const EdgeInsets.all(8),
                child:
                    CustomPaint(painter: AvatarPainter(AvatarLook.of(_shown)))),
          ])),
      WardrobeTab.stall => CustomPaint(
          key: const Key('preview-stall'),
          painter: NightStallPainter(
              background: _shown(CosmeticSlot.background),
              night: isNightTime(_shown(CosmeticSlot.time), DateTime.now()),
              stove: _shown(CosmeticSlot.stove),
              decoration: _shown(CosmeticSlot.decoration),
              avatar: AvatarLook.of(_shown)),
          // Post lamps live in the stall frame.
          foregroundPainter: StallFramePainter(lamp: _shown(CosmeticSlot.lamp)),
          child: Center(child: SizedBox(width: 120, height: 90, child: fish))),
    };
  }
}

/// [item] on its own subject: the pastry or the vendor wearing it with
/// everything else [equipped], or the stall part's own art.
class CosmeticThumb extends StatelessWidget {
  final CosmeticDefinition item;
  final String Function(CosmeticSlot) equipped;
  const CosmeticThumb(this.item, this.equipped, {super.key});

  @override
  Widget build(BuildContext context) {
    String shown(CosmeticSlot s) => s == item.slot ? item.id : equipped(s);
    return switch (item.slot.category) {
      CosmeticCategory.bungeoppang => CustomPaint(
          size: Size.infinite,
          painter: FishPainter(
              skin: shown(CosmeticSlot.fish),
              pattern: shown(CosmeticSlot.pattern),
              topping: shown(CosmeticSlot.topping))),
      CosmeticCategory.avatar => CustomPaint(
          size: Size.infinite, painter: AvatarPainter(AvatarLook.of(shown))),
      _ when item.slot == CosmeticSlot.time => Icon(
          switch (item.id) {
            'night_time' => Icons.nightlight_round,
            'clock' => Icons.schedule,
            'scenetime' => Icons.landscape_rounded,
            _ => Icons.wb_sunny_rounded,
          },
          color: Cozy.woodLight,
          size: 36),
      CosmeticCategory.stall => switch (
            PixelSprites.cosmetic(item.slot, item.id)) {
          final image? =>
            CustomPaint(size: Size.infinite, painter: _FitImagePainter(image)),
          null => const Icon(Icons.block, color: Cozy.inkSoft),
        },
    };
  }
}

/// One sprite fitted into the canvas, centred, pixels kept crisp.
class _FitImagePainter extends CustomPainter {
  final ui.Image image;
  const _FitImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.min(size.width / image.width, size.height / image.height);
    final w = image.width * scale, h = image.height * scale;
    PixelSprites.draw(canvas, image,
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h));
  }

  @override
  bool shouldRepaint(covariant _FitImagePainter old) => image != old.image;
}

/// The concept art's menu (서브UI 메뉴): 도감, 업적, 통계, 배경 테마, then
/// the screens that used to sit on the home screen.
class MenuPanel extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;
  const MenuPanel({super.key, required this.controller, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final weekly = controller.state.weekly;
    final theme = seasonThemeForMonth(DateTime.parse(weekly.week).month);
    // Rewards ready to claim, per row (daily, event, missions, achievements).
    final claimable = <String, int>{};
    for (final g in claimableGoals(controller.state)) {
      claimable[g.destination] = (claimable[g.destination] ?? 0) + 1;
    }
    Widget fish() => const SizedBox(
        width: 36, height: 27, child: CustomPaint(painter: FishPainter()));
    final rows = <(String, String, String?, Widget, Key)>[
      (
        'achievements:collection',
        '도감',
        null,
        fish(),
        const Key('menu-collection')
      ),
      (
        'achievements',
        '업적',
        null,
        const PixelIcon('achievements', size: 32),
        const Key('menu-achievements')
      ),
      (
        'records',
        '통계',
        null,
        const PixelIcon('records', size: 32),
        const Key('menu-records')
      ),
      (
        'skins:stall',
        '배경 테마',
        null,
        const _ThemeGlyph(),
        const Key('menu-theme')
      ),
      (
        'daily',
        '일일 미션',
        null,
        const PixelIcon('daily', size: 32),
        const Key('menu-daily')
      ),
      (
        'event',
        '주간 도전',
        '${theme.title} · ${weeklyCountdownLabel(weekly.week, controller.gameNow)}',
        const PixelIcon('weekly', size: 32),
        const Key('event-entry')
      ),
      (
        'missions',
        '레벨 미션',
        null,
        const PixelIcon('mission', size: 32),
        const Key('menu-missions')
      ),
      (
        'friends',
        '친구',
        '하루 한 번 서로 방문하면 황금 부스트',
        const _FriendsGlyph(),
        const Key('menu-friends')
      ),
      (
        'share',
        '공유',
        null,
        const PixelIcon('share', size: 32),
        const Key('menu-share')
      ),
    ];
    // A short list: built eagerly (not lazily) so every entry exists even
    // when large text pushes it below the fold.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(children: [
        for (final (dest, title, subtitle, icon, key) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Cozy.wood,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(12),
                onTap: () => onOpen(dest),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minHeight: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Cozy.cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Cozy.woodLight, width: 1.5)),
                  child: Row(children: [
                    CountBadge(
                        count: claimable[dest] ?? 0,
                        badgeKey: Key('badge-$dest'),
                        child: icon),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Cozy.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          if (subtitle != null)
                            Text(subtitle,
                                key: dest == 'event'
                                    ? const Key('event-countdown')
                                    : null,
                                style: const TextStyle(
                                    color: Cozy.inkSoft, fontSize: 12)),
                        ])),
                    const Icon(Icons.chevron_right, color: Cozy.wood),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The pixel `theme` icon, or a sun until it is drawn.
class _ThemeGlyph extends StatelessWidget {
  const _ThemeGlyph();
  @override
  Widget build(BuildContext context) {
    final icon = PixelSprites.icon('theme');
    if (icon != null) return PixelImage(icon, size: 32);
    return const Icon(Icons.wb_sunny_outlined,
        color: Cozy.orangeDeep, size: 32);
  }
}

class _FriendsGlyph extends StatelessWidget {
  const _FriendsGlyph();
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.people_alt_outlined, color: Cozy.orangeDeep, size: 32);
}
