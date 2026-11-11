import '../cooking_result_rules.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../cooking_input.dart';
import '../cooking_sensor_input.dart';
import '../cooking_tilt_source.dart';
import '../development_balance.dart';
import '../game_controller.dart';
import '../workshop_controller.dart';
import '../cosmetic_config.dart';
import '../workshop_purchases.dart';
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
import 'workshop_guide.dart';
import '../workshop_tutorial.dart';
import 'friends_panel.dart';
import 'ranking_panel.dart';
import 'progress_panels.dart' show SharePanel;

class WorkshopPage extends StatefulWidget {
  final WorkshopController controller;
  final GameController accountController;
  const WorkshopPage({super.key, required this.controller, required this.accountController});
  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}
class _WorkshopPageState extends State<WorkshopPage> with WidgetsBindingObserver {
  WorkshopController get c => widget.controller;
  StreamSubscription<CookingTiltSample>? _sensor;
  late TiltDirectionGate _gate;
  bool _sensorEnabled = false;
  late CookingSensorInput _sensorInput;
  int _sensorGeneration = 0;
  final Stopwatch _sensorClock = Stopwatch()..start();
  int _windowCount=0;
  final _homeKey=GlobalKey();
  bool _awayShowing=false;
  /// The welcome-back card, once per report, after the frame that noticed it.
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
  void _enterWindow(){_windowCount++;c.gridVisible=false;}
  void _leaveWindow(){_windowCount--;c.gridVisible=_windowCount==0;}
  Future<void> _window(String title,Widget Function(BuildContext) content) async {
    _enterWindow();
    try {await showWorkshopWindow(context,controller:c,account:widget.accountController,title:title,content:content);}
    finally {_leaveWindow();}
  }
  String? _sensorNotice;
  String _sensorStatus = '현재 자세를 보정 중이에요';
  @override
  void initState() { super.initState(); _gate = TiltDirectionGate.fromBalance(c.config); _sensorInput = CookingSensorInput(_gate); WidgetsBinding.instance.addObserver(this); c.addListener(_cancelPausedInput); }
  void _cancelPausedInput() {
    if(!c.gameplayPaused) return;
    _sensorInput.reset();
  }
  @override
  void didUpdateWidget(covariant WorkshopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.controller!=widget.controller) {
      oldWidget.controller.removeListener(_cancelPausedInput);c.addListener(_cancelPausedInput);
      _gate=TiltDirectionGate.fromBalance(c.config);_sensorInput=CookingSensorInput(_gate);
    }
  }
  Future<void> _setSensor(bool enabled) async {
    final generation = ++_sensorGeneration;
    final subscription = _sensor; _sensor = null;
    _sensorInput.reset();
    await subscription?.cancel();
    if (!mounted || generation != _sensorGeneration) return;
    setState(() { _sensorEnabled = enabled; _sensorNotice = null; _sensorStatus = '현재 자세를 보정 중이에요'; });
    if (!enabled) return;
    _sensor = CookingTiltSource().samples(c.config).listen((sample) {
      if (!mounted || !_sensorEnabled || generation != _sensorGeneration) return;
      if (!sample.available) {
        _sensorInput.reset();
        setState(() { _sensorEnabled = false; _sensorNotice = '큰 틀을 길게 눌러 반죽을 부어 주세요.'; }); return;
      }
      if(c.gameplayPaused) { _sensorInput.reset(); return; }
      if(c.cookingInputBlocked) { _sensorInput.interrupt(); return; }
      final session = c.state.session;
      if (session == null || session.finished) { _sensorInput.reset(); return; }
      final next = _sensorInput.sample(session, sample.angleMillidegrees!, _sensorClock.elapsedMilliseconds);
      final status = _sensorInput.pouring ? '붓는 중 · 제자리로 돌아오면 멈춰요' :
        _sensorInput.waitingNeutral ? '처음 자세로 돌아와 주세요' : '준비 · 좌우로 기울여 주세요';
      if (_sensorStatus != status) {
        assert(() { debugPrint('STEP02_SENSOR $status angle=${sample.angleMillidegrees}'); return true; }());
        setState(() => _sensorStatus = status);
      }
      if (next != null) unawaited(c.cookingCommand(next));
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_setSensor(false));
  }
  @override
  void dispose() { c.removeListener(_cancelPausedInput); _sensorGeneration++; _sensor?.cancel(); _sensorInput.reset(); _sensorClock.stop(); _gate.reset(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _closeBusiness() async {
    _enterWindow();
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('오늘 영업을 끝낼까요?'),
        content: const Text('대기 손님은 돌아가고 진행 중인 큰 틀 제작은 취소돼요. 보관한 재고와 숙련 기록은 남고, 6구는 멈춘 상태로 보관돼요.'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message ?? '로그인 후 확인할 수 있어요.')));return;
    }
    await c.syncRewards();
    if (!mounted) return;
    await c.recoverAds();
    if (!mounted) return;
    final walletMessage=await account.refreshWorkshopWallet();
    if (mounted && walletMessage!=null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(walletMessage)));
  }
  CosmeticMenuAccess get _cosmetics {
    final account=widget.accountController,catalog=c.config.section('avatar_catalog');
    bool avatar(CosmeticDefinition d)=>catalog[d.id] is Map<String,dynamic> && (catalog[d.id] as Map)['slot']==d.slot.name;
    bool owned(CosmeticDefinition d)=>d.slot==CosmeticSlot.time || (avatar(d) ? c.ownsAvatar(d.id):account.state.ownsCosmetic(d));
    bool unlocked(CosmeticDefinition d)=>d.slot==CosmeticSlot.time || (avatar(d) ? owned(d) || c.state.level>=DevelopmentBalance.integer(catalog[d.id] as Map<String,dynamic>,'unlock_level') &&
      c.state.lifetime>=DevelopmentBalance.decimal(catalog[d.id] as Map<String,dynamic>,'unlock_total'):cosmeticUnlocked(account.state,d));
    String price(CosmeticDefinition d){
      if(owned(d))return '보유 중';
      if(!avatar(d))return '판매 준비 중';
      final quote=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
      return '붕어빵력 ${compactNumber(quote.buns)} + 황금붕어빵력 ${compactNumber(quote.gold)}';
    }
    bool canApply(CosmeticDefinition d){
      if(c.busy || c.purchaseBusy || c.error!=null || account.busy || _equipped(d.slot)==d.id || !unlocked(d))return false;
      if(owned(d))return true;
      if(!avatar(d) || c.purchaseGateway==null)return false;
      final q=quoteWorkshopProduct(c.config,'cosmetic:${d.id}',owned:0,quantity:1);
      return q.affordable(c.state.purchases.available(c.state.buns),BigInt.from(account.state.premium.gold));
    }
    return CosmeticMenuAccess(equipped:_equipped,owned:owned,unlocked:unlocked,canApply:canApply,price:price,
      requirement:(d)=>avatar(d) ? '해금 Lv.${(catalog[d.id] as Map)['unlock_level']} · 누적 ${(catalog[d.id] as Map)['unlock_total']}' : '',
      action:(d)=>_equipped(d.slot)==d.id ? '장착 중':!unlocked(d) ? '잠김':owned(d) ? '적용':!avatar(d) ? '준비 중':'구매하고 적용',
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
  Future<void> _wardrobe({WardrobeTab tab=WardrobeTab.hair})=>_window('꾸미기',(_)=>WardrobePanel(
    controller:widget.accountController,access:_cosmetics,initialTab:tab));
  Future<void> _store()=>_window('상점',(_)=>ShopPanel(controller:widget.accountController,
    access:_cosmetics,onOpen:_open));
  Future<void> _goldPacks() async {
    _enterWindow();
    try {
      final account = widget.accountController;
      final message = await account.signInOnline();
      if (!mounted) return;
      if (message != null || !account.online.signedIn) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? '로그인 후 이용할 수 있어요.')));
        return;
      }
      final packs = await account.goldPacks();
      if (!mounted) return;
      await showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: ListView(
        shrinkWrap: true, children: [const ListTile(title: Text('황금붕어빵력 충전'), subtitle: Text('실제 결제 상품이에요.')),
        if (packs.isEmpty) const ListTile(title: Text('지금은 결제 상품을 불러올 수 없어요.')),
        for (final pack in packs) ListTile(title: Text(pack.title), subtitle: Text(pack.price),
          trailing: FilledButton(onPressed: () async {
            Navigator.pop(context);
            final error = await account.buyGoldPack(pack.id);
            if (mounted && error != null) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(error)));
          }, child: const Text('구매'))),
      ])));
    } finally { _leaveWindow(); }
  }
  Future<void> _audioSettings()=>_window('설정',(ctx){
    final account=widget.accountController,settings=account.state.settings;
    return ListView(padding:const EdgeInsets.all(12),children:[
      SoundSettings(controller:account),
      CozySettingRow(icon:const PixelIcon('vibration',size:28),label:'진동',value:settings.vibration,
        onChanged:(v)=>account.updateSettings(vibration:v)),
      CozySettingRow(icon:const Icon(Icons.slow_motion_video),label:'모션 줄이기',value:settings.reduceMotion,
        onChanged:(v)=>account.updateSettings(reduceMotion:v)),
      const Text('배경 시간'),
      DropdownButton<String>(value:c.state.sceneTime,isExpanded:true,
        items:[for(final item in cosmeticDefinitions.where((d)=>d.slot==CosmeticSlot.time))
          DropdownMenuItem(value:item.id,child:Text(item.name))],
        onChanged:c.busy ? null : (value){if(value!=null)c.setBackgroundTime(value);}),
      if(account.error!=null)Text(account.error!),
      FilledButton.icon(key:const Key('settings-save'),onPressed:account.busy ? null : () async {
        await account.save();if(ctx.mounted)Navigator.pop(ctx);
      },icon:const PixelIcon('save',size:28),label:const Text('저장')),
    ]);
  });
  Widget _mission(String scope,String id,{Map<String,dynamic>? rule}) {
    final missions=c.state.missions,key=missions.claimKey(scope,id),claimed=missions.claims.containsKey(key);
    final gold=DevelopmentBalance.integer(c.config.section('mission_gold_rewards'),rule?['reward_key'] as String? ?? 'daily_all');
    final caption=rule==null ? '일일 미션 전체 완료' : rule['label'] as String;
    final current=rule==null ? '' : '${missions.progress(scope,rule['metric'] as String)}/${rule['target']} · ';
    return ListTile(title:Text(caption),subtitle:Text('$current황금붕어빵력 $gold · 서버 검증 후 지급'),
      trailing:TextButton(onPressed:c.busy || claimed || !missions.complete(c.config,scope,id) ? null :
        () async {
          final ok=await c.claimMission(scope,id,expectedPeriod:scope=='daily' ? missions.day:missions.week);
          // Already signed in: hand the claim to server verification right away.
          if(ok && widget.accountController.online.signedIn && await c.syncRewards()) await widget.accountController.refreshWorkshopWallet();
        },child:Text(claimed ? '신청 완료' : '보상 신청')));
  }
  String _equipped(CosmeticSlot slot) => slot == CosmeticSlot.time ? c.state.sceneTime :
    c.state.avatarEquipment[slot.name] ?? widget.accountController.state.equippedCosmetic(slot);
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
            CozyPanel(padding:const EdgeInsets.fromLTRB(16,14,16,14),child:SingleChildScrollView(child:child)),
            Positioned(top:-10,right:-8,child:CozyCloseButton(onPressed:()=>Navigator.pop(ctx))),
          ]));
      });
    } finally {c.removeListener(closeForScene);_leaveWindow();}
  }
  Future<void> _customerCard(String orderId)=>_popup(const Key('customer-card'),WorkshopCustomerCard(controller:c,orderId:orderId));
  Future<void> _stock()=>_popup(const Key('stock-card'),WorkshopStockList(controller:c));
  Map<String,int> _rewardCounts(){
    final m=c.state.missions;
    int ready(String scope)=>[...m.goals(c.config,scope).keys,if(scope=='daily')'all'].where((id)=>
      m.complete(c.config,scope,id) && !m.claims.containsKey(m.claimKey(scope,id))).length;
    return {'daily':ready('daily'),'event':ready('weekly'),'missions':c.canLevelUp ? 1:0};
  }
  Future<void> _menu()=>_window('메뉴',(ctx)=>Column(children:[
    Expanded(child:MenuPanel(controller:widget.accountController,legacyDescriptions:false,rewardCounts:_rewardCounts(),
      onOpen:(destination){Navigator.pop(ctx);_open(destination);})),
    Padding(padding:const EdgeInsets.all(8),child:Column(children:[
      Text('황금붕어빵력 심사 대기 ${c.pendingRewardCount}건. 확정 잔액에는 아직 포함되지 않아요.',
        key:const Key('menu-pending-gold'),style:const TextStyle(fontSize:12,color:Cozy.inkSoft),textAlign:TextAlign.center),
      const SizedBox(height:6),
      Wrap(alignment:WrapAlignment.center,spacing:8,runSpacing:6,children:[
        CozyButton(key:const Key('menu-sync'),onPressed:c.rewardBusy || c.adBusy ? null : _syncOnline,label:'로그인·보상 확인',minHeight:40,fontSize:15),
        if(c.state.business.open)CozyButton(key:const Key('menu-close-business'),minHeight:40,fontSize:15,
          onPressed:c.busy ? null : (){Navigator.pop(ctx);_closeBusiness();},label:'영업 종료'),
      ]),
    ])),
  ]));
  void _open(String destination) {
    switch(destination) {
      case 'menu': unawaited(_menu());
      case 'skills': unawaited(_shop());
      case 'shop': unawaited(_store());
      case 'skins': case 'skins:avatar': unawaited(_wardrobe());
      case 'skins:stall': unawaited(_wardrobe(tab:WardrobeTab.stall));
      case 'settings': unawaited(_audioSettings());
      case 'ranking': unawaited(_window('온라인 랭킹',(_)=>RankingPanel(controller:widget.accountController)));
      case 'friends': unawaited(_window('친구',(_)=>FriendsPanel(controller:widget.accountController,showRewardDetails:false)));
      case 'share': unawaited(_window('게임 공유',(_)=>SharePanel(controller:widget.accountController)));
      case 'records': case 'balance': unawaited(_window('생산 기록',(_)=>_records()));
      case 'achievements:collection': unawaited(_window('도감',(_)=>_collection()));
      case 'achievements': unawaited(_window('업적',(_)=>_achievements()));
      case 'daily': unawaited(_window('일일 미션',(_)=>_missions('daily')));
      case 'event': unawaited(_window('주간 도전',(_)=>_missions('weekly')));
      case 'missions': unawaited(_window('레벨 미션',(_)=>_levelMissions()));
      case 'gold': unawaited(_goldPacks());
    }
  }
  Widget _records()=>ListView(key:const Key('records-scroll'),padding:const EdgeInsets.all(16),children:[
    const Text('이 기기 기록'),
    for(final row in [('레벨','${c.state.level}'),('붕어빵력','${c.state.buns}'),('누적 생산','${c.state.lifetime}'),
      ('누적 탭','${c.state.taps}'),('판매 횟수','${c.state.completedSales}'),('클릭당','${c.tapRate}'),('초당','${c.autoRate}'),
      ('숙련한 맛','${c.state.masteryAwards.length}'),('실제 영업일','${c.state.business.businessIndex}')])
        Padding(padding:const EdgeInsets.only(bottom:8),child:CozyPanel(child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(row.$1),Text(row.$2)]))),
  ]);
  Widget _collection()=>ListView(padding:const EdgeInsets.all(16),children:[
    if(c.state.level<DevelopmentBalance.integer(c.config.section('feature_unlock_levels'),'full_recipe_collection_ui'))
      Text('맛 도감은 Lv.${c.config.section('feature_unlock_levels')['full_recipe_collection_ui']}부터 열려요.')
    else for(final flavor in c.state.recipes) ...[
      Text(c.flavorLabel(flavor),style:Theme.of(context).textTheme.titleLarge),
      Wrap(spacing:6,children:[for(var i=0;i<5;i++)Chip(label:Text('${c.state.flavorMasteries[flavor]?.discovered.contains(i)==true || (flavor=='redbean' && i==2) ? '●':'○'} ${provisionalDonenessLabels[i]}'))]),
      Text(c.state.masteryAwards.containsKey(flavor) ? '숙련 완료 · 6구 생산 가능':'연습 중'),
    ],
    for(final flavor in c.state.recipes)Builder(builder:(context){
      final m=c.state.flavorMasteries[flavor]!,rule=c.config.mastery(c.difficulty(flavor));
      return Text('${c.flavorLabel(flavor)} 연습 ${m.practices}/${rule['practice_required']}, 손기술 ${m.techniquePasses}/${rule['technique_passes_required']}, 연습 익힘 ${m.practiceDiscovered.length}/5',
        key:Key('mastery-$flavor'));
    }),
    if(c.state.level>=DevelopmentBalance.integer(c.config.section('feature_unlock_levels'),'customer_collection_ui'))...[
      if(c.state.tasteObservations.isNotEmpty || c.state.relationships.stories.isNotEmpty)const Divider(),
      for(final story in c.state.relationships.stories)CozyButton(key:Key('replay-$story'),minHeight:40,fontSize:15,
        onPressed:c.busy ? null : (){Navigator.pop(context);c.replayCustomerStory(story);},
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
  Widget _achievements()=>ListView(padding:const EdgeInsets.all(16),children:[
    for(final flavor in c.state.recipes)CozyPanel(child:ListTile(leading:const PixelIcon('achievements'),title:Text('${c.flavorLabel(flavor)} 숙련'),
      subtitle:Text('연습 ${c.state.flavorMasteries[flavor]?.practices ?? 0}회 · 손기술 ${c.state.flavorMasteries[flavor]?.techniquePasses ?? 0}회'),
      trailing:Text(c.state.masteryAwards.containsKey(flavor) ? '달성':'진행 중'))),
  ]);
  Widget _missions(String scope)=>ListView(padding:const EdgeInsets.all(16),children:[
    Text(scope=='daily' ? '일일 ${c.state.missions.day}':'주간 ${c.state.missions.week}'),
    for(final e in c.state.missions.goals(c.config,scope).entries)_mission(scope,e.key,rule:e.value as Map<String,dynamic>),
    if(scope=='daily')_mission('daily','all'),
  ]);
  Widget _levelMissions()=>ListView(padding:const EdgeInsets.all(16),children:[
    Text('Lv.${c.state.level}',style:Theme.of(context).textTheme.headlineMedium),
    LinearProgressIndicator(value:_levelProgress()/1000),const SizedBox(height:12),
    if(c.state.level<50)Text('다음 승급: 누적 ${c.config.rows('level_progression')[c.state.level]['season_total_buns']} · '
      '추가 탭 ${c.state.taps-c.state.levelStartTaps}/${c.config.rows('level_progression')[c.state.level]['additional_taps']} · '
      '추가 판매 ${c.state.completedSales-c.state.levelStartSales}/${c.config.rows('level_progression')[c.state.level]['additional_sales']}'),
    if(c.state.level==50)const Text('최고 레벨에 도달했어요.'),
    FilledButton(onPressed:c.busy || !c.canLevelUp ? null:c.levelUp,child:const Text('승급')),
    for(final flavor in ['custard','cocoa'])
      if(!c.state.recipes.contains(flavor))Builder(builder:(context){
        final tier=DevelopmentBalance.integer(c.config.section('active_recipes')[flavor] as Map<String,dynamic>,'acquisition_tier');
        final requirement=c.config.rows('additional_recipe_acquisition_tiers').firstWhere((r)=>r['tier']==tier);
        final ready=c.state.level>=DevelopmentBalance.integer(requirement,'unlock_level') &&
          c.state.completedSales>=DevelopmentBalance.integer(requirement,'mission_sales');
        return ListTile(key:Key('recipe-mission-$flavor'),title:Text('${c.flavorLabel(flavor)} 레시피 미션'),
          subtitle:Text('Lv.${requirement['unlock_level']}, 판매 ${c.state.completedSales}/${requirement['mission_sales']}회'),
          trailing:FilledButton(onPressed:c.busy || !ready ? null : ()=>c.claimRecipeFromMission(flavor),child:const Text('받기')));
      }),
  ]);
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
  Widget _sensorControl() => Row(mainAxisAlignment:MainAxisAlignment.center,children:[
    Switch(value:_sensorEnabled,onChanged:_setSensor),
    Flexible(child:Text(_sensorEnabled ? _sensorStatus : _sensorNotice ?? '기울기로 반죽 붓기',
      style:const TextStyle(color:Cozy.cream,fontSize:12,shadows:[Shadow(color:Cozy.woodDark,blurRadius:4)]))),
    if(_sensorEnabled) IconButton(tooltip:'현재 자세로 다시 보정',onPressed:()=>_setSensor(true),
      icon:const Icon(Icons.screen_rotation,color:Cozy.cream,size:20)),
  ]);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation:Listenable.merge([c,widget.accountController]),
    builder:(context,_)=>_content(context));
  Widget _content(BuildContext context) {
    _showAwayReport();
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
          FilledButton(onPressed:c.busy || c.error!=null ? null : c.finishCustomerScene,child:const Text('대화 마치기')),
        ]);
      }
      return Scaffold(appBar:AppBar(title:const Text('이웃 이야기')),
        body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:content)));
    }
    final step=workshopTutorialStep(s,ready:s.customers.isEmpty ? 0 : c.saleReadyCount(s.customers.first));
    final home=NightHome(key:_homeKey,controller:widget.accountController,onOpen:_open,
      equipped:_equipped,headerData:NightHomeHeaderData(level:s.level,progressPermille:_levelProgress(),
        buns:s.buns,lifetime:s.lifetime,autoRate:c.autoRate,tapRate:c.tapRate,claimable:_rewardCounts().values.fold<int>(0,(a,b)=>a+b),
        status:c.error!=null ? '저장 확인 필요' : '${s.business.open ? '영업 중' : '영업 준비'} · 주문 ${s.customers.length}'),
      centerBuilder:(fish,clean)=>Stack(children:[
        Positioned.fill(child:WorkshopMoldStage(controller:c,fishOnScreen:fish,cleanCounter:clean,sensorControl:_sensorControl())),
        // Below the flavor row, clear of the counter strip.
        Positioned(left:2,top:48,bottom:56,width:64,child:WorkshopCustomerQueue(controller:c,onOpenCustomer:_customerCard)),
      ]),
      counter:WorkshopSaleCounter(controller:c,onOpenStock:_stock,onCloseBusiness:_closeBusiness),
      griddleContent:WorkshopGriddleLayer(controller:c,stove:_equipped(CosmeticSlot.stove)),
      vendor:CookCut(equipped:_equipped,taps:BigInt.from(s.taps),
        reduceMotion:widget.accountController.state.settings.reduceMotion,greeting:s.customers.isNotEmpty));
    return Stack(children:[home,if(step!=null)Positioned.fill(child:WorkshopTutorialOverlay(step:step,home:_homeKey,
      onSkip:c.busy || c.error!=null ? null : c.skipTutorial))]);
  }
}
