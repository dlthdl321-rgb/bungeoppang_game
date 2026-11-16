import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cooking_paint.dart';
import '../cooking_result_rules.dart' show paintOverflowed;
import '../development_balance.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'workshop_mold_stage.dart' show WorkshopMoldArt;

/// Paste colors of the fillings: the painted filling cells fall back to
/// this flat color when a filling texture (25번 필요한 그림 3번) is
/// missing, and so do the drawn drips/bag.
const fillingPasteColors = {
  'redbean': Color(0xff642b27),
  'custard': Color(0xffe8b84a),
  'cocoa': Color(0xff4a2c1d),
};
const batterPasteColor = Color(0xffe9d6a7);
Color fillingPasteColor(String flavor) => fillingPasteColors[flavor] ?? fillingPasteColors['redbean']!;

/// What one painted layer reveals: a mold picture ([image], e.g. 'batter')
/// or a flat paste [color]. [cells] are [MoldPaint.layers]; null draws the
/// whole [image] (a step finished in an earlier run of the app). [drip] is
/// the paste of the spilled drips (`fx/overflow_<drip>.png`): 'batter' or a
/// flavor.
class MoldPaintLayer {
  final String? image;
  final Color? color;
  final Uint8List? cells;
  final bool overflow;
  final String drip;
  const MoldPaintLayer({this.image, this.color, this.cells, this.overflow = false,
      this.drip = 'batter'});
}

/// Smooth sampling for drawn art shown smaller than its pixels (the piping
/// bag and the drips), so its fine dots do not break up.
final _downscalePaint = Paint()..filterQuality = FilterQuality.medium;

void _drawArt(Canvas canvas, ui.Image image, Rect dst) => canvas.drawImageRect(
    image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    dst, _downscalePaint);

/// Mold-picture pixels per filling-texture pixel. The fish is 769 mold
/// pixels wide (about 270 screen pixels on a 390-wide screen, k 0.35), so
/// one 256 tile is about 180 screen pixels (two thirds of the fish), a
/// texture pixel about 0.7 and a red bean about 10-12 screen pixels.
const fillingTextureScale = 2.0;

/// Draws [layer] over the mold, with the same fit as [WorkshopMoldArt].
void paintMoldLayer(Canvas canvas, Size size, double grow, MoldPaintLayer layer,
    {FishCavityMask? mask}) {
  final m = mask ?? FishCavityMask.standard;
  final (k, origin) = WorkshopMoldArt.fit(size, grow);
  final image = layer.image == null ? null : PixelSprites.mold(layer.image!);
  final cells = layer.cells;
  if (cells == null) {
    WorkshopMoldArt.drawAt(canvas, image, Offset.zero, k, origin);
    return;
  }
  final top = origin + WorkshopMoldArt.fishRect.topLeft * k;
  final side = m.cell * k;
  Rect cellRect(int i) => Rect.fromLTWH(top.dx + (i % m.cols) * side - .4,
      top.dy + (i ~/ m.cols) * side - .4, side + .8, side + .8);
  final path = Path(), thick = Path();
  for (var i = 0; i < cells.length; i++) {
    if (cells[i] == 0) continue;
    path.addRect(cellRect(i));
    if (cells[i] > 1) thick.addRect(cellRect(i));
  }
  final paste = layer.color ?? batterPasteColor;
  if (image != null) {
    canvas.save();
    canvas.clipPath(path);
    WorkshopMoldArt.drawAt(canvas, image, Offset.zero, k, origin);
    canvas.restore();
  } else {
    // The filling texture (mold/paint_<flavor>.png, 256x256 seamless tile,
    // 25번 필요한 그림 3번), [fillingTextureScale] mold-picture pixels per
    // texture pixel; flat color when the picture is missing.
    final texture = PixelSprites.fillingTexture(layer.drip);
    final fill = Paint()..color = paste;
    if (texture != null) {
      final t = k * fillingTextureScale;
      fill.shader = ImageShader(texture, TileMode.repeated, TileMode.repeated,
          (Matrix4.identity()
                ..translateByDouble(origin.dx, origin.dy, 0, 1)
                ..scaleByDouble(t, t, 1, 1))
              .storage,
          filterQuality: FilterQuality.none);
    }
    canvas.drawPath(path, fill);
  }
  // Overpainted cells are a little darker (DEC-032).
  canvas.drawPath(thick, Paint()..color = const Color(0x1f3b1a08));
  if (!layer.overflow) return;
  // Spilled paste hangs over the fish's lower edge where it was painted
  // (fx/overflow_<paste>.png, 25번 필요한 그림 4번: its top centre on the
  // edge; a drawn drop when the picture is missing).
  final art = PixelSprites.fx('overflow_${layer.drip}');
  final drip = Paint()..color = paste;
  for (var c = 2; c < m.cols; c += 5) {
    for (var r = m.rows - 1; r >= 0; r--) {
      final i = r * m.cols + c;
      if (!m.inFish(i)) continue;
      if (cells[i] == 0) break;
      final x = top.dx + (c + .5) * side, y = top.dy + (r + 1) * side;
      if (art != null) {
        final w = side * 2.4;
        _drawArt(canvas, art,
            Rect.fromLTWH(x - w / 2, y - side * .3, w, w * art.height / art.width));
        break;
      }
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x - side * .45, y - side * .3, side * .9, side * 1.6),
          Radius.circular(side * .45)), drip);
      canvas.drawCircle(Offset(x, y + side * 1.5), side * .6, drip);
      break;
    }
  }
}

