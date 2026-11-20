// 4차 피드백 g6 미리보기(한글 글꼴): 도감 칸 채우기와 숙련된 붕어빵 틀(6구).
// flutter test tools/preview_i4_g6_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 결과: build/preview/g6_<장면>_<폭>.png (실제 앱 크기 390×844·360×800).
// 이전 코드에서도 돌도록 결과 원장(MasteryResult)과 예전 숙련 확정만 씀.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

  var seq = 0;
  void bake(WorkshopController c, String flavor, List<int> counts, {bool technique = false}) {
    var m = c.state.flavorMasteries[flavor]!;
    for (var v = 0; v < 5; v++) {
      for (var i = 0; i < counts[v]; i++) {
        m = m.record(MasteryResult(id: 'p-${seq++}', flavor: flavor, variant: v,
            completed: true, practice: true, techniquePassed: technique));
      }
    }
    c.state.flavorMasteries[flavor] = m;
  }

  /// [scene]: 'partial' (팥 일부·슈크림 시작), 'collected' (팥 다 모음),
  /// 'griddle' (팥 다 모음 + 예전 숙련, 6구 여섯 칸이 서로 다른 때).
  Future<WorkshopController> controller(String scene) async {
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 19, 3), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = 5;
      c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= 5; i++) i]);
      c.state.featureIntros.addAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
      c.state.recipes.add('custard');
      c.state.recipeMissions.add('custard');
      c.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: 1);
      c.state.completedSales = 0;
      if (scene == 'partial') {
        bake(c, 'redbean', [2, 1, 3, 0, 0]);
        bake(c, 'custard', [0, 4, 7, 0, 0]);
      } else {
        bake(c, 'redbean', [2, 3, 5, 3, 2], technique: true);
        bake(c, 'custard', [3, 12, 30, 5, 0]);
      }
      if (scene == 'griddle') {
        c.state.masteryAwards['redbean'] = {'revision': 'old', 'resultId': c.state.flavorMasteries['redbean']!.results.keys.first, 'practiceRequired': 5, 'techniqueRequired': 3};
      }
    });
    await c.openBusiness();
    if (scene == 'griddle') {
      // Cells started at different times: each shows a different moment.
      for (final (cell, wait) in [(5, 9000), (4, 5000), (3, 4000), (2, 3000), (1, 2000), (0, 500)]) {
        await c.startCell(cell);
        await c.command(() => c.state.grid = c.state.grid.advanceActive(wait));
      }
    }
    // ignore: avoid_print
    print('state error: ${c.error} ${c.notice}');
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.toInt();
    for (final scene in ['partial', 'collected', 'griddle']) {
      testWidgets('g6 미리보기 $scene $w', (tester) async {
        await fonts(tester);
        final account = await mountGame(tester, size, reduced: true);
        final c = await controller(scene);
        await tester.pumpWidget(GameApp(controller: account, workshop: c));
        await settle(tester);
        await shot(tester, 'g6_home_${scene}_$w');
        Future<void> close() async {
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          while (nav.canPop()) {
            nav.pop();
            await settle(tester);
          }
        }
        if (scene != 'griddle') {
          await tester.tap(find.byKey(const Key('menu-menubar')));
          await settle(tester);
          await shot(tester, 'g6_menu_${scene}_$w');
          await tester.ensureVisible(find.byKey(const Key('menu-collection')));
          await tester.tap(find.byKey(const Key('menu-collection')));
          await settle(tester);
          await shot(tester, 'g6_collection_${scene}_$w');
          await close();
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
