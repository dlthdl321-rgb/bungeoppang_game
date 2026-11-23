// 4차 병합 3 확인용 화면(한글 글꼴): 영업 중에도 보이는 맛 버튼, 영업 중 맛 고르기 창의
// '특제 팥' 칸, 특제를 고른 영업 중 홈을 390×844·360×800으로 그린다.
// flutter test tools/preview_i4_merge3_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_merge3/<이름>_<폭>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;
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
        if (korean.isNotEmpty) await load('FlutterTest', korean);
      });

  Future<void> shot(WidgetTester tester, String name) async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/i4_merge3/${name}_${view.size.width.round()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size, {required bool premium, bool business = false,
      bool auto = false, bool empty = false}) async {
    WeatherLayer.animate = false;
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await mountGame(tester, size, reduced: true, online: online);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final now = DateTime.utc(2026, 11, 2, 3);
    final c = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway(),
        now: () => now, monotonicMs: () => 0);
    final p = PantryConfig.of(config);
    await tester.runAsync(() async {
      await c.initialize();
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = 6;
        c.state.claimedLevels..clear()..addAll([for (var l = 2; l <= 6; l++) l]);
        c.state.featureIntros.addAll(workshopIntroIds);
        c.state.lifetime = BigInt.from(10000000);
        c.state.buns = BigInt.from(5000000);
        c.state.recipes.add('custard');
        c.state.flavorMasteries['custard'] = FlavorMasteryProgress(flavor: 'custard', difficulty: c.difficulty('custard'));
        if (premium) {
          final pantry = c.state.pantry;
          pantry.buyPremium(p, 'cultured_butter', 1, 6);
          pantry.buyPremium(p, 'fresh_adzuki', 1, 6);
          pantry.make(p, 'batter', 1, 6, now.millisecondsSinceEpoch, c.state.recipes, premium: true);
          pantry.make(p, 'redbean', 1, 6, now.millisecondsSinceEpoch, c.state.recipes, premium: true);
        }
      });
      if (auto) await c.purchaseSkill(Gateway(), 'auto_1');
      if (business) await c.openBusiness();
      if (empty) {
        await c.command(() {
          final pantry = c.state.pantry;
          for (final lot in pantry.lots) {
            pantry.ledger[lot.kind]!.used += lot.portions;
          }
          pantry.lots.clear();
        });
      }
    });
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    return c;
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final w = size.width.round();
    testWidgets('영업 중 맛 버튼과 맛 고르기(특제 팥) $w', (tester) async {
      final c = await open(tester, size, premium: true, business: true);
      expect(c.state.business.open, isTrue);
      expect(find.byKey(const Key('flavor-button')), findsOneWidget);
      await shot(tester, 'business_home');
      await tester.tap(find.byKey(const Key('flavor-button')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const Key('flavor-pick-premium-redbean')), findsOneWidget);
      await shot(tester, 'business_picker');
      await tester.tap(find.byKey(const Key('flavor-pick-premium-redbean')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(c.state.selectedPremium, isTrue);
      await shot(tester, 'business_premium');
    });
  }
}
