import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import 'skill_shop.dart';
import 'night_home.dart';
import 'level_missions.dart';
import 'invite_panel.dart';
import 'support_panels.dart';
import 'public_menus.dart';

class GameApp extends StatefulWidget {
  final GameController controller;
  const GameApp({super.key, required this.controller});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.resume().then((v) {
        if (v > BigInt.zero && mounted) {
          showDialog(
              context: _navigatorKey.currentContext!,
              builder: (_) => AlertDialog(
                      title: const Text('다시 오셨네요!'),
                      content: Text('자리를 비운 동안 ${compactNumber(v)}개를 구웠어요.'),
                      actions: [
                        TextButton(
                            onPressed: () => _navigatorKey.currentState!.pop(),
                            child: const Text('확인'))
                      ]));
        }
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      widget.controller.leaveActive();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: '오늘의 붕어빵',
      theme: ThemeData(
          splashFactory: InkRipple.splashFactory,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff9b4436),
              surface: const Color(0xfffff8e8)),
          scaffoldBackgroundColor: const Color(0xfffff8e8),
          useMaterial3: true),
      home: GameHome(controller: widget.controller));
}

class RecoveryApp extends StatelessWidget {
  final GameController controller;
  const RecoveryApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
      home: Scaffold(
          body: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber, size: 64),
                        Text(controller.error ?? '저장 데이터를 열 수 없습니다.'),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: () async {
                              final recovered =
                                  await controller.repository.recover();
                              if (recovered != null) {
                                await controller.repository.save(recovered);
                              }
                            },
                            child: const Text('이전 저장 복구')),
                        TextButton(
                            onPressed: controller.reset,
                            child: const Text('새로 시작 (데이터 초기화)'))
                      ]))))));
}

class GameHome extends StatefulWidget {
  final GameController controller;
  const GameHome({super.key, required this.controller});
  @override
  State<GameHome> createState() => _GameHomeState();
}

class _GameHomeState extends State<GameHome> {
  GameController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    c.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!c.state.tutorialDone) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            scrollable: true,
            title: const Text('오늘의 붕어빵'),
            content: const Text(
                '큰 붕어빵을 눌러 생산하고, 오른쪽 상점에서 클릭과 자동 생산을 강화해요. 아래 진행 막대에서 다음 레벨 목표를 확인하세요.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('건너뛰기')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('시작하기')),
            ],
          ),
        );
        if (mounted) await c.finishTutorial();
      }
    });
  }

  @override
  void dispose() {
    c.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => NightHome(controller: c, onOpen: _open);

  Future<void> _open(String destination) async {
    if (destination == 'settings') {
      await _settings();
      return;
    }
    final titles = {
      'shop': '상점 · 생산 스킬',
      'skins': '꾸미기',
      'daily': '일일 미션',
      'ranking': '랭킹',
      'invite': '친구 초대',
      'event': '이벤트 보상 안내',
      'exchange': '모의 보상 교환',
      'balance': '생산 기록',
      'missions': '레벨 미션',
      'support': '아이템 · 코인 상점',
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .82,
        child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                      child: Row(children: [
                        Expanded(
                            child: Text(titles[destination]!,
                                style: Theme.of(ctx).textTheme.titleLarge)),
                        IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close)),
                      ])),
                  if (destination == 'shop' || destination == 'skins')
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(destination == 'shop'
                            ? '보유 붕어빵 ${compactNumber(c.state.buns)}개'
                            : '코인 ${compactNumber(c.state.support.coins)}개')),
                  Expanded(child: _body(destination)),
                ])),
      ),
    );
  }

  Widget _entryPreview(String destination) {
    final details = switch (destination) {
      'ranking' =>
        '모의 기능 · 랭킹 진입 화면\n\n내 누적 생산 ${compactNumber(c.state.lifetime)}개\n실제 사용자 순위 서버에는 연결되어 있지 않습니다.',
      _ =>
        '보유 붕어빵\n${exactNumber(c.state.buns)}개\n\n누적 생산\n${exactNumber(c.state.lifetime)}개\n\n클릭당 ${exactNumber(c.currentTapRate)}개\n초당 ${exactNumber(c.currentAutoRate)}개\n보유 코인 ${exactNumber(c.state.support.coins)}개',
    };
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: SelectableText(details));
  }

  Widget _body(String destination) => switch (destination) {
        'shop' => Column(children: [
            TextButton(
                key: const Key('support-entry'),
                onPressed: () => _open('support'),
                child: const Text('아이템 · 코인 상점')),
            Expanded(child: SkillShop(controller: c))
          ]),
        'skins' => WardrobePanel(controller: c),
        'ranking' => RankingPanel(controller: c),
        'missions' => LevelMissions(
            controller: c,
            onInvites: () => _open('invite'),
            onItems: () => _open('support')),
        'invite' => InvitePanel(controller: c),
        'daily' =>
          DailyMissionsPanel(controller: c, onStore: () => _open('support')),
        'support' =>
          SupportPanel(controller: c, onExchange: () => _open('exchange')),
        'exchange' => FinalExchangePanel(controller: c),
        'event' =>
          EventPanel(controller: c, onExchange: () => _open('exchange')),
        _ => _entryPreview(destination),
      };
  Future<void> _settings() async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => AnimatedBuilder(
            animation: c,
            builder: (_, __) => SafeArea(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('설정',
                              style: Theme.of(context).textTheme.headlineSmall),
                          SwitchListTile(
                              title: const Text('진동'),
                              value: c.state.settings.vibration,
                              onChanged: (v) => c.updateSettings(vibration: v)),
                          SwitchListTile(
                              title: const Text('길게 눌러 굽기'),
                              subtitle: const Text('길게 누르면 초당 4회'),
                              value: c.state.settings.holdToBake,
                              onChanged: (v) => c.updateSettings(hold: v)),
                          SwitchListTile(
                              title: const Text('모션 줄이기'),
                              value: c.state.settings.reduceMotion,
                              onChanged: (v) =>
                                  c.updateSettings(reduceMotion: v)),
                          ListTile(
                              textColor: Colors.red,
                              title: const Text('데이터 초기화'),
                              onTap: () async {
                                final yes = await showDialog<bool>(
                                    context: ctx,
                                    builder: (_) => AlertDialog(
                                            title: const Text('정말 초기화할까요?'),
                                            content: const Text(
                                                '모든 진행 상황이 삭제되며 되돌릴 수 없습니다.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('취소')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text('초기화'))
                                            ]));
                                if (yes == true) {
                                  await c.reset();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                }
                              })
                        ]))))));
  }
}