/// One piping step on the special bungeoppang mold (24번 5단계): the player
/// rubs over the mold like painting. Only the first pointer paints; lifting
/// it confirms the step with the painted [PaintAmount]. An empty stroke (no
/// fish cell painted) confirms nothing (G3). Pointer cancel, [blocked], a
/// new [stageToken] or leaving the app discards the stroke. The screen
/// reader's activation confirms one even layer (G4).
class MoldPaintControl extends StatefulWidget {
  final int stageToken;
  final bool blocked, filling, reduceMotion, vibration;
  final String flavor;
  final DevelopmentBalance config;

  /// [WorkshopMoldArt.fit] grow of the mold under this control.
  final double grow;

  /// How far the caption sits above the bottom, clear of the stage's
  /// '제작 취소' button (WorkshopMoldStage).
  final double captionLift;

  /// Gets the stroke and the cells it painted (kept on screen, G2).
  final void Function(PaintAmount paint, Uint8List cells) onFinished;
  const MoldPaintControl({super.key, required this.stageToken, required this.blocked,
      required this.filling, required this.flavor, required this.config,
      required this.onFinished, this.grow = 1, this.captionLift = 0, this.reduceMotion = false,
      this.vibration = false});
  @override
  State<MoldPaintControl> createState() => MoldPaintControlState();
}

class MoldPaintControlState extends State<MoldPaintControl> with WidgetsBindingObserver {
  MoldPaint? _paint;
  _Stroke? _stroke;
  Offset? _finger;
  double _lean = 0;
  bool _squeeze = false;
  bool _overflowBuzzed = false;

  /// The stroke being painted, for tests.
  MoldPaint? get stroke => _paint;

