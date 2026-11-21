// 26번 4차 g15 미리보기(한글 글꼴): 스킬 창(돌림판 MAX·아이콘 선명도·붕어빵력/황금 아이콘 크기),
// 결과 등급 다섯 개(보통 추가), 꾸미기 배경 탭(파는 것 없는 화로·장식 숨김).
// flutter test tools/preview_i4_g15_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 화면 배율은 휴대폰처럼 3(PREVIEW_DPR)로 그린다. 글꼴은 앱에 넣지 않는다.
// 결과: build/preview/i4_g15/<태그>_<이름>.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/cooking_result_effects.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/widget_test.dart' show mountGame;
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';

/// Keeps every receipt (the shared test Gateway reuses one).
class _Gateway implements WorkshopPurchaseGateway {
  final _receipts = <String, Map<String, dynamic>>{};
  @override
  String get authenticatedAccount => 'account';
  @override
  Future<void> requireActiveProgress(String progressId) async {}
  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent) async =>
      _receipts[intent.transactionId] = {...intent.toJson(), 'status': 'reserved'};
  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal intent) async => _receipts[intent.transactionId] =
      {...intent.toJson(), 'status': 'committed', 'receiptId': 'r-${intent.transactionId}', 'grantId': 'g-${intent.transactionId}'};
  @override
  Future<Map<String, dynamic>> query(String accountId, String transactionId) async =>
      _receipts[transactionId] ?? {'account': accountId, 'transaction': transactionId, 'status': 'unknown'};
  @override
  Future<Map<String, dynamic>> cancel(String accountId, String transactionId) async => throw UnimplementedError();
}

const _dpr = int.fromEnvironment('PREVIEW_DPR', defaultValue: 3) * 1.0;
const _tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');

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
      // The root layer already scales by the view's pixel ratio.
      final image = await layer.toImage(Offset.zero & (view.size * _dpr));
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/i4_g15/${_tag}_$name.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkshopController> open(WidgetTester tester, Size size, {required int level, required BigInt buns}) async {
    WeatherLayer.animate = false;
    final online = FakeOnlineBackend(products: const {}, prices: const {})
      ..signedIn = true
      ..gold = 40;
    final account = await mountGame(tester, size, reduced: true, online: online);
    tester.view.devicePixelRatio = _dpr;
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final gateway = _Gateway();
    final c = WorkshopController(config, MemoryRepository(), purchaseGateway: gateway,
        now: () => DateTime.utc(2026, 11, 2, 3), monotonicMs: () => 0);
    await tester.runAsync(() async {
      await c.initialize();
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = level;
        c.state.claimedLevels..clear()..addAll([for (var l = 2; l <= level; l++) l]);
        c.state.featureIntros.addAll(workshopIntroIds);
        c.state.lifetime = buns * BigInt.two;
        c.state.buns = buns;
      });
      for (final e in {'tap_1': 40, 'tap_2': 25, 'tap_3': 12, 'tap_4': 6, 'auto_1': 30, 'auto_2': 18, 'auto_3': 8}.entries) {
        await c.purchaseSkill(gateway, e.key, quantity: e.value);
      }
    });
    c.skillSteps['tap_2'] = skillLevelUpMax;
    c.skillSteps['auto_2'] = skillLevelUpMax;
    c.skillSteps['tap_3'] = 10;
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final s = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('스킬 창 $s', (tester) async {
      await open(tester, size, level: 16, buns: BigInt.from(1500000));
      await tapKey(tester, 'menu-skills');
      await shot(tester, 'skills_tap_$s');
      await tapKey(tester, 'kind-auto');
      await shot(tester, 'skills_auto_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('꾸미기 배경 탭 $s', (tester) async {
      await open(tester, size, level: 9, buns: BigInt.from(5000000));
      await tapKey(tester, 'menu-skins');
      await shot(tester, 'wardrobe_tabs_$s');
      if (find.byKey(const Key('cosmetic-category-stall')).evaluate().isNotEmpty) {
        await tapKey(tester, 'cosmetic-category-stall');
      }
      await shot(tester, 'wardrobe_stall_$s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('결과 등급 띠 다섯 개 390', (tester) async {
    await mountGame(tester, const Size(390, 844), reduced: true);
    tester.view.devicePixelRatio = _dpr;
    await fonts(tester);
    const lines = {
      'perfect': '겉은 바삭, 속은 촉촉!',
      'good': '알맞게 잘 익었어요',
      'fair': '반죽이 조금 많았어요',
      'near': '반죽이 조금 모자랐어요',
      'fail': '타버렸어요',
    };
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: const Color(0xff8a6a4f),
            body: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final g in CookingGrade.values)
                SizedBox(
                    height: 150,
                    width: 390,
                    child: Align(
                        alignment: const Alignment(0, 1),
                        child: SizedBox(
                            height: 90,
                            child: CookingResultView(
                                sessionId: 'preview-${g.name}',
                                grade: g,
                                line: lines[g.name]!,
                                reduceMotion: true)))),
            ]))));
    await tester.pumpAndSettle();
    await shot(tester, 'result_grades_390x844');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
