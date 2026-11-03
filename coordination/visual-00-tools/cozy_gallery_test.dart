// Gallery of the cozy widgets (visual step 2). Not part of the suite. To rerun, copy to
// 1_app_development/build/visual-02/gallery_test.dart and run flutter test --no-pub on it from 1_app_development.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

Future<void> _font(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void main() {
  testWidgets('cozy widget gallery', (tester) async {
    await tester.runAsync(() async {
      await _font('Jua', 'assets/fonts/Jua-Regular.ttf');
      await _font('MaterialIcons',
          'C:/flutter-sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      await PixelSprites.load();
    });
    await tester.binding.setSurfaceSize(const Size(390, 900));
    tester.view.devicePixelRatio = 1;
    const key = Key('gallery');
    var volume = 60.0;
    await tester.pumpWidget(MaterialApp(
        theme: cozyTheme(),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                backgroundColor: Cozy.creamDeep,
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CozyFrame(
                      child: ListView(padding: const EdgeInsets.all(12), children: [
                    CozyTabBar<int>(tabs: const [
                      CozyTab(0, '장비'),
                      CozyTab(1, '꾸미기'),
                      CozyTab(2, '테마')
                    ], selected: 0, onSelected: (_) {}),
                    const SizedBox(height: 14),
                    CozyPanel(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          const PixelIcon('skill', size: 48),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('빠른 손',
                                    style: TextStyle(fontFamily: 'Jua', fontSize: 20)),
                                SizedBox(height: 4),
                                CozyChip(label: '클릭 +2'),
                              ])),
                          CozyPrimaryButton(onPressed: () {}, label: '강화'),
                        ])),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: CozyPrimaryButton(onPressed: () {}, label: '구매')),
                      const SizedBox(width: 8),
                      Expanded(child: CozyButton(onPressed: () {}, label: '버리기')),
                      const SizedBox(width: 8),
                      const Expanded(child: CozyPrimaryButton(onPressed: null, label: '잠김')),
                    ]),
                    const SizedBox(height: 8),
                    CozyMenuRow(
                        icon: const PixelIcon('achievements', size: 48),
                        title: '업적',
                        onPressed: () {}),
                    const SizedBox(height: 8),
                    CozySettingRow(
                        icon: const PixelIcon('bgm', size: 28),
                        label: '배경음',
                        value: true,
                        onChanged: (_) {}),
                    CozySettingRow(
                        icon: const PixelIcon('vibration', size: 28),
                        label: '진동',
                        value: false,
                        onChanged: (_) {}),
                    CozyPanel(
                        child: StatefulBuilder(
                            builder: (context, set) => Slider(
                                value: volume,
                                max: 100,
                                divisions: 20,
                                onChanged: (v) => set(() => volume = v)))),
                    const SizedBox(height: 4),
                    CozyPanel(
                        child: Slider(value: 40, max: 100, onChanged: null)),
                    const SizedBox(height: 8),
                    CozyPrimaryButton(
                        onPressed: () {},
                        label: '저장',
                        icon: const PixelIcon('save', size: 28),
                        minHeight: 52,
                        fontSize: 22),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      CozyRoundButton(
                          tooltip: '메뉴',
                          icon: const PixelIcon('menu', size: 28),
                          onPressed: () {}),
                      CozyCloseButton(onPressed: () {}),
                    ]),
                    const SizedBox(height: 12),
                    Center(child: CozyBackButton(onPressed: () {})),
                  ])),
                )))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.element(find.byKey(key)).findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/visual-02/gallery.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
