import '../cooking_result_rules.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../development_balance.dart';
import '../game_controller.dart';
import '../workshop_controller.dart';
import '../cosmetic_config.dart';
import '../workshop_purchases.dart';
import 'center_toast.dart';
import 'flavor_picker.dart';
import 'night_home.dart';
import 'workshop_mold_stage.dart';
import 'cozy_style.dart';
import 'cook_cut.dart';
import 'customer_story_panel.dart';
import 'game_app.dart' show SoundSettings;
import 'pixel_sprites.dart';
import '../menu_rules.dart';
import '../economy.dart';
import 'public_menus.dart';
import 'shop_panel.dart';
import 'workshop_windows.dart';
import 'workshop_counter.dart';
import 'workshop_daily_card.dart';
import 'workshop_guests.dart';
import 'workshop_home_layout.dart';
import 'workshop_guide.dart';
import '../workshop_tutorial.dart';
import '../customer_notifier.dart';
import '../workshop_feature_unlocks.dart';
import '../usage_stats.dart';
import '../owner_account.dart';
import '../owner_texts.dart';
import 'owner_settings.dart';
import 'notice_permission_hint.dart';
import '../share_card.dart';
import 'share_card_view.dart';
import 'workshop_collection.dart';
import '../workshop_collection_rules.dart' show collectionRequired, collectionTitle;
import 'workshop_records.dart';

class WorkshopPage extends StatefulWidget {
  final WorkshopController controller;
  final GameController accountController;
  /// Customer notifications (26번 5-1단계); null keeps the question card
  /// and permission requests away (tests, platforms without notifications).
  final CustomerNotifier? notifier;
  /// The owner name and account settings (26번 2-1단계); null in tests of
  /// the game screens.
  final OwnerAccount? owner;
  const WorkshopPage({super.key, required this.controller, required this.accountController, this.notifier, this.owner});
  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}
