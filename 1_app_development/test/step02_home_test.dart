import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_result_rules.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/flip_circle_control.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/piping_bag_control.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/bake_target.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// Rubs across the mold paint control in a few rows and lifts (24번 5단계).
Future<void> paintMold(WidgetTester tester) async {
  final box = tester.getRect(find.byType(MoldPaintControl));
  final gesture = await tester.startGesture(box.center);
  for (var row = 0; row < 5; row++) {
    final y = box.top + box.height * (.3 + row * .1);
    await gesture.moveTo(Offset(box.left + box.width * .2, y));
    await gesture.moveTo(Offset(box.left + box.width * .8, y));
  }
  await gesture.up();
  await tester.pump();
}

/// Pushes the flipping mold up over its axle and lifts (26번 3차 피드백 H21;
/// the name stays from the old circle of 24번 6단계).
Future<void> drawFlipCircle(WidgetTester tester) async {
  final box = tester.getRect(find.byType(FlipCircleControl));
  final start = box.center + Offset(0, box.height * .3);
  final gesture = await tester.startGesture(start);
  for (var d = 0.0; d <= box.height; d += 10) {
    await gesture.moveTo(start - Offset(0, d));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  for(final size in [const Size(390,844),const Size(360,640)]) {
    testWidgets('original stall hosts real Workshop commands at $size', (tester) async {
      final account=await mountGame(tester,size,reduced:true);
      final config=DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>);
      final c=WorkshopController(config,MemoryRepository(),now:()=>DateTime.utc(2026,10,18));
      await c.initialize();
      await tester.pumpWidget(GameApp(controller:account,workshop:c));
      await tester.pump();
      expect(find.byType(NightHome),findsOneWidget);
      expect(find.byType(BakeTarget),findsNothing);
      // 26번 3차 피드백 H28: the menu is only in the bottom bar; the flavor sits top-left.
      expect(find.byKey(const Key('menu-menu')),findsNothing);
      expect(find.byKey(const Key('menu-menubar')),findsOneWidget);
      expect(find.byKey(const Key('flavor-button')),findsOneWidget);
      // 26번 2단계: the per-second and per-tap numbers open with the skills at Lv.2.
      expect(find.byKey(const Key('auto-rate')),findsNothing);
      expect(find.byKey(const Key('tap-rate')),findsNothing);
      await tester.tap(find.byTooltip('설정'));await tester.pumpAndSettle();
      expect(find.byKey(const Key('setting-music')),findsOneWidget);
      await tester.scrollUntilVisible(find.text('진동'),250,scrollable:find.byType(Scrollable).last);
      expect(find.text('진동'),findsOneWidget);
      // The settings list grew (5-1단계 손님 알림 3줄, 5단계 사용 통계): move
      // it 100px at a time (no fling) until the target lies inside the list.
      bool inView(Finder target) {
        if (target.evaluate().isEmpty) return false;
        final r = tester.getRect(target.first), view = tester.getRect(find.byType(Scrollable).last);
        return r.top >= view.top && r.bottom <= view.bottom;
      }
      Future<void> reveal(Finder target) async {
        await tester.pumpAndSettle(); // let scrollUntilVisible's animation end first
        final position = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
        for (var i = 0; i < 40 && !inView(target); i++) {
          position.jumpTo((position.pixels + 100).clamp(0.0, position.maxScrollExtent)); await tester.pump();
        }
      }
      await reveal(find.text('모션 줄이기'));
      expect(find.text('모션 줄이기'),findsOneWidget);
      await reveal(find.text('밤 알림 끄기 (밤 10시~아침 8시)'));
      expect(find.text('단골 손님 알림'),findsOneWidget);
      await reveal(find.byKey(const Key('settings-save')));
      await tester.tap(find.byKey(const Key('settings-save')));await tester.pumpAndSettle();
      expect(find.byKey(const Key('griddle')),findsOneWidget);
      // Before opening the griddle is an empty picture with no cells (24번 3단계).
      expect(find.byKey(const Key('griddle-idle')),findsOneWidget);
      expect(find.byKey(const Key('workshop-cell-5')),findsNothing);
      final oldBuns=account.state.buns;
      await tester.ensureVisible(find.byKey(const Key('workshop-mold-action')));
      await tester.tap(find.byKey(const Key('workshop-mold-action')));
      await tester.pump();
      expect(c.state.session?.phase,CookingPhase.firstBatter);
      expect(find.byKey(const Key('workshop-phase-time')),findsOneWidget);
      expect(find.byKey(const Key('active-empty-mold')),findsOneWidget);
      if(size.height==844) await tester.runAsync(() async {
        final boundary=tester.element(find.byKey(const Key('home-capture'))).findRenderObject() as RenderRepaintBoundary;
        final image=await boundary.toImage(pixelRatio:1);
        final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
        Directory('build/step02-preview').createSync(recursive:true);
        File('build/step02-preview/home-empty.png').writeAsBytesSync(bytes!.buffer.asUint8List());image.dispose();
      });

      await c.command(()=>c.state.phaseMs=12000);await tester.pump();
      // 26번 3차 피드백 H19: only which bungeoppang, no step time.
      expect(tester.widget<Text>(find.byKey(const Key('workshop-phase-time'))).data,'팥 붕어빵 연습');
      await c.setForeground(false);await tester.pump();
      final pausedMs=c.state.phaseMs;
      await tester.pump(const Duration(seconds:5));
      expect(c.state.phaseMs,pausedMs);
      expect(tester.widget<Text>(find.byKey(const Key('workshop-phase-time'))).data,contains('일시정지'));
      await c.setForeground(true);await tester.pump();
      expect(c.state.session?.phase,CookingPhase.firstBatter);
      expect(account.state.buns,oldBuns);
      await paintMold(tester);
      expect(c.state.session?.phase,CookingPhase.filling);
      expect(c.state.session!.firstBatter!.coverage,greaterThan(0));
      expect(find.byType(MoldPaintControl),findsOneWidget);
      expect(tester.takeException(),isNull);
      if(size.height==844) {
        await tester.runAsync(() async {
          final font=File('C:/Windows/Fonts/malgun.ttf');
          if(await font.exists()) await (FontLoader('Jua')..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        });
        await tester.pump();
        await tester.runAsync(() async {
          final box=tester.element(find.byKey(const Key('home-capture'))).findRenderObject() as RenderRepaintBoundary;
          final image=await box.toImage(pixelRatio:1);
          final data=await image.toByteData(format:ui.ImageByteFormat.png);
          Directory('build/step02-preview').createSync(recursive:true);
          File('build/step02-preview/home-filling.png').writeAsBytesSync(data!.buffer.asUint8List());image.dispose();
        });
      }
      expect(find.text('숟가락'),findsNothing);
      expect(find.text('왼쪽으로 속 넣기'),findsNothing);
      expect(find.byKey(const Key('piping-amount')),findsOneWidget);
      await paintMold(tester);
      expect(c.state.session!.phase,CookingPhase.secondBatter);
      expect(c.state.session!.filling,isNotNull);
      await paintMold(tester);
      expect(c.state.session!.phase,CookingPhase.closing);
      Future<void> step(CookingPhase phase) async {
        await c.command(()=>c.state.phaseMs=15000);await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('workshop-mold-action')));
        await tester.tap(find.byKey(const Key('workshop-mold-action')));await tester.pump();
        expect(c.state.session!.phase,phase);
      }
      await step(CookingPhase.flipping);
      // Flipping has no button: a tap does nothing, a circle flips (24번 6단계).
      expect(find.byKey(const Key('workshop-mold-action')),findsNothing);
      expect(find.text('틀을 위로 밀어 올려 뒤집어요'),findsOneWidget);
      await c.command(()=>c.state.phaseMs=15000);await tester.pump();
      await tester.tap(find.byType(FlipCircleControl));await tester.pump(const Duration(seconds:2));
      expect(c.state.session!.phase,CookingPhase.flipping);
      await drawFlipCircle(tester);
      await tester.pump(const Duration(milliseconds:1100));await tester.pump();
      expect(c.state.session!.phase,CookingPhase.cooking);
      await step(CookingPhase.result);
      // The result shows its grade and names why the batter failed (G6,
      // 26번 4단계: '반죽이 조금 모자랐어요').
      final session=c.state.session!;
      final grade=cookingGrade(c.config,session,difficulty:c.difficulty(session.flavor));
      final variant=evaluateCookingResult(c.config,session,difficulty:c.difficulty(session.flavor)).variant;
      expect(find.text(cookingGradeTitle(grade)),findsOneWidget);
      final caption=tester.widget<Text>(find.byKey(const Key('mold-result-caption'))).data!;
      expect(caption,cookingGradeLine(c.config,session,grade,variant:variant));
      final why=batterFailureLabel(c.config,session);
      if(why!=null&&grade==CookingGrade.near) expect(caption,contains('반죽'));
      await tester.tap(find.text('보관하기'));await tester.pump();
      expect(c.state.session,isNull);
      expect(account.state.buns,oldBuns);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());

    });
  }
}
