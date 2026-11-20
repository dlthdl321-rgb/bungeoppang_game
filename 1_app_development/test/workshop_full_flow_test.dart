import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_paint.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'step02_home_test.dart' show drawFlipCircle, paintMold;
import 'widget_test.dart' show mountGame;

/// 24번 7단계 통합 흐름: 새 설치 → 튜토리얼 → 영업 준비 중 스페셜 붕어빵
/// 제작(색칠·원 그리기) → 보관 → 영업 시작 → 숙련된 붕어빵 수확·판매 →
/// 영업 중 클리커 탭 → 손님 창 '주문 제작'(틀이 나왔다가 클리커로 복귀).
///
/// 화면 조작은 실제 위젯을 누르고 문지른다. 숙련(연습 8회)에 필요한 나머지
/// 7번 연습만 컨트롤러 명령으로 빠르게 채운다. 시간은 가짜 단조 시계로 넘긴다.
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final manual = config.section('manual_cooking');

  testWidgets('새 설치부터 주문 제작 뒤 클리커 복귀까지 한 흐름', (tester) async {
    final account = await mountGame(tester, const Size(390, 844), reduced: true);
    var mono = 0;
    var clock = DateTime.utc(2026, 10, 18);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => clock, random: Random(24), monotonicMs: () => mono);
    await c.initialize();
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();

    Finder key(String name) => find.byKey(Key(name));
    String tutorialText() => tester.widget<Text>(key('tutorial-text')).data!;
    Future<void> setPhaseMs(int ms) async { await c.command(() => c.state.phaseMs = ms); await tester.pump(); }
    Future<void> tapKey(String name) async {
      await tester.ensureVisible(key(name));
      await tester.tap(key(name));
      await tester.pump();
    }
    /// Lets [ms] of active time pass: the controller's 100ms tick reads the
    /// fake monotonic clock, so one pump after the jump settles it.
    Future<void> elapse(int ms) async {
      mono += ms;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
    }
    /// 26번 5-1단계: after the guide the next regular guest comes in real
    /// time, 30 s~5 min later. Move the wall clock to that arrival.
    Future<void> nextGuest() async {
      clock = DateTime.fromMillisecondsSinceEpoch(c.state.regularClock.nextAt!, isUtc: true);
      await elapse(100);
    }
    /// Bakes the open special bungeoppang in the mold through the real
    /// controls: paint three times, close, draw a circle, take out.
    Future<void> bakeOnScreen() async {
      expect(key('active-empty-mold'), findsOneWidget);
      for (final next in [CookingPhase.filling, CookingPhase.secondBatter, CookingPhase.closing]) {
        expect(find.byType(MoldPaintControl), findsOneWidget);
        await paintMold(tester);
        expect(c.state.session!.phase, next);
      }
      await setPhaseMs(DevelopmentBalance.integer(manual, 'lid_close_ms'));
      await tapKey('workshop-mold-action');
      expect(c.state.session!.phase, CookingPhase.flipping);
      expect(key('workshop-mold-action'), findsNothing, reason: '뒤집기는 버튼 없이 원 그리기');
      await setPhaseMs(DevelopmentBalance.integer(manual, 'flip_ms'));
      await drawFlipCircle(tester);
      await tester.pump(Duration(milliseconds: DevelopmentBalance.integer(manual, 'flip_ms') + 100));
      await tester.pump();
      expect(c.state.session!.phase, CookingPhase.cooking);
      await setPhaseMs(15000);
      await tapKey('workshop-mold-action');
      expect(c.state.session!.phase, CookingPhase.result);
    }

    // 1. 새 설치: 환영 이야기(26번 3차 H6, 화면 아무 곳이나 눌러 넘김) →
    // 안내 1단계, 영업 준비 중 두 틀.
    expect(key('story-overlay'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(195, 120));
      await tester.pump();
    }
    expect(key('story-overlay'), findsNothing);
    expect(c.state.tutorial, 'cook');
    expect(c.state.business.open, isFalse);
    expect(key('tutorial-card'), findsOneWidget);
    expect(tutorialText(), contains('스페셜 붕어빵 틀을 눌러'));
    expect(key('idle-mold'), findsOneWidget);
    expect(key('griddle-idle'), findsOneWidget);
    expect(key('workshop-clicker'), findsNothing);

    // 2. 영업 준비 중 스페셜 붕어빵 연습 제작(색칠·원 그리기) → 보관.
    await tapKey('workshop-mold-action');
    expect(c.state.session?.practice, isTrue);
    expect(tutorialText(), contains('문질러 반죽'));
    await bakeOnScreen();
    expect(find.text('보관하기'), findsOneWidget);
    await tapKey('mold-store');
    expect(c.state.session, isNull);
    expect(c.state.tutorial, 'sell');
    await tapKey('story-skip');
    expect(tutorialText(), contains("'영업 시작'"));

    // 숙련(익힘 5단계 발견, 연습·손기술 횟수)까지 남은 연습은 명령으로 채운다
    // (손 조작은 위에서 확인함). 꺼내는 시간을 바꿔 익힘 5단계를 모두 본다.
    const takeOutMs = [5000, 12000, 15000, 19000, 25000];
    for (var i = 0; i < 20 && !c.state.masteryAwards.containsKey('redbean'); i++) {
      expect(await c.startPractice(), isTrue);
      var s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.squeezeFilling(s.token, PaintAmount.even)), isTrue);
      s = c.state.session!;
      expect(await c.cookingCommand(s.pour(s.token, PaintAmount.even)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'lid_close_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.close(s.token)), isTrue);
      await c.command(() => c.state.phaseMs = DevelopmentBalance.integer(manual, 'flip_ms'));
      s = c.state.session!;
      expect(await c.cookingCommand(s.flip(s.token)), isTrue);
      final out = takeOutMs[i % takeOutMs.length];
      await c.command(() => c.state.phaseMs = out);
      s = c.state.session!;
      expect(await c.cookingCommand(s.takeOut(s.token, out)), isTrue);
      expect(await c.storeResult(false), isTrue);
    }
    expect(c.state.masteryAwards.containsKey('redbean'), isTrue);
    await tester.pump();

    // 3. 영업 시작: 스페셜 붕어빵 틀 대신 클리커, 숙련된 붕어빵 칸이 열림.
    await tapKey('business-open');
    expect(c.state.business.open, isTrue);
    expect(key('workshop-clicker'), findsOneWidget);
    expect(key('idle-mold'), findsNothing);
    expect(key('griddle-idle'), findsNothing);
    expect(tester.widget<InkWell>(key('workshop-cell-0')).onTap, isNotNull);

    // 4. 숙련된 붕어빵: 1번 칸 굽기 → 익으면 수확 → 재고.
    await tapKey('workshop-cell-0');
    expect(c.state.grid.cells[0].cooking, isTrue);
    await elapse(17000);
    final grade = c.state.grid.doneness(0, c.config);
    expect(grade, inInclusiveRange(1, 3), reason: '17초면 덜익음~알맞음 사이');
    final stockBefore = c.state.inventory.toJson().toString();
    await tapKey('workshop-cell-0');
    expect(c.state.grid.cells[0].cooking, isFalse);
    expect(c.state.inventory.toJson().toString(), isNot(stockBefore));

    // 첫 손님 도윤(안내 중에는 바로 입장) → 안내대로 판매.
    expect(c.state.customers, isNotEmpty);
    expect(c.state.customerScene, isNull);
    await tester.pump();
    expect(tutorialText(), contains('판매'));
    await tapKey('sale-button');
    expect(c.state.completedSales, 1);
    expect(c.state.tutorial, 'done');
    expect(key('tutorial-card'), findsNothing);
    // 26번 2단계: the first sale's praise (words, big star) for two seconds,
    // then the six-cell griddle's card once (팥 was mastered in the guide).
    expect(key('sale-praise'), findsOneWidget);
    expect(key('sale-praise-star'), findsOneWidget);
    expect(key('feature-intro-griddle'), findsNothing, reason: '칭찬이 먼저');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(key('sale-praise'), findsNothing);
    // 4차 g5: first the 꾸미기·상점·오늘 card and its short tour, then the
    // griddle's card and its one-step tour.
    expect(key('feature-intro-wardrobe'), findsOneWidget);
    await tester.tap(key('feature-intro-ok'));
    await tester.pumpAndSettle();
    await tester.tap(key('tour-skip'));
    await tester.pumpAndSettle();
    expect(key('feature-intro-griddle'), findsOneWidget);
    await tester.tap(key('feature-intro-ok'));
    await tester.pumpAndSettle();
    expect(c.state.featureIntros, contains('griddle'));
    expect(key('tour-next'), findsOneWidget);
    await tester.tap(key('tour-next'));
    await tester.pumpAndSettle();
    expect(key('tutorial-card'), findsNothing);

    // 둘째 손님에게는 남은 재고(보관한 연습 붕어빵과 수확분 중 남은 1개)를 판다.
    await nextGuest();
    expect(c.state.customers, hasLength(1));
    expect(c.state.customerScene, isNull);
    expect(c.saleReadyCount(c.state.customers.first), 1);
    await tapKey('sale-button');
    expect(c.state.completedSales, 2);
    expect(c.state.customers, isEmpty);

    // 5. 영업 중 클리커 탭.
    final buns = c.state.buns, taps = c.state.taps;
    await tapKey('workshop-clicker');
    expect(c.state.taps, taps + 1);
    expect(c.state.buns, greaterThanOrEqualTo(buns + c.tapRate));

    // 6. 손님 창 '주문 제작': 틀이 나왔다가 결과를 닫으면 클리커로 돌아옴.
    await nextGuest();
    expect(c.state.customers, hasLength(1));
    expect(c.saleReadyCount(c.state.customers.first), 0, reason: '재고가 없어 주문 제작이 필요');
    expect(c.state.customerScene, isNull);
    final orderId = c.state.customers.first.id;
    await tapKey('customer-0');
    await tester.pump(const Duration(milliseconds: 400));
    expect(key('customer-card'), findsOneWidget);
    await tester.tap(key('customer-produce-redbean'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(key('customer-card'), findsNothing);
    expect(c.state.session?.practice, isFalse);
    expect(key('workshop-clicker'), findsNothing);
    expect(c.clickerTap(), isNull, reason: '주문 제작 중 클리커 막힘');
    expect(tester.widget<InkWell>(key('workshop-cell-0')).onTap, isNull, reason: '숙련된 붕어빵 틀은 멈춤');
    await bakeOnScreen();
    expect(find.text('결과 닫기'), findsOneWidget);
    await tapKey('mold-store');
    expect(c.state.session, isNull);
    expect(key('workshop-clicker'), findsOneWidget);
    expect(key('active-empty-mold'), findsNothing);
    // The order bake went to stock for that customer.
    expect(c.saleReadyCount(c.state.customers.firstWhere((o) => o.id == orderId)), greaterThan(0));
    final after = c.state.taps;
    await tapKey('workshop-clicker');
    expect(c.state.taps, after + 1);
    // 주문 제작한 붕어빵을 그 손님에게 판다.
    await tapKey('sale-button');
    expect(c.state.completedSales, 3);
    expect(c.state.customers, isEmpty);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
