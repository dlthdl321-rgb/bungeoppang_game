import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/invite_reward_rules.dart';
import 'package:todays_bungeoppang/local_test_purchases.dart';
import 'package:todays_bungeoppang/ranking_config.dart';
import 'package:todays_bungeoppang/online_ranking.dart';
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
      FakeAudio? audio, void Function(GameController)? setUp, bool ranking = false, bool testBuild = false}) async {
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await setUpAccount(tester, size,
        textScale: textScale, reduced: reduced, repository: repository,
        // A test build has no online settings (main.dart): no server, local test gold.
        online: testBuild ? const NoOnlineBackend() : online,
        ranking: ranking ? ServerRankingService(online) : const NoRankingService());
    setUp?.call(account);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 11, 23), monotonicMs: () => 0,
        purchaseGateway: testBuild
            ? LocalTestPurchaseGateway(gold: () => account.state.premium.gold, setGold: account.setLocalTestGold)
            : null);
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

  // 29번 친구 초대 (DEC-150): '친구' is in the new home's menu only once
  // invites launch, from Lv.3, with the new game's goal and gold.
  testWidgets('새 홈 메뉴 친구: 가출시엔 없고, 출시 스위치를 켜면 Lv.3부터 열리며 황금 보상을 안내한다', (tester) async {
    Future<void> openMenu() async {
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
    }
    await home(tester, const Size(390, 844), level: 5);
    await openMenu();
    expect(find.byKey(const Key('menu-friends')), findsNothing, reason: '가출시(DEC-029)');
    await tester.pumpWidget(const SizedBox.shrink());
    debugInviteLaunchedOverride = true;
    addTearDown(() => debugInviteLaunchedOverride = null);
    await home(tester, const Size(390, 844), level: 2);
    await openMenu();
    await tester.ensureVisible(find.byKey(const Key('menu-friends')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('menu-lock-friends'))).data, 'Lv.3 달성하면 열려요');
    await tester.pumpWidget(const SizedBox.shrink());
    await home(tester, const Size(390, 844), level: 3);
    await openMenu();
    await tap(tester, 'menu-friends');
    expect(find.byKey(const Key('my-online-id')), findsOneWidget);
    expect(find.textContaining('친구는 황금 3개'), findsOneWidget);
    expect(find.textContaining('Lv.5이 되면 나도 황금 5개'), findsOneWidget);
    expect(find.textContaining('하루 3명, 모두 20명까지'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // DEC-153 (31번): the new game's ranking, behind its launch switch.
  testWidgets('새 홈 메뉴 온라인 랭킹: 가출시엔 없고, 스위치를 켜면 판매왕·누적 붕어빵력 두 판', (tester) async {
    await home(tester, const Size(390, 844), level: 3);
    await tester.tap(find.byKey(const Key('menu-menubar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-ranking')), findsNothing, reason: '가출시(DEC-029)');
    await tester.pumpWidget(const SizedBox.shrink());
    debugRankingLaunchedOverride = true;
    addTearDown(() => debugRankingLaunchedOverride = null);
    await home(tester, const Size(390, 844), level: 3, ranking: true);
    await tester.tap(find.byKey(const Key('menu-menubar')));
    await tester.pumpAndSettle();
    await tap(tester, 'menu-ranking');
    expect(find.byKey(const Key('ranking-tab-workshopPieces')), findsOneWidget);
    expect(find.byKey(const Key('ranking-tab-workshopLifetime')), findsOneWidget);
    expect(find.byKey(const Key('ranking-tab-bestAutoRate')), findsNothing, reason: '예전 클리커 판은 없음');
    expect(find.text('판매왕'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 5차 피드백 9 (2026-11-25): '시험용 빌드여도 + 누르면 충전 화면이 나와야'.
  testWidgets('시험용 빌드: 황금 +는 바로 주지 않고 충전 화면을 열며, 시험용 황금은 그 화면 버튼으로만', (tester) async {
    final (_, account) = await home(tester, const Size(390, 844), level: 3, testBuild: true);
    final before = account.state.premium.gold;
    expect(find.byKey(const Key('hud-gold')), findsOneWidget);
    await tap(tester, 'hud-gold');
    expect(find.byKey(const Key('gold-charge-sheet')), findsOneWidget);
    expect(find.text('황금붕어빵력 충전'), findsOneWidget);
    expect(account.state.premium.gold, before, reason: '+만 눌러서는 황금이 늘지 않음');
    await tap(tester, 'gold-charge-test-add');
    expect(account.state.premium.gold, before + 10);
    expect(tester.takeException(), isNull);
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
