import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'night_home.dart' show NightHome;
import 'pixel_sprites.dart';

// 26번 4-3단계: the skill window moved to its own file.
export 'workshop_skill_shop.dart' show WorkshopSkillShop, LevelUpButton, SkillStepWheel;

/// The original wooden sub-window, with current authoritative balances.
///
/// It fills the screen below the status bar. A dark wooden strip at the
/// bottom holds '돌아가기' and covers the home's bottom menu, so the menu never
/// peeks out beside the button, and small screens get the most list space.
///
/// The balance row on top (26번 4-5단계, F31·S45-Q4) shows both currencies
/// as icon and big number; the '+' beside the gold opens [onGold] (the gold
/// packs). The cute fish of 25번 15번 flanks the title (F36·G13, 48x36,
/// the left one mirrored).
Future<void> showWorkshopWindow(BuildContext context,{required WorkshopController controller,
  required GameController account,required String title,required Widget Function(BuildContext) content,
  VoidCallback? onGold}) =>
  showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
    backgroundColor:Colors.transparent,builder:(ctx)=>SizedBox(key:const Key('workshop-window'),
      height:MediaQuery.sizeOf(ctx).height,
      child:AnimatedBuilder(animation:Listenable.merge([controller,account]),builder:(context,_)=>Column(children:[
        Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(6,4,6,0),child:Column(children:[
          MediaQuery.withClampedTextScaling(maxScaleFactor:1.3,child:CozyPanel(radius:16,
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
            child:Wrap(key:const Key('workshop-balance'),alignment:WrapAlignment.center,crossAxisAlignment:WrapCrossAlignment.center,
              spacing:18,runSpacing:2,children:[
              // 4차 g14: a huge balance shrinks in its own width so 황금 stays on the same line.
              ConstrainedBox(constraints:const BoxConstraints(maxWidth:200),
                child:CurrencyAmount(Currency.buns,controller.state.buns,key:const Key('balance-buns'),size:30,fontSize:19)),
              Row(mainAxisSize:MainAxisSize.min,children:[
                CurrencyAmount(Currency.gold,BigInt.from(account.state.premium.gold),key:const Key('balance-gold'),size:30,fontSize:19),
                if(onGold!=null)Padding(padding:const EdgeInsets.only(left:4),child:Material(color:Cozy.honey,
                  shape:const CircleBorder(side:BorderSide(color:Cozy.wood,width:1.5)),
                  child:InkWell(key:const Key('balance-gold-plus'),customBorder:const CircleBorder(),onTap:onGold,
                    child:const Padding(padding:EdgeInsets.all(3),
                      child:Icon(Icons.add_rounded,size:18,color:Cozy.ink,semanticLabel:'황금붕어빵력 충전'))))),
              ]),
            ]))),
          const SizedBox(height:10),Expanded(child:Stack(clipBehavior:Clip.none,children:[
            Positioned.fill(child:CozyFrame(child:Column(children:[
              Padding(padding:const EdgeInsets.fromLTRB(52,10,52,4),child:MediaQuery.withClampedTextScaling(
                maxScaleFactor:1.3,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  // 25번 35번 redraw (ui/title_fish.png).
                  title=='설정' ? const Padding(padding:EdgeInsets.only(right:6),child:PixelIcon('settings',size:30))
                    : const TitleFish(key:Key('title-fish-left'),width:48,height:36,flip:true),
                  Flexible(child:Text(title,key:const Key('workshop-window-title'),textAlign:TextAlign.center,
                    style:const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,fontSize:28,color:Cozy.ink))),
                  title=='설정' ? const Padding(padding:EdgeInsets.only(left:6),child:PixelIcon('settings',size:30))
                    : const TitleFish(width:48,height:36),
                ]))),
              // H41: a tinted line per kind (warning, info) instead of plain text.
              if(controller.error!=null)Padding(padding:const EdgeInsets.fromLTRB(12,0,12,6),
                child:CozyNotice(controller.error!,key:const Key('workshop-window-error'),tone:CozyTone.warning)),
              if(controller.notice!=null)Padding(padding:const EdgeInsets.fromLTRB(12,0,12,6),
                child:CozyNotice(controller.notice!,key:const Key('workshop-window-notice'))),
              Expanded(child:content(ctx)),
            ]))),
            Positioned(top:CozyCloseButton.edge,right:CozyCloseButton.edge,child:CozyCloseButton(onPressed:()=>Navigator.pop(ctx))),
          ])),
        ]))),
        // At least as tall as the home's bottom menu (NightHome.navHeight).
        Container(key:const Key('workshop-window-base'),width:double.infinity,
          constraints:const BoxConstraints(minHeight:NightHome.navHeight),
          margin:const EdgeInsets.only(top:8),
          padding:EdgeInsets.fromLTRB(16,8,16,10+MediaQuery.viewPaddingOf(context).bottom),
          // H41: a quiet light strip with a hairline (it was dark wood).
          decoration:const BoxDecoration(color:Cozy.creamDeep,border:Border(top:BorderSide(color:Cozy.line))),
          child:Center(child:MediaQuery.withClampedTextScaling(maxScaleFactor:1.3,
            child:CozyBackButton(onPressed:()=>Navigator.pop(ctx))))),
      ]))));
