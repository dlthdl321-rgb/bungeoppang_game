import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../avatar_rig_config.dart';
import '../cosmetic_config.dart';
import 'avatar_face.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'weather_layer.dart';

/// The vendor's cooking cut: a small framed window at the bottom right of
/// the home screen (07_UI/메인UI_화면).
///
/// A character with concept cooking frames ([PixelSprites.cookFrames])
/// loops them (준비 → 반죽 → 닫기 → 굽기 → 꺼내기 → 포장) and shows 꺼내기
/// on a tap; the frames are the concept art as drawn, so they do not show
/// equipped cosmetics. Others are drawn from avatar layers wearing every
/// equipped item and lift the tongs on a tap. Either way the vendor blinks
/// and talks while [greeting] (a visitor is at the stall) with eye and
/// mouth layers over the face. Still when [reduceMotion].
class CookCut extends StatefulWidget {
  final String Function(CosmeticSlot) equipped;
  final BigInt taps;
  final bool reduceMotion, greeting;
  const CookCut(
      {super.key,
      required this.equipped,
      required this.taps,
      this.reduceMotion = false,
      this.greeting = false});

  static const liftMs = 250;

  /// How long each concept cooking frame stays.
  static const frameMs = 700;

  @override
  State<CookCut> createState() => _CookCutState();
}

class _CookCutState extends State<CookCut> with TickerProviderStateMixin {
  late final _lift = AnimationController(
      vsync: this, duration: const Duration(milliseconds: CookCut.liftMs));

  /// Loops the concept frames; one cycle is all frames.
  late final _loop = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: CookCut.frameMs * PixelSprites.cookFrameCount));

  bool get _looping =>
      WeatherLayer.animate &&
      !widget.reduceMotion &&
      PixelSprites.cookFrames(widget.equipped(CosmeticSlot.character)) != null;

  void _syncLoop() {
    if (_looping && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!_looping && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncLoop();
  }

  @override
  void didUpdateWidget(CookCut old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion) {
      _lift.value = 0;
    } else if (widget.taps != old.taps) {
      _lift.forward(from: 0);
    }
    _syncLoop();
  }

  @override
  void dispose() {
    _lift.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
              color: Cozy.wood,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), offset: Offset(0, 2))
              ]),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AvatarFace(
              animate: WeatherLayer.animate && !widget.reduceMotion,
              talking: widget.greeting,
              builder: (context, face) => AnimatedBuilder(
                  animation: Listenable.merge([_lift, _loop]),
                  builder: (context, _) => CustomPaint(
                      key: const Key('cook-cut'),
                      size: Size.infinite,
                      painter: CookCutPainter(
                          look: AvatarLook.of(widget.equipped),
                          face: face,
                          lift: _lift.isAnimating
                              ? math.sin(math.pi * _lift.value)
                              : 0,
                          frame: (_loop.value * PixelSprites.cookFrameCount)
                                  .floor() %
                              PixelSprites.cookFrameCount))),
            ),
          ),
        ),
      );
}

/// The shop interior (ui/wardrobe_bg) with the vendor in front of it: the concept
/// cooking frame [frame] when the character has them, else the avatar
/// layers.
class CookCutPainter extends CustomPainter {
  final AvatarLook look;

  /// Eye and mouth frames ([AvatarFace]).
  final Map<String, String> face;

  /// Tap animation of the vendor, 0..1.
  final double lift;

  /// Concept cooking frame (0-based) when not lifting.
  final int frame;
  CookCutPainter(
      {required this.look, this.face = const {}, this.lift = 0, this.frame = 0})
      : super(repaint: AvatarRigDebug.show);

  /// The 꺼내기 (taking out with tongs) frame, shown on a tap.
  static const tapFrame = 4;

  /// Concept frames are big photos-sized art; high-quality downscaling keeps
  /// them sharp without shimmering at the window's small size. The shop
  /// interior is stored at 4x nearest-neighbour, so the same smooth filter
  /// only softens the edges of its dots.
  static final _framePaint = Paint()..filterQuality = FilterQuality.high;

  /// Fraction of the avatar canvas, from the top, shown in the window.
  static const visibleHeight = .9;

  @override
  void paint(Canvas canvas, Size size) {
    // The shop interior from the user's art (ui/wardrobe_bg), covering the
    // window; plain wood colour until it loads.
    canvas.drawRect(Offset.zero & size, Paint()..color = Cozy.woodDark);
    if (PixelSprites.screenArt('wardrobe_bg') case final room?) {
      final cover =
          math.max(size.width / room.width, size.height / room.height);
      final w = room.width * cover, h = room.height * cover;
      canvas.drawImageRect(
          room,
          Rect.fromLTWH(0, 0, room.width.toDouble(), room.height.toDouble()),
          Rect.fromLTWH((size.width - w) / 2, size.height - h, w, h),
          _framePaint);
    }
    final frames = PixelSprites.cookFrames(look.character);
    if (frames != null) {
      final shown = lift > 0 ? tapFrame : frame % frames.length;
      final image = frames[shown];
      // Fill the window's height, anchored to the bottom right like the
      // avatar below. The face layers hang on this frame's own anchors.
      final scale = size.height / image.height;
      AvatarRig(look.character, cookPoses[shown % cookPoses.length],
              face: face)
          .paint(canvas, _framePaint,
              at: Offset(size.width - image.width * scale, 0), scale: scale);
      return;
    }
    const art = AvatarLook.size;
    final scale = math.min(
        size.width / art.width, size.height / (art.height * visibleHeight));
    canvas.save();
    canvas.translate(size.width - art.width * scale,
        size.height - art.height * visibleHeight * scale);
    canvas.scale(scale);
    look.paint(canvas, Offset.zero, lift: lift, face: face);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CookCutPainter old) =>
      old.look != look ||
      old.lift != lift ||
      old.frame != frame ||
      !mapEquals(old.face, face);
}
