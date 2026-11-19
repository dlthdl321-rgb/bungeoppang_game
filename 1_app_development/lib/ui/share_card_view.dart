import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../cosmetic_config.dart';
import '../share_card.dart';
import '../usage_stats.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'night_stall_painter.dart';
import 'pixel_sprites.dart';
import 'workshop_home_layout.dart';
import 'workshop_mold_stage.dart' show ResultLook;

/// The share card (26번 8단계, DEC-048; 3차 피드백 H43 재설계 A안): laid out
/// at [size] (4:5) and captured at 1080×1350 (`share.card_width`). The top
/// is a photo of the street in front of the stall with **the player's own
/// vendor standing big in front**, smiling with the tool raised (the pose,
/// [vendorFace]·lift; its own pose art is 25번 H-D-2), the bungeoppang held
/// up beside it with sparkles and the guest on the right. The bottom is a
/// light band with the badge, the title, one line and the store line. No
/// owner name, account, level, currency, date or device detail
/// (ShareCardData).
class ShareCardView extends StatelessWidget {
  final ShareCardData data;
  final ShareCardTexts texts;
  const ShareCardView({super.key, required this.data, required this.texts});

  /// The card's layout size; the capture scales it to 1080×1350.
  static const size = Size(360, 450);
  static const pictureHeight = 318.0;

  /// The vendor's face in the card: talking, a little open mouth.
  static const vendorFace = {'mouth': 'small'};

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

  static const _paper = Color(0xfffffaf0);

  @override
  Widget build(BuildContext context) {
    final guest = data.guestArt == null ? null : PixelSprites.guest(data.guestArt!, 'happy');
    // Every card holds a bungeoppang up; the shop photo a medium one.
    final variant = data.variant ?? 2;
    // Its own Material: the card is also drawn outside any screen (preview).
    return SizedBox.fromSize(
      size: size,
      child: Material(type: MaterialType.transparency, child: ColoredBox(
        color: _paper,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: pictureHeight - 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(clipBehavior: Clip.hardEdge, children: [
                  // The street in front of the stall (scene y 130..290; the
                  // concept backgrounds' pixels 260..557).
                  Positioned(
                      left: 0,
                      right: 0,
                      top: -246,
                      height: NightStallPainter.sceneSize.height * 2 * (340 / 360),
                      child: CustomPaint(
                          painter: NightStallPainter(
                              background: _equipped(CosmeticSlot.background),
                              night: false,
                              stove: null,
                              decoration: _equipped(CosmeticSlot.decoration),
                              cleanCounter: true,
                              lowStall: WorkshopHomeLayout.active))),
                  // A soft floor shadow so the vendor stands on the street.
                  Positioned(
                      left: 36, bottom: 6, width: 120, height: 18,
                      child: DecoratedBox(decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(60),
                          gradient: const RadialGradient(colors: [Color(0x55000000), Color(0x00000000)])))),
                  if (guest != null)
                    Positioned(
                        right: 0,
                        bottom: 0,
                        width: 120,
                        height: 158,
                        child: RawImage(
                            key: const Key('share-card-guest'),
                            image: guest,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.medium)),
                  // The player's vendor, big, in its pose.
                  Positioned(
                      left: 22,
                      bottom: 12,
                      width: 146,
                      height: 270,
                      child: CustomPaint(
                          key: const Key('share-card-vendor'),
                          painter: _PosePainter(AvatarLook.of(_equipped)))),
                  // The bungeoppang held out in the vendor's tongs, with sparkles.
                  Positioned(
                      left: 124,
                      top: guest == null ? 130 : 138,
                      width: guest == null ? 150 : 120,
                      height: guest == null ? 106 : 86,
                      child: Transform.rotate(
                          angle: -.18,
                          child: CustomPaint(
                              key: const Key('share-card-fish'),
                              painter: ShareFishPainter(variant: variant, shine: data.shine)))),
                  const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _SparklePainter()))),
                  Positioned(left: 10, top: 10, child: _Badge(data.moment.badge)),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
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
                    const SizedBox(width: 24, height: 18, child: CustomPaint(painter: ShareFishPainter(variant: 2))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(texts.storeLine,
                            key: const Key('share-card-store'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
                                fontSize: 14, color: Cozy.woodLight))),
                  ]),
                ]),
              ),
            ),
          ]),
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
            color: Colors.white.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 17, color: Cozy.brick)),
      );
}

/// The vendor standing, smiling, the tool raised (AvatarLook.paint lift).
class _PosePainter extends CustomPainter {
  final AvatarLook look;
  _PosePainter(this.look);
  @override
  void paint(Canvas canvas, Size size) {
    const art = AvatarLook.size;
    final scale = math.min(size.width / art.width, size.height / art.height);
    canvas.save();
    canvas.translate((size.width - art.width * scale) / 2, size.height - art.height * scale);
    canvas.scale(scale);
    look.paint(canvas, Offset.zero, lift: 1, face: ShareCardView.vendorFace);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) => old.look != look;
}

/// A few four-point sparkles around the held bungeoppang.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final glow = Paint()..color = const Color(0x88fff3b0);
    for (final (x, y, r) in const [(.44, .36, 9.0), (.8, .4, 7.0), (.58, .74, 6.0), (.88, .16, 5.0)]) {
      final c = Offset(size.width * x, size.height * y);
      canvas.drawCircle(c, r * .9, glow);
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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
