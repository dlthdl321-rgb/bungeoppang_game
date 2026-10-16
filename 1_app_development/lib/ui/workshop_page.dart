import 'dart:async';
import 'package:flutter/material.dart';
import '../cooking_input.dart';
import '../cooking_result_rules.dart';
import '../cooking_session.dart';
import '../cooking_tilt_source.dart';
import '../development_balance.dart';
import '../development_rules.dart';
import '../game_controller.dart';
import '../music_config.dart';
import '../workshop_controller.dart';
import 'cooking_session_controls.dart';

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
  int? _baselineAngle;
  BatterHoldInput? _sensorBatter;
  final Stopwatch _sensorClock = Stopwatch()..start();
  String? _sensorNotice;
  @override
  void initState() { super.initState(); _gate = TiltDirectionGate.fromBalance(c.config); WidgetsBinding.instance.addObserver(this); }
  Future<void> _setSensor(bool enabled) async {
    await _sensor?.cancel(); _sensor = null; _gate.reset();
    _baselineAngle = null; _sensorBatter?.cancel(); _sensorBatter = null;
    if (!mounted) return;
    setState(() => _sensorEnabled = enabled);
    if (!enabled) return;
    _sensor = CookingTiltSource().samples(c.config).listen((sample) {
      if (!mounted || !_sensorEnabled) return;
      if (!sample.available) {
        setState(() { _sensorEnabled = false; _sensorNotice = '센서 대신 방향 버튼을 이용해 주세요.'; }); return;
      }
      final angle = sample.angleMillidegrees!;
      if (!_gate.calibrated) { _baselineAngle = angle; _gate.calibrate(angle); return; }
      final session = c.state.session;
      if (session == null || c.busy || c.error != null) { _sensorBatter?.cancel(); return; }
      if (session.phase == CookingPhase.firstBatter || session.phase == CookingPhase.secondBatter) {
        if (_sensorBatter?.stageToken != session.token) {
          _sensorBatter?.cancel(); _sensorBatter = BatterHoldInput(session.token);
        }
        final delta = ((angle - _baselineAngle! + 180000) % 360000 - 180000).abs();
        final input = _sensorBatter!;
        if (delta >= _gate.activation && !input.active) {
          input.begin(token: session.token, pointer: -2, monotonicMs: _sensorClock.elapsedMilliseconds);
        } else if (delta <= _gate.deadZone && input.active) {
          final duration = input.finish(token: session.token, pointer: -2, monotonicMs: _sensorClock.elapsedMilliseconds);
          if (duration != null) unawaited(c.cookingCommand(session.pour(session.token, duration)));
        }
        return;
      }
      _sensorBatter?.cancel(); _sensorBatter = null;
      final direction = _gate.sample(angle);
      if (direction != null && session.phase == CookingPhase.filling) {
        unawaited(c.cookingCommand(session.fill(session.token, direction)));
      }
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_setSensor(false));
  }
  @override
  void dispose() { _sensor?.cancel(); _sensorBatter?.cancel(); _sensorClock.stop(); _gate.reset(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
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
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('스킬 상점'), const Text('붕어빵력과 황금붕어빵력이 모두 필요해요. 구매 기능은 준비 중이에요.'),
            for (final id in [for (final kind in ['tap','auto']) for (var n = 1; n <= 16; n++) '${kind}_$n'])
              Builder(builder: (context) {
                final quote = quoteCompositeSkill(c.config, id, owned: 0, quantity: 1);
                final tier = int.parse(id.split('_').last);
                return ListTile(title: Text('${id.startsWith('tap') ? '손기술' : '자동 생산'} $tier단계'),
                  subtitle: Text('예상 가격: 붕어빵력 ${quote.buns} + 황금붕어빵력 ${quote.gold}'),
                  trailing: const Icon(Icons.lock_outline));
              }),
          ]))));
    } finally { c.gridVisible = true; }
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
            return SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('소리 설정'),
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
  Widget _volume(String label, int value, void Function(int) save) => _VolumeControl(label: label, value: value, save: save);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: c, builder: (context, _) {
    final s = c.state, session = s.session;
    final rule = c.config.mastery(c.difficulty(s.selectedFlavor));
    final target = DevelopmentBalance.integer(rule, 'batter_target_ms');
    return Scaffold(appBar: AppBar(title: const Text('오늘의 붕어빵'), actions: [IconButton(
      tooltip: '소리 설정', onPressed: _audioSettings, icon: const Icon(Icons.volume_up)),
      IconButton(tooltip: '스킬 상점', onPressed: _shop, icon: const Icon(Icons.shopping_cart)),
      IconButton(tooltip: '황금붕어빵력 충전', onPressed: _goldPacks, icon: const Icon(Icons.storefront))]),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(child: Image.asset('assets/images/bg/clear.png', height: 120, fit: BoxFit.cover, filterQuality: FilterQuality.none)),
        Text('Lv.${s.level} · 붕어빵력 ${s.buns}', style: Theme.of(context).textTheme.titleLarge),
        Text('누적 ${s.lifetime} · 판매 ${s.completedSales}회'),
        AnimatedBuilder(animation: widget.accountController, builder: (context, _) =>
          Text('황금붕어빵력 ${widget.accountController.state.premium.gold} · 심사 대기 ${s.pendingGold.length}건')),
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
            Wrap(spacing: 8, children: [FilledButton(onPressed: c.busy ? null : () => c.storeResult(true), child: const Text('보관')),
              TextButton(onPressed: c.busy ? null : () => c.storeResult(false), child: const Text('버리기'))]),
          ] else CookingSessionControls(key: ValueKey('${session.id}:$_sensorEnabled'), session: session, blocked: c.busy || c.error != null,
            cookingElapsedMs: s.phaseMs, onCommand: (next) => c.cookingCommand(next)),
        ],
        const Divider(), Text('6구 · 숙련한 맛 ${s.masteryAwards.length}종'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var i = 0; i < s.grid.cells.length; i++)
          SizedBox(width: 140, child: OutlinedButton(onPressed: c.busy || session != null || !s.business.permitsProducts(DateTime.now().toUtc()) || s.masteryAwards.isEmpty ? null :
            () => s.grid.cells[i].cooking ? c.harvestCell(i) : c.startCell(i),
            child: Text(s.grid.cells[i].cooking ? '${i+1}번 ${c.flavorLabel(s.grid.cells[i].flavor!)} ${provisionalDonenessLabels[s.grid.doneness(i, c.config)]}\n직접 꺼내기' : '${i+1}번 굽기 시작')))]),
        const Divider(), Text('재고 ${s.inventory.batches.values.fold<int>(0, (n,b) => n+b.quantity)}개 · 영업 전 준비품 ${s.inventory.prepared.length}묶음'),
        for (final b in s.inventory.batches.values) Text('${c.flavorLabel(b.flavor)} ${provisionalDonenessLabels[b.variant]} ${b.quantity}개 · ${s.business.businessIndex-b.madeOnBusinessIndex}영업일 경과'),
        const Divider(), const Text('손님 주문'),
        TextButton(onPressed: c.busy ? null : c.welcomeCustomer, child: const Text('손님 맞이')),
        for (var i = 0; i < s.customers.length; i++) Text('${i+1}번 손님 · ${s.customers[i].lines.map((line) =>
          '${c.flavorLabel(line.flavor)} ${line.variant == null ? '(일반 익힘)' : provisionalDonenessLabels[line.variant!]} ${line.quantity}개').join(', ')} · '
          '남은 ${(s.customers[i].remainingMs/1000).ceil()}초'),
        FilledButton(onPressed: s.customers.isEmpty || c.busy ? null : c.sellToFirstCustomer, child: const Text('첫 손님에게 전량 판매')),
        if (s.level >= DevelopmentBalance.integer(c.config.section('feature_unlock_levels'), 'customer_collection_ui')) ...[
          const Divider(), const Text('손님 취향 도감 · 확인한 주문'),
          for (final customer in s.tasteObservations.entries) Text('${customer.key.replaceFirst('customer_', '손님 ')}: '
            '${customer.value.entries.map((e) => '${c.flavorLabel(e.key)} ${e.value.map((v) => provisionalDonenessLabels[v]).join('/')}').join(', ')}'),
        ],
        const Padding(padding: EdgeInsets.only(top: 16), child: Text('황금 심사 대기는 확정 잔액에 포함되지 않아요. 상점·미션 보상·보상광고는 준비 중이에요.')),
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
