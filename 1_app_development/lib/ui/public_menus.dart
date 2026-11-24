import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../game_controller.dart';
import 'avatar_painter.dart';
import 'center_toast.dart';
import 'count_badge.dart';
import 'cozy_style.dart';
import 'fish_painter.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';
import 'weather_layer.dart';
import 'workshop_wardrobe.dart';
export 'workshop_wardrobe.dart' show WardrobeMode, WardrobePrice, WorkshopWardrobe;

/// The concept art's wardrobe (3.5_completed_game_mockups/꾸미기): tabs 헤어 / 의상 / 소품 /
/// 붕어빵 / 가게 (approved D3), a preview on top, a 3-column grid of items and
/// an '적용' button for the picked one. Picking only previews; nothing is
/// bought or equipped until '적용'. With [CosmeticMenuAccess] (the Workshop)
/// the panel is [WorkshopWardrobe] (26번 4-5단계): 꾸미기 wears what is
/// owned, several slots at once with '모두 적용(N)'; the shop's 꾸미기 tab
/// sells avatar items and wears them as soon as they are bought.
class CosmeticMenuAccess {
  final String Function(CosmeticSlot) equipped;
  final bool Function(CosmeticDefinition) owned, unlocked, canApply;
  final String Function(CosmeticDefinition) price, action;
  final Future<bool> Function(CosmeticDefinition) apply;
  /// Why a locked item is locked ('Lv.5 해금'; 26번 4-5단계: no '누적').
  final String Function(CosmeticDefinition)? requirement;

  /// Items this build shows at all; items nobody can buy yet stay out of
  /// the wardrobe and the shop instead of reading '판매 준비 중'.
  final bool Function(CosmeticDefinition) listed;

  /// Items the shop sells (the avatar catalog); null: everything not owned.
  final bool Function(CosmeticDefinition)? forSale;

  /// An item's price as icons and numbers, with what the player lacks.
  final WardrobePrice? Function(CosmeticDefinition)? cost;

  /// Why a tab is still closed ('Lv.5 달성하면 열려요', 붕어빵 Lv.5; S45-Q6),
  /// or null when open; null function: all open. A closed tab is still
  /// listed, faded under the lock, and says why when tapped (4차 g5).
  final String? Function(WardrobeTab)? tabLock;

  /// Why a slot inside a tab is still closed (26번 3차 H42: the 가게 tab
  /// shows 배경 and 시간 from Lv.1, the stove, decoration and lamp from
  /// Lv.8), or null; listed locked like [tabLock].
  final String? Function(CosmeticSlot)? slotLock;

  /// What several items cost together, with what the player lacks for all
  /// of them ('모두 사기', 3차 피드백 H15); null: not sold together.
  final WardrobePrice? Function(List<CosmeticDefinition>)? total;

  /// Why nothing can be bought right now (a build without the online
  /// settings, or before the login; 4차 피드백 IC10), or null.
  final String? Function()? purchaseBlock;
  const CosmeticMenuAccess({required this.equipped,required this.owned,required this.unlocked,
    required this.canApply,required this.price,required this.action,required this.apply,this.requirement,
    this.listed=_always,this.forSale,this.cost,this.tabLock,this.slotLock,this.total,this.purchaseBlock});
  static bool _always(CosmeticDefinition _)=>true;
}

class AccessCosmeticAction extends StatelessWidget {
  final CosmeticMenuAccess access;final CosmeticDefinition item;final VoidCallback? onDone;
  const AccessCosmeticAction({super.key,required this.access,required this.item,this.onDone});
  @override
  Widget build(BuildContext context)=>CozyPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(item.name,style:const TextStyle(fontWeight:FontWeight.bold)),Text(access.price(item)),
    if(access.requirement!=null)Text(access.requirement!(item)),
    FilledButton(key:Key('buy-cosmetic-${item.id}'),onPressed:!access.canApply(item) ? null : () async {
      final ok=await access.apply(item);if(context.mounted && ok)onDone?.call();
    },child:Text(access.action(item))),
  ]));
}

class WardrobePanel extends StatelessWidget {
  final GameController controller;
  final WardrobeTab initialTab;
  /// What can be worn or bought (32번: the old coin wardrobe is gone).
  final CosmeticMenuAccess access;
  /// Wear what is owned, or the shop's avatar items.
  final WardrobeMode mode;
  final CosmeticSlot? initialSlot;
  /// In [WardrobeMode.wear]: '상점에서 더 보기' for a slot.
  final void Function(CosmeticSlot slot)? onMore;
  /// Closes the window once everything tried on is worn.
  final VoidCallback? onClose;
  const WardrobePanel(
      {super.key,
      required this.controller,
      this.initialTab = WardrobeTab.hair,required this.access,this.mode=WardrobeMode.wear,
      this.initialSlot,this.onMore,this.onClose});

  @override
  Widget build(BuildContext context) => WorkshopWardrobe(
      access: access,
      mode: mode,
      initialTab: initialTab,
      initialSlot: initialSlot,
      onMore: onMore,
      onClose: onClose,
      animate: WeatherLayer.animate && !controller.state.settings.reduceMotion);
}

