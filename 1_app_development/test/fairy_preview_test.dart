@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_fairy.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'test_support.dart' show setUpAccount;

/// 4차 피드백 IA3 붕어빵 요정 미리보기: 헤엄·숨기·나오기·톡 반짝이를
/// 시간별 정지 화면으로 그린다. 보통 테스트에서는 건너뛰고,
/// `FAIRY_PREVIEW=1 flutter test test/fairy_preview_test.dart --update-goldens`
/// 로 build/fairy_preview/에 남긴다(눈 확인용, 골든 아님).
void main() {
  final skip = Platform.environment['FAIRY_PREVIEW'] == null;

  Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      });

  Future<WorkshopController> mount(WidgetTester tester, Size size, {String flavor = 'redbean'}) async {
    final account = await setUpAccount(tester, size);
    await loadFonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
        monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.featureIntros.add('fairy');
      if (flavor != 'redbean') {
        c.state.featureIntros.add('recipes');
        c.state.recipes.add(flavor);
        c.state.flavorMasteries[flavor] = FlavorMasteryProgress(flavor: flavor, difficulty: c.difficulty(flavor));
        c.state.selectedFlavor = flavor;
      }
    });
    await c.openBusiness();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  Future<void> guests(WorkshopController c, int n) => c.command(() {
        for (var i = 0; i < n; i++) {
          c.state.customers.add(CustomerOrder(id: 'g$i', customerId: 'anonymous_g$i', remainingMs: 100000,
              lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)]));
        }
      });

  Future<void> shot(WidgetTester tester, String name, int ms, {int? switched, int? tapped}) async {
    FairyMotion.previewMs = ms;
    FairyMotion.previewSwitchMs = switched;
    FairyMotion.previewTapMs = tapped;
    // Rebuild the fairy at the new moment.
    tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
    await tester.pump();
    await expectLater(find.byType(GameApp), matchesGoldenFile('../build/fairy_preview/$name.png'));
  }

  tearDown(() {
    FairyMotion.previewMs = null;
    FairyMotion.previewSwitchMs = null;
    FairyMotion.previewTapMs = null;
  });

  for (final size in [const Size(390, 844), const Size(360, 800), const Size(360, 640), const Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('요정 미리보기 $tag', (tester) async {
      final c = await mount(tester, size);
      // Swimming with no guests (4차 g12: wide, out past a side and back):
      // a frame every 1.4 s.
      for (var ms = 0; ms <= 9800; ms += 1400) {
        await shot(tester, '${tag}_swim_${ms.toString().padLeft(5, '0')}', ms);
      }
      await shot(tester, '${tag}_tap_twinkle', 5900, tapped: 5600);
      // Guests come at 10 s: the shy run to the right edge.
      await guests(c, 3);
      for (final ms in [10000, 10200, 10400, 10650, 12000, 14600]) {
        await shot(tester, '${tag}_hide_$ms', ms, switched: 10000);
      }
      await shot(tester, '${tag}_hidden_tap', 15300, switched: 10000, tapped: 15000);
      // Everyone leaves at 20 s: out again, slowly.
      await c.command(() => c.state.customers.clear());
      for (final ms in [20000, 20500, 21000, 21400, 23000]) {
        await shot(tester, '${tag}_emerge_$ms', ms, switched: 20000);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: skip);
  }

  // 4차 g12: frame sequences of the wide swim (a frame every 250 ms,
  // two rounds with their trips out of the stage), for the review folder.
  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('요정 넓은 헤엄 연속 $tag', (tester) async {
      await mount(tester, size);
      for (var ms = 0; ms <= 52000; ms += 250) {
        await shot(tester, 'seq_$tag/${ms.toString().padLeft(5, '0')}', ms);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }, skip: skip || Platform.environment['FAIRY_SEQ'] == null);
  }

  testWidgets('요정 소개 카드 390x844', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    await c.command(() => c.state.featureIntros.remove('fairy'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(GameApp), matchesGoldenFile('../build/fairy_preview/390x844_intro_card.png'));
    await tester.tap(find.byKey(const Key('feature-intro-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: skip);
}
