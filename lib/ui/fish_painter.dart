import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original vector pastry: embossed scales and a golden baked crust.
/// Every look, filling included, derives from [skin] so all screens match.
class FishPainter extends CustomPainter {
  final String skin;
  const FishPainter({this.skin = 'redbean'});

  Color get filling => switch (skin) {
        'cocoa' => const Color(0xff663322),
        'custard' => const Color(0xffffef9b),
        'sweetpotato' => const Color(0xff8a4f8f),
        'matcha' => const Color(0xff6f8f3a),
        'strawberry' => const Color(0xffd9506d),
        _ => const Color(0xffa95738),
      };

  /// Crust gradient (light to dark) per skin.
  List<Color> get crust => switch (skin) {
        'cocoa' => const [
            Color(0xffb78361),
            Color(0xff885439),
            Color(0xff663822),
            Color(0xff3f251e)
          ],
        'custard' => const [
            Color(0xfffff6cf),
            Color(0xffffe9a5),
            Color(0xffe7c56d),
            Color(0xffbd8844)
          ],
        'sweetpotato' => const [
            Color(0xfff6c98f),
            Color(0xffe0995a),
            Color(0xffb8693a),
            Color(0xff7f4128)
          ],
        'matcha' => const [
            Color(0xffe4eeb4),
            Color(0xffb9cf78),
            Color(0xff8aa451),
            Color(0xff5b7136)
          ],
        'strawberry' => const [
            Color(0xffffe1dc),
            Color(0xfff6b2ab),
            Color(0xffe0837c),
            Color(0xffa9524f)
          ],
        _ => const [
            Color(0xffffed9c),
            Color(0xfff7ca58),
            Color(0xffdc9632),
            Color(0xffac6327)
          ],
      };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .02, size.height * .02);
    canvas.scale(size.width / 320, size.height / 240);
    final body = Path()
      ..moveTo(76, 123)
      ..cubicTo(88, 61, 164, 30, 230, 53)
      ..cubicTo(286, 68, 315, 103, 302, 137)
      ..cubicTo(284, 193, 168, 214, 107, 173)
      ..quadraticBezierTo(85, 157, 76, 123)
      ..close();
    final tail = Path()
      ..moveTo(94, 118)
      ..lineTo(23, 72)
      ..quadraticBezierTo(6, 75, 18, 102)
      ..lineTo(33, 127)
      ..lineTo(16, 165)
      ..quadraticBezierTo(14, 180, 30, 176)
      ..lineTo(102, 151)
      ..close();
    final fin = Path()
      ..moveTo(127, 69)
      ..lineTo(151, 27)
      ..quadraticBezierTo(181, 23, 215, 51)
      ..close();
    final bread = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: crust,
        stops: [0, .4, .78, 1],
      ).createShader(const Rect.fromLTWH(0, 20, 320, 195));
    final edge = Paint()
      ..color = const Color(0xff915225)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    for (final shape in [fin, tail, body]) {
      canvas.drawShadow(shape, const Color(0xcc17120d), 9, false);
      canvas.drawPath(shape, bread);
      canvas.drawPath(shape, edge);
    }
    canvas.save();
    canvas.clipPath(body);
    final grooves = Paint()
      ..color = const Color(0xffbf8131)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        final rect = Rect.fromLTWH(
            90 + col * 29 + (row % 2) * 13, 67 + row * 28, 30, 31);
        canvas.drawArc(
            rect.translate(-1, -2),
            -math.pi / 2,
            math.pi,
            false,
            Paint()
              ..color = const Color(0xffffe795)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        canvas.drawArc(rect, -math.pi / 2, math.pi, false, grooves);
      }
    }
    canvas.restore();
    canvas.drawArc(const Rect.fromLTWH(216, 74, 38, 82), 1.4, 2.8, false,
        edge..strokeWidth = 3);
    canvas.drawOval(const Rect.fromLTWH(259, 87, 12, 15),
        Paint()..color = const Color(0xff714323));
    canvas.drawCircle(
        const Offset(262, 90), 2, Paint()..color = const Color(0xffffefb9));
    canvas.drawArc(const Rect.fromLTWH(272, 110, 33, 23), .2, 1.4, false, edge);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(38, 99.0 + i * 26), Offset(81, 124.0 + i * 6),
          edge..strokeWidth = 2);
    }
    canvas.drawOval(const Rect.fromLTWH(200, 141, 28, 12),
        Paint()..color = filling.withValues(alpha: .35));
    canvas.drawArc(
        const Rect.fromLTWH(127, 66, 126, 91),
        3.7,
        1.15,
        false,
        Paint()
          ..color = const Color(0x99fff6bd)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FishPainter oldDelegate) =>
      oldDelegate.skin != skin;
}
