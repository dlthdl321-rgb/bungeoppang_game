// 26번 4차 녹화 피드백 g3 묶음(IA5 손님 말풍선·IB2 6구 잠금 안내·카운터 버튼 정리) 확인용 화면(한글 글꼴).
// flutter test tools/preview_i4_g3_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after
// 글꼴은 앱에 넣지 않는다. 결과: build/preview/i4_g3/<TAG>_<이름>_<크기>.png (화면 크기 2배)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import '../test/step02_controller_test.dart' show MemoryRepository;
import '../test/test_support.dart' show mountGame;
import '../test/workshop_controller_test.dart' show Gateway;

const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');

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
    final size = view.size;
    await tester.runAsync(() async {
      final image = await layer.toImage(Offset.zero & size, pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/preview/i4_g3/${tag}_${name}_${size.width.toInt()}x${size.height.toInt()}.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  var mono = 0;
  Future<WorkshopController> open(WidgetTester tester, Size size) async {
    WeatherLayer.animate = false;
    WorkshopStatusBadge.animate = false;
    mono = 0;
    final online = FakeOnlineBackend(products: const {}, prices: const {})..signedIn = true;
    final account = await mountGame(tester, size, reduced: true, online: online);
    await fonts(tester);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final c = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway(),
        now: () => DateTime.utc(2026, 11, 2, 3), monotonicMs: () => mono);
    await c.initialize();
    await c.openBusiness();
    await c.command(() {
      c.state.tutorial = 'done';
      c.state.level = 3;
      c.state.buns = BigInt.from(1668);
      c.state.lifetime = BigInt.from(1668);
      c.state.claimedLevels..clear()..addAll([2, 3]);
      c.state.featureIntros.addAll(['skills', 'pantry', 'griddle', 'collection', 'recipes', 'specialOrders',
        'fishCosmetics', 'freshness', 'stallCosmetics'].where(workshopIntroIds.contains));
    });
    expect(c.error, isNull);
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    return c;
  }

  Future<void> stock(WorkshopController c, int n) => c.command(() => c.state.inventory = c.state.inventory.recordResult(
      ProductBatch(id: 'one', flavor: 'redbean', variant: 2, quantity: n, madeOnBusinessIndex: c.state.business.businessIndex),
      keep: true));

  CustomerOrder guest(String id, String who, int qty, {int ms = 100000}) =>
      CustomerOrder(id: id, customerId: who, remainingMs: ms, lines: [CustomerOrderLine(flavor: 'redbean', quantity: qty)]);

  for (final size in const [Size(390, 844), Size(360, 800), Size(360, 640)]) {
    // The recording's scene: 도윤 runs out of time while a walk-in waits.
    testWidgets('시간 초과 대사 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      await c.command(() {
        c.state.relationships = c.state.relationships.visit('d', 'npc_doyun', c.state.business.businessIndex, c.customerCatalog);
      });
      await c.command(() => c.state.customers
        ..add(guest('d', 'npc_doyun', 1, ms: 200))
        ..add(guest('w', 'anonymous_first', 1))
        ..add(guest('w2', 'anonymous_second', 2)));
      mono += 300;
      await c.command(() {});
      await tester.pump();
      // ignore: avoid_print
      print('timeout error: ${c.error} notice: ${c.notice}');
      await shot(tester, 'timeout');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    // Words stay while the guest is there (사용자 답 2026-11-21): a walk-in
    // in line still has their words about an order bake when 도윤 leaves.
    testWidgets('여러 말풍선 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      await c.command(() {
        c.state.relationships = c.state.relationships.visit('d', 'npc_doyun', c.state.business.businessIndex, c.customerCatalog);
      });
      await c.command(() => c.state.customers
        ..add(guest('d', 'npc_doyun', 1, ms: 200))
        ..add(guest('w', 'anonymous_first', 1))
        ..add(guest('w2', 'anonymous_second', 2)));
      c.guestWords['anonymous_first'] = (order: 'w', text: '와, 이건 사진 찍고 싶을 만큼 예뻐요!');
      c.guestWords['anonymous_second'] = (order: 'w2', text: '제 것 나오면 알려주세요.');
      mono += 300;
      await c.command(() {});
      await tester.pump();
      await shot(tester, 'many');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('주문 제작 필요 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      await c.command(() => c.state.customers
        ..add(guest('w', 'anonymous_first', 1))
        ..add(guest('w2', 'anonymous_second', 2)));
      await tester.pump();
      await shot(tester, 'produce');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('판매 가능 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      await stock(c, 1);
      await c.command(() => c.state.customers
        ..add(guest('w', 'anonymous_first', 1))
        ..add(guest('w2', 'anonymous_second', 2)));
      await tester.pump();
      await shot(tester, 'sell');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('판매 뒤 대사 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      await stock(c, 1);
      await c.command(() => c.state.customers.add(guest('w', 'anonymous_first', 1)));
      expect(await c.sellToCustomer('w'), isTrue);
      await tester.pump();
      await shot(tester, 'sold');
      mono += 4000;
      await c.command(() {});
      await tester.pump();
      await shot(tester, 'sold_later');
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('태오 사진 반응 ${size.width}x${size.height}', (tester) async {
      final c = await open(tester, size);
      // The visit can be refused now and then (random arrival rules): try a few times.
      var welcomed = false;
      for (var i = 0; i < 5 && !welcomed; i++) {
        welcomed = await c.welcomeCustomer(visitor: 'npc_taeo');
      }
      if (!welcomed) return;
      final order = c.state.customers.single;
      await c.command(() => c.state.inventory = c.state.inventory.recordResult(ProductBatch(
          id: 'taeo', flavor: order.lines.single.flavor, variant: 2, quantity: order.lines.single.quantity,
          madeOnBusinessIndex: c.state.business.businessIndex), keep: true));
      await c.command(() => c.state.customers.add(guest('w', 'anonymous_first', 1)));
      // A random first-visit scene can hold the sale: then no picture.
      final sold = await c.sellToCustomer(order.id);
      await tester.pump();
      if (sold && c.photoReactionSale != null) await shot(tester, 'photo');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
