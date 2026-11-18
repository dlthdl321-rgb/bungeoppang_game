import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../cosmetic_config.dart';
import '../share_card.dart';
import '../usage_stats.dart';
import 'avatar_painter.dart';
import 'cook_cut.dart';
import 'cozy_style.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'workshop_home_layout.dart';
import 'workshop_mold_stage.dart' show ResultLook;

/// The share card (26번 8단계, DEC-048): laid out at [size] (4:5) and
/// captured at 1080×1350 (`share.card_width`). The top 70% is the stall
/// with the vendor, the bungeoppang and the guest; the bottom 30% the badge,
/// the title, one line and the store line. No owner name, account, level,
/// currency, date or device detail (ShareCardData).
class ShareCardView extends StatelessWidget {
  final ShareCardData data;
  final ShareCardTexts texts;
  const ShareCardView({super.key, required this.data, required this.texts});

  /// The card's layout size; the capture scales it to 1080×1350.
  static const size = Size(360, 450);
  static const pictureHeight = 315.0;

  String _equipped(CosmeticSlot slot) => data.equipped[slot.name] ?? _defaults[slot] ?? 'none';
  static const _vendor = AvatarLook();
  static final _defaults = {
    CosmeticSlot.background: 'clear',
    CosmeticSlot.decoration: 'none',
    CosmeticSlot.lamp: 'amberlamp',
    CosmeticSlot.character: _vendor.character,
    CosmeticSlot.skin: _vendor.skin,
    CosmeticSlot.hair: _vendor.hair,
    CosmeticSlot.top: _vendor.top,
    CosmeticSlot.bottom: _vendor.bottom,
    CosmeticSlot.shoes: _vendor.shoes,
    CosmeticSlot.outfit: _vendor.outfit,
    CosmeticSlot.hat: _vendor.hat,
    CosmeticSlot.accessory: _vendor.accessory,
    CosmeticSlot.tool: _vendor.tool,
  };

  @override
  Widget build(BuildContext context) {
    final guest = data.guestArt == null ? null : PixelSprites.guest(data.guestArt!, 'happy');
    final shop = data.moment == ShareMoment.shop;
    // Its own Material: the card is also drawn outside any screen (preview).
    return SizedBox.fromSize(
      size: size,
      child: Material(type: MaterialType.transparency, child: DecoratedBox(
        decoration: const BoxDecoration(color: Cozy.wood),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: Cozy.cream,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: pictureHeight - 6,
                  child: Stack(clipBehavior: Clip.hardEdge, children: [
                    // The stall's view at the card's width, cut to the street
                    // and the counter top (scene y 130..290; the concept
                    // backgrounds' pixels 260..557).
                    Positioned(
                        left: 0,
                        right: 0,
                        top: -252,
                        height: NightStallPainter.sceneSize.height * 2 * (348 / 360),
                        child: CustomPaint(
                            painter: NightStallPainter(
                                background: _equipped(CosmeticSlot.background),
                                night: false,
                                stove: null,
                                decoration: _equipped(CosmeticSlot.decoration),
                                cleanCounter: true,
                                lowStall: WorkshopHomeLayout.active))),
                    // The vendor in the cooking cut's window.
                    Positioned(
                        left: shop ? 104 : 10,
                        bottom: shop ? 18 : 12,
                        width: shop ? 140 : 104,
                        height: shop ? 120 : 90,
                        child: _VendorWindow(look: AvatarLook.of(_equipped))),
                    if (guest != null)
                      Positioned(
                          right: 4,
                          bottom: 0,
                          width: 128,
                          height: 160,
                          child: RawImage(
                              key: const Key('share-card-guest'),
                              image: guest,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              filterQuality: FilterQuality.medium)),
                    if (data.variant case final variant?)
                      Positioned(
                          left: guest == null ? 104 : 86,
                          bottom: 20,
                          width: 170,
                          height: 120,
                          child: CustomPaint(
                              key: const Key('share-card-fish'),
                              painter: ShareFishPainter(variant: variant, shine: data.shine))),
                    Positioned(left: 10, top: 10, child: _Badge(data.moment.badge)),
                  ]),
                ),
                Container(height: 3, color: Cozy.tan),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.title,
                          key: const Key('share-card-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 24, color: Cozy.ink)),
                      const SizedBox(height: 2),
                      if (data.line != null)
                        Text(data.speaker == null ? data.line! : '${data.speaker}: "${data.line}"',
                            key: const Key('share-card-line'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                                fontSize: 15, height: 1.25, color: Cozy.inkSoft)),
                      const Spacer(),
                      Row(children: [
                        const SizedBox(width: 26, height: 20, child: CustomPaint(painter: ShareFishPainter(variant: 2))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(texts.storeLine,
                                key: const Key('share-card-store'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                                    fontSize: 15, color: Cozy.wood))),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      )),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('share-card-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: Cozy.honey,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Cozy.wood, width: 2),
            boxShadow: const [BoxShadow(color: Cozy.shadow, offset: Offset(0, 2))]),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 18, color: Cozy.ink)),
      );
}

/// The vendor as in the home's cooking cut, standing still.
class _VendorWindow extends StatelessWidget {
  final AvatarLook look;
  const _VendorWindow({required this.look});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Cozy.wood,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2))]),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(key: const Key('share-card-vendor'), size: Size.infinite,
                painter: CookCutPainter(look: look))),
      );
}

