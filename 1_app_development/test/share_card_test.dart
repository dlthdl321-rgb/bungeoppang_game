import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/invite_sharing.dart';
import 'package:todays_bungeoppang/share_card.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/share_card_view.dart';
import 'package:todays_bungeoppang/usage_stats.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'usage_stats_test.dart' show RecordingSink;
import 'widget_test.dart' show mountGame;

DevelopmentBalance _config() => DevelopmentBalance.fromJson(
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

/// Keeps what would have gone to the share window, or fails like it.
class _FakeSharer implements CardSharer {
  final sent = <(Uint8List, String, String)>[];
  bool fail = false;
  @override
  Future<void> sharePng(Uint8List png, {required String text, required String fileName, Rect? origin}) async {
    if (fail) throw StateError('no share window');
    sent.add((png, text, fileName));
  }
}

/// Width and height from a PNG's IHDR chunk.
(int, int) _pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

const _look = {'background': 'clear', 'decoration': 'starlights', 'lamp': 'amberlamp'};
const _cards = {
  'perfect': ShareCardData(moment: ShareMoment.perfect, title: '팥 붕어빵', speaker: '도윤',
      line: '와, 이건 사진 찍고 싶을 만큼 예뻐요!', guestArt: 'npc_doyun', variant: 2, shine: true, equipped: _look),
  'story': ShareCardData(moment: ShareMoment.story, title: '간식 지도 공개', speaker: '도윤',
      line: '여기 붕어빵집이 1등이에요!', guestArt: 'npc_doyun', equipped: _look),
  'shop': ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '따끈한 붕어빵 구워 놓고 기다릴게요!', equipped: _look),
};