/// [item]'s tile picture: the pastry wearing it, the avatar item's own
/// icon (26번 4-5단계, G5: `cosmetic_icons/<id>.png`, not a tiny dressed
/// vendor; the vendor wearing it only while an icon is missing), or the
/// stall part's own art (a background as its middle square, lamps and
/// day/night as their tile pictures).
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
      CosmeticCategory.avatar => switch (PixelSprites.cosmeticIcon(item.id,
            character: shown(CosmeticSlot.character))) {
          final icon? => CustomPaint(
              key: Key('icon-${item.id}'),
              size: Size.infinite,
              painter: _FitImagePainter(icon)),
          null => CustomPaint(
              size: Size.infinite, painter: AvatarPainter(AvatarLook.of(shown))),
        },
      _ when PixelSprites.stallTile(item) != null => CustomPaint(
          size: Size.infinite,
          painter: _FitImagePainter(PixelSprites.stallTile(item)!)),
      _ when item.slot == CosmeticSlot.time => Icon(
          switch (item.id) {
            'night_time' => Icons.nightlight_round,
            'clock' => Icons.schedule,
            _ => Icons.wb_sunny_rounded,
          },
          color: Cozy.woodLight,
          size: 36),
      CosmeticCategory.stall => switch (
            PixelSprites.cosmetic(item.slot, item.id)) {
          final image? => CustomPaint(
              size: Size.infinite,
              painter: _FitImagePainter(image,
                  cover: item.slot == CosmeticSlot.background)),
          null => const Icon(Icons.block, color: Cozy.inkSoft),
        },
    };
  }
}

/// One sprite fitted into the canvas, centred, pixels kept crisp.
class _FitImagePainter extends CustomPainter {
  final ui.Image image;
  /// Fill the box with the picture's middle (a tall background as a
  /// square thumbnail) instead of fitting all of it.
  final bool cover;
  const _FitImagePainter(this.image, {this.cover = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (cover) {
      final k = math.max(size.width / image.width, size.height / image.height);
      final w = size.width / k, h = size.height / k;
      final src = Rect.fromLTWH((image.width - w) / 2, (image.height - h) / 2, w, h);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)));
      // 4차 피드백 g15: smoothed when shrunk, like every sprite.
      PixelSprites.drawPart(canvas, image, src, Offset.zero & size);
      canvas.restore();
      return;
    }
    final scale =
        math.min(size.width / image.width, size.height / image.height);
    final w = image.width * scale, h = image.height * scale;
    PixelSprites.draw(canvas, image,
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h));
  }

  @override
  bool shouldRepaint(covariant _FitImagePainter old) =>
      image != old.image || cover != old.cover;
}

/// The concept art's menu (서브UI 메뉴): 도감, 업적, 통계, 배경 테마, then
/// the screens that used to sit on the home screen.
class MenuPanel extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;
  /// Rewards ready to claim per row (the new game's daily, event, missions).
  final Map<String,int> rewardCounts;

  /// Destinations left out of this build's menu (the soft launch hides the
  /// online ranking, friends and sharing: DEC-029).
  final Set<String> hidden;

  /// Destinations shown but not open yet, with the reason ('Lv.3 달성하면
  /// 열려요'): the icon under the common lock (one stripe, the padlock art
  /// in its corner), the reason in red under the title, no arrow, and a tap
  /// says '도감: Lv.3 달성하면 열려요' in a center toast instead of opening
  /// (3차 피드백 H32 → 4차 g5).
  final Map<String,String> locks;

  /// The padlock's side on a locked row's icon.
  static const lockSize = 18.0;
  const MenuPanel({super.key, required this.controller, required this.onOpen,
    this.rewardCounts=const {},this.hidden=const {},this.locks=const {}});

  @override
  Widget build(BuildContext context) {
    // 32번 1단계: only the new game's counts (no old-clicker goals).
    final claimable = rewardCounts;
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
        // 3차 피드백 H44: '통계' → '생산 기록'.
        '생산 기록',
        null,
        const PixelIcon('records', size: 32),
        const Key('menu-records')
      ),
      (
        'ranking',
        '온라인 랭킹',
null,
        const PixelIcon('leaderboard', size: 32),
        const Key('menu-ranking')
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
null,
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
null,
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
      // 26번 8단계 공유 카드(보상 없음): the stall as a picture to share.
      (
        'photo',
        '가게 사진 찍기',
        null,
        const Icon(Icons.photo_camera_outlined, color: Cozy.orangeDeep, size: 32),
        const Key('menu-photo')
      ),
    ];
    // A short list: built eagerly (not lazily) so every entry exists even
    // when large text pushes it below the fold.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(children: [
        for (final (dest, title, subtitle, icon, key) in rows)
          if (!hidden.contains(dest))
          Builder(builder: (context) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // H41: a white card with a hairline, not a wooden frame.
            child: Material(
              color: Cozy.cream,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Cozy.line)),
              shadowColor: Cozy.shadow,
              elevation: 1,
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (locks[dest] case final lock?) {
                    showCenterToast(context, '$title: $lock');
                  } else {
                    onOpen(dest);
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    CountBadge(
                        count: claimable[dest] ?? 0,
                        badgeKey: Key('badge-$dest'),
                        child: locks.containsKey(dest)
                            ? SizedBox.square(
                                dimension: 36,
                                child: LockedOverlay(
                                    key: Key('menu-locked-$dest'),
                                    caption: '$title: ${locks[dest]}',
                                    showCaption: false,
                                    maxLock: lockSize,
                                    lockAlignment: const Alignment(1, -1),
                                    child: Center(child: icon)))
                            : icon),
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
                          if (locks[dest] case final lock?)
                            Text(lock,
                                key: Key('menu-lock-$dest'),
                                style: const TextStyle(
                                    color: Cozy.brick,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800))
                          else if (subtitle != null)
                            Text(subtitle,
                                key: dest == 'event'
                                    ? const Key('event-countdown')
                                    : null,
                                style: const TextStyle(
                                    color: Cozy.inkSoft, fontSize: 12)),
                        ])),
                    if (!locks.containsKey(dest))
                      const Icon(Icons.chevron_right_rounded, color: Cozy.caption),
                  ]),
                ),
              ),
            ),
          )),
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
