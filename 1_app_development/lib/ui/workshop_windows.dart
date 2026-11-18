import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'night_home.dart' show NightHome;
import 'pixel_sprites.dart';

// 26번 4-3단계: the skill window moved to its own file.
export 'workshop_skill_shop.dart' show WorkshopSkillShop, LevelUpButton, SkillStepWheel;

/// The original wooden sub-window, with current authoritative balances.
///
/// It fills the screen below the status bar. A dark wooden strip at the
/// bottom holds '돌아가기' and covers the home's bottom menu, so the menu never
/// peeks out beside the button, and small screens get the most list space.
Future<void> showWorkshopWindow(BuildContext context,{required WorkshopController controller,
  required GameController account,required String title,required Widget Function(BuildContext) content}) =>
  showModalBottomSheet<void>(context:context,isScrollControlled:true,useSafeArea:true,
    backgroundColor:Colors.transparent,builder:(ctx)=>SizedBox(key:const Key('workshop-window'),
      height:MediaQuery.sizeOf(ctx).height,
      child:AnimatedBuilder(animation:Listenable.merge([controller,account]),builder:(context,_)=>Column(children:[
        Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(6,4,6,0),child:Column(children:[
          MediaQuery.withClampedTextScaling(maxScaleFactor:1.3,child:CozyPanel(radius:16,
            child:Wrap(alignment:WrapAlignment.center,spacing:12,children:[
              Text('붕어빵력 ${compactNumber(controller.state.buns)}'),
              Text('황금붕어빵력 ${compactNumber(BigInt.from(account.state.premium.gold))}'),
            ]))),
          const SizedBox(height:10),Expanded(child:Stack(clipBehavior:Clip.none,children:[
            Positioned.fill(child:CozyFrame(child:Column(children:[
              Padding(padding:const EdgeInsets.fromLTRB(48,12,48,6),child:MediaQuery.withClampedTextScaling(
                maxScaleFactor:1.3,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  title=='설정' ? const PixelIcon('settings',size:30) : PixelArt(PixelSprites.screenArt('title_fish'),width:30,height:23),const SizedBox(width:8),
                  Flexible(child:Text(title,key:const Key('workshop-window-title'),textAlign:TextAlign.center,
                    style:const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,fontSize:28,color:Cozy.ink))),const SizedBox(width:8),
                  title=='설정' ? const PixelIcon('settings',size:30) : PixelArt(PixelSprites.screenArt('title_fish'),width:30,height:23),
                ]))),
              if(controller.error!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Text(controller.error!)),
              if(controller.notice!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Text(controller.notice!)),
              Expanded(child:content(ctx)),
            ]))),
            Positioned(top:-8,right:-6,child:CozyCloseButton(onPressed:()=>Navigator.pop(ctx))),
          ])),
        ]))),
        // At least as tall as the home's bottom menu (NightHome.navHeight).
        Container(key:const Key('workshop-window-base'),width:double.infinity,
          constraints:const BoxConstraints(minHeight:NightHome.navHeight),
          margin:const EdgeInsets.only(top:8),
          padding:EdgeInsets.fromLTRB(16,8,16,10+MediaQuery.viewPaddingOf(context).bottom),
          decoration:const BoxDecoration(color:Cozy.woodDark,border:Border(top:BorderSide(color:Cozy.wood,width:2))),
          child:Center(child:MediaQuery.withClampedTextScaling(maxScaleFactor:1.3,
            child:CozyBackButton(onPressed:()=>Navigator.pop(ctx))))),
      ]))));