  int get _brush => DevelopmentBalance.integer(
      widget.config.section('manual_cooking'), 'paint_brush_width_permille');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant MoldPaintControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageToken != widget.stageToken || widget.blocked) _discard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _discard();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _discard() {
    _stroke?.dead = true;
    _stroke = null;
    if (_paint == null && _finger == null) return;
    _paint = null;
    _finger = null;
    if (mounted) setState(() {});
  }

  /// Local position → mask coordinates (mold-picture pixels from fishRect).
  Offset _toMask(Offset local) {
    final box = context.findRenderObject() as RenderBox;
    final (k, origin) = WorkshopMoldArt.fit(box.size, widget.grow);
    return (local - origin) / k - WorkshopMoldArt.fishRect.topLeft;
  }

  Drag? _start(Offset global) {
    if (widget.blocked || _stroke != null || !mounted) return null;
    final stroke = _Stroke(this, widget.stageToken);
    _stroke = stroke;
    _paint = MoldPaint(FishCavityMask.standard, brushWidthPermille: _brush);
    _overflowBuzzed = false;
    _move(global);
    return stroke;
  }

  void _move(Offset global) {
    final paint = _paint;
    if (paint == null) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(global);
    final at = _toMask(local);
    paint.moveTo(at.dx, at.dy);
    // Squeezing while over the fish (the paste goes in), plain outside.
    final m = FishCavityMask.standard;
    final col = (at.dx / m.cell).floor(), row = (at.dy / m.cell).floor();
    _squeeze = col >= 0 && row >= 0 && col < m.cols && row < m.rows &&
        m.inFish(row * m.cols + col);
    if (!widget.reduceMotion && _finger != null) {
      _lean = ((local.dx - _finger!.dx) * .02).clamp(-.25, .25);
    }
    _finger = local;
    if (!_overflowBuzzed && paintOverflowed(widget.config, paint.amount)) {
      _overflowBuzzed = true;
      if (widget.vibration) HapticFeedback.mediumImpact();
    }
    setState(() {});
  }

  void _end() {
    final paint = _paint;
    _stroke = null;
    _paint = null;
    _finger = null;
    if (mounted) setState(() {});
    if (paint == null || widget.blocked || !paint.painted) return;
    if (widget.vibration) HapticFeedback.selectionClick();
    widget.onFinished(paint.amount, Uint8List.fromList(paint.layers));
  }

  void _finishEven() {
    if (widget.blocked || _stroke != null) return;
    final cells = Uint8List(FishCavityMask.standard.cells.length)
      ..setAll(0, FishCavityMask.standard.cells);
    widget.onFinished(PaintAmount.even, cells);
  }

  String get caption {
    final paint = _paint;
    final what = widget.filling ? '속' : '반죽';
    if (paint == null) {
      return widget.filling ? '틀 위를 문질러 속을 짜 주세요' : '틀 위를 문질러 반죽을 부어 주세요';
    }
    final a = paint.amount;
    final over = paintOverflowed(widget.config, a) ? ' · 넘쳤어요' : '';
    return widget.filling
        ? '$what 양 ${a.amount ~/ 10}% · 손을 떼면 마무리$over'
        : '$what 덮음 ${a.coverage ~/ 10}% · 양 ${a.amount ~/ 10}% · 손을 떼면 마무리$over';
  }

  @override
  Widget build(BuildContext context) {
    final paint = _paint;
    final paste = widget.filling ? fillingPasteColor(widget.flavor) : batterPasteColor;
    return Semantics(
      button: true,
      enabled: !widget.blocked,
      label: widget.filling ? '짤주머니로 속 넣기' : '짤주머니로 반죽 붓기',
      hint: '틀 위를 문질러 칠하거나, 화면 읽기 기능으로 두 번 활성화하면 고르게 칠해요.',
      onTap: widget.blocked ? null : _finishEven,
      child: ExcludeSemantics(
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          // Wins the gesture arena at once, so a scrolling home (large text)
          // does not scroll while painting.
          gestures: {
            ImmediateMultiDragGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<ImmediateMultiDragGestureRecognizer>(
                    ImmediateMultiDragGestureRecognizer.new,
                    (r) => r.onStart = _start),
          },
          child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
            IgnorePointer(
                child: CustomPaint(
                    key: const Key('mold-paint-live'),
                    painter: _LivePainter(
                        paint == null
                            ? null
                            : MoldPaintLayer(
                                image: widget.filling ? null : 'batter',
                                color: widget.filling ? paste : null,
                                cells: paint.layers,
                                drip: widget.filling ? widget.flavor : 'batter',
                                overflow: paintOverflowed(widget.config, paint.amount)),
                        paint?.version ?? -1,
                        widget.grow,
                        _finger,
                        paste,
                        widget.reduceMotion ? 0 : _lean,
                        PixelSprites.pipingBag(widget.filling ? widget.flavor : 'batter',
                            squeeze: _squeeze)))),
            Padding(
                padding: EdgeInsets.only(bottom: widget.captionLift),
                child: Align(
                alignment: Alignment.bottomCenter,
                child: IgnorePointer(
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Cozy.woodDark.withValues(alpha: .9),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(caption,
                            key: const Key('piping-amount'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Cozy.cream, fontWeight: FontWeight.bold, fontSize: 13)))))),
          ]),
        ),
      ),
    );
  }
}

