import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../balance.dart';
import '../development_balance.dart';
import '../development_rules.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../models.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'night_home.dart' show NightHome;
import 'pixel_sprites.dart';

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

class WorkshopSkillShop extends StatefulWidget {
  final WorkshopController controller;final GameController account;
  const WorkshopSkillShop({super.key,required this.controller,required this.account});
  @override
  State<WorkshopSkillShop> createState()=>_WorkshopSkillShopState();
}
class _WorkshopSkillShopState extends State<WorkshopSkillShop>{
  UpgradeKind _kind=UpgradeKind.tap;PurchaseMode _mode=PurchaseMode.one;
  /// Leading tiers whose tap and auto skills cost no gold (DEC-041: 4).
  static int _freeTiers(WorkshopController c){
    var tier=0;
    while(tier<16 && DevelopmentBalance.integer(c.config.skill('tap_${tier+1}'),'gold')==0 &&
        DevelopmentBalance.integer(c.config.skill('auto_${tier+1}'),'gold')==0){tier++;}
    return tier;
  }
  @override
  Widget build(BuildContext context){
    final c=widget.controller,account=widget.account;
    return Column(children:[
      Wrap(spacing:8,children:[for(final kind in UpgradeKind.values)ChoiceChip(key:Key('kind-${kind.name}'),
        avatar:PixelIcon(kind==UpgradeKind.tap ? 'tab_tap':'tab_auto',size:18),
        label:Text(kind==UpgradeKind.tap ? '클릭 생산':'자동 생산'),selected:kind==_kind,onSelected:(_)=>setState(()=>_kind=kind))]),
      Wrap(spacing:8,children:[for(final mode in [(PurchaseMode.one,'1개'),(PurchaseMode.ten,'10개'),(PurchaseMode.maximum,'최대')])
        ChoiceChip(key:Key('quantity-${mode.$1.name}'),label:Text(mode.$2),selected:mode.$1==_mode,onSelected:(_)=>setState(()=>_mode=mode.$1))]),
      Expanded(child:ListView(key:ValueKey('skills-${_kind.name}'),padding:const EdgeInsets.all(12),children:[
        if(c.purchaseGateway==null) const Text('스킬 구매는 온라인 연결(카카오 로그인)이 있는 빌드에서만 할 수 있어요.')
        else if(!account.online.signedIn) CozyPanel(key:const Key('skill-sign-in'),child:Column(children:[
          const Text('카카오 로그인 후 레벨업할 수 있어요.',textAlign:TextAlign.center),
          const SizedBox(height:6),
          FilledButton(key:const Key('skill-sign-in-button'),onPressed:account.signingIn ? null : () async {
            final message=await account.signInOnline();
            if(message!=null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
          },child:const Text('카카오 로그인')),
        ])),
        if(_freeTiers(c)>0)Text(_freeTiers(c)>=16 ? '모든 스킬은 붕어빵력만으로 레벨업해요.'
            : '1~${_freeTiers(c)}단계 스킬은 붕어빵력만으로 레벨업해요. 황금붕어빵력은 ${_freeTiers(c)+1}단계부터 필요해요.',
          key:const Key('skill-gold-note'),textAlign:TextAlign.center,style:const TextStyle(color:Cozy.inkSoft,fontSize:13)),
        if(c.notice!=null)Text(c.notice!),if(c.error!=null)Text(c.error!),
        for(final journal in c.state.purchases.journals.values.where((j)=>!j.settled)) CozyPanel(child:Column(children:[
          Text('구매 확인 대기: ${journal.quote.skillId}'),Wrap(children:[
            TextButton(onPressed:c.purchaseGateway==null || c.purchaseBusy || c.busy ? null : ()=>c.recoverPurchase(c.purchaseGateway!,journal.transactionId),child:const Text('복구')),
            TextButton(onPressed:c.purchaseGateway==null || c.purchaseBusy || c.busy ? null : ()=>c.recoverPurchase(c.purchaseGateway!,journal.transactionId,cancel:true),child:const Text('취소 확인')),
          ])])),
        for(final skill in upgrades.where((u)=>u.kind==_kind)) Builder(builder:(context){
          final id=skill.id,owned=c.state.purchases.owned[id] ?? 0;
          final cap=DevelopmentBalance.integer(c.config.section('skill_purchase'),'max_owned_per_skill');
          final quantity=math.min(cap-owned,_mode==PurchaseMode.ten ? 10:1);
          final q=_mode==PurchaseMode.maximum ? maximumCompositeSkill(c.config,id,owned:owned,
              availableBuns:c.state.purchases.available(c.state.buns),availableGold:BigInt.from(account.state.premium.gold))
            : quoteCompositeSkill(c.config,id,owned:owned,quantity:quantity);
          final rule=c.config.skill(id);
          final unlocked=c.state.lifetime>=DevelopmentBalance.decimal(rule,'unlock_total');
          final enabled=unlocked && q.quantity>0 && c.purchaseGateway!=null && !c.busy && !c.purchaseBusy && c.error==null &&
            q.affordable(c.state.purchases.available(c.state.buns),BigInt.from(account.state.premium.gold));
          return Card(key:Key('skill-$id'),child:Padding(padding:const EdgeInsets.all(14),child:Column(
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Row(children:[PixelImage(PixelSprites.skill(id),size:48),const SizedBox(width:12),Expanded(child:Text(skill.name))]),
              Text('$owned/$cap · ${_kind==UpgradeKind.tap ? '클릭당':'초당'} ${compactNumber(_kind==UpgradeKind.tap ? c.tapRate:c.autoRate)}'),
              Text('구매 후 ${_kind==UpgradeKind.tap ? '클릭당':'초당'} ${compactNumber((_kind==UpgradeKind.tap ? c.tapRate:c.autoRate)+DevelopmentBalance.decimal(rule,'effect')*BigInt.from(q.quantity))}',key:Key('after-$id')),
              Text(unlocked ? owned>=cap ? '최대 강화':q.gold==BigInt.zero ? '붕어빵력만 있으면 돼요.':'붕어빵력과 황금붕어빵력이 모두 필요해요.':'누적 ${rule['unlock_total']} 해금'),
              FilledButton(key:Key('buy-$id'),onPressed:!enabled ? null : () async {
                await c.purchaseSkill(c.purchaseGateway!,id,quantity:q.quantity);await account.refreshWorkshopWallet();
              },child:Text('${q.quantity}개 · 붕어빵력 ${compactNumber(q.buns)}${q.gold==BigInt.zero ? '':' + 황금 ${compactNumber(q.gold)}'}')),
              TextButton(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:Text(skill.name),
                content:SelectableText('구매 수량 ${q.quantity}개\n붕어빵력 ${q.buns}${q.gold==BigInt.zero ? '':'\n황금붕어빵력 ${q.gold}'}'),
                actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('확인'))])),child:const Text('자세히 보기')),
            ])));
        }),
      ])),
    ]);
  }
}
