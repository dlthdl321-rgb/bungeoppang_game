import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_gestures.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/cooking_filling_controls.dart';

void main() {
  testWidgets('render both filling tools at a narrow Android viewport',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/malgun.ttf');
      if (await font.exists()) {
        await (FontLoader('Step02Preview')
              ..addFont(font.readAsBytes().then(ByteData.sublistView)))
            .load();
      }
      final icons = File(
          'C:/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (await icons.exists()) {
        await (FontLoader('MaterialIcons')
              ..addFont(icons.readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    });
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync())
            as Map<String, dynamic>);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Step02Preview'),
        home: Scaffold(
            backgroundColor: const Color(0xfff8edda),
            body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                    color: const Color(0xfff8edda),
                    child: Center(
                        child: CookingFillingControls(
                            stageToken: 0,
                            rules: FillingGestureRules.fromBalance(config),
                            blocked: false,
                            expected: CookingDirection.left,
                            onDirection: (_) {})))))));
    final output = Directory('build/step02-preview')
      ..createSync(recursive: true);
    for (final tool in ['spoon', 'chopsticks']) {
      if (tool == 'chopsticks') await tester.tap(find.text('젓가락'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${output.path}/$tool.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
