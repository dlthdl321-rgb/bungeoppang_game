import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart' show FlavorMasteryProgress;
import 'package:todays_bungeoppang/pantry_rules.dart';
import 'package:todays_bungeoppang/prep_minigames.dart';
import 'package:todays_bungeoppang/ui/center_toast.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/currency_amount.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/pantry_window.dart';
import 'package:todays_bungeoppang/ui/prep_minigames.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_pantry_prep.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'test_support.dart' show setUpAccount;

/// 재료 타이쿤 D — '재료 준비' 창과 미니게임 화면: 탭(얻은 레시피만), 보관 막대·버리는 시각,
/// 필요한 재료(모자라면 빨강), 모자란 재료 한 번에 사기, 만들기 → 미니게임 3종 성공(덤)·실패(덤 없음),
/// 그만두기(아무것도 안 줆), 화면 읽기 '보통으로 만들기', 특제, 진동, 영업 중엔 안내만.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final pc = PantryConfig.of(config);
  final t0 = DateTime.utc(2026, 11, 21, 3);

  final live = <WorkshopController>[];
  void pantryTest(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          for (final c in live) {
            if (!c.disposed) c.dispose();
          }
          live.clear();
        }
      });

  /// A recipe owned the way the mission gives it (the save checks it).
  void addRecipes(WorkshopController c, List<String> flavors) {
    for (final f in flavors) {
      c.state.recipes.add(f);
      c.state.recipeMissions.add(f);
      c.state.flavorMasteries[f] = FlavorMasteryProgress(flavor: f, difficulty: c.difficulty(f));
    }
  }
  void setBuns(WorkshopController c, int buns) {
    c.state.buns = BigInt.from(buns);
    if (c.state.lifetime < c.state.buns) c.state.lifetime = c.state.buns;
  }
  void setLevel(WorkshopController c, int level) {
    c.state.level = level;
    c.state.claimedLevels..clear()..addAll([for (var i = 2; i <= level; i++) i]);
  }

  Future<WorkshopController> controller({void Function(WorkshopController c)? setup}) async {
    final c = WorkshopController(config, MemoryRepository(), now: () => t0, monotonicMs: () => 0);
    live.add(c);
    await c.initialize();
    expect(await c.command(() {
      c.state.tutorial = 'done';
      setup?.call(c);
    }), isTrue, reason: c.notice ?? c.error);
    return c;
  }

  Future<WorkshopController> open(WidgetTester tester, {void Function(WorkshopController c)? setup,
      bool vibration = false, Size size = const Size(390, 844)}) async {
    await tester.binding.setSurfaceSize(size);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    final c = await controller(setup: setup);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AnimatedBuilder(animation: c,
        builder: (_, __) => PantryWindow(controller: c, vibration: vibration)))));
    await tester.pump();
    return c;
  }

  int nowMs() => t0.millisecondsSinceEpoch;
  String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('pantry-stock-count'))).data!;
  PrepGameScreenState screen(WidgetTester tester) => tester.state<PrepGameScreenState>(find.byType(PrepGameScreen));

  Future<void> start(WidgetTester tester, {String kind = 'batter', int tubs = 1}) async {
    if (kind != 'batter') await tester.tap(find.byKey(Key('pantry-tab-$kind')));
    await tester.pump();
    if (tubs != 1) await tester.tap(find.byKey(Key('pantry-tubs-$tubs')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('pantry-make')));
    await tester.tap(find.byKey(const Key('pantry-make')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byType(PrepGameScreen), findsOneWidget);
  }

  /// Waits for the save and the result, then '확인'.
  Future<String> finish(WidgetTester tester) async {
    for (var i = 0; i < 10 && find.byKey(const Key('prep-result-ok')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final heading = tester.widget<Text>(find.byKey(const Key('prep-result-heading'))).data!;
    await tester.tap(find.byKey(const Key('prep-result-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PrepGameScreen), findsNothing);
    return heading;
  }

  /// Circles [degrees] round the bowl, then lifts the finger.
  Future<void> stir(WidgetTester tester, double degrees) async {
    final box = tester.getRect(find.byKey(const Key('prep-game-area')));
    final r = math.min(box.width, box.height) * .3;
    Offset at(double a) => box.center + Offset(math.sin(a * math.pi / 180), -math.cos(a * math.pi / 180)) * r;
    final g = await tester.startGesture(at(0));
    for (var a = 10.0; a <= degrees; a += 10) {
      await g.moveTo(at(a));
    }
    await tester.pump();
    await g.up();
    await tester.pump();
  }

  group('창', () {
    pantryTest('탭은 반죽과 얻은 레시피의 속만, 보관 막대와 버리는 시각', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('pantry-tab-batter')), findsOneWidget);
      expect(find.byKey(const Key('pantry-tab-redbean')), findsOneWidget);
      expect(find.byKey(const Key('pantry-tab-custard')), findsNothing);
      expect(find.byKey(const Key('pantry-tab-cocoa')), findsNothing);
      expect(count(tester), '3통 / 10통');
      // 4차 병합 3: the starting stock never goes off (묶음 B·E 사용자 결정).
      expect(tester.widget<Text>(find.byKey(const Key('pantry-expiry'))).data, '처음 받은 통은 상하지 않아요.');
      expect(find.text('반죽 젓기 미니게임을 하면 만들어요.\n잘하면 1통에 덤 10인분, 못해도 통은 그대로 만들어져요.'), findsOneWidget);
    });

    pantryTest('레시피를 얻으면 슈크림·초코 탭, 초코 크림은 \'초코\'', (tester) async {
      await open(tester, setup: (c) => addRecipes(c, ['custard', 'cocoa']));
      expect(find.byKey(const Key('pantry-tab-custard')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('pantry-tabs')), matching: find.text('초코')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pantry-tab-cocoa')));
      await tester.pump();
      expect(count(tester), '0통 / 10통');
      expect(tester.widget<Text>(find.byKey(const Key('pantry-expiry'))).data, '만든 초코 크림이 없어요.');
    });

    pantryTest('모자란 재료는 빨강, 한 번에 사면 붕어빵력이 줄고 만들 수 있음', (tester) async {
      final c = await open(tester, setup: (c) => setBuns(c, 100000));
      await tester.tap(find.byKey(const Key('pantry-tubs-3')));
      await tester.pump();
      // 처음 재료는 1통분: 밀가루 2개뿐 → 3통엔 6개가 필요.
      final have = tester.widget<Text>(find.byKey(const Key('pantry-have-flour')));
      expect(have.textSpan!.toPlainText(), '2 / 6');
      expect((have.textSpan! as TextSpan).children!.first.style!.color, CurrencyAmount.missingColor);
      expect(tester.widget<CozyPrimaryButton>(find.byKey(const Key('pantry-make'))).onPressed, isNull);
      final cost = c.prepShortfallCost('batter', 3);
      expect(cost, greaterThan(BigInt.zero));
      await tester.ensureVisible(find.byKey(const Key('pantry-buy-short')));
      await tester.tap(find.byKey(const Key('pantry-buy-short')));
      await tester.pump();
      await tester.pump();
      expect(c.state.buns, BigInt.from(100000) - cost);
      expect(c.state.pantry.shortfall(pc, 'batter', 3), isEmpty);
      expect(find.byKey(const Key('pantry-buy-short')), findsNothing);
      expect(tester.widget<CozyPrimaryButton>(find.byKey(const Key('pantry-make'))).onPressed, isNotNull);
    });

    pantryTest('붕어빵력이 모자라면 사기 버튼이 꺼지고 까닭을 보여 줌', (tester) async {
      await open(tester, setup: (c) {
        c.state.buns = BigInt.zero;
        c.state.pantry.basic.clear();
      });
      expect(find.byKey(const Key('pantry-short')), findsOneWidget);
      expect(find.text('재료가 모자라요. 붕어빵력도 모자라서 지금은 살 수 없어요.'), findsOneWidget);
      expect(tester.widget<CozyButton>(find.byKey(const Key('pantry-buy-short'))).onPressed, isNull);
    });

    pantryTest('보관 한도가 차면 까닭', (tester) async {
      await open(tester, setup: (c) {
        c.state.pantry.basic.addAll({'flour': 20, 'milk': 20, 'egg': 20, 'sugar': 20, 'salt': 20});
        for (var i = 0; i < 2; i++) {
          c.state.pantry.make(pc, 'batter', 3, 1, nowMs(), c.state.recipes);
        }
      });
      await tester.tap(find.byKey(const Key('pantry-tubs-3')));
      await tester.pump();
      expect(find.text('반죽은 10통까지 보관할 수 있어요.'), findsOneWidget);
    });
  });

  group('미니게임', () {
    pantryTest('반죽 젓기: 초록 칸에서 손을 떼면 성공(1통당 덤 10인분)', (tester) async {
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'batter', nowMs());
      await start(tester);
      expect(find.text('반죽 젓기'), findsOneWidget);
      await stir(tester, 1150);
      expect(screen(tester).game!.phase, PrepPhase.success);
      expect(await finish(tester), '딱 좋아요!');
      expect(c.state.pantry.usable(pc, 'batter', nowMs()), before + 110);
      expect(count(tester), '4통 10인분 / 10통');
      expect(c.state.pantry.shortfall(pc, 'batter', 1), isNotEmpty); // 재료를 썼음
    });

    pantryTest('반죽 젓기: 덜 저으면 실패지만 재료는 그대로 100인분', (tester) async {
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'batter', nowMs());
      await start(tester);
      await stir(tester, 300);
      await tester.pump(const Duration(seconds: 9));
      expect(await finish(tester), '덜 저었어요');
      expect(c.state.pantry.usable(pc, 'batter', nowMs()), before + 100);
    });

    pantryTest('반죽 젓기: 너무 저으면 조금 묽어요', (tester) async {
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'batter', nowMs());
      await start(tester);
      await stir(tester, 1400);
      expect(await finish(tester), '조금 묽어요');
      expect(c.state.pantry.usable(pc, 'batter', nowMs()), before + 100);
    });

    pantryTest('불 조절(팥소): 누르고 떼며 초록 칸에 두면 성공', (tester) async {
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'redbean', nowMs());
      await start(tester, kind: 'redbean');
      expect(find.text('불 조절'), findsOneWidget);
      final area = tester.getCenter(find.byKey(const Key('prep-game-area')));
      TestGesture? finger;
      for (var t = 0; t < 10400; t += 100) {
        final game = screen(tester).game;
        if (game == null || !game.playing) break;
        final want = (game as HeatGame).level < .57;
        if (want && finger == null) {
          finger = await tester.startGesture(area);
        } else if (!want && finger != null) {
          await finger.up();
          finger = null;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await finger?.up();
      expect(await finish(tester), '딱 좋아요!');
      expect(c.state.pantry.usable(pc, 'redbean', nowMs()), before + 110);
    });

    pantryTest('불 조절: 그냥 두면 실패(100인분)', (tester) async {
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'redbean', nowMs());
      await start(tester, kind: 'redbean');
      await tester.pump(const Duration(seconds: 11));
      expect(await finish(tester), '불이 고르지 않았어요');
      expect(c.state.pantry.usable(pc, 'redbean', nowMs()), before + 100);
    });

    pantryTest('불 조절(초코): 누르고 있는 동안 센 불', (tester) async {
      await open(tester, setup: (c) {
        addRecipes(c, ['cocoa']);
        c.state.pantry.basic.addAll({'cocoa_powder': 2, 'milk': 1, 'sugar': 1});
      });
      await start(tester, kind: 'cocoa');
      final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('prep-game-area'))));
      await tester.pump(const Duration(milliseconds: 100));
      expect((screen(tester).game! as HeatGame).holding, isTrue);
      await g.up();
      await tester.pump();
      expect((screen(tester).game! as HeatGame).holding, isFalse);
      await tester.tap(find.byKey(const Key('prep-game-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    Future<WorkshopController> custard(WidgetTester tester) => open(tester, setup: (c) {
          addRecipes(c, ['custard']);
          c.state.pantry.basic.addAll({'milk': 2, 'egg': 2, 'sugar': 1});
        });

    pantryTest('휘젓기(슈크림): 좌우로 빠르게 문지르면 성공', (tester) async {
      final c = await custard(tester);
      await start(tester, kind: 'custard');
      expect(find.text('휘젓기'), findsOneWidget);
      final box = tester.getRect(find.byKey(const Key('prep-game-area')));
      final g = await tester.startGesture(box.center);
      for (var i = 0; i < 30 && screen(tester).game!.playing; i++) {
        final x = box.center.dx + (i.isEven ? 70 : -70);
        for (var k = 0; k < 4; k++) {
          await g.moveTo(Offset(box.center.dx + (x - box.center.dx) * (k + 1) / 4, box.center.dy));
        }
        await tester.pump(const Duration(milliseconds: 60));
      }
      await g.up();
      expect(await finish(tester), '딱 좋아요!');
      expect(c.state.pantry.usable(pc, 'custard', nowMs()), 110);
    });

    pantryTest('휘젓기: 시간 안에 못 채우면 실패(100인분)', (tester) async {
      final c = await custard(tester);
      await start(tester, kind: 'custard');
      await tester.pump(const Duration(seconds: 7));
      expect(await finish(tester), '거품이 덜 올랐어요');
      expect(c.state.pantry.usable(pc, 'custard', nowMs()), 100);
    });

    pantryTest('그만두기는 아무것도 줄지 않음', (tester) async {
      final c = await open(tester);
      final saved = jsonEncode(c.state.pantry.toJson());
      await start(tester);
      await stir(tester, 500);
      await tester.tap(find.byKey(const Key('prep-game-quit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PrepGameScreen), findsNothing);
      expect(jsonEncode(c.state.pantry.toJson()), saved);
    });

    pantryTest('앱을 나가면 그만두기와 같음', (tester) async {
      final c = await open(tester);
      final saved = jsonEncode(c.state.pantry.toJson());
      await start(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // Frames run again once back (the pop was asked while away).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PrepGameScreen), findsNothing);
      expect(jsonEncode(c.state.pantry.toJson()), saved);
    });

    pantryTest('화면 읽기: 두 번 눌러 보통으로 만들기(덤 없음)', (tester) async {
      final c = await open(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(accessibleNavigation: true);
      final before = c.state.pantry.usable(pc, 'batter', nowMs());
      await start(tester);
      expect(find.byKey(const Key('prep-game-area')), findsNothing);
      await tester.pump(const Duration(seconds: 20)); // 시간이 흐르지 않음
      expect(find.byKey(const Key('prep-result-ok')), findsNothing);
      await tester.tap(find.byKey(const Key('prep-game-normal')));
      await tester.pump();
      expect(await finish(tester), '보통으로 만들었어요');
      expect(c.state.pantry.usable(pc, 'batter', nowMs()), before + 100);
    });

    pantryTest('게임 칸의 화면 읽기 동작도 보통으로 만들기', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester);
      final before = c.state.pantry.usable(pc, 'batter', nowMs());
      await start(tester);
      expect(find.bySemanticsLabel('보통으로 만들기'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('보통으로 만들기'));
      await tester.pump();
      expect(await finish(tester), '보통으로 만들었어요');
      expect(c.state.pantry.usable(pc, 'batter', nowMs()), before + 100);
      handle.dispose();
    });

    pantryTest('특제: 특별한 재료가 있을 때만 고르고, 1통에 1개 씀', (tester) async {
      final c = await open(tester, setup: (c) {
        setLevel(c, 5);
        c.state.pantry.premium['cultured_butter'] = 2;
      });
      expect(find.byKey(const Key('pantry-premium')), findsOneWidget);
      expect(find.text('특제 반죽으로 만들기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pantry-tab-redbean')));
      await tester.pump();
      expect(find.byKey(const Key('pantry-premium')), findsNothing); // 국산 햇팥 없음
      await tester.tap(find.byKey(const Key('pantry-tab-batter')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('pantry-premium')));
      await tester.tap(find.byKey(const Key('pantry-premium')));
      await tester.pump();
      expect(find.byKey(const Key('pantry-need-cultured_butter')), findsOneWidget);
      await start(tester);
      expect(find.text('특제 반죽 1통'), findsOneWidget);
      await stir(tester, 1150);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('prep-result-text'))).data, '특제 반죽 1통을 만들었어요. 덤 10인분도 더 들어갔어요.');
      await finish(tester);
      expect(c.state.pantry.premium['cultured_butter'], 1);
      expect(c.state.pantry.portions('batter', premium: true), 110);
    });

    pantryTest('진동 설정이면 결과에 진동, 아니면 없음', (tester) async {
      for (final on in [true, false]) {
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
          return null;
        });
        await open(tester, vibration: on);
        await start(tester);
        await stir(tester, 1150);
        await finish(tester);
        expect(calls.contains('HapticFeedbackType.mediumImpact'), on);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      }
    });

    pantryTest('작은 화면(360×800)에서도 넘치지 않음', (tester) async {
      await open(tester, size: const Size(360, 800), setup: (c) {
        setLevel(c, 5);
        addRecipes(c, ['custard', 'cocoa']);
        c.state.pantry.premium['cultured_butter'] = 1;
      });
      expect(tester.takeException(), isNull);
      await start(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('들어가는 곳', () {
    pantryTest('영업 중이면 창 대신 까닭, 영업 준비 중이면 창', (tester) async {
      final account = await setUpAccount(tester, const Size(390, 844), reduced: true);
      // Lv.2: 재료 준비 opens with `pantry_prep` (묶음 E, 4차 병합 3).
      final c = await controller(setup: (c) => c..state.level = 2 ..state.claimedLevels.add(2));
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      await c.openBusiness();
      await tester.pump();
      tester.widget<NightHome>(find.byType(NightHome)).onOpen('pantry');
      await tester.pump();
      expect(CenterToast.current, pantryPrepClosedText);
      expect(find.byType(PantryWindow), findsNothing);
      expect(await c.makePrepared('batter', 1, success: true), isNull);
      expect(c.notice, pantryPrepClosedText);
      await tester.pump(const Duration(seconds: 3));
      await c.closeBusiness();
      await tester.pump();
      tester.widget<NightHome>(find.byType(NightHome)).onOpen('pantry');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PantryWindow), findsOneWidget);
      expect(find.text('재료 준비'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
