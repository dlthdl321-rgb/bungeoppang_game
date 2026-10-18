import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cooking_input.dart';
import 'package:todays_bungeoppang/cooking_session.dart';
import 'package:todays_bungeoppang/cooking_sensor_input.dart';
import 'package:todays_bungeoppang/cooking_tilt_source.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/cooking_session_controls.dart';
import 'package:todays_bungeoppang/ui/cooking_filling_controls.dart';
import 'package:todays_bungeoppang/ui/night_home.dart';
import 'package:todays_bungeoppang/ui/bake_target.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

void main() {
  test('gravity projection stays neutral upright/flat and produces a full batter command', () {
    int angle(num x,num y,num z)=>CookingTiltSample.fromEvent({'available':true,'gravityX':x,'gravityY':y,'gravityZ':z}).angleMillidegrees!;
    expect(angle(0,9.8,0),0);
    expect(angle(0,0,9.8),0);
    expect(angle(-4.9,0,8.487),closeTo(30000,2));
    expect(angle(4.9,8.487,0),closeTo(-30000,2));
    expect(CookingTiltSample.fromEvent({'available':true,'gravityX':0,'gravityY':0,'gravityZ':0}).available,isFalse);
    expect(CookingTiltSample.fromEvent({'available':true,'gravityX':double.nan,'gravityY':0,'gravityZ':1}).available,isFalse);
    final input=CookingSensorInput(TiltDirectionGate(activation:15000,deadZone:5000));
    final session=CookingSession.start(id:'flat',flavor:'redbean',practice:true,fillingSequence:[CookingDirection.left]);
    expect(input.sample(session,angle(0,0,9.8),0),isNull);
    expect(input.sample(session,angle(0,0,9.8),100),isNull);
    expect(input.sample(session,angle(-4.9,0,8.487),200),isNull);
    expect(input.pouring,isTrue);
    final next=input.sample(session,angle(0,0,9.8),2700)!;
    expect(next.phase,CookingPhase.filling);
    expect(next.firstBatterMs,2500);
  });
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
      expect(find.byKey(const Key('menu-menu')),findsOneWidget);
      expect(find.byKey(const Key('auto-rate')),findsOneWidget);
      expect(find.byKey(const Key('tap-rate')),findsOneWidget);
      await tester.tap(find.byTooltip('설정'));await tester.pumpAndSettle();
      expect(find.byKey(const Key('setting-music')),findsOneWidget);
      await tester.scrollUntilVisible(find.text('진동'),250,scrollable:find.byType(Scrollable).last);
      expect(find.text('진동'),findsOneWidget);
      await tester.scrollUntilVisible(find.text('모션 줄이기'),200,scrollable:find.byType(Scrollable).last);
      expect(find.text('모션 줄이기'),findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('settings-save')),200,scrollable:find.byType(Scrollable).last);
      await tester.tap(find.byKey(const Key('settings-save')));await tester.pumpAndSettle();
      expect(find.byKey(const Key('griddle')),findsOneWidget);
      expect(find.byKey(const Key('workshop-cell-5')),findsOneWidget);
      final oldBuns=account.state.buns;
      await tester.ensureVisible(find.byKey(const Key('workshop-mold-action')));
      await tester.tap(find.byKey(const Key('workshop-mold-action')));
      await tester.pump();
      expect(c.state.session?.phase,CookingPhase.firstBatter);
      expect(account.state.buns,oldBuns);
      final hold=await tester.startGesture(tester.getCenter(find.byType(BatterHoldButton)));
      await tester.pump(const Duration(milliseconds:2500));
      await hold.up();await tester.pump();
      expect(c.state.session?.phase,CookingPhase.filling);
      expect(find.byType(CookingFillingControls),findsOneWidget);
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
      while(c.state.session!.phase==CookingPhase.filling) {
        final session=c.state.session!;
        final direction=session.fillingSequence[session.fillingIndex];
        final button=find.text('${direction==CookingDirection.left ? '왼쪽' : '오른쪽'}으로 속 넣기');
        await tester.ensureVisible(button);
        await tester.tap(button);await tester.pump();
        expect(c.state.session!.token,session.token+1);
      }
      final second=await tester.startGesture(tester.getCenter(find.byType(BatterHoldButton)));
      await tester.pump(const Duration(milliseconds:2500));await second.up();await tester.pump();
      expect(c.state.session!.phase,CookingPhase.closing);
      for(final phase in [CookingPhase.flipping,CookingPhase.cooking,CookingPhase.result]) {
        await c.command(()=>c.state.phaseMs=15000);await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('workshop-mold-action')));
        await tester.tap(find.byKey(const Key('workshop-mold-action')));await tester.pump();
        expect(c.state.session!.phase,phase);
      }
      await tester.tap(find.text('보관'));await tester.pump();
      expect(c.state.session,isNull);
      expect(account.state.buns,oldBuns);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());

    });
  }
}
