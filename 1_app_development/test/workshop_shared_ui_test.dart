import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'test_support.dart' show CountingRepository, FakeAudio, setUpAccount;

/// 28번 C2: 예전 클리커 홈에서만 검사하던 것 중 **새 게임도 쓰는 화면**의 검사를
/// 실제 앱 경로(새 홈 = GameApp + WorkshopController)로 옮겼다.
/// - 날씨는 모션 감소면 꺼진다 (stage14_systems에서)
/// - 상점·꾸미기 창이 글자 2배에서도 넘치지 않는다 (stage14_systems·public_menus_widget에서)
/// - 설정의 저장 버튼은 계정을 저장하고 닫는다 (stage14_systems에서)
/// - 앱이 뒤로 가면 배경음을 멈추고 돌아오면 다시 튼다 (stage10_feedback에서, C3-2)
/// - 음량 슬라이더는 끄는 동안 저장하지 않고 놓을 때 한 번 저장 (stage10_feedback에서, C3-2)
/// - 설정 화면에 배경음 선택 드롭다운이 없다 (independent_music에서, C3-2)
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  Future<(WorkshopController, GameController)> home(WidgetTester tester, Size size,
      {double textScale = 1, bool reduced = true, int level = 1, CountingRepository? repository,
      FakeAudio? audio, void Function(GameController)? setUp}) async {
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await setUpAccount(tester, size,
        textScale: textScale, reduced: reduced, online: online, repository: repository);
    setUp?.call(account);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 11, 23), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = level;
      c.state.claimedLevels.addAll([for (var n = 2; n <= level; n++) n]);
      c.state.featureIntros.addAll(['fairy', 'wardrobe', 'skills', 'pantry', 'collection', 'recipes',
        'specialOrders', 'fishCosmetics', 'stallCosmetics']);
    });
    await tester.pumpWidget(GameApp(controller: account, audio: audio ?? FakeAudio(), workshop: c));
    await tester.pump();
    return (c, account);
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final reduced in [false, true]) {
    testWidgets('새 홈 날씨는 모션 감소면 꺼진다 ($reduced)', (tester) async {
      await home(tester, const Size(390, 844), reduced: reduced);
      expect(find.byKey(const Key('weather')), reduced ? findsNothing : findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final size in const [Size(360, 800), Size(412, 915)]) {
    testWidgets('새 홈 상점: 글자 2배 ${size.width.toInt()}에서도 탭마다 넘치지 않는다', (tester) async {
      await home(tester, size, textScale: 2, level: 5);
      await tap(tester, 'menu-shop');
      for (final tab in ['cosmetics', 'ingredients', 'gold']) {
        final chip = find.byKey(Key('shop-tab-$tab'));
        if (chip.evaluate().isEmpty) continue;
        await tap(tester, 'shop-tab-$tab');
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('새 홈 꾸미기: 글자 2배 ${size.width.toInt()}에서도 넘치지 않는다', (tester) async {
      await home(tester, size, textScale: 2, level: 5);
      await tap(tester, 'menu-skins');
      expect(find.byKey(const Key('preview-avatar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('새 홈 설정의 저장 버튼은 계정을 저장하고 닫는다', (tester) async {
    final repo = CountingRepository();
    await home(tester, const Size(390, 844), repository: repo);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    final before = repo.saves;
    await tester.scrollUntilVisible(find.byKey(const Key('settings-save')), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();
    expect(repo.saves, before + 1);
    expect(find.byKey(const Key('settings-save')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('새 홈: 앱이 뒤로 가면 배경음을 멈추고 돌아오면 다시 튼다', (tester) async {
    final audio = FakeAudio();
    await home(tester, const Size(390, 844), audio: audio);
    expect(audio.musicPlaying, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(audio.musicPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.musicPlaying, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('새 홈 설정: 음량 슬라이더는 끄는 동안 저장하지 않고 놓을 때 한 번 저장', (tester) async {
    final repo = CountingRepository();
    final (_, account) = await home(tester, const Size(390, 844), repository: repo);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const Key('setting-music-volume'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final saves = repo.saves;
    final volume = account.state.settings.musicVolume;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump();
    }
    expect(repo.saves, saves);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.saves, saves + 1);
    expect(account.state.settings.musicVolume, lessThan(volume));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('새 홈 설정: 배경음 선택 드롭다운이 없고 저장된 선택은 그대로', (tester) async {
    final (_, account) = await home(tester, const Size(390, 844),
        setUp: (a) => a.state.settings.musicSelection = 'rain');
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setting-music')), findsOneWidget);
    expect(find.byKey(const Key('setting-music-selection')), findsNothing);
    expect(find.text('배경음 선택'), findsNothing);
    expect(account.state.settings.musicSelection, 'rain');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
