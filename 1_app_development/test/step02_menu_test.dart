import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
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
    // 26번 2단계: during the first-run guide 상점·꾸미기·스킬 are locked.
    for(final id in ['shop','skins','skills']){expect(find.byKey(Key('menu-$id-locked')),findsOneWidget);}
    expect(await c.skipTutorial(),isTrue);
    // Lv.8 opens every menu row; the cards were seen (they have their own test).
    expect(await c.command((){c.state.level=8;c.state.claimedLevels.addAll([for(var n=2;n<=8;n++)n]);
      c.state.featureIntros.addAll(['skills','collection','recipes','specialOrders','fishCosmetics','stallCosmetics']);}),isTrue);
    await tester.pump();
    await tapKey('menu-shop');
    expect(tester.getBottomRight(find.byType(CozyBackButton)).dy,lessThanOrEqualTo(776));
    expect(tester.widget<Text>(find.byKey(const Key('workshop-window-title'))).data,'상점');
    // The window's base covers the home's bottom menu: nothing peeks out beside '돌아가기'.
    expect(tester.getTopLeft(find.byKey(const Key('workshop-window-base'))).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('home-nav'))).dy));
    expect(tester.getSize(find.byKey(const Key('workshop-window-base'))).width,360);
    // 26번 4-5단계: the workshop shop sells avatar items in 꾸미기 only.
    expect(find.byKey(const Key('shop-tab-gear')),findsNothing);
    // 26번 3단계: the workshop shop opens on 꾸미기, where gold buys avatar items.
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('shop-tab-cosmetics'))).selected,isTrue);
    // Stall themes are not on sale in the soft launch: no empty tab, no '판매 준비 중'.
    expect(find.byKey(const Key('shop-tab-theme')),findsNothing);
    await tapKey('shop-tab-gold');expect(find.textContaining('부스트'),findsNothing);
    expect(find.byKey(const Key('gold-uses')),findsOneWidget);
    expect(find.textContaining('스킬 해금'),findsNothing);
    expect(find.textContaining('준비 중'),findsNothing);
    expect(tester.takeException(),isNull);await close();expect(c.gridVisible,isTrue);
    await tapKey('menu-skills');expect(find.byType(WorkshopSkillShop),findsOneWidget);
    // DEC-041: tiers 1~4 cost no gold, so the button shows no '+ 황금 0'.
    expect(find.byKey(const Key('skill-gold-note')),findsOneWidget);
    expect(find.descendant(of:find.byKey(const Key('skill-tap_1')),matching:find.textContaining('황금')),findsNothing);
    // 26번 4-3단계: the 1개/10개/최대 chips became the ×1·×10·×100 wheel
    // (one per skill since 시안 확인 2차).
    await tapKey('kind-auto');await tapKey('step-auto_1-10');await tapKey('step-auto_1-100');
    expect(find.byKey(const Key('skill-auto_1')),findsOneWidget);await close();
    await tapKey('menu-skins');expect(find.byKey(const Key('cosmetic-category-hair')),findsOneWidget);
    await tapKey('preview-boy');expect(c.state.avatarEquipment['character'],isNot('boy'));
    // 26번 4-5단계: '모두 적용' on the preview wears every changed slot.
    await tapKey('wardrobe-apply-all');expect(c.state.avatarEquipment['character'],'boy');
    await close();
    for(final route in [('menu-collection','도감'),('menu-achievements','업적'),('menu-records','생산 기록'),
      ('menu-theme','꾸미기'),('menu-daily','일일 미션'),('event-entry','주간 도전'),
      ('menu-missions','레벨 미션')]){
      await tapKey('menu-menubar');expect(c.gridVisible,isFalse);
      await tapKey(route.$1);
      expect(tester.widget<Text>(find.byKey(const Key('workshop-window-title'))).data,route.$2);
      if(route.$1=='menu-collection')expect(find.textContaining('맛 도감은 Lv.'),findsNothing);
      expect(c.gridVisible,isFalse,reason:'switching windows must keep the grid paused');
      if(route.$1=='menu-theme')expect(find.textContaining('준비 중'),findsNothing);
      expect(tester.takeException(),isNull);await close();expect(c.gridVisible,isTrue);
    }
    // Out of the soft launch (DEC-029): no online ranking, friends or sharing.
    await tapKey('menu-menubar');
    for(final key in ['menu-ranking','menu-friends','menu-share']){expect(find.byKey(Key(key)),findsNothing);}
    await close();
    expect(account.state.buns,oldLegacy);expect(account.state.support.coins,coins);expect(c.state.buns,oldBuns);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