class _WorkshopPageState extends State<WorkshopPage> {
  WorkshopController get c => widget.controller;
  int _windowCount=0;
  final _homeKey=GlobalKey();
  /// Story chapters already told in this run (26번 3차 H6, not saved).
  final _storySeen=<WorkshopStoryChapter>{};
  bool _awayShowing=false;
  /// The welcome-back card, once per report, after the frame that noticed it.
  /// 4차 피드백 g6: a 도감 cell or flavor just completed ('팥 · 부드러움 칸
  /// 완성!'), as one short centre notice.
  void _showCollectionNews() {
    if(c.collectionNews.isEmpty) return;
    final news=c.takeCollectionNews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) showCenterToast(context,news.join('\n'));
    });
  }
  void _showAwayReport() {
    final report=c.awayReport;
    if(report==null || _awayShowing) return;
    _awayShowing=true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if(!mounted) return;
      _enterWindow();
      try {
        await showDialog<void>(context:context,builder:(_)=>WorkshopWelcomeBackCard(report:report,config:c.config,
          reduceMotion:widget.accountController.state.settings.reduceMotion));
      } finally {
        _leaveWindow();_awayShowing=false;
        if(c.awayReport==report) c.dismissAwayReport();
      }
    });
  }
  bool _introShowing=false;
  /// A feature that just opened gets its one-screen card once (26번 2단계),
  /// after the guide and never over another window, card, scene or a bake
  /// in the big mold.
  void _showFeatureIntro() {
    final feature=c.pendingIntro;
    if(feature==null || _introShowing || _noticeAsking || _windowCount>0 || _awayShowing ||
        c.state.customerScene!=null || c.state.session!=null || c.salePraise!=null || c.busy || c.error!=null) {
      return;
    }
    _introShowing=true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if(!mounted || c.pendingIntro!=feature){_introShowing=false;return;}
      _enterWindow();
      try {
        await showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>WorkshopFeatureIntroCard(
          feature:feature,onDone:()=>Navigator.pop(ctx)));
      } finally {
        _leaveWindow();
        await c.markIntroSeen(feature);
        _introShowing=false;
      }
    });
  }
  bool _noticeAsking=false;
  static const noticeDeniedText='휴대폰 설정에서 이 앱의 알림을 허용해야 받을 수 있어요.';
  /// After the first-run guide, once: may we tell the player when guests
  /// come while the app is off? Either answer is remembered (5-1단계).
  void _askNotifications() {
    final account=widget.accountController,s=c.state,notifier=widget.notifier;
    if(notifier==null || _noticeAsking || _introShowing || _windowCount>0 || _awayShowing || s.tutorialActive || s.completedSales==0 ||
        c.salePraise!=null ||
        s.customerScene!=null || account.state.settings.notificationPromptDone) {
      return;
    }
    _noticeAsking=true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if(!mounted){_noticeAsking=false;return;}
      _enterWindow();
      try {
        final accept=await showDialog<bool>(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(
          key:const Key('notice-prompt'),
          title:const Text('손님 알림'),
          content:const Text('손님이 찾아오면 알려 드릴까요? 앱을 꺼 둬도 단골손님이 오면 알림으로 알려 드려요.'),
          actions:[TextButton(key:const Key('notice-later'),onPressed:()=>Navigator.pop(ctx,false),child:const Text('나중에')),
            FilledButton(key:const Key('notice-accept'),onPressed:()=>Navigator.pop(ctx,true),child:const Text('알림 받기'))]));
        final granted=accept==true && await notifier.requestPermission();
        // DEC-105: 'later' and a refused permission leave both switches
        // as they are (named on, regular off by default). Settings show that
        // the permission is missing (NoticePermissionHint); the app never
        // asks again on its own.
        await account.updateSettings(notificationPromptDone:true);
        if(accept==true && !granted && mounted) {
          showCenterToast(context,noticeDeniedText);
        }
      } finally {_leaveWindow();_noticeAsking=false;}
    });
  }
  /// A notification switch: turning one on asks for the permission first.
  Future<void> _setNotice({bool? regular,bool? named,bool? quiet}) async {
    final account=widget.accountController,notifier=widget.notifier;
    if((regular==true || named==true) && notifier!=null && !await notifier.requestPermission()) {
      if(mounted) showCenterToast(context,noticeDeniedText);
      return;
    }
    if(regular==true || named==true) _permissionChecks++;
    await account.updateSettings(notifyRegularGuests:regular,notifyNamedGuests:named,quietNightNotices:quiet);
  }
  /// Bumped after a switch got the permission: the settings hint looks again.
  int _permissionChecks=0;
  void _enterWindow(){_windowCount++;c.gridVisible=false;}
  void _leaveWindow(){_windowCount--;c.gridVisible=_windowCount==0;}
  Future<void> _window(String title,Widget Function(BuildContext) content) async {
    _enterWindow();
    try {await showWorkshopWindow(context,controller:c,account:widget.accountController,title:title,content:content,
      onGold:()=>unawaited(_goldPacks()));}
    finally {_leaveWindow();}
  }
  Future<void> _closeBusiness() async {
    _enterWindow();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('오늘 영업을 끝낼까요?'),
        content: const Text('대기 손님은 돌아가고 진행 중인 스페셜 붕어빵 제작은 취소돼요. 보관한 재고와 도감 기록은 남고, 숙련된 붕어빵 제작은 멈춘 상태로 보관돼요.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 영업')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('영업 종료'))]));
      if (confirmed == true) await c.closeBusiness();
    } finally { _leaveWindow(); }
  }
  Future<void> _shop()=>_window('스킬',(_)=>WorkshopSkillShop(controller:c,account:widget.accountController));
  Future<void> _syncOnline() async {
    final account=widget.accountController;
    final message=await account.signInOnline();
    if (!mounted) return;
    if (message!=null || !account.online.signedIn) {
      showCenterToast(context,message ?? '로그인 후 확인할 수 있어요.');return;
    }
    await c.syncRewards();
    if (!mounted) return;
    await c.recoverAds();
    if (!mounted) return;
    final before=account.state.premium.gold;
    final walletMessage=await account.refreshWorkshopWallet();
    if (!mounted) return;
    final gained=account.state.premium.gold-before;
    // Welcome gold (and other server gold) lands here: point it at 꾸미기.
    final note=walletMessage ?? (gained>0 ? '황금붕어빵력 $gained개를 받았어요. 꾸미기에서 써 보세요.' : null);
    if (note!=null) showCenterToast(context,note);
  }
  CosmeticMenuAccess get _cosmetics {
    final account=widget.accountController,catalog=c.config.section('avatar_catalog');
    bool avatar(CosmeticDefinition d)=>catalog[d.id] is Map<String,dynamic> && (catalog[d.id] as Map)['slot']==d.slot.name;
    bool owned(CosmeticDefinition d)=>d.slot==CosmeticSlot.time || (avatar(d) ? c.ownsAvatar(d.id):account.state.ownsCosmetic(d));
    bool unlocked(CosmeticDefinition d)=>d.slot==CosmeticSlot.time || (avatar(d) ? owned(d) || c.state.level>=DevelopmentBalance.integer(catalog[d.id] as Map<String,dynamic>,'unlock_level') &&
      c.state.lifetime>=DevelopmentBalance.decimal(catalog[d.id] as Map<String,dynamic>,'unlock_total'):cosmeticUnlocked(account.state,d));
    String price(CosmeticDefinition d){
      if(owned(d))return '보유 중';
      if(!avatar(d))return '판매하지 않아요';
      final quote=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
      return '붕어빵력 ${compactNumber(quote.buns)} + 황금붕어빵력 ${compactNumber(quote.gold)}';
    }
    // The price as icons, the currency the player lacks in red (F28).
    WardrobePrice? cost(CosmeticDefinition d){
      if(!avatar(d) || owned(d))return null;
      final q=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
      return WardrobePrice(q.buns,q.gold,missingBuns:c.state.purchases.available(c.state.buns)<q.buns,
        missingGold:BigInt.from(account.state.premium.gold)<q.gold);
    }
    // Several items at once ('모두 사기', 3차 피드백 H15).
    WardrobePrice? total(List<CosmeticDefinition> items){
      if(items.isEmpty || items.any((d)=>!avatar(d) || owned(d)))return null;
      var buns=BigInt.zero,gold=BigInt.zero;
      for(final d in items){
        final q=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
        buns+=q.buns;gold+=q.gold;
      }
      return WardrobePrice(buns,gold,missingBuns:c.state.purchases.available(c.state.buns)<buns,
        missingGold:BigInt.from(account.state.premium.gold)<gold);
    }
    bool canApply(CosmeticDefinition d){
      if(c.inputBusy || c.purchaseBusy || c.error!=null || account.busy || _equipped(d.slot)==d.id || !unlocked(d))return false;
      if(owned(d))return true;
      if(!avatar(d) || c.purchaseGateway==null)return false;
      final q=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
      return q.affordable(c.state.purchases.available(c.state.buns),BigInt.from(account.state.premium.gold));
    }
    // Only the avatar catalog is for sale; other old cosmetics show once owned.
    return CosmeticMenuAccess(equipped:_equipped,owned:owned,unlocked:unlocked,canApply:canApply,price:price,
      // Avatar items show once their art is ready for the vendor worn now
      // (PixelSprites.avatarArtReady); owners keep seeing what they bought.
      // Withdrawn items (26번 3차 H10) stay hidden even when owned.
      listed:(d)=>avatar(d) && (d.slot==CosmeticSlot.background || PixelSprites.avatarArtReady(_equipped(CosmeticSlot.character),d.slot,d.id)) ||
        owned(d) && !avatarItemWithdrawn(_equipped(CosmeticSlot.character),d.id),
      forSale:avatar,cost:cost,total:total,
      // 26번 4-5단계(S45-Q2): only the level; the production total ('누적',
      // 0 for every item) is not shown.
      requirement:(d)=>avatar(d) ? 'Lv.${(catalog[d.id] as Map)['unlock_level']} 해금' : '',
      // 붕어빵 꾸미기 from Lv.5, 가게 꾸미기 from Lv.8 (S45-Q6): hidden before.
      // 26번 3차 H42: the 가게 tab opens with its 배경·시간 from Lv.1 (the
      // backgrounds are sold in the shop again); stove, decoration and lamp
      // still wait for Lv.8.
      tabOpen:(t)=>switch(t){
        WardrobeTab.bungeoppang=>c.featureIsOpen(WorkshopFeature.fishCosmetics),
        WardrobeTab.stall=>c.featureIsOpen(WorkshopFeature.stallBackground),
        _=>true},
      slotOpen:(s)=>s.tab!=WardrobeTab.stall || s==CosmeticSlot.background || s==CosmeticSlot.time ||
        c.featureIsOpen(WorkshopFeature.stallCosmetics),
      action:(d)=>_equipped(d.slot)==d.id ? '장착 중':!unlocked(d) ? '잠김':owned(d) ? '적용':!avatar(d) ? '살 수 없음':'구매하고 적용',
      apply:(d) async {
        if(!canApply(d))return false;
        if(d.slot==CosmeticSlot.time)return c.setBackgroundTime(d.id);
        if(avatar(d)){
          if(!owned(d)){
            final ok=await c.purchaseSkill(c.purchaseGateway!,'cosmetic:${d.id}');
            await account.refreshWorkshopWallet();if(!ok)return false;
          }
          return c.equipAvatar(d.id);
        }
        return account.buyOrEquipCosmetic(d.id);
      });
  }
  /// 꾸미기 wears what is owned; '상점에서 더 보기' opens the shop at that
  /// slot (26번 4-5단계, S45-Q1 B).
  Future<void> _wardrobe({WardrobeTab tab=WardrobeTab.hair,CosmeticSlot? slot})=>_window('꾸미기',(ctx)=>WardrobePanel(
    controller:widget.accountController,access:_cosmetics,initialTab:tab,initialSlot:slot,
    onMore:(slot){Navigator.pop(ctx);unawaited(_store(slot:slot));},
    // 3차 피드백 H15: '모두 적용' wears and closes; no back button needed.
    onClose:()=>Navigator.pop(ctx)));
  Future<void> _store({CosmeticSlot? slot}){
    c.usage.record(UsageEvent.shopOpen); // 사용 통계(26번 5단계), 하루 1번
    return _window('상점',(_)=>ShopPanel(controller:widget.accountController,access:_cosmetics,onOpen:_open,initialSlot:slot));
  }
  Future<void> _goldPacks() async {
    _enterWindow();
    try {
      final account = widget.accountController;
      final message = await account.signInOnline();
      if (!mounted) return;
      if (message != null || !account.online.signedIn) {
        showCenterToast(context, message ?? '로그인 후 이용할 수 있어요.');
        return;
      }
      account.usage.record(UsageEvent.payView); // 사용 통계(26번 5단계), 하루 1번
      final packs = await account.goldPacks();
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: ListView(
        shrinkWrap: true, children: [const ListTile(title: Text('황금붕어빵력 충전'), subtitle: Text('실제 결제 상품이에요.')),
        if (packs.isEmpty) const ListTile(title: Text('지금은 결제 상품을 불러올 수 없어요.')),
        for (final pack in packs) ListTile(title: Text(pack.title), subtitle: Text(pack.price),
          trailing: FilledButton(onPressed: () async {
            Navigator.pop(context);
            final error = await account.buyGoldPack(pack.id);
            if (mounted && error != null) showCenterToast(this.context, error);
          }, child: const Text('구매'))),
      ])));
    } finally { _leaveWindow(); }
  }
  Future<void> _audioSettings()=>_window('설정',(ctx){
    final account=widget.accountController,settings=account.state.settings;
    final owner=widget.owner;
    return ListView(padding:const EdgeInsets.all(12),children:[
      if(owner!=null)OwnerSettingsSection(owner:owner,closeWindow:()=>Navigator.pop(ctx),
        notify:(m){if(mounted)showCenterToast(context,m);}),
      // 26번 3차 H42: the background picture is chosen here again (it opens
      // the wardrobe's 가게 tab at 배경, where owned ones are worn).
      if(_lockFor('skins:stall')==null)Padding(padding:const EdgeInsets.only(bottom:8),child:CozyMenuRow(
        key:const Key('settings-background'),icon:const PixelIcon('theme',size:28),iconSize:28,minHeight:52,
        title:'배경 바꾸기',subtitle:'지금: ${_backgroundName()}',
        onPressed:(){Navigator.pop(ctx);_open('skins:stall');})),
      SoundSettings(controller:account),
      CozySettingRow(icon:const PixelIcon('vibration',size:28),label:'진동',value:settings.vibration,
        onChanged:(v)=>account.updateSettings(vibration:v)),
      CozySettingRow(icon:const Icon(Icons.slow_motion_video),label:'모션 줄이기',value:settings.reduceMotion,
        onChanged:(v)=>account.updateSettings(reduceMotion:v)),
      // 26번 5-1단계: device-only notices when guests come while the app is off.
      CozySettingRow(key:const Key('settings-notify-regular'),icon:const Icon(Icons.notifications_none),label:'일반 손님 알림',
        subtitle:'앱을 꺼 둔 동안 손님이 오면 알려요',value:settings.notifyRegularGuests,onChanged:(v)=>_setNotice(regular:v)),
      CozySettingRow(key:const Key('settings-notify-named'),icon:const Icon(Icons.notifications_active_outlined),label:'단골 손님 알림',
        subtitle:'이름 있는 손님이 오면 알려요',value:settings.notifyNamedGuests,onChanged:(v)=>_setNotice(named:v)),
      if(widget.notifier case final notifier? when settings.notifyNamedGuests || settings.notifyRegularGuests)
        NoticePermissionHint(notifier:notifier,revision:_permissionChecks,
          denied:(){if(mounted)showCenterToast(context,noticeDeniedText);}),
      CozySettingRow(key:const Key('settings-quiet-night'),icon:const Icon(Icons.bedtime_outlined),label:'밤 알림 끄기 (밤 10시~아침 8시)',
        value:settings.quietNightNotices,onChanged:(v)=>_setNotice(quiet:v)),
      // 26번 5단계(DEC-046): on by default, no first-run notice; off stops
      // Firebase Analytics collection (privacy_policy.md '사용 통계'). It
      // starts only after the first-run consent (DEC-126).
      CozySettingRow(key:const Key('settings-usage-stats'),icon:const Icon(Icons.insights_outlined),label:'사용 통계 보내기',
        subtitle:'게임을 고치는 데 쓰는 사용 기록이에요(이름·계정과 연결하지 않아요)',value:settings.sendUsageStats,
        onChanged:(v)=>account.updateSettings(sendUsageStats:v)),
      const Text('배경 시간'),
      DropdownButton<String>(value:c.state.sceneTime,isExpanded:true,
        items:[for(final item in cosmeticDefinitions.where((d)=>d.slot==CosmeticSlot.time))
          DropdownMenuItem(value:item.id,child:Text(item.name))],
        onChanged:c.inputBusy ? null : (value){if(value!=null)c.setBackgroundTime(value);}),
      if(account.error!=null)Text(account.error!),
      FilledButton.icon(key:const Key('settings-save'),onPressed:account.busy ? null : () async {
        await account.save();if(ctx.mounted)Navigator.pop(ctx);
      },icon:const PixelIcon('save',size:28),label:const Text('저장')),
    ]);
  });
  /// The name of the background worn now ('맑은 날').
  String _backgroundName() {
    final id=_equipped(CosmeticSlot.background);
    return cosmeticDefinitions.where((d)=>d.slot==CosmeticSlot.background && d.id==id).firstOrNull?.name ?? id;
  }
  // Hair never picked is the character's own (26번 3차 G, avatarWorn).
  String _equipped(CosmeticSlot slot) => slot == CosmeticSlot.time ? c.state.sceneTime :
    c.state.avatarWorn(slot,widget.accountController.state.equippedCosmetic(slot));
  /// What the home draws: during a seasonal event its decoration hangs on
  /// the stall (26번 7단계, S7-Q3) without changing what is equipped.
  String _homeEquipped(CosmeticSlot slot) =>
    slot == CosmeticSlot.decoration && c.seasonalEvent != null ? c.seasonalEvent!.decoration : _equipped(slot);
  /// A small window over the stall; it closes itself when a story scene starts.
  Future<void> _popup(Key key,Widget child) async {
    _enterWindow();
    BuildContext? popupContext;
    void closeForScene() {
      final current=popupContext;
      if (c.state.customerScene != null && current != null && current.mounted) { popupContext=null; Navigator.pop(current); }
    }
    c.addListener(closeForScene);
    try {
      await showDialog<void>(context:context,builder:(ctx){
        popupContext=ctx;
        return Dialog(key:key,backgroundColor:Colors.transparent,insetPadding:const EdgeInsets.all(16),
          child:Stack(clipBehavior:Clip.none,children:[
            // 3차 피드백 H38: the close button sits inside the panel, off its
            // border, and the content keeps clear of it.
            CozyPanel(radius:20,padding:const EdgeInsets.fromLTRB(16,14,16,14),child:SingleChildScrollView(
              child:Padding(padding:const EdgeInsets.only(top:CozyCloseButton.inset),child:child))),
            Positioned(top:CozyCloseButton.edge,right:CozyCloseButton.edge,child:CozyCloseButton(onPressed:()=>Navigator.pop(ctx))),
          ]));
      });
    } finally {c.removeListener(closeForScene);_leaveWindow();}
  }
  Future<void> _customerCard(String orderId)=>_popup(const Key('customer-card'),WorkshopCustomerCard(controller:c,orderId:orderId));
  Future<void> _stock()=>_popup(const Key('stock-card'),WorkshopStockList(controller:c));
  /// 26번 7단계: the '오늘' slip's card. The seventh stamp's gold goes to
  /// the server right away when signed in, like mission gold.
  /// 3차 피드백 H36: the '오늘' window holds the attendance card, the order,
  /// the daily missions and 주간 도전 (no menu rows for them any more).
  Future<void> _daily()=>_window('오늘',(_)=>SingleChildScrollView(key:const Key('today-scroll'),
    padding:const EdgeInsets.fromLTRB(12,4,12,14),
    child:WorkshopDailyCard(key:const Key('daily-card'),controller:c,onClaimMission:_claimMission,onGoldClaim:() async {
      if(widget.accountController.online.signedIn && await c.syncRewards()) await widget.accountController.refreshWorkshopWallet();
    })));
  /// '보상 받기' on a mission: a claim for server verification, handed over
  /// right away when signed in.
  Future<void> _claimMission(String scope,String goal) async {
    final missions=c.state.missions;
    final ok=await c.claimMission(scope,goal,expectedPeriod:scope=='daily' ? missions.day:missions.week);
    if(ok && widget.accountController.online.signedIn && await c.syncRewards()) await widget.accountController.refreshWorkshopWallet();
  }
  /// 공유 카드(26번 8단계, DEC-048): the card, '공유하기' and nothing else
  /// (no reward, no state change).
  Future<void> _shareCard(ShareCardData data) async {
    _enterWindow();
    try {await showShareCardDialog(context,data:data,texts:ShareCardTexts.of(c.config),usage:c.usage);}
    finally {_leaveWindow();}
  }
  /// What the stall and the vendor wear in a share card: the home's look.
  Map<String,String> get _shareLook => {for(final slot in CosmeticSlot.values)slot.name:_homeEquipped(slot)};
  void _sharePerfect(ResultLook look) {
    final session=c.state.session;
    if(session==null) return;
    final reaction=c.resultReaction(look.grade);
    final orderId=c.resultReactionOrderId;
    final order=orderId==null ? null : c.state.customers.where((o)=>o.id==orderId).firstOrNull;
    final split=reaction?.indexOf(': ') ?? -1;
    unawaited(_shareCard(ShareCardData(moment:ShareMoment.perfect,title:'${c.flavorLabel(session.flavor)} 붕어빵',
      speaker:split>0 ? reaction!.substring(0,split) : null,
      line:split>0 ? reaction!.substring(split+2) : cookingGradeLine(c.config,session,look.grade,variant:look.variant),
      guestArt:order==null ? null : c.guestArtId(order.customerId),variant:look.variant,shine:true,equipped:_shareLook)));
  }
  void _shareStory(String npc,String title,String? scene) {
    // One spoken line of the scene ('수아: 저 이제 …'), not the owner's
    // and not the '완료 처리' note; the guest's own name when there is none.
    final spoken=[for(final row in (scene ?? '').split('\n'))
      if(RegExp(r'^([^:#\s][^:]{0,15}): (.+)$').firstMatch(row.trim()) case final m?
          when m.group(1)!='사장님' && m.group(1)!='완료 처리') (m.group(1)!,m.group(2)!)];
    final name=c.customerShortName(npc);
    unawaited(_shareCard(ShareCardData(moment:ShareMoment.story,title:title,
      speaker:spoken.isEmpty ? null : spoken.first.$1,
      line:spoken.isEmpty ? '$name의 이야기를 들었어요.' : spoken.first.$2,
      guestArt:c.guestArtId(npc),equipped:_shareLook)));
  }
  void _shareCollection(String flavor)=>unawaited(_shareCard(ShareCardData(moment:ShareMoment.collection,
    title:'${c.flavorLabel(flavor)} 붕어빵 도감',line:'다섯 가지 익힘을 모두 완성했어요.',
    variant:3,equipped:_shareLook)));
  void _sharePhoto()=>unawaited(_shareCard(ShareCardData(moment:ShareMoment.shop,title:'우리 가게',
    line:c.seasonalEvent?.greeting ?? '따끈한 붕어빵 구워 놓고 기다릴게요!',equipped:_shareLook)));
  Map<String,int> _rewardCounts(){
    final m=c.state.missions;
    int ready(String scope)=>[...m.goals(c.config,scope).keys,if(scope=='daily')'all'].where((id)=>
      m.complete(c.config,scope,id) && !m.claims.containsKey(m.claimKey(scope,id))).length;
    return {'daily':ready('daily'),'event':ready('weekly'),'missions':c.canLevelUp ? 1:0};
  }
  Future<void> _menu()=>_window('메뉴',(ctx)=>Column(children:[
    // 26번 2-1단계: where the owner name shows.
    if(widget.owner?.profile.name case final name?)Padding(padding:const EdgeInsets.only(top:6),
      child:Text(OwnerTexts.shopOf(name),key:const Key('menu-owner-name'),style:const TextStyle(fontSize:18,color:Cozy.wood))),
    // 4차 피드백 g6: the titles of collected flavors, under the shop's name.
    if(c.collectionTitles.isNotEmpty)Text('칭호 · ${c.collectionTitles.join(' · ')}',key:const Key('menu-owner-title'),
      textAlign:TextAlign.center,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(0xffa86a00))),
    Expanded(child:MenuPanel(controller:widget.accountController,legacyDescriptions:false,rewardCounts:_rewardCounts(),
      // 일일 미션·주간 도전 live in the '오늘' window (H36). 도감 shows even
      // before it opens, with its level (H32).
      hidden:{'ranking','friends','share','daily','event',
        for(final d in ['skins:stall']) if(_lockFor(d)!=null) d},
      locks:{if(_lockFor('achievements:collection') case final lock?)'achievements:collection':lock},
      onOpen:(destination){Navigator.pop(ctx);_open(destination);})),
    Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      Text('황금붕어빵력 심사 대기 ${c.pendingRewardCount}건. 확정 잔액에는 아직 포함되지 않아요.',
        key:const Key('menu-pending-gold'),style:const TextStyle(fontSize:12,color:Cozy.inkSoft),textAlign:TextAlign.center),
      const SizedBox(height:6),
      Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:6,children:[
        CozyButton(key:const Key('menu-sync'),onPressed:c.rewardBusy || c.adBusy ? null : _syncOnline,label:'로그인·보상 확인',minHeight:40,fontSize:15),
        if(c.state.business.open)CozyButton(key:const Key('menu-close-business'),minHeight:40,fontSize:15,
          onPressed:c.inputBusy ? null : (){Navigator.pop(ctx);_closeBusiness();},label:'영업 종료'),
      ]),
    ])),
  ]));
  /// Why [destination] is still closed (26번 2단계), or null.
  String? _lockFor(String destination) => switch(destination) {
    'skills' => c.featureLock(WorkshopFeature.skills),
    'shop' || 'skins' || 'skins:avatar' => c.featureLock(WorkshopFeature.wardrobe),
    'skins:stall' => c.featureLock(WorkshopFeature.wardrobe) ?? c.featureLock(WorkshopFeature.stallBackground),
    'achievements:collection' => c.featureLock(WorkshopFeature.collection),
    _ => null,
  };
  void _open(String destination) {
    // 도감 opens before its level to show what is coming (H32).
    if(destination!='achievements:collection')if(_lockFor(destination) case final reason?) {
      showCenterToast(context,reason);
      return;
    }
    switch(destination) {
      case 'menu': unawaited(_menu());
      case 'skills': unawaited(_shop());
      case 'shop': unawaited(_store());
      case 'skins': case 'skins:avatar': unawaited(_wardrobe());
      case 'skins:stall': unawaited(_wardrobe(tab:WardrobeTab.stall,slot:CosmeticSlot.background));
      case 'settings': unawaited(_audioSettings());
      case 'records': case 'balance': unawaited(_window('생산 기록',(_)=>_records()));
      case 'achievements:collection': unawaited(_window('도감',(_)=>_collection()));
      case 'achievements': unawaited(_window('업적',(_)=>_achievements()));
      case 'daily': case 'event': unawaited(_daily());
      case 'missions': unawaited(_window('레벨 미션',(_)=>_levelMissions()));
      case 'gold': unawaited(_goldPacks());
      case 'photo': _sharePhoto();
    }
  }
  /// 생산 기록 (3차 피드백 H44·H45): icon + number tiles.
  Widget _records()=>WorkshopRecordsView(tiles:WorkshopRecordsView.of(level:c.state.level,buns:c.state.buns,
    lifetime:c.state.lifetime,taps:c.state.taps,sales:c.state.completedSales,tapRate:c.tapRate,autoRate:c.autoRate,
    mastered:c.collectionTitles.length,businessDays:c.state.business.businessIndex));
  CollectionFlavor _collectionFlavor(String flavor){
    if(!c.state.recipes.contains(flavor)){
      final tier=DevelopmentBalance.integer(c.config.section('active_recipes')[flavor] as Map<String,dynamic>,'acquisition_tier');
      final need=c.config.rows('additional_recipe_acquisition_tiers').where((r)=>r['tier']==tier).firstOrNull;
      return CollectionFlavor(id:flavor,label:c.flavorLabel(flavor),owned:false,found:const {},
        required:collectionRequired(c.config,flavor),
        howToGet:need==null ? null : 'Lv.${need['unlock_level']}에 판매 ${need['mission_sales']}번을 채우면 레벨 미션에서 얻어요.');
    }
    // 4차 피드백 g6: each cell counts its bakes to the number that completes it.
    final progress=c.state.collection(c.config,flavor);
    return CollectionFlavor(id:flavor,label:c.flavorLabel(flavor),owned:true,
      found:{for(var i=0;i<provisionalDonenessLabels.length;i++)
        if(progress.found(i) || (flavor=='redbean' && i==2))i},
      counts:progress.counts,required:progress.required,
      title:progress.collected ? collectionTitle(c.config,flavor) : null,
      legacyMastered:c.state.masteryAwards.containsKey(flavor));
  }
  /// 붕어빵 도감 (3차 피드백 H32): every flavor's five donenesses as
  /// pictures, shown dimmed under its level note before it opens.
  Widget _collection(){
    final unlocks=c.config.section('feature_unlock_levels');
    final open=c.state.level>=DevelopmentBalance.integer(unlocks,'full_recipe_collection_ui');
    return WorkshopCollectionView(
      flavors:[for(final flavor in c.config.section('active_recipes').keys)_collectionFlavor(flavor)],
      lockText:open ? null : '도감은 Lv.${unlocks['full_recipe_collection_ui']}에 열려요. 익힘마다 정해진 횟수를 구워 칸을 채워 보세요.',
      titles:c.collectionTitles,
      onShare:_shareCollection,
      extra:[
        if(c.state.level>=DevelopmentBalance.integer(unlocks,'customer_collection_ui'))...[
          if(c.state.tasteObservations.isNotEmpty || c.state.relationships.stories.isNotEmpty)const Divider(),
          for(final story in c.state.relationships.stories)CozyButton(key:Key('replay-$story'),minHeight:40,fontSize:15,
            onPressed:c.inputBusy ? null : (){Navigator.pop(context);c.replayCustomerStory(story);},
            label:'${c.customerCatalog.story(story)['event']} (다시 보기)'),
          for(final customer in c.state.tasteObservations.entries)
            if(c.customerCatalog.contains(customer.key))CustomerRecordCard(
              catalog:c.customerCatalog,npcId:customer.key,met:c.state.relationships.met.contains(customer.key),
              completedStories:c.state.relationships.stories,
              stageLabel:const ['첫 만남','낯익은 손님','동네 단골','가까운 이웃'][c.state.relationships.stage(customer.key,c.config)],
              observedPreferences:[for(final e in customer.value.entries)
                '${c.flavorLabel(e.key)} ${e.value.map((v)=>provisionalDonenessLabels[v]).join('/')}'])
            else ListTile(title:Text(c.customerName(customer.key)),
              subtitle:Text(customer.value.entries.map((e)=>'${c.flavorLabel(e.key)} ${e.value.map((v)=>provisionalDonenessLabels[v]).join('/')}').join(', '))),
        ],
      ]);
  }
  Widget _achievements()=>ListView(padding:const EdgeInsets.all(16),children:[
    // 4차 피드백 g6: a flavor's achievement is its full 도감 (and its title).
    for(final flavor in c.state.recipes)CozyPanel(child:ListTile(leading:const PixelIcon('achievements'),title:Text('${c.flavorLabel(flavor)} 도감 완성'),
      subtitle:Text('완성 ${c.state.collection(c.config,flavor).completedCells}/5 · 칭호 「${collectionTitle(c.config,flavor)}」'),
      trailing:Text(c.state.collection(c.config,flavor).collected ? '달성':'진행 중'))),
  ]);
  /// 레벨 미션, in the same cards as the '오늘' window (3차 피드백: like
  /// H34·H45, readable rows with bars instead of one long line).
  Widget _levelMissions(){
    final s=c.state,top=s.level>=50;
    final row=top ? null : c.config.rows('level_progression')[s.level];
    Widget bar(String label,BigInt current,BigInt target,{Key? key})=>Padding(key:key,padding:const EdgeInsets.only(top:8),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Cozy.ink))),
          Text('${compactNumber(current>target ? target:current)}/${compactNumber(target)}',
            style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Cozy.inkSoft))]),
        const SizedBox(height:3),
        ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(minHeight:7,
          value:target==BigInt.zero ? 1 : ((current>target ? target:current)*BigInt.from(1000)~/target).toInt()/1000,
          backgroundColor:const Color(0xfff3e4cf),color:current>=target ? const Color(0xff3f9b5a):Cozy.tangerine)),
      ]));
    return ListView(padding:const EdgeInsets.fromLTRB(12,4,12,14),children:[
      TodaySection(icon:const PixelIcon('star',size:26),title:'Lv.${s.level}',
        trailing:Text(top ? '최고 레벨' : '다음 Lv.${s.level+1}',style:const TextStyle(fontFamily:'Jua',fontFamilyFallback:Cozy.fontFallback,fontSize:14,color:Cozy.inkSoft)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          if(top)const Text('최고 레벨에 도달했어요.')
          else ...[
            bar('누적 붕어빵력',s.lifetime,BigInt.parse('${row!['season_total_buns']}')),
            bar('이번 레벨 탭',BigInt.from(s.taps-s.levelStartTaps),BigInt.from(DevelopmentBalance.integer(row,'additional_taps'))),
            bar('이번 레벨 판매',BigInt.from(s.completedSales-s.levelStartSales),BigInt.from(DevelopmentBalance.integer(row,'additional_sales'))),
          ],
          const SizedBox(height:10),
          CozyPrimaryButton(minHeight:40,fontSize:16,label:'승급',onPressed:c.inputBusy || !c.canLevelUp ? null:c.levelUp),
        ])),
      for(final flavor in ['custard','cocoa'])
        if(!s.recipes.contains(flavor))Builder(builder:(context){
          final tier=DevelopmentBalance.integer(c.config.section('active_recipes')[flavor] as Map<String,dynamic>,'acquisition_tier');
          final requirement=c.config.rows('additional_recipe_acquisition_tiers').firstWhere((r)=>r['tier']==tier);
          final level=DevelopmentBalance.integer(requirement,'unlock_level');
          final ready=s.level>=level && s.completedSales>=DevelopmentBalance.integer(requirement,'mission_sales');
          return Padding(padding:const EdgeInsets.only(top:10),child:TodaySection(key:Key('recipe-mission-$flavor'),
            icon:const PixelIcon('mission',size:26),title:'${c.flavorLabel(flavor)} 레시피 미션',
            trailing:Text('Lv.$level부터',style:const TextStyle(fontFamily:'Jua',fontFamilyFallback:Cozy.fontFallback,fontSize:14,color:Cozy.inkSoft)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              bar('판매',BigInt.from(s.completedSales),BigInt.from(DevelopmentBalance.integer(requirement,'mission_sales'))),
              const SizedBox(height:10),
              CozyPrimaryButton(minHeight:36,fontSize:15,label:'레시피 받기',
                onPressed:c.inputBusy || !ready ? null : ()=>c.claimRecipeFromMission(flavor)),
            ])));
        }),
    ]);
  }
  int _levelProgress() {
    final s=c.state;
    if(s.level>=50)return 1000;
    final row=c.config.rows('level_progression')[s.level];
    final total=BigInt.parse('${row['season_total_buns']}');
    int fraction(int current,int required)=>required<=0 ? 1000 : (current*1000~/required).clamp(0,1000);
    final values=[total==BigInt.zero ? 1000 : (s.lifetime*BigInt.from(1000)~/total).toInt().clamp(0,1000),
      fraction(s.taps-s.levelStartTaps,DevelopmentBalance.integer(row,'additional_taps')),
      fraction(s.completedSales-s.levelStartSales,DevelopmentBalance.integer(row,'additional_sales'))];
    return values.reduce((a,b)=>a<b ? a:b);
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation:Listenable.merge([c,widget.accountController]),
    builder:(context,_)=>_content(context));
  Widget _content(BuildContext context) {
    _showAwayReport();
    _showCollectionNews();
    _showFeatureIntro();
    _askNotifications();
    final s = c.state;
    final scene=s.customerScene;
    if(scene!=null) {
      final id=scene['id'] as String,npc=scene['npc'] as String;
      Widget content;
      if(scene['kind']=='choice') {
        content=CustomerChoicePanel(catalog:c.customerCatalog,eventId:id,
          completedStories:s.relationships.stories,choiceOrder:List<String>.from(scene['order'] as List),
          selected:s.relationships.active?['choice'] as String?,
          onSelect:c.respondToCustomer,onCloseReaction:c.finishCustomerScene);
      } else {
        final definition=['story','replay'].contains(scene['kind']) ? c.customerCatalog.story(id) : c.customerCatalog.choice(id);
        content=Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(c.customerName(npc)),
          Text(['story','replay'].contains(scene['kind']) ? definition['event'] as String :
            (definition['followups'] as Map<String,dynamic>)[scene['choice']] as String),
          if(['story','replay'].contains(scene['kind']) && definition['scene'] is String) Text(definition['scene'] as String),
          if(c.notice!=null) Text(c.notice!),if(c.error!=null) Text(c.error!),
          FilledButton(onPressed:c.inputBusy || c.error!=null ? null : c.finishCustomerScene,child:const Text('대화 마치기')),
          // 26번 8단계: a story's end can be shown off (no reward).
          if(['story','replay'].contains(scene['kind']))TextButton.icon(key:const Key('story-share'),
            onPressed:()=>_shareStory(npc,definition['event'] as String,definition['scene'] as String?),
            icon:const Icon(Icons.ios_share),label:const Text('자랑하기')),
        ]);
      }
      return Scaffold(appBar:AppBar(title:const Text('이웃 이야기')),
        body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:content)));
    }
    final step=workshopTutorialStep(s,ready:s.customers.isEmpty ? 0 : c.saleReadyCount(s.customers.first));
    final reduceMotion=widget.accountController.state.settings.reduceMotion;
    // The guests-at-the-stall layout once every lowered background is in
    // (26번 4-1단계, S4-1-Q4); the old left line until then.
    final low=WorkshopHomeLayout.active;
    final home=NightHome(key:_homeKey,controller:widget.accountController,onOpen:_open,
      equipped:_homeEquipped,headerData:NightHomeHeaderData(level:s.level,progressPermille:_levelProgress(),
        buns:s.buns,lifetime:s.lifetime,autoRate:c.autoRate,tapRate:c.tapRate,claimable:_rewardCounts()['missions']!,
        // The guests show themselves now: no '· 주문 N' (F7).
        status:c.error!=null ? '저장 확인 필요' : s.business.open ? '영업 중' : '영업 준비',
        statusKind:c.error!=null ? WorkshopStatusKind.error : s.business.open ? WorkshopStatusKind.open : WorkshopStatusKind.preparing,
        showRates:c.featureIsOpen(WorkshopFeature.skills),
        // 황금붕어빵력 beside 붕어빵력 (26번 3차 피드백 H30).
        gold:BigInt.from(widget.accountController.state.premium.gold)),
      // The menu is only in the bottom bar (H28); the special bungeoppang's
      // flavor takes the top-left slot (H26).
      hudLeading:WorkshopFlavorButton(controller:c),
      navLocks:{for(final id in const ['skills','skins','shop']) if(_lockFor(id) case final reason?) id:reason},
      lowStall:low,
      guests:(clicker,taps)=>WorkshopGuestLayer(controller:c,onOpenCustomer:_customerCard,taps:taps,clicker:clicker,
        reduceMotion:reduceMotion || MediaQuery.disableAnimationsOf(context)),
      centerBuilder:(fish,clean,counterTop,moldLimit)=>Stack(children:[
        Positioned.fill(child:WorkshopMoldStage(controller:c,fishOnScreen:fish,cleanCounter:clean,counterTop:counterTop,moldLimit:moldLimit,
          lowStall:low,reduceMotion:reduceMotion,onSharePerfect:_sharePerfect,
          vibration:widget.accountController.state.settings.vibration)),
        // The old layout: below the flavor row, clear of the counter strip.
        if(!low)Positioned(left:2,top:48,bottom:56,width:64,child:WorkshopCustomerQueue(controller:c,onOpenCustomer:_customerCard)),
      ]),
      counter:WorkshopSaleCounter(controller:c,onOpenStock:_stock,onCloseBusiness:_closeBusiness),
      // The '오늘' slip (오늘의 주문서·출석, 26번 7단계) under the settings
      // button (시안 확인 2차).
      counterSlip:WorkshopDailyTicket(controller:c,onOpen:_daily,
        claimable:_rewardCounts()['daily']!+_rewardCounts()['event']!),
      counterAction:WorkshopCounterAction(controller:c,onCloseBusiness:_closeBusiness),
      // '영업 시작'·'영업 종료' small beside the '영업 중' sign (시안 확인 2차).
      statusAction:WorkshopBusinessButton(controller:c,onCloseBusiness:_closeBusiness),
      griddleContent:WorkshopGriddleLayer(controller:c,stove:_equipped(CosmeticSlot.stove)),
      // The griddle art is empty; only cooking cells show a bungeoppang, and
      // none before opening (24번 4단계).
      griddleFilled:workshopGriddleFilled(c),
      // Closed and cold before opening and while locked; open with the
      // flames on once it can be used (26번 4-2단계 F8).
      griddleOpen:workshopGriddleOpen(c),
      vendor:CookCut(equipped:_equipped,taps:BigInt.from(s.taps),
        reduceMotion:reduceMotion,greeting:s.customers.isNotEmpty));
    final praise=c.salePraise;
    // 26번 3차 H6: the story first, then the guide's card.
    final chapter=workshopStoryChapter(s);
    final story=chapter!=null && !_storySeen.contains(chapter) ? chapter : null;
    return Stack(children:[home,if(story!=null)Positioned.fill(child:WorkshopStoryOverlay(key:ValueKey(story),
      lines:workshopStoryLines(story,widget.accountController.ownerName),action:workshopStoryAction(story),
      reduceMotion:reduceMotion || MediaQuery.disableAnimationsOf(context),
      onDone:()=>setState(()=>_storySeen.add(story))))
    else if(step!=null)Positioned.fill(child:WorkshopTutorialOverlay(step:step,home:_homeKey,
      cardLeft:WorkshopHomeLayout.guideLeft(low),
      onSkip:c.inputBusy || c.error!=null ? null : c.skipTutorial)),
      if(praise!=null)Positioned.fill(child:WorkshopSalePraiseBanner(key:ObjectKey(praise),praise:praise,
        reduceMotion:widget.accountController.state.settings.reduceMotion || MediaQuery.disableAnimationsOf(context),
        onDone:c.dismissSalePraise))]);
  }
}
