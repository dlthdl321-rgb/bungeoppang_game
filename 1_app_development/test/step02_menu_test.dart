import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_windows.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

void main(){
  for(final scale in [1.0,1.5])testWidgets('restored menu routes and appearance authority at text scale $scale',(tester)async{
    final account=await mountGame(tester,const Size(360,800),textScale:scale,reduced:true);
    final config=DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>);
    final c=WorkshopController(config,MemoryRepository());await c.initialize();
    await tester.pumpWidget(GameApp(controller:account,workshop:c));await tester.pump();
    final oldLegacy=account.state.buns,coins=account.state.support.coins,oldBuns=c.state.buns;
    Future<void> tapKey(String key)async{
      final finder=find.byKey(Key(key));await tester.ensureVisible(finder);await tester.pumpAndSettle();
      await tester.tap(finder);await tester.pumpAndSettle();
    }
    Future<void> close()async{await tester.tap(find.byTooltip('닫기').last);await tester.pumpAndSettle();}
    await tapKey('menu-shop');expect(tester.widget<Text>(find.byKey(const Key('workshop-window-title'))).data,'상점');
    expect(find.byKey(const Key('shop-tab-gear')),findsOneWidget);
    await tapKey('shop-tab-theme');expect(tester.takeException(),isNull);await close();expect(c.gridVisible,isTrue);
    await tapKey('menu-skills');expect(find.byType(WorkshopSkillShop),findsOneWidget);
    await tapKey('kind-auto');await tapKey('quantity-ten');await tapKey('quantity-maximum');
    expect(find.byKey(const Key('skill-auto_1')),findsOneWidget);await close();
    await tapKey('menu-skins');expect(find.byKey(const Key('cosmetic-category-hair')),findsOneWidget);
    await tapKey('preview-boy');expect(c.state.avatarEquipment['character'],isNot('boy'));
    final apply=find.byKey(const Key('buy-cosmetic-boy'));
    await tester.scrollUntilVisible(apply,250,scrollable:find.byType(Scrollable).last);
    await tester.tap(apply);await tester.pumpAndSettle();expect(c.state.avatarEquipment['character'],'boy');
    await close();
    for(final route in [('menu-collection','도감'),('menu-achievements','업적'),('menu-records','생산 기록'),
      ('menu-ranking','온라인 랭킹'),('menu-theme','꾸미기'),('menu-daily','일일 미션'),('event-entry','주간 도전'),
      ('menu-missions','레벨 미션'),('menu-friends','친구'),('menu-share','게임 공유'),('menu-management','가게 관리')]){
      await tapKey('menu-menu');expect(c.gridVisible,isFalse);
      await tapKey(route.$1);
      expect(tester.widget<Text>(find.byKey(const Key('workshop-window-title'))).data,route.$2);
      if(route.$1=='menu-collection')expect(find.textContaining('맛 도감은 Lv.'),findsOneWidget);
      expect(c.gridVisible,isFalse,reason:'switching windows must keep the grid paused');
      expect(tester.takeException(),isNull);await close();expect(c.gridVisible,isTrue);
    }
    expect(account.state.buns,oldLegacy);expect(account.state.support.coins,coins);expect(c.state.buns,oldBuns);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
