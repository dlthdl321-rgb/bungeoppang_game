import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_audio.dart';
import '../game_controller.dart';
import 'celebration.dart';
import 'friends_panel.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'skill_shop.dart';
import 'night_home.dart';
import 'level_missions.dart';
import 'invite_panel.dart';
import 'support_panels.dart';
import 'pixel_sprites.dart';
import 'public_menus.dart';
import 'progress_panels.dart';
import 'ranking_panel.dart';
import 'shop_panel.dart';

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
    // A cold start settles the time away in initialize(), before this app
    // exists; greet the player once the navigator is up.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _welcomeBack(widget.controller.lastOfflineReward));
  }

  void _welcomeBack(BigInt gain) {
    if (!mounted || !widget.controller.welcomesBack(gain)) return;
    widget.audio.play(Sfx.reward);
    showDialog(
        context: _navigatorKey.currentContext!,
        builder: (dialogContext) => OfflineRewardDialog(
            amount: gain,
            away: widget.controller.lastOfflineDuration,
            reduceMotion: widget.controller.state.settings.reduceMotion ||
                MediaQuery.disableAnimationsOf(dialogContext)));
  }

  // Settings live in the controller; the audio follows them. Cheap no-op
  // when nothing changed, so it is fine on every controller notification.
  // The music follows the equipped background's mood the same way.
  void _syncAudio() => widget.audio
    ..configure(widget.controller.state.settings)
    // Night plays the night mood whatever the season.
    ..setScene(isNightTime(
                widget.controller.state.equippedCosmetic(CosmeticSlot.time),
                DateTime.now()) ==
            true
        ? 'night'
        : widget.controller.state.equippedCosmetic(CosmeticSlot.background));

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
      widget.controller.resume().then(_welcomeBack);
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
      theme: cozyTheme(),
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
                content: const Text('진행·이전 저장 모두 삭제, 되돌릴 수 없어요.'),
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
                                      const PixelIcon('warning', size: 64),
                                      Text(
                                          widget.controller.error ??
                                              '저장 데이터를 열 수 없어요.',
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
            content: const Text('붕어빵을 눌러 굽고, 스킬에서 강화해요.'),
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
      'menu': '메뉴',
      'skills': '스킬',
      'friends': '친구',
      'shop': '상점',
      'skins': '꾸미기',
      'daily': '일일 미션',
      'records': '내 기록',
      'ranking': '온라인 랭킹',
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
      backgroundColor: Colors.transparent,
      // A sub-window like the concept UI (07_UI): the balance on top, a
      // wooden-framed cream panel with the title between little fish and a
      // red X at its corner, and a '돌아가기' button under it.
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .92,
        child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                  child: Column(children: [
                    // The frame's own labels grow with large text only up
                    // to 1.3x, leaving room for the content, which scales.
                    _clamped(_balancePill(destination)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(
                          child: CozyFrame(
                            child: Column(children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(52, 12, 52, 6),
                                child: _clamped(Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      PixelArt(
                                          PixelSprites.screenArt('title_fish'),
                                          width: 30,
                                          height: 23),
                                      const SizedBox(width: 8),
                                      Flexible(
                                          child: Text(
                                              titles[destination
                                                  .split(':')
                                                  .first]!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontFamily: 'Jua',
                                                  fontSize: 28,
                                                  color: Cozy.ink))),
                                      const SizedBox(width: 8),
                                      PixelArt(
                                          PixelSprites.screenArt('title_fish'),
                                          width: 30,
                                          height: 23),
                                    ])),
                              ),
                              Expanded(child: _body(destination)),
                            ]),
                          ),
                        ),
                        Positioned(
                            top: -8,
                            right: -6,
                            child: CozyCloseButton(
                                onPressed: () => Navigator.pop(ctx))),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    _clamped(
                        CozyBackButton(onPressed: () => Navigator.pop(ctx))),
                  ]),
                )),
      ),
    );
  }

  static Widget _clamped(Widget child) => Builder(
      builder: (context) =>
          MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child));

  /// The balance pill above a sub-window: bungeoppang, or coins where
  /// things are paid in coins.
  Widget _balancePill(String destination) {
    final coins = destination == 'shop' || destination.startsWith('skins');
    return CozyPanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PixelIcon(coins ? 'coin' : 'bun', size: 24),
        const SizedBox(width: 8),
        Text(
            coins
                ? '코인 ${compactNumber(c.state.support.coins)}개'
                : '${compactNumber(c.state.buns)}개',
            style: const TextStyle(
                fontFamily: 'Jua', fontSize: 20, color: Cozy.ink)),
      ]),
    );
  }

  Widget _entryPreview(String destination) {
    final details =
        '보유 붕어빵\n${exactNumber(c.state.buns)}개\n\n누적 생산\n${exactNumber(c.state.lifetime)}개\n\n클릭당 ${exactNumber(c.currentTapRate)}개\n초당 ${exactNumber(c.currentAutoRate)}개\n보유 코인 ${exactNumber(c.state.support.coins)}개';
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: SelectableText(details));
  }

  /// Closes the open sheet and opens [destination] instead.
  void _switchTo(String destination) {
    Navigator.of(context).pop();
    _open(destination);
  }

  Widget _body(String destination) => switch (destination) {
        'menu' => MenuPanel(controller: c, onOpen: _switchTo),
        'skills' => SkillShop(controller: c),
        'friends' => FriendsPanel(controller: c),
        'shop' => ShopPanel(controller: c, onOpen: _open),
        'skins' => WardrobePanel(controller: c),
        'skins:avatar' => WardrobePanel(controller: c),
        'skins:stall' =>
          WardrobePanel(controller: c, initialTab: WardrobeTab.stall),
        'achievements:collection' =>
          AchievementPanel(controller: c, initialCollection: true),
        'records' => RecordsPanel(controller: c),
        'ranking' => RankingPanel(controller: c),
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

  /// Settings in the concept art's look (07_UI/설정): a cream panel,
  /// orange ON / grey OFF toggles and a '저장' button. Every change is
  /// already saved when made; '저장' writes once more and closes.
  /// Settings like the concept (07_UI/설정): the sub-window frame, a row per
  /// option with an icon and an ON/OFF pill, the volume sliders and a big
  /// orange '저장'. Every change is already saved when made; '저장' writes
  /// once more and closes.
  Future<void> _settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .92,
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Column(children: [
              _clamped(_balancePill('settings')),
              const SizedBox(height: 10),
              Expanded(
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: CozyFrame(
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(52, 12, 52, 6),
                          child: _clamped(const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PixelIcon('settings', size: 30),
                                SizedBox(width: 8),
                                Text('설정',
                                    style: TextStyle(
                                        fontFamily: 'Jua',
                                        fontSize: 28,
                                        color: Cozy.ink)),
                                SizedBox(width: 8),
                                PixelIcon('settings', size: 30),
                              ])),
                        ),
                        Expanded(
                          child: ListView(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              children: [
                                SoundSettings(controller: c),
                                CozySettingRow(
                                    icon: const PixelIcon('vibration',
                                        size: 28),
                                    label: '진동',
                                    value: c.state.settings.vibration,
                                    onChanged: (v) =>
                                        c.updateSettings(vibration: v)),
                                CozySettingRow(
                                    icon: const Icon(Icons.touch_app_rounded,
                                        color: Cozy.ink, size: 28),
                                    label: '길게 눌러 굽기',
                                    subtitle: '길게 누르면 초당 4회',
                                    value: c.state.settings.holdToBake,
                                    onChanged: (v) =>
                                        c.updateSettings(hold: v)),
                                CozySettingRow(
                                    icon: const Icon(
                                        Icons.slow_motion_video_rounded,
                                        color: Cozy.ink,
                                        size: 28),
                                    label: '모션 줄이기',
                                    value: c.state.settings.reduceMotion,
                                    onChanged: (v) =>
                                        c.updateSettings(reduceMotion: v)),
                                const SizedBox(height: 6),
                                FilledButton.icon(
                                    key: const Key('settings-save'),
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(56),
                                        textStyle: const TextStyle(
                                            fontFamily: 'Jua', fontSize: 24)),
                                    onPressed: c.busy
                                        ? null
                                        : () async {
                                            await c.save();
                                            if (ctx.mounted) Navigator.pop(ctx);
                                          },
                                    icon: const PixelIcon('save', size: 28),
                                    label: const Text('저장')),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: Cozy.brick),
                                    onPressed: () => _confirmReset(ctx),
                                    child: const Text('데이터 초기화')),
                                // Development only, last so the player's
                                // settings keep their places: outlines the
                                // vendor's layers and marks their anchors.
                                if (c.developerTools)
                                  ValueListenableBuilder<bool>(
                                      valueListenable: AvatarRigDebug.show,
                                      builder: (context, on, _) =>
                                          CozySettingRow(
                                              key: const Key(
                                                  'setting-rig-debug'),
                                              icon: const Icon(
                                                  Icons.grid_on_rounded,
                                                  color: Cozy.ink,
                                                  size: 28),
                                              label: '레이어 기준점 보기',
                                              subtitle:
                                                  '개발용 · 사장님 그림의 경계와 기준점',
                                              value: on,
                                              onChanged: (v) => AvatarRigDebug
                                                  .show.value = v)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                  Positioned(
                      top: -8,
                      right: -6,
                      child:
                          CozyCloseButton(onPressed: () => Navigator.pop(ctx))),
                ]),
              ),
              const SizedBox(height: 10),
              _clamped(CozyBackButton(onPressed: () => Navigator.pop(ctx))),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext ctx) async {
    final yes = await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
                title: const Text('정말 초기화할까요?'),
                content: const Text('모든 진행 삭제, 되돌릴 수 없어요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('초기화'))
                ]));
    if (yes == true) {
      await c.reset();
      if (ctx.mounted) Navigator.pop(ctx);
    }
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
            padding: const EdgeInsets.only(top: 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label ${drag ?? saved}%',
                  style: const TextStyle(color: Cozy.inkSoft)),
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
      CozySettingRow(
          key: const Key('setting-music'),
          icon: const PixelIcon('bgm', size: 28),
          label: '배경음',
          value: s.music,
          onChanged: (v) => c.updateSettings(music: v)),
      CozySettingRow(
          key: const Key('setting-sfx'),
          icon: const PixelIcon('sfx', size: 28),
          label: '효과음',
          value: s.soundEffects,
          onChanged: (v) => c.updateSettings(soundEffects: v)),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CozyPanel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              PixelIcon('volume', size: 26),
              SizedBox(width: 8),
              Text('음량', style: TextStyle(fontFamily: 'Jua', fontSize: 20)),
            ]),
            slider(
                'setting-music-volume',
                '배경음',
                s.music,
                s.musicVolume,
                _musicDrag,
                (v) => _musicDrag = v,
                (v) => c.updateSettings(musicVolume: v)),
            slider(
                'setting-sfx-volume',
                '효과음',
                s.soundEffects,
                s.sfxVolume,
                _sfxDrag,
                (v) => _sfxDrag = v,
                (v) => c.updateSettings(sfxVolume: v)),
          ]),
        ),
      ),
    ]);
  }
}
