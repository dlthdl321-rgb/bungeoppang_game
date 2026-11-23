@Tags(['golden'])
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/sparkle_art.dart';
import 'package:todays_bungeoppang/ui/workshop_mold_stage.dart';

/// 26번 4단계 F11: 반짝이 시안 A(별빛)·B(광채)·C(김+빛)를 네 순간씩 큰 붕어빵
/// 둘레에 그린 비교 그림. 사용자가 고를 때 보는 build/f11_sparkle_options.png는
/// 이 골든(test/goldens/sparkle_options.png)을 복사한 것이다.
void main() {
  testWidgets('반짝이 시안 3안 × 4프레임', (tester) async {
    await tester.runAsync(PixelSprites.load);
    await tester.runAsync(() async {
      final file = File('assets/fonts/Jua-Regular.ttf');
      if (!file.existsSync()) return;
      await (FontLoader('Jua')..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    });
    await tester.binding.setSurfaceSize(const Size(760, 560));
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
    const phases = [.06, .3, .55, .66];
    const names = {
      SparkleStyle.star: 'A 별빛(기본)',
      SparkleStyle.glow: 'B 광채',
      SparkleStyle.steam: 'C 김+빛',
    };
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
            color: const Color(0xff2a211c),
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final style in SparkleStyle.values)
                Expanded(
                    child: Row(children: [
                  SizedBox(
                      width: 96,
                      child: Text(names[style]!,
                          style: const TextStyle(
                              fontFamily: 'Jua', fontSize: 16, color: Color(0xfffff3d6)))),
                  for (final phase in phases)
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CustomPaint(
                                painter: _Option(style, phase),
                                child: const SizedBox.expand()))),
                ])),
            ]))));
    await expectLater(find.byType(Container).first, matchesGoldenFile('goldens/sparkle_options.png'));
  });
}

class _Option extends CustomPainter {
  final SparkleStyle style;
  final double phase;
  _Option(this.style, this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    const FloatingFishPainter().paint(canvas, size);
    for (var i = 0; i < FloatingFishPainter.sparkles.length; i++) {
      final (x, y, s) = FloatingFishPainter.sparkles[i];
      // Every other one a little behind, as on the home screen.
      SparkleArt.paint(canvas, Offset(x * size.width, y * size.height), size.shortestSide * s,
          i.isEven ? phase : (phase + .12).clamp(0, .69), look: style);
    }
  }

  @override
  bool shouldRepaint(covariant _Option old) => false;
}
