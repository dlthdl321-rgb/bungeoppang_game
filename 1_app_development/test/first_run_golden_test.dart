@Tags(['golden'])
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'owner_first_run_test.dart' show agreeAndLogin, enterName, mountFirstRun, tap;
import 'dart:convert';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'test_support.dart' show setUpAccount;

/// 26번 2-1단계: the first-run screens (login with the consents, owner name,
/// 여자/남자 사장님, optional info) with the app's own fonts.
void main() {
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

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/first_run_$name.png'));
    expect(tester.takeException(), isNull);
  }

  // 26번 3차 H2~H5: the winter stall behind every step, a light card, small
  // pill buttons and the name rule only when broken; both phone sizes.
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('첫 실행 화면 골든 $tag: 로그인·이름·이름 오류·캐릭터·선택 정보', (tester) async {
      await mountFirstRun(tester, size: size);
      await loadFonts(tester);
      await tester.pump();
      await shoot(tester, 'login_$tag');
      await agreeAndLogin(tester, LoginProvider.kakao);
      // Not focused, so no cursor blinks into the picture.
      FocusManager.instance.primaryFocus?.unfocus();
      await shoot(tester, 'name_$tag');
      await enterName(tester, '붕');
      FocusManager.instance.primaryFocus?.unfocus();
      await shoot(tester, 'name_error_$tag');
      await enterName(tester, '붕어빵장인');
      await tap(tester, const Key('character-boy'));
      await shoot(tester, 'character_$tag');
      await tap(tester, const Key('first-run-character-start'));
      await tap(tester, const Key('gender-female'));
      await tap(tester, const Key('age-twenties'));
      await tap(tester, const Key('consent-optional'));
      await shoot(tester, 'optional_$tag');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // 26번 3차 H6: the story over the real home before the first-run guide.
  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('첫 영업 이야기 골든 $tag', (tester) async {
      final account = await setUpAccount(tester, size, reduced: true);
      account.ownerName = '소이';
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 19));
      await c.initialize();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await loadFonts(tester);
      await tester.pump();
      await tester.pump();
      await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/story_welcome_$tag.png'));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('story-next')));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/story_welcome_last_$tag.png'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('작은 화면 360x640에서도 로그인 화면이 잘리지 않는다', (tester) async {
    await mountFirstRun(tester, size: const Size(360, 640));
    await loadFonts(tester);
    await tester.pump();
    await shoot(tester, 'login_360x640');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
