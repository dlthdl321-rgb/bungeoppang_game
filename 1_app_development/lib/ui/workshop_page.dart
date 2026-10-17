import 'dart:async';
import 'package:flutter/material.dart';
import '../cooking_input.dart';
import '../cooking_sensor_input.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cooking_tilt_source.dart';
import '../development_balance.dart';
import '../development_rules.dart';
import '../game_controller.dart';
import '../music_config.dart';
import '../workshop_controller.dart';
import '../cosmetic_config.dart';
import '../workshop_purchases.dart';
import 'avatar_painter.dart';
import 'cooking_session_controls.dart';
import 'customer_story_panel.dart';

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
  String? _sensorNotice;
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
    setState(() { _sensorEnabled = enabled; _sensorNotice = null; });
    if (!enabled) return;
    _sensor = CookingTiltSource().samples(c.config).listen((sample) {
      if (!mounted || !_sensorEnabled || generation != _sensorGeneration) return;
      if (!sample.available) {
        _sensorInput.reset();
        setState(() { _sensorEnabled = false; _sensorNotice = '센서 대신 방향 버튼을 이용해 주세요.'; }); return;
      }
      if(c.gameplayPaused) { _sensorInput.reset(); return; }
      if(c.busy || c.error != null) { _sensorInput.interrupt(); return; }
      final session = c.state.session;
      if (session == null || session.finished) { _sensorInput.reset(); return; }
      final next = _sensorInput.sample(session, sample.angleMillidegrees!, _sensorClock.elapsedMilliseconds);
      if (next != null) unawaited(c.cookingCommand(next));
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_setSensor(false));
  }
  @override
  void dispose() { c.removeListener(_cancelPausedInput); _sensorGeneration++; _sensor?.cancel(); _sensorInput.reset(); _sensorClock.stop(); _gate.reset(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  VoidCallback _cellCommand(int index) {
    final cell = c.state.grid.cells[index];
    return cell.cooking ? () => c.harvestCell(index, expectedCycle: cell.cycle) : () => c.startCell(index);
  }
  Future<void> _closeBusiness() async {
    c.gridVisible = false;
    try {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('오늘 영업을 끝낼까요?'),
        content: const Text('대기 손님은 돌아가고 진행 중인 큰 틀 제작은 취소돼요. 보관한 재고와 숙련 기록은 남고, 6구는 멈춘 상태로 보관돼요.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('계속 영업')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('영업 종료'))]));
      if (confirmed == true) await c.closeBusiness();
    } finally { c.gridVisible = true; }
  }
  Future<void> _shop() async {
    c.gridVisible = false;
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .75,
          child: AnimatedBuilder(animation: c, builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
            const Text('스킬 상점'), const Text('붕어빵력과 황금붕어빵력이 모두 필요해요.'),
            if (c.purchaseGateway == null) const Text('서버 구매 검증 연결을 준비 중이에요. 지금은 결제할 수 없어요.'),
            if (c.notice != null) Text(c.notice!),
            for (final journal in c.state.purchases.journals.values.where((j) => !j.settled))
              ListTile(title: Text('구매 확인 대기: ${journal.quote.skillId}'),
                subtitle: Text('거래 ${journal.transactionId} · ${journal.serverStatus}'),
                trailing: Wrap(children: [TextButton(onPressed: c.purchaseGateway == null || c.purchaseBusy || c.busy ? null :
                  () => c.recoverPurchase(c.purchaseGateway!, journal.transactionId), child: const Text('복구')),
                  TextButton(onPressed: c.purchaseGateway == null || c.purchaseBusy || c.busy ? null :
                  () => c.recoverPurchase(c.purchaseGateway!, journal.transactionId, cancel: true), child: const Text('취소 확인'))])),
            for (final id in [for (final kind in ['tap','auto']) for (var n = 1; n <= 16; n++) '${kind}_$n'])
              Builder(builder: (context) {
                final owned = c.state.purchases.owned[id] ?? 0;
                final cap = DevelopmentBalance.integer(c.config.section('skill_purchase'), 'max_owned_per_skill');
                final capped = owned >= cap;
                final quote = quoteCompositeSkill(c.config, id, owned: capped ? cap : owned, quantity: capped ? 0 : 1);
                final tier = int.parse(id.split('_').last);
                return ListTile(title: Text('${id.startsWith('tap') ? '손기술' : '자동 생산'} $tier단계'),
                  subtitle: Text('예상 가격: 붕어빵력 ${quote.buns} + 황금붕어빵력 ${quote.gold}'),
                  trailing: FilledButton(onPressed: capped || c.purchaseGateway == null || c.purchaseBusy || c.busy || c.error != null ? null :
                    () async { await c.purchaseSkill(c.purchaseGateway!,id); await widget.accountController.refreshWorkshopWallet(); }, child: Text(capped ? '최대 보유' : '구매')),
                  leading: Text('$owned개'));
              }),
          ])))));
    } finally { c.gridVisible = true; }
  }
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
  AvatarLook get _look => AvatarLook.of((slot) => c.state.avatarEquipment[slot.name] ?? defaultCosmetics[slot]!);
  Future<void> _wardrobe() async {
    c.gridVisible=false;
    try {
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(context) =>
        SafeArea(child:SizedBox(height:MediaQuery.sizeOf(context).height*.8,
          child:AnimatedBuilder(animation:c,builder:(context,_) => ListView(padding:const EdgeInsets.all(16),children:[
            const Text('사장님 꾸미기'),SizedBox(height:180,child:CustomPaint(painter:AvatarPainter(_look))),
            if(c.notice!=null) Text(c.notice!),
            for(final e in c.config.section('avatar_catalog').entries) Builder(builder:(context) {
              final row=e.value as Map<String,dynamic>,owned=c.ownsAvatar(e.key),equipped=
                (c.state.avatarEquipment[row['slot']] ?? defaultCosmetics[CosmeticSlot.values.byName(row['slot'] as String)])==e.key;
              final quote=owned ? null : quoteWorkshopProduct(c.config,'cosmetic:${e.key}',owned:0,quantity:1);
              return ListTile(title:Text(row['label'] as String),subtitle:Text(owned ? '보유 중' :
                'Lv.${row['unlock_level']} · 누적 ${row['unlock_total']} · 붕어빵력 ${quote!.buns} + 황금붕어빵력 ${quote.gold}'),
                trailing:TextButton(onPressed:equipped || c.busy || c.purchaseBusy ? null : owned ? () => c.equipAvatar(e.key) :
                  c.purchaseGateway==null ? null : () async {
                    await c.purchaseSkill(c.purchaseGateway!,'cosmetic:${e.key}');
                    await widget.accountController.refreshWorkshopWallet();
                  },child:Text(equipped ? '착용 중' : owned ? '착용' : '구매')));
            }),
          ])))));
    } finally { c.gridVisible=true; }
  }
  Future<void> _goldPacks() async {
    c.gridVisible = false;
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
    } finally { c.gridVisible = true; }
  }
  Future<void> _audioSettings() async {
    c.gridVisible = false;
    try {
      await showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (context) => AnimatedBuilder(animation: widget.accountController,
          builder: (context, _) {
            final account = widget.accountController, settings = account.state.settings;
            return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('배경·소리 설정'),
              AnimatedBuilder(animation:c,builder:(context,_) => DropdownButton<String>(value:c.state.sceneTime,isExpanded:true,
                items:[for(final item in cosmeticDefinitions.where((d)=>d.slot==CosmeticSlot.time))
                  DropdownMenuItem(value:item.id,child:Text(item.name))],
                onChanged:c.busy ? null : (value) {if(value!=null)c.setBackgroundTime(value);})),
              SwitchListTile(title: const Text('배경 음악'), value: settings.music, onChanged: (v) => account.updateSettings(music: v)),
              DropdownButton<String>(value: settings.musicSelection, isExpanded: true,
                items: [for (final entry in musicSelectionLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value))],
                onChanged: (v) { if (v != null) account.updateSettings(musicSelection: v); }),
              _volume('배경 음악 음량', settings.musicVolume, (v) => account.updateSettings(musicVolume: v)),
              SwitchListTile(title: const Text('굽는 소리'), value: settings.cookingSound, onChanged: (v) => account.updateSettings(cookingSound: v)),
              _volume('굽는 소리 음량', settings.cookingVolume, (v) => account.updateSettings(cookingVolume: v)),
              SwitchListTile(title: const Text('효과음'), value: settings.soundEffects, onChanged: (v) => account.updateSettings(soundEffects: v)),
              _volume('효과음 음량', settings.sfxVolume, (v) => account.updateSettings(sfxVolume: v)),
            ])));
          }));
    } finally { c.gridVisible = true; }
  }
  Widget _mission(String scope,String id,{Map<String,dynamic>? rule}) {
    final missions=c.state.missions,key=missions.claimKey(scope,id),claimed=missions.claims.containsKey(key);
    final gold=DevelopmentBalance.integer(c.config.section('mission_gold_rewards'),rule?['reward_key'] as String? ?? 'daily_all');
    final caption=rule==null ? '일일 미션 전체 완료' : rule['label'] as String;
    final current=rule==null ? '' : '${missions.progress(scope,rule['metric'] as String)}/${rule['target']} · ';
    return ListTile(title:Text(caption),subtitle:Text('$current황금붕어빵력 $gold · 서버 검증 후 지급'),
      trailing:TextButton(onPressed:c.busy || claimed || !missions.complete(c.config,scope,id) ? null :
        () => c.claimMission(scope,id,expectedPeriod:scope=='daily' ? missions.day:missions.week),child:Text(claimed ? '신청 완료' : '보상 신청')));
  }
  Widget _volume(String label, int value, void Function(int) save) => _VolumeControl(label: label, value: value, save: save);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: c, builder: (context, _) {
    final s = c.state, session = s.session;
    final firstOrderId = s.customers.isEmpty ? null : s.customers.first.id;
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
    final rule = c.config.mastery(c.difficulty(s.selectedFlavor));
    final target = DevelopmentBalance.integer(rule, 'batter_target_ms');
    return Scaffold(appBar: AppBar(title: const Text('오늘의 붕어빵'), actions: [
      IconButton(tooltip:'스킬 상점',onPressed:_shop,icon:const Icon(Icons.shopping_cart)),
      PopupMenuButton<String>(tooltip:'게임 메뉴',onSelected:(value) {
        switch(value) {
          case 'avatar':unawaited(_wardrobe());break;
          case 'sound':unawaited(_audioSettings());break;
          case 'sync':unawaited(_syncOnline());break;
          case 'gold':unawaited(_goldPacks());break;
        }
      },itemBuilder:(context)=>[
        const PopupMenuItem(value:'avatar',child:Text('사장님 꾸미기')),
        const PopupMenuItem(value:'sound',child:Text('배경·소리 설정')),
        PopupMenuItem(value:'sync',enabled:!c.rewardBusy && !c.adBusy,child:const Text('로그인·보상 확인')),
        const PopupMenuItem(value:'gold',child:Text('황금붕어빵력 충전')),
      ]),
    ]),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(child: Image.asset(isNightTime(s.sceneTime,DateTime.now())==true ? 'assets/images/bg/clear_night.png':'assets/images/bg/clear.png', height: 120, fit: BoxFit.cover, filterQuality: FilterQuality.none)),
        Semantics(label:'현재 사장님 아바타',child:SizedBox(height:140,child:CustomPaint(painter:AvatarPainter(_look)))),
        Text('Lv.${s.level} · 붕어빵력 ${s.buns}', style: Theme.of(context).textTheme.titleLarge),
        Text('누적 ${s.lifetime} · 판매 ${s.completedSales}회'),
        AnimatedBuilder(animation: widget.accountController, builder: (context, _) =>
          Text('황금붕어빵력 ${widget.accountController.state.premium.gold} · 심사 대기 ${c.pendingRewardCount}건')),
        if (c.error != null) ...[Text(c.error!), FilledButton(onPressed: () => c.reloadAfterError(), child: const Text('저장 다시 확인'))],
        if (c.notice != null) Text(c.notice!),
        if (widget.accountController.error != null) Text(widget.accountController.error!),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: c.busy || c.error != null ? null : c.openBusiness,
            child: Text(!s.business.open ? '영업 시작' : s.business.needsContinuation(DateTime.now().toUtc()) ? '새 영업일 이어가기' : '영업 중')),
          TextButton(onPressed: s.business.open && !c.busy ? _closeBusiness : null, child: const Text('영업 종료')),
          TextButton(onPressed: c.busy || c.error != null ? null : c.tap, child: const Text('붕어빵력 모으기')),
          TextButton(onPressed: c.canLevelUp && !c.busy ? c.levelUp : null, child: const Text('승급')),
        ]),
        if (s.level < 50) Text('다음 승급: 누적 ${c.config.rows('level_progression')[s.level]['season_total_buns']} · '
          '추가 탭 ${s.taps-s.levelStartTaps}/${c.config.rows('level_progression')[s.level]['additional_taps']} · '
          '추가 판매 ${s.completedSales-s.levelStartSales}/${c.config.rows('level_progression')[s.level]['additional_sales']}'),
        if (s.level == 50) const Text('최고 레벨에 도달했어요. 분점은 후속 콘텐츠로 준비 중이에요.'),
        const Divider(), Text('${c.flavorLabel(s.selectedFlavor)} 큰 틀 연습', style: Theme.of(context).textTheme.titleMedium),
        const Text('처음에는 팥 미디엄 레시피만 보유해요. 연습은 구매 없이 시작할 수 있어요.'),
        DropdownButton<String>(value: s.selectedFlavor, isExpanded: true,
          items: [for (final flavor in s.recipes) DropdownMenuItem(value: flavor, child: Text(c.flavorLabel(flavor)))],
          onChanged: session != null || c.busy ? null : (flavor) { if (flavor != null) c.selectFlavor(flavor); }),
        for (final flavor in ['custard','cocoa'])
          if (!s.recipes.contains(flavor)) Builder(builder: (context) {
            final tier = DevelopmentBalance.integer(c.config.section('active_recipes')[flavor] as Map<String, dynamic>, 'acquisition_tier');
            final requirement = c.config.rows('additional_recipe_acquisition_tiers').firstWhere((r) => r['tier'] == tier);
            return ListTile(title: Text('${c.flavorLabel(flavor)} 레시피 미션'),
              subtitle: Text('Lv.${requirement['unlock_level']} · 판매 ${requirement['mission_sales']}회'),
              trailing: TextButton(onPressed: c.busy ? null : () => c.claimRecipeFromMission(flavor), child: const Text('받기')));
          }),
        Text('연습 ${s.mastery.practices}/${rule['practice_required']} · 손기술 ${s.mastery.techniquePasses}/${rule['technique_passes_required']} · 연습 익힘 ${s.mastery.practiceDiscovered.length}/5'),
        if (s.level >= DevelopmentBalance.integer(c.config.section('feature_unlock_levels'), 'full_recipe_collection_ui'))
          Wrap(spacing: 8, children: [for (var i = 0; i < 5; i++) Chip(label: Text(
            '${(s.selectedFlavor == 'redbean' && i == 2) || s.mastery.discovered.contains(i) ? '●' : '○'} ${provisionalDonenessLabels[i]}'))]),
        if (session == null) FilledButton(onPressed: c.busy || c.error != null ? null : c.startPractice, child: const Text('큰 틀 연습 시작'))
        else ...[
          Text('두 반죽 목표: ${target/1000}초 · 익힘 ${(DevelopmentBalance.integer(rule, 'doneness_target_ms')/1000).toStringAsFixed(1)}초 기준'),
          if (session.phase == CookingPhase.filling) Text('다음 방향: ${session.fillingSequence[session.fillingIndex] == CookingDirection.left ? '왼쪽' : '오른쪽'}'),
          SwitchListTile(title: const Text('기울기로 반죽·속 넣기'), subtitle: Text(_sensorNotice ?? '켜면 현재 자세로 보정해요. 기울여 붓고 중립으로 돌아오면 멈춰요. 터치도 사용할 수 있어요.'),
            value: _sensorEnabled, onChanged: _setSensor),
          Text('현재 단계 경과 ${(s.phaseMs/1000).toStringAsFixed(1)}초'),
          if (session.phase == CookingPhase.result) ...[
            Text('결과: ${provisionalDonenessLabels[evaluateCookingResult(c.config, session, difficulty: c.difficulty(session.flavor)).variant]}'),
            if (session.practice) Wrap(spacing: 8, children: [FilledButton(onPressed: c.busy ? null : () => c.storeResult(true), child: const Text('보관')),
              TextButton(onPressed: c.busy ? null : () => c.storeResult(false), child: const Text('버리기'))])
            else ...[const Text('주문 제작품은 재고에 저장됐어요. 탄 제품은 판매할 수 없어요.'),
              FilledButton(onPressed: c.busy ? null : () => c.storeResult(true), child: const Text('결과 닫기'))],
          ] else CookingSessionControls(key: ValueKey('${session.id}:$_sensorEnabled'), session: session, blocked: c.busy || c.error != null || c.gameplayPaused,
            cookingElapsedMs: s.phaseMs, onCommand: (next) => c.cookingCommand(next)),
        ],
        const Divider(), Text('6구 · 숙련한 맛 ${s.masteryAwards.length}종'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < s.grid.cells.length; i++)
          SizedBox(width: 140, child: OutlinedButton(onPressed: c.busy || c.error != null || c.gameplayPaused || session != null || !s.business.permitsProducts(c.now()) || s.masteryAwards.isEmpty ? null :
            _cellCommand(i),
            child: Text(s.grid.cells[i].cooking ? '${i+1}번 ${c.flavorLabel(s.grid.cells[i].flavor!)} ${provisionalDonenessLabels[s.grid.doneness(i, c.config)]}\n직접 꺼내기' : '${i+1}번 굽기 시작')))]),
        const Divider(), Text('재고 ${s.inventory.batches.values.fold<int>(0, (n,b) => n+b.quantity)}개 · 영업 전 준비품 ${s.inventory.prepared.length}묶음'),
        for (final b in s.inventory.batches.values) Text('${c.flavorLabel(b.flavor)} ${provisionalDonenessLabels[b.variant]} ${b.quantity}개 · ${s.business.businessIndex-b.madeOnBusinessIndex}영업일 경과'),
        const Divider(), const Text('손님 주문'),
        TextButton(onPressed: c.busy ? null : c.welcomeCustomer, child: const Text('손님 맞이')),
        for (var i = 0; i < s.customers.length; i++) ...[Text('${i+1}번 · ${c.customerName(s.customers[i].customerId)} · ${s.customers[i].lines.map((line) =>
          '${c.flavorLabel(line.flavor)} ${line.variant == null ? '(일반 익힘)' : provisionalDonenessLabels[line.variant!]} ${line.quantity}개').join(', ')} · '
          '남은 ${(s.customers[i].remainingMs/1000).ceil()}초'),
          if(c.customerOrderSpeech(s.customers[i])!=null) Text(c.customerOrderSpeech(s.customers[i])!),
          if(c.customerWaitingAction(s.customers[i])!=null) Text(c.customerWaitingAction(s.customers[i])!),
          Text(c.waitingLine(s.customers[i])),
          if(c.customerDelaySpeech(s.customers[i])!=null) Text(c.customerDelaySpeech(s.customers[i])!),
          if(c.customerCatalog.contains(s.customers[i].customerId) && c.customerConversation(s.customers[i])!=c.waitingLine(s.customers[i])) Text(c.customerConversation(s.customers[i])),
          if(c.customerCatalog.contains(s.customers[i].customerId)) TextButton(
            onPressed:c.busy ? null : ()=>c.observeWaiting(s.customers[i].id),child:const Text('이웃 이야기 확인')),
          Wrap(children: [for (final flavor in s.customers[i].lines.map((l) => l.flavor).toSet())
            TextButton(onPressed: c.busy || session != null || c.gameplayPaused ? null :
              () => c.startOrderProduction(s.customers[i].id, flavor), child: Text('${c.flavorLabel(flavor)} 주문 제작'))]),
        ],
        if(c.lastSaleFeedback!=null) Text(c.lastSaleFeedback!),
        if(c.photoReactionSale!=null) ...[
          const Text('태오: 와, 냄새 좋다. ……아! 또 사진 전에 먹었네.'),
          TextButton(onPressed:c.busy ? null : ()=>c.acknowledgePhotoReaction(c.photoReactionSale!),child:const Text('태오의 반응 확인')),
        ],
        FilledButton(onPressed: firstOrderId == null || c.busy ? null : () => c.sellToCustomer(firstOrderId), child: const Text('첫 손님에게 전량 판매')),
        if (s.level >= DevelopmentBalance.integer(c.config.section('feature_unlock_levels'), 'customer_collection_ui')) ...[
          const Divider(), const Text('손님 취향 도감 · 확인한 주문'),
          for(final story in s.relationships.stories) TextButton(onPressed:c.busy ? null : ()=>c.replayCustomerStory(story),child:Text('${c.customerCatalog.story(story)['event']} · 다시 보기')),
          for (final customer in s.tasteObservations.entries)
            if (c.customerCatalog.contains(customer.key)) CustomerRecordCard(
              catalog:c.customerCatalog,npcId:customer.key,met:s.relationships.met.contains(customer.key),
              completedStories:s.relationships.stories,
              stageLabel:const ['첫 만남','낯익은 손님','동네 단골','가까운 이웃'][s.relationships.stage(customer.key,c.config)],
              observedPreferences:[for(final e in customer.value.entries)
                '${c.flavorLabel(e.key)} ${e.value.map((v) => provisionalDonenessLabels[v]).join('/')}'],
            ) else Text('${c.customerName(customer.key)}: '
              '${customer.value.entries.map((e) => '${c.flavorLabel(e.key)} ${e.value.map((v) => provisionalDonenessLabels[v]).join('/')}').join(', ')}'),
        ],
        const Divider(),const Text('일일·주간 미션'),
        Text('일일 ${s.missions.day} · 주간 ${s.missions.week}'),
        const Text('손님 판매로도 희귀 황금 보상을 받을 수 있어요. 구매·자동 생산 목표도 포함돼요.'),
        for(final e in s.missions.goals(c.config,'daily').entries) _mission('daily',e.key,rule:e.value as Map<String,dynamic>),
        _mission('daily','all'),
        for(final e in s.missions.goals(c.config,'weekly').entries) _mission('weekly',e.key,rule:e.value as Map<String,dynamic>),
        const Divider(),const Text('황금 보상 확인'),
        Text('판매·승급·미션 심사 대기 ${c.pendingRewardCount}건 · 광고 기록 ${s.adAttempts.length}건'),
        TextButton(onPressed:c.rewardBusy || c.adBusy ? null : _syncOnline,child:const Text('로그인·심사 및 잔액 다시 확인')),
        const FilledButton(onPressed:null,child:Text('선택형 보상광고 · 하루 최대 2회')),
        const Text('광고 연결을 준비 중이에요. 시청 완료만으로 지급하지 않고 서버 검증 후 황금 잔액에 반영해요.'),
        const Padding(padding: EdgeInsets.only(top:16),child:Text('황금 심사 대기는 확정 잔액에 포함되지 않아요.')),
      ]))),
    );
  });
}

class _VolumeControl extends StatefulWidget {
  final String label; final int value; final void Function(int) save;
  const _VolumeControl({required this.label, required this.value, required this.save});
  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}
class _VolumeControlState extends State<_VolumeControl> {
  double? draft;
  @override
  void didUpdateWidget(covariant _VolumeControl oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.value != widget.value) draft = null; }
  @override
  Widget build(BuildContext context) => Column(children: [Text(widget.label), Slider(
    value: draft ?? widget.value.toDouble(), min: 0, max: 100, divisions: 100,
    onChanged: (v) => setState(() => draft = v), onChangeEnd: (v) { setState(() => draft = null); widget.save(v.round()); })]);
}
