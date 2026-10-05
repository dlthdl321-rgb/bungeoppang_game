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
            colors: background == 'dusk'
                ? const [
                    Color(0xff503c6c),
                    Color(0xff7b596c),
                    Color(0xff624646)
                  ]
                : background == 'forest'
                    ? const [
                        Color(0xff123d37),
                        Color(0xff315d50),
                        Color(0xff3c4937)
                      ]
                    : const [
                        Color(0xff111e30),
                        Color(0xff243342),
                        Color(0xff493d38)
                      ],
          ).createShader(Offset.zero & size));
    final paint = Paint();
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
    for (var i = 1; i < 9; i++) {
      canvas.drawLine(
          Offset(w * i / 9, h * .8),
          Offset(w * i / 9, h),
          Paint()
            ..color = const Color(0xff302721)
            ..strokeWidth = 2);
    }
    final burner = Rect.fromLTWH(w * .2, h * .705, w * .48, h * .068);
    canvas.drawRRect(
        RRect.fromRectAndRadius(burner, Radius.circular(w * .025)),
        paint
          ..color = stove == 'copper'
              ? const Color(0xffb9794f)
              : const Color(0xff48505b));
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

  @override
  bool shouldRepaint(covariant NightStallPainter oldDelegate) =>
      background != oldDelegate.background ||
      stove != oldDelegate.stove ||
      decoration != oldDelegate.decoration;
}
