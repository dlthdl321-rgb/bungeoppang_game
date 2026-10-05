import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_audio.dart';
import '../game_controller.dart';
import 'celebration.dart';
import 'skill_shop.dart';
import 'night_home.dart';
import 'level_missions.dart';
import 'invite_panel.dart';
import 'support_panels.dart';
import 'public_menus.dart';
import 'progress_panels.dart';

class GameApp extends StatefulWidget {
  final GameController controller;
  final GameAudio audio;
  const GameApp(
      {super.key, required this.controller, this.audio = const SilentAudio()});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncAudio);
    widget.audio.init().then((_) => _syncAudio());
  }

  // Settings live in the controller; the audio follows them. Cheap no-op
  // when nothing changed, so it is fine on every controller notification.
  void _syncAudio() => widget.audio.configure(widget.controller.state.settings);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncAudio);
    widget.audio.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.audio.resumeMusic();
      widget.controller.resume().then((v) {
        if (v > BigInt.zero && mounted) {
          widget.audio.play(Sfx.reward);
          showDialog(
              context: _navigatorKey.currentContext!,
              builder: (dialogContext) => OfflineRewardDialog(
                  amount: v,
                  away: widget.controller.lastOfflineDuration,
                  reduceMotion: widget.controller.state.settings.reduceMotion ||
                      MediaQuery.disableAnimationsOf(dialogContext)));
        }
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      widget.audio.pauseMusic();
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
      // Above the navigator so celebrations show over sheets and dialogs.
      builder: (context, child) => GameAudioScope(
          audio: widget.audio,
          child: CelebrationHost(controller: widget.controller, child: child!)),
      home: GameHome(controller: widget.controller));
}

/// Shown when the save cannot be loaded. Switches to [GameApp] once a
/// recovery command succeeds; otherwise stays and explains why.
class RecoveryApp extends StatefulWidget {
  final GameController controller;
  final GameAudio audio;
  const RecoveryApp(
      {super.key, required this.controller, this.audio = const SilentAudio()});
  @override
  State<RecoveryApp> createState() => _RecoveryAppState();
}

class _RecoveryAppState extends State<RecoveryApp> {
  bool _working = false, _started = false;
  String? _message;

  Future<void> _run(Future<String?> Function() command) async {
    setState(() {
      _working = true;
      _message = null;
    });
    final failure = await command();
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = failure;
      _started = failure == null;
    });
  }

  Future<void> _confirmReset(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('정말 초기화할까요?'),
                content: const Text('모든 진행 상황과 이전 저장이 삭제되며 되돌릴 수 없습니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소')),
                  FilledButton(
                      key: const Key('recovery-reset-confirm'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('초기화'))
                ]));
    if (yes == true) await _run(widget.controller.resetAndStart);
  }

  @override
  Widget build(BuildContext context) {
    if (_started) {
      return GameApp(controller: widget.controller, audio: widget.audio);
    }
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '오늘의 붕어빵',
        home: Scaffold(
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Builder(
                            builder: (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber, size: 64),
                                      Text(
                                          widget.controller.error ??
                                              '저장 데이터를 열 수 없습니다.',
                                          textAlign: TextAlign.center),
                                      if (_message != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(_message!,
                                                key: const Key(
                                                    'recovery-message'),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error))),
                                      const SizedBox(height: 16),
                                      if (_working)
                                        const Padding(
                                            padding: EdgeInsets.only(bottom: 8),
                                            child: CircularProgressIndicator()),
                                      FilledButton(
                                          onPressed: _working
                                              ? null
                                              : () => _run(widget.controller
                                                  .restoreBackupAndStart),
                                          child: const Text('이전 저장 복구')),
                                      TextButton(
                                          onPressed: _working
                                              ? null
                                              : () => _confirmReset(context),
                                          child: const Text('새로 시작 (데이터 초기화)'))
                                    ])))))));
  }
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
      'records': '내 기록',
      'share': '게임 공유',
      'invite': '개발자 도구 · 초대 시스템',
      'event': '주간 도전',
      'achievements': '업적 · 도감',
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
    final details =
        '보유 붕어빵\n${exactNumber(c.state.buns)}개\n\n누적 생산\n${exactNumber(c.state.lifetime)}개\n\n클릭당 ${exactNumber(c.currentTapRate)}개\n초당 ${exactNumber(c.currentAutoRate)}개\n보유 코인 ${exactNumber(c.state.support.coins)}개';
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
        'records' => RecordsPanel(controller: c),
        'share' => SharePanel(
            controller: c,
            onDeveloperInvites:
                c.developerTools ? () => _open('invite') : null),
        'achievements' => AchievementPanel(controller: c),
        'missions' => LevelMissions(controller: c, onOpen: _open),
        // Debug-only screen; release builds never route here.
        'invite' when c.developerTools => InvitePanel(controller: c),
        'daily' =>
          DailyMissionsPanel(controller: c, onStore: () => _open('support')),
        'support' => SupportPanel(controller: c),
        'event' => WeeklyPanel(controller: c),
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
                          SoundSettings(controller: c),
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

/// Sound toggles and volumes. Sliders preview locally while dragging and save
/// once on release, so dragging never writes the save file per frame.
class SoundSettings extends StatefulWidget {
  final GameController controller;
  const SoundSettings({super.key, required this.controller});
  @override
  State<SoundSettings> createState() => _SoundSettingsState();
}

class _SoundSettingsState extends State<SoundSettings> {
  int? _sfxDrag, _musicDrag;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, s = c.state.settings;
    Widget slider(String key, String label, bool enabled, int saved, int? drag,
            void Function(int?) setDrag, void Function(int) commit) =>
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label ${drag ?? saved}%'),
              Slider(
                  key: Key(key),
                  value: (drag ?? saved).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${drag ?? saved}%',
                  onChanged: enabled
                      ? (v) => setState(() => setDrag(v.round()))
                      : null,
                  onChangeEnd: enabled
                      ? (v) {
                          setState(() => setDrag(null));
                          commit(v.round());
                        }
                      : null),
            ]));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SwitchListTile(
          key: const Key('setting-sfx'),
          title: const Text('효과음'),
          value: s.soundEffects,
          onChanged: (v) => c.updateSettings(soundEffects: v)),
      slider('setting-sfx-volume', '효과음 크기', s.soundEffects, s.sfxVolume,
          _sfxDrag, (v) => _sfxDrag = v, (v) => c.updateSettings(sfxVolume: v)),
      SwitchListTile(
          key: const Key('setting-music'),
          title: const Text('배경 음악'),
          value: s.music,
          onChanged: (v) => c.updateSettings(music: v)),
      slider(
          'setting-music-volume',
          '배경 음악 크기',
          s.music,
          s.musicVolume,
          _musicDrag,
          (v) => _musicDrag = v,
          (v) => c.updateSettings(musicVolume: v)),
    ]);
  }
}
