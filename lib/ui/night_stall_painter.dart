import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original vector scenery. No source-game bitmap or extracted assets.
class NightStallPainter extends CustomPainter {
  final String background, stove, decoration;
  const NightStallPainter(
      {this.background = 'night',
      this.stove = 'iron',
      this.decoration = 'none'});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: switch (background) {
              'dusk' => const [
                  Color(0xff503c6c),
                  Color(0xff7b596c),
                  Color(0xff624646)
                ],
              'forest' => const [
                  Color(0xff123d37),
                  Color(0xff315d50),
                  Color(0xff3c4937)
                ],
              'snow' => const [
                  Color(0xff1b2838),
                  Color(0xff3a4a5c),
                  Color(0xff5b6470)
                ],
              'cherry' => const [
                  Color(0xff3b2648),
                  Color(0xff6d4462),
                  Color(0xff6b4a4e)
                ],
              'seaside' => const [
                  Color(0xff0c2433),
                  Color(0xff174257),
                  Color(0xff2f4a4f)
                ],
              _ => const [
                  Color(0xff111e30),
                  Color(0xff243342),
                  Color(0xff493d38)
                ],
            },
          ).createShader(Offset.zero & size));
    final paint = Paint();
    if (background == 'seaside') _sea(canvas, size);
    for (var i = 0; i < 7; i++) {
      final x = w * i / 6;
      final top = h * (.18 + (i % 3) * .04);
      canvas.drawRect(
          Rect.fromLTWH(x, top, w / 6 - 3, h * .56),
          paint
            ..color =
                i.isEven ? const Color(0xff182633) : const Color(0xff1d2d3a));
      for (var row = 0; row < 4; row++) {
        canvas.drawRect(
            Rect.fromLTWH(x + 10, top + 18 + row * 48, 13, 22),
            paint
              ..color = (i + row) % 3 == 0
                  ? const Color(0xff695844)
                  : const Color(0xff293c4a));
      }
    }
    if (background == 'snow') {
      _scatter(canvas, size, const Color(0xddf4f8ff), 2.2);
    }
    if (background == 'cherry') _petals(canvas, size);
    final ground = Path()
      ..moveTo(0, h)
      ..lineTo(w * .4, h * .46)
      ..lineTo(w * .6, h * .46)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(ground, paint..color = const Color(0xff344047));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * .46, h * .61), width: w * 1.2, height: h * .52),
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x558eb7a8), Color(0x008eb7a8)],
          ).createShader(Rect.fromLTWH(0, h * .35, w, h * .52)));
    final wire = Path()
      ..moveTo(0, h * .29)
      ..quadraticBezierTo(w * .5, h * .39, w, h * .28);
    canvas.drawPath(
        wire,
        Paint()
          ..color = const Color(0xff070f1b)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      final y = h * (.29 + .17 * t * (1 - t));
      final center = Offset(w * t, y);
      canvas.drawCircle(
          center,
          15,
          Paint()
            ..shader = const RadialGradient(
              colors: [Color(0x66ffe1a4), Color(0x00ffe1a4)],
            ).createShader(Rect.fromCircle(center: center, radius: 15)));
      canvas.drawCircle(center, 3, paint..color = const Color(0xffffd58b));
    }
    final counter = Rect.fromLTWH(0, h * .79, w, h * .21);
    canvas.drawRect(counter, paint..color = const Color(0xff3d302a));
    canvas.drawRect(Rect.fromLTWH(0, h * .79, w, 8),
        paint..color = const Color(0xff846346));
    if (background == 'snow') {
      // Snow lying on the counter edge.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, h * .785, w, 6), const Radius.circular(3)),
          paint..color = const Color(0xfff2f6fb));
    }
    for (var i = 1; i < 9; i++) {
      canvas.drawLine(
          Offset(w * i / 9, h * .8),
          Offset(w * i / 9, h),
          Paint()
            ..color = const Color(0xff302721)
            ..strokeWidth = 2);
    }
    final burner = Rect.fromLTWH(w * .2, h * .705, w * .48, h * .068);
    final burnerShape =
        RRect.fromRectAndRadius(burner, Radius.circular(w * .025));
    if (stove == 'golden') {
      canvas.drawRRect(
          burnerShape,
          Paint()
            ..shader = const LinearGradient(colors: [
              Color(0xfff6d77a),
              Color(0xffc99a2e),
              Color(0xfff3cf6a),
              Color(0xffa8791f)
            ], stops: [
              0,
              .45,
              .6,
              1
            ]).createShader(burner));
    } else {
      canvas.drawRRect(
          burnerShape,
          paint
            ..color = switch (stove) {
              'copper' => const Color(0xffb9794f),
              'castiron' => const Color(0xff2b2e33),
              _ => const Color(0xff48505b),
            });
    }
    if (stove == 'castiron') {
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(
            Offset(burner.left + burner.width * (i + .5) / 6,
                burner.top + burner.height * .2),
            w * .006,
            paint..color = const Color(0xff5c6168));
      }
    }
    for (var i = 0; i < 3; i++) {
      final x = w * (.28 + i * .15);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, h * .715), width: w * .11, height: h * .018),
          paint..color = const Color(0xff191d25));
      canvas.drawCircle(
          Offset(x, h * .75), w * .012, paint..color = const Color(0xffffc178));
    }
    if (decoration == 'lantern') {
      for (final x in [w * .15, w * .83]) {
        canvas.drawLine(
            Offset(x, h * .2),
            Offset(x, h * .26),
            Paint()
              ..color = const Color(0xffd4c6a6)
              ..strokeWidth = 2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset(x, h * .285),
                    width: w * .085,
                    height: h * .06),
                const Radius.circular(9)),
            paint..color = const Color(0xffeec16f));
      }
    } else if (decoration == 'starlights') {
      for (var i = 0; i < 7; i++) {
        final t = (i + .5) / 7;
        final c = Offset(w * t, h * (.29 + .17 * t * (1 - t)) + h * .025);
        canvas.drawPath(
            _star(c, w * .022), paint..color = const Color(0xfffff0b8));
        canvas.drawCircle(
            c,
            w * .05,
            Paint()
              ..shader = const RadialGradient(
                      colors: [Color(0x55fff0b8), Color(0x00fff0b8)])
                  .createShader(Rect.fromCircle(center: c, radius: w * .05)));
      }
    } else if (decoration == 'windchime') {
      for (final x in [w * .13, w * .85]) {
        final string = Paint()
          ..color = const Color(0xffd4c6a6)
          ..strokeWidth = 1.5;
        canvas.drawLine(Offset(x, h * .18), Offset(x, h * .235), string);
        final bell = Path()
          ..moveTo(x - w * .03, h * .275)
          ..quadraticBezierTo(x - w * .03, h * .225, x, h * .225)
          ..quadraticBezierTo(x + w * .03, h * .225, x + w * .03, h * .275)
          ..close();
        canvas.drawPath(bell, paint..color = const Color(0xff7fb6c9));
        canvas.drawLine(Offset(x, h * .275), Offset(x, h * .315), string);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(x, h * .33), width: w * .03, height: h * .03),
            paint..color = const Color(0xfff1e3c4));
      }
    } else if (decoration == 'snowman') {
      final base = Offset(w * .86, h * .775);
      final white = Paint()..color = const Color(0xfff4f7fb);
      canvas.drawCircle(base.translate(0, -w * .035), w * .045, white);
      canvas.drawCircle(base.translate(0, -w * .1), w * .03, white);
      final eye = Paint()..color = const Color(0xff20262e);
      canvas.drawCircle(base.translate(-w * .01, -w * .105), w * .004, eye);
      canvas.drawCircle(base.translate(w * .01, -w * .105), w * .004, eye);
      canvas.drawPath(
          Path()
            ..moveTo(base.dx, base.dy - w * .097)
            ..lineTo(base.dx + w * .028, base.dy - w * .092)
            ..lineTo(base.dx, base.dy - w * .088)
            ..close(),
          Paint()..color = const Color(0xffe9883a));
      canvas.drawRect(
          Rect.fromLTWH(
              base.dx - w * .03, base.dy - w * .078, w * .06, w * .01),
          Paint()..color = const Color(0xffc0504d));
    } else if (decoration == 'bunting') {
      for (var i = 0; i < 9; i++) {
        final x = w * (.05 + i * .11), y = h * (.27 + .035 * (i % 3));
        final flag = Path()
          ..moveTo(x, y)
          ..lineTo(x + w * .07, y)
          ..lineTo(x + w * .035, y + h * .035)
          ..close();
        canvas.drawPath(
            flag,
            paint
              ..color =
                  i.isEven ? const Color(0xffcf948b) : const Color(0xff8ec9b7));
      }
    }
  }

  // Deterministic pseudo-random points so the scenery never flickers.
  static Iterable<Offset> _points(Size size, int count, int seed) sync* {
    final r = math.Random(seed);
    for (var i = 0; i < count; i++) {
      yield Offset(
          r.nextDouble() * size.width, r.nextDouble() * size.height * .78);
    }
  }

  void _scatter(Canvas canvas, Size size, Color color, double radius) {
    final paint = Paint()..color = color;
    for (final p in _points(size, 60, 11)) {
      canvas.drawCircle(p, radius * (.6 + (p.dx % 7) / 10), paint);
    }
  }

  void _petals(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xcff6b8c8);
    for (final p in _points(size, 40, 23)) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(p.dy % 3);
      canvas.drawOval(const Rect.fromLTWH(-4, -2, 8, 4), paint);
      canvas.restore();
    }
  }

  void _sea(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, h * .38, w, h * .1),
        Paint()..color = const Color(0xff0f3a4d));
    final moon = Offset(w * .78, h * .12);
    canvas.drawCircle(moon, w * .05, Paint()..color = const Color(0xfff6e7b8));
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
          Offset(w * (.74 - i * .01), h * (.40 + i * .016)),
          Offset(w * (.82 + i * .01), h * (.40 + i * .016)),
          Paint()
            ..color = const Color(0x66f6e7b8)
            ..strokeWidth = 2);
    }
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * .45;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant NightStallPainter oldDelegate) =>
      background != oldDelegate.background ||
      stove != oldDelegate.stove ||
      decoration != oldDelegate.decoration;
}