/// A finished bungeoppang (fish/redbean scales) in its doneness color, with
/// a perfect bake's shine (the result screen's look, ResultLook).
class ShareFishPainter extends CustomPainter {
  final int variant;
  final bool shine;
  const ShareFishPainter({required this.variant, this.shine = false});
  static final _smooth = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    final image = PixelSprites.fish('redbean', 'scales');
    if (image == null) return;
    final k = math.min(size.width / image.width, size.height / image.height);
    final w = image.width * k, h = image.height * k;
    final dst = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
    final filter = ResultLook.filter(variant);
    if (filter != null) canvas.saveLayer(dst, Paint()..colorFilter = filter);
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), dst, _smooth);
    if (filter != null) canvas.restore();
    if (!shine) return;
    final glow = Rect.fromCenter(
        center: Offset(dst.left + dst.width * .42, dst.top + dst.height * .3),
        width: dst.width * .4, height: dst.height * .16);
    canvas.drawOval(glow, Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)])
          .createShader(glow));
  }

  @override
  bool shouldRepaint(covariant ShareFishPainter old) => old.variant != variant || old.shine != shine;
}

/// The card as a 1080×1350 PNG from the boundary that holds a [ShareCardView].
Future<Uint8List> captureShareCard(RenderRepaintBoundary boundary, ShareCardTexts texts) async {
  final image = await boundary.toImage(pixelRatio: texts.width / boundary.size.width);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// '자랑하기': the card big enough to look at, '공유하기' and '닫기'. The
/// share window is the phone's own (no photo-library save, no permission).
/// Nothing in the game changes either way; a failed share says so and the
/// card stays open. The `share` event goes once a day after it opened.
Future<void> showShareCardDialog(BuildContext context,
    {required ShareCardData data, required ShareCardTexts texts, required UsageStats usage}) =>
    showDialog<void>(
        context: context,
        builder: (ctx) => ShareCardDialog(data: data, texts: texts, usage: usage));

class ShareCardDialog extends StatefulWidget {
  final ShareCardData data;
  final ShareCardTexts texts;
  final UsageStats usage;
  const ShareCardDialog({super.key, required this.data, required this.texts, required this.usage});
  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final _card = GlobalKey();
  final _send = GlobalKey();
  bool _busy = false, _failed = false;

  Future<void> _share() async {
    setState(() {_busy = true; _failed = false;});
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final png = await captureShareCard(boundary, widget.texts);
      final box = _send.currentContext?.findRenderObject();
      final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
      await ShareCards.sharer.sharePng(png,
          text: widget.texts.message(widget.data), fileName: widget.texts.fileName(widget.data), origin: origin);
      widget.usage.record(UsageEvent.share, {'moment': widget.data.moment.id});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      key: const Key('share-card-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: CozyPanel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
              child: FittedBox(
                  child: RepaintBoundary(
                      key: _card,
                      child: ShareCardView(key: const Key('share-card'), data: widget.data, texts: widget.texts)))),
          if (_failed)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(ShareCards.failedText,
                    key: Key('share-card-failed'), textAlign: TextAlign.center,
                    style: TextStyle(color: Cozy.brick, fontSize: 14))),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
            CozyButton(key: const Key('share-card-close'), minHeight: 40, fontSize: 16,
                onPressed: _busy ? null : () => Navigator.pop(context), label: '닫기'),
            KeyedSubtree(key: _send, child: CozyPrimaryButton(key: const Key('share-card-send'), minHeight: 40, fontSize: 16,
                onPressed: _busy ? null : _share, label: '공유하기')),
          ]),
        ]),
      ));
}
