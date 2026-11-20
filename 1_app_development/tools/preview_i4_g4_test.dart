// 4차 피드백 g4 미리보기(ID3 꾸미기 레벨 잠금 없앰, IC10 온라인 전용)를 실제 앱
// 크기(390×844)로 그린다.
//   flutter test --update-goldens tools/preview_i4_g4_test.dart
// 결과: build/preview_g4/<이름>.png
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/owner_account.dart';
import 'package:todays_bungeoppang/owner_profile.dart';
import 'package:todays_bungeoppang/owner_repository.dart';
import 'package:todays_bungeoppang/ui/connection_notice.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;
import '../test/workshop_controller_test.dart' show Gateway;

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      const preview = String.fromEnvironment('PREVIEW_FONT');
      if (preview.isNotEmpty) {
        for (final family in ['Roboto', 'Jua']) {
          await (FontLoader(family)..addFont(File(preview).readAsBytes().then(ByteData.sublistView))).load();
        }
      }
    });

Future<void> _shot(WidgetTester tester, String name) =>
    expectLater(find.byType(GameApp), matchesGoldenFile('../build/preview_g4/$name.png'));

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Level 1 shop; [gateway] false = a build without the online settings.
Future<WorkshopController> _open(WidgetTester tester, {bool gateway = true, bool band = false, OwnerAccount Function(GameController, WorkshopController)? owner}) async {
  final online = FakeOnlineBackend(products: const {}, prices: const {})
    ..signedIn = true
    ..gold = 5;
  final game = await mountGame(tester, const Size(390, 844), reduced: true, online: online);
  await _fonts(tester);
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final c = WorkshopController(config, MemoryRepository(),
      purchaseGateway: gateway ? Gateway() : null, now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
  await c.initialize();
  await c.command(() {
    c.state.tutorial = 'done';
    c.state.level = 2;
    c.state.claimedLevels.add(2);
    c.state.featureIntros.addAll(['skills']);
    c.state.lifetime = BigInt.from(20000);
    c.state.buns = BigInt.from(5000);
  });
  game.state.premium.gold = 5;
  final o = owner?.call(game, c);
  if (o != null) await o.load();
  await tester.pumpWidget(GameApp(controller: game, workshop: c, owner: o, devBuildBand: band));
  await tester.pump();
  return c;
}

void main() {
  testWidgets('ID3 상점 머리 칸(Lv.2)', (tester) async {
    await _open(tester);
    await _tap(tester, 'menu-shop');
    await _tap(tester, 'cosmetic-slot-hair');
    await _shot(tester, 'id3_shop_hair');
    await _tap(tester, 'cosmetic-slot-hat');
    await _shot(tester, 'id3_shop_hat');
  });

  testWidgets('ID3 상점 가게 배경(Lv.2)', (tester) async {
    await _open(tester);
    await _tap(tester, 'menu-shop');
    await _tap(tester, 'cosmetic-category-stall');
    await _shot(tester, 'id3_shop_stall');
  });

  testWidgets('IC10 키 없는 빌드 스킬 창', (tester) async {
    await _open(tester, gateway: false, band: true);
    await _tap(tester, 'menu-skills');
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, 'ic10_skill_nokey');
  });

  testWidgets('IC10 키 없는 빌드 상점 구매', (tester) async {
    await _open(tester, gateway: false, band: true);
    await _tap(tester, 'menu-shop');
    await _tap(tester, 'cosmetic-slot-hat');
    await _tap(tester, 'preview-earmuffs');
    await _tap(tester, 'buy-cosmetic-earmuffs');
    await _shot(tester, 'ic10_shop_nokey');
  });

  testWidgets('IC10 연결 끊김 알림', (tester) async {
    await _open(tester,
        owner: (game, c) => OwnerAccount(
            repository: MemoryOwnerProfileRepository(OwnerProfile()
              ..account = 'kakao:1001'
              ..provider = LoginProvider.kakao
              ..consentVersion = requiredConsentVersion
              ..name = '붕어빵'
              ..characterChosen = true
              ..optionalAsked = true),
            online: (game.online as FakeOnlineBackend)..loginProvider = LoginProvider.kakao,
            rules: OwnerNameRules.fromJson(
                jsonDecode(File('config/owner_name_rules.json').readAsStringSync()) as Map<String, dynamic>),
            game: game,
            workshop: c,
            hasInternet: () async => false));
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, 'ic10_connection_lost');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('IC10 키 없는 릴리스 빌드 화면', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(PixelSprites.load);
    await _fonts(tester);
    await tester.pumpWidget(const OnlineSetupMissingApp());
    await tester.pump();
    await expectLater(find.byType(OnlineSetupMissingApp), matchesGoldenFile('../build/preview_g4/ic10_release_nokey.png'));
  });
}
