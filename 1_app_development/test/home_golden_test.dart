import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'widget_test.dart' show mountGame;

void main() {
  // Flutter's bundled test font keeps these layout/artwork baselines portable.
  // Korean glyph appearance is not validated by these goldens.
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    testWidgets('홈 레이아웃 골든 ${size.width.toInt()}', (tester) async {
      await mountGame(tester, size);
      await expectLater(
          find.byKey(const Key('home-capture')),
          matchesGoldenFile(
              'goldens/home_${size.width.toInt()}x${size.height.toInt()}.png'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
