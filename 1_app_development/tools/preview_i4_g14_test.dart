// 26번 4차 g14 미리보기(한글 글꼴): 아주 큰 스킬 비용이 한국식 단위로 보이는지(지수 표기 없음).
// flutter test tools/preview_i4_g14_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4g14_skills_<태그>_<폭>.png (실제 앱 크기 390×844·360×800)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show setUpAccount;
import '../test/workshop_controller_test.dart' show Gateway;

void main() {
  Future<void> fonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        const korean = String.fromEnvironment('PREVIEW_FONT');
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
        if (korean.isNotEmpty) await load('Roboto', korean);
      });

  Future<void> shot(WidgetTester tester, String name) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & view.size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    testWidgets('g14 미리보기 $w', (tester) async {
      final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
      final game = await setUpAccount(tester, size, reduced: true, online: online);
      await fonts(tester);
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final gateway = Gateway();
      final c = WorkshopController(config, MemoryRepository(),
          purchaseGateway: gateway, now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
      await tester.runAsync(() async {
        await c.initialize();
        await c.command(() {
          c.state.tutorial = 'done';
          c.state.level = 2;
          c.state.claimedLevels.add(2);
          c.state.featureIntros.addAll(['skills', 'pantry']);
          c.state.lifetime = BigInt.from(10).pow(200);
          c.state.buns = BigInt.from(10).pow(200);
        });
        // ignore: avoid_print
        print('base error ${c.error} notice ${c.notice}');
        for (final e in {'tap_1': 950, 'tap_2': 700, 'tap_3': 400, 'tap_4': 250}.entries) {
          await c.purchaseSkill(gateway, e.key, quantity: e.value);
        }
        // ignore: avoid_print
        print('owned error ${c.error} notice ${c.notice} buns ${c.state.buns}');
      });
      await tester.pumpWidget(GameApp(controller: game, workshop: c));
      await tester.pump();
      final menu = find.byKey(const Key('menu-skills'));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await shot(tester, 'i4g14_skills_${tag}_$w');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
