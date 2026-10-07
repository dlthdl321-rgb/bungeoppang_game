import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import '../test/widget_test.dart' show mountGame;

class OriginalGriddlePreview extends CustomPainter {
  final double enlargement;
  final ui.Image? corrected;
  OriginalGriddlePreview(this.enlargement, [this.corrected]);
  @override
  void paint(Canvas canvas, Size size) {
    final image = corrected ?? PixelSprites.cosmetic(CosmeticSlot.stove, 'iron')!;
    final scale = math.min(size.width / image.width, size.height / image.height) * enlargement;
    final width = image.width * scale;
    final height = image.height * scale;
    canvas.drawImageRect(image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH((size.width - width) / 2, size.height - height, width, height),
      Paint()..filterQuality = FilterQuality.none..isAntiAlias = false);
  }
  @override
  bool shouldRepaint(OriginalGriddlePreview old) => old.enlargement != enlargement || old.corrected != corrected;
}

void main() {
  testWidgets('original sprite bottom anchored placement previews', (tester) async {
    await tester.runAsync(() async {
      final font = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
      await (FontLoader('Jua')..addFont(Future.value(font))).load();
      final bytes = await File('C:/Windows/Fonts/malgun.ttf').readAsBytes();
      await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
    });
    tester.view.physicalSize = const Size(390, 844);
    await mountGame(tester, const Size(390, 844), reduced: true);
    final griddle = tester.renderObject<RenderCustomPaint>(find.byKey(const Key('griddle')));
    final bottom = griddle.localToGlobal(Offset(0, griddle.size.height)).dy;
    for (final factor in [1.0, 1.15]) {
      await tester.pump();
      griddle.painter = OriginalGriddlePreview(factor);
      tester.binding.rootPipelineOwner.flushPaint();
      expect(griddle.localToGlobal(Offset(0, griddle.size.height)).dy, bottom);
      expect(tester.takeException(), isNull);
      final capture = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('home-capture')));
      await tester.runAsync(() async {
        final image = await capture.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/preview/original_griddle_${factor == 1 ? "before" : "up15"}.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    ui.Image? correctedImage;
    await tester.runAsync(() async {
      final bytes = await File('이미지/추가 생성 이미지 2/stove/iron.png').readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      correctedImage = frame.image;
      codec.dispose();
    });
    await tester.pump();
    griddle.painter = OriginalGriddlePreview(1.15, correctedImage);
    tester.binding.rootPipelineOwner.flushPaint();
    expect(griddle.localToGlobal(Offset(0, griddle.size.height)).dy, bottom);
    final correctedCapture = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('home-capture')));
    await tester.runAsync(() async {
      final image = await correctedCapture.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/preview/corrected_griddle_up15.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
  });
}