void main() {
  late _FakeSharer sharer;
  setUp(() => ShareCards.sharer = sharer = _FakeSharer());
  tearDown(() => ShareCards.sharer = const SharePlusCardSharer());

  group('카드 내용', () {
    test('설정: 1080×1350, 곧 출시 문구, 스토어 주소가 공유 글에', () {
      final texts = ShareCardTexts.of(_config());
      expect((texts.width, texts.height), (1080, 1350));
      expect(texts.storeLine, '오늘의 붕어빵 · 곧 Google Play에서');
      final message = texts.message(_cards['perfect']!);
      expect(message, contains('완벽한 팥 붕어빵을 구웠어요!'));
      expect(message, endsWith('https://play.google.com/store/apps/details?id=com.todaybungeoppang.app'));
      final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
      (raw['share'] as Map)['store_line_mode'] = 'live';
      expect(ShareCardTexts.of(DevelopmentBalance.fromJson(raw)).storeLine, '오늘의 붕어빵 · Google Play에서 만나요');
    });
    test('공유 이벤트는 한국 날짜로 하루 1번', () {
      var now = DateTime.utc(2026, 11, 18, 14, 59);
      final sink = RecordingSink(), usage = UsageStats(sink, now: () => now);
      usage.record(UsageEvent.share, {'moment': 'shop'});
      usage.record(UsageEvent.share, {'moment': 'perfect'});
      now = now.add(const Duration(minutes: 1));
      usage.record(UsageEvent.share, {'moment': 'perfect'});
      expect(sink.lines, ['share {moment: shop}', 'share {moment: perfect}']);
    });
  });

  group('카드 그림', () {
    for (final entry in _cards.entries) {
      testWidgets('골든 축소본 ${entry.key}', (tester) async {
        await tester.runAsync(PixelSprites.load);
        await tester.binding.setSurfaceSize(ShareCardView.size);
        tester.view.devicePixelRatio = 1;
        addTearDown(() async {
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false,
            home: ShareCardView(key: const Key('card'), data: entry.value, texts: ShareCardTexts.of(_config()))));
        await tester.pump();
        await expectLater(find.byKey(const Key('card')), matchesGoldenFile('goldens/share_card_${entry.key}_360x450.png'));
      });
    }
  });

  group('가게 화면에서 공유', () {
    Future<(WorkshopController, RecordingSink)> mount(WidgetTester tester, {void Function(WorkshopController)? setup}) async {
      final account = await mountGame(tester, const Size(390, 844), reduced: true);
      final sink = RecordingSink();
      final now = DateTime.utc(2026, 11, 2, 3);
      final c = WorkshopController(_config(), MemoryRepository(), now: () => now, random: Random(2),
          monotonicMs: () => 0, usage: UsageStats(sink, now: () => now));
      await c.initialize();
      await c.openBusiness();
      expect(await c.command(() {
        c.state.tutorial = 'done';
        c.state.level = 5;
        c.state.claimedLevels..clear()..addAll([2, 3, 4, 5]);
        c.state.featureIntros.addAll(['skills', 'griddle', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'freshness']);
        c.state.relationships = c.state.relationships.visit('known-doyun', 'npc_doyun', 1, c.customerCatalog);
      }), isTrue, reason: c.error ?? c.notice);
      // Shown only, never saved (a real 도감 needs the result ledger).
      setup?.call(c);
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();
      return (c, sink);
    }

    Future<void> openPhoto(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
      // 26번 3차 H42: '배경 테마' is back in the menu, so scroll to it.
      await tester.ensureVisible(find.byKey(const Key('menu-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('share-card-dialog')), findsOneWidget);
    }

    Future<void> send(WidgetTester tester) async {
      final count = sharer.sent.length;
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('share-card-send')));
        await tester.pump();
        bool busy() => tester.widget<CozyPrimaryButton>(find.byKey(const Key('share-card-send'))).onPressed == null;
        for (var i = 0; i < 40 && find.byKey(const Key('share-card-send')).evaluate().isNotEmpty &&
            sharer.sent.length == count && busy(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
    }

    testWidgets('메뉴 가게 사진: 1080×1350 그림 + 스토어 글, 보상 없음, 이벤트 하루 1번', (tester) async {
      final (c, sink) = await mount(tester);
      await openPhoto(tester);
      final before = (c.state.buns, c.state.lifetime, c.state.level, c.state.taps, c.state.completedSales);
      expect(find.byKey(const Key('share-card-badge')), findsOneWidget);
      // No owner name, level or currency on the card.
      final words = tester.widgetList<Text>(find.descendant(of: find.byKey(const Key('share-card')), matching: find.byType(Text)))
          .map((t) => t.data ?? '').join(' ');
      expect(words, isNot(contains('Lv.')));
      expect(words, isNot(contains('${c.state.buns}')));
      expect(words, isNot(contains('사장님')));
      await send(tester);
      expect(sharer.sent, hasLength(1));
      final (png, text, fileName) = sharer.sent.single;
      expect(_pngSize(png), (1080, 1350));
      expect(text, contains('우리 붕어빵 가게에 놀러 오세요!'));
      expect(text, contains('play.google.com'));
      expect(fileName, 'todays_bungeoppang_shop.png');
      expect(find.byKey(const Key('share-card-dialog')), findsNothing);
      expect((c.state.buns, c.state.lifetime, c.state.level, c.state.taps, c.state.completedSales), before,
          reason: '공유는 아무것도 바꾸지 않는다(보상 없음)');
      await openPhoto(tester);
      await send(tester);
      expect(sharer.sent, hasLength(2));
      expect(sink.lines.where((l) => l.startsWith('share')).toList(), ['share {moment: shop}']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('공유 창이 안 열리면 안내하고 카드는 그대로, 상태·이벤트 없음', (tester) async {
      final (c, sink) = await mount(tester);
      sharer.fail = true;
      await openPhoto(tester);
      final before = jsonEncode(c.state.toJson());
      await send(tester);
      expect(find.text(ShareCards.failedText), findsOneWidget);
      expect(find.byKey(const Key('share-card-dialog')), findsOneWidget);
      expect(jsonEncode(c.state.toJson()), before);
      expect(sink.names, isNot(contains('share')));
      sharer.fail = false;
      await send(tester);
      expect(sharer.sent, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('완벽 결과에만 자랑하기: 맛·손님 반응이 카드에', (tester) async {
      final (c, _) = await mount(tester);
      await c.command(() => c.state.customers.add(CustomerOrder(
          id: 'order', remainingMs: 100000, lines: [CustomerOrderLine(flavor: 'redbean', quantity: 1)])));
      expect(await c.startOrderProduction('order', 'redbean'), isTrue, reason: c.error ?? c.notice);
      var s = c.state.session!;
      s = s.pour(s.token, PaintAmount.even);
      s = s.squeezeFilling(s.token, PaintAmount.even);
      s = s.pour(s.token, PaintAmount.even);
      s = s.close(s.token);
      final flipped = s.flip(s.token);
      await c.command(() {
        c.state.session = flipped;
        c.state.phaseMs = 15000;
      });
      expect(await c.cookingCommand(flipped.takeOut(flipped.token, 15000)), isTrue);
      expect(cookingGrade(c.config, c.state.session!, difficulty: c.difficulty('redbean')), CookingGrade.perfect);
      await tester.pump();
      expect(find.byKey(const Key('mold-share')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mold-share')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('share-card-title'))).data, '팥 붕어빵');
      // The proud pose (26번 3차 AV) holds its own bungeoppang.
      expect(find.byKey(const Key('share-card-fish')),
          avatarV2ProudReady('girl', 'skin1') ? findsNothing : findsOneWidget);
      expect(find.byKey(const Key('share-card-badge')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('share-card-line'))).data, contains(': "'));
      expect(find.byKey(const Key('share-card-guest')), findsOneWidget);
      await tester.tap(find.byKey(const Key('share-card-close')));
      await tester.pumpAndSettle();
      // Once the result is closed the button goes with it.
      expect(await c.storeResult(true), isTrue);
      await tester.pump();
      expect(find.byKey(const Key('mold-share')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('이야기 장면 끝과 도감 완성에서 자랑하기', (tester) async {
      late FlavorMasteryProgress original;
      final (c, _) = await mount(tester, setup: (c) {
        original = c.state.flavorMasteries['redbean']!;
        c.state.flavorMasteries['redbean'] = FlavorMasteryProgress(flavor: 'redbean',
            difficulty: c.state.flavorMasteries['redbean']!.difficulty, discovered: {0, 1, 2, 3, 4});
      });
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-collection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-share-redbean')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('share-card-title'))).data, '팥 붕어빵 도감');
      expect(find.text('도감 완성'), findsOneWidget);
      await tester.tap(find.byKey(const Key('share-card-close')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byKey(const Key('collection-share-redbean')))).pop();
      await tester.pumpAndSettle();
      c.state.flavorMasteries['redbean'] = original;
      await c.command(() => c.state.customerScene = {'kind': 'story', 'id': 'story_doyun_01', 'npc': 'npc_doyun'});
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('story-share')), findsOneWidget);
      await tester.tap(find.byKey(const Key('story-share')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('share-card-title'))).data, '간식 지도 공개');
      expect(find.byKey(const Key('share-card-guest')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
