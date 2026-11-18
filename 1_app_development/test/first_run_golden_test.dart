import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'owner_first_run_test.dart' show agreeAndLogin, enterName, mountFirstRun, tap;

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

  testWidgets('첫 실행 화면 골든 390x844: 로그인·이름·캐릭터·선택 정보', (tester) async {
    await mountFirstRun(tester);
    await loadFonts(tester);
    await tester.pump();
    await shoot(tester, 'login_390x844');
    await agreeAndLogin(tester, LoginProvider.kakao);
    // Not focused, so no cursor blinks into the picture.
    FocusManager.instance.primaryFocus?.unfocus();
    await shoot(tester, 'name_390x844');
    await enterName(tester, '붕어빵장인');
    await tap(tester, const Key('character-boy'));
    await shoot(tester, 'character_390x844');
    await tap(tester, const Key('first-run-character-start'));
    await tap(tester, const Key('gender-female'));
    await tap(tester, const Key('age-twenties'));
    await tap(tester, const Key('consent-optional'));
    await shoot(tester, 'optional_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('작은 화면 360x640에서도 로그인 화면이 잘리지 않는다', (tester) async {
    await mountFirstRun(tester, size: const Size(360, 640));
    await loadFonts(tester);
    await tester.pump();
    await shoot(tester, 'login_360x640');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