class _Stroke extends Drag {
  final MoldPaintControlState owner;
  final int token;
  bool dead = false;
  _Stroke(this.owner, this.token);
  bool get _live => !dead && owner.mounted && owner._stroke == this &&
      owner.widget.stageToken == token;
  @override
  void update(DragUpdateDetails details) {
    if (_live) owner._move(details.globalPosition);
  }

  @override
  void end(DragEndDetails details) {
    if (_live) owner._end();
  }

  @override
  void cancel() {
    if (_live) owner._discard();
  }
}

/// The live stroke and the piping bag at the finger ([bag], 25번 필요한 그림
/// 2번; a drawn bag when the picture is missing). The paste under the
/// nozzle ([PixelSprites.pipingBagTip]) sits on the finger; the body leans
/// up and right so the finger does not hide the paste.
class _LivePainter extends CustomPainter {
  final MoldPaintLayer? layer;
  final int version;
  final double grow, lean;
  final Offset? finger;
  final Color paste;
  final ui.Image? bag;
  _LivePainter(this.layer, this.version, this.grow, this.finger, this.paste, this.lean,
      this.bag);
  @override
  void paint(Canvas canvas, Size size) {
    if (layer != null) paintMoldLayer(canvas, size, grow, layer!);
    final at = finger;
    if (at == null) return;
    // 64 wide (art 128x192 at half size, the bag itself about 43x92) on
    // the usual mold (262 wide at 390x844); narrower only on a tiny mold.
    final w = math.min(size.width * .3, 64.0), h = math.min(size.height * .45, 92.0);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final art = this.bag;
    if (art != null) {
      // [w] x 1.5w on screen, pointing down, then leaned up-right.
      final k = w / art.width;
      canvas.rotate(.45 + lean);
      _drawArt(canvas, art, Rect.fromLTWH(-PixelSprites.pipingBagTip.dx * k,
          -PixelSprites.pipingBagTip.dy * k, art.width * k, art.height * k));
      canvas.restore();
      return;
    }
    canvas.rotate(math.pi + .45 + lean);
    // Drawn tip-first: the tip at the origin, the bag body behind it.
    final bag = Path()
      ..moveTo(0, 12)
      ..quadraticBezierTo(-w * .42, h * .7, -w * .5, h + 12)
      ..quadraticBezierTo(0, h * 1.14 + 12, w * .5, h + 12)
      ..quadraticBezierTo(w * .32, h * .7, 0, 12)
      ..close();
    canvas.drawPath(bag, Paint()..color = const Color(0xfff7e1ad));
    canvas.drawPath(bag, Paint()..color = Cozy.wood..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawLine(Offset(-w * .45, h + 12), Offset(w * .45, h + 12),
        Paint()..color = Cozy.orangeDeep..strokeWidth = 7);
    canvas.drawPath(Path()..moveTo(-5, 22)..lineTo(5, 22)..lineTo(0, 6)..close(),
        Paint()..color = const Color(0xffa9adb0));
    canvas.drawCircle(Offset.zero, 6, Paint()..color = paste);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LivePainter old) => old.version != version ||
      old.finger != finger || old.layer?.overflow != layer?.overflow ||
      old.paste != paste || old.lean != lean || old.grow != grow || old.bag != bag;
}
