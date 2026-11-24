import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../game_audio.dart';
import '../game_controller.dart';
import 'celebration.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import '../workshop_controller.dart';
import '../cooking_session.dart';
import 'workshop_page.dart';
import '../customer_notifier.dart';
import '../development_balance.dart';
import '../owner_account.dart';
import 'first_run.dart';
import 'connection_notice.dart';
import 'dart:async';

class GameApp extends StatefulWidget {
  final GameController controller;
  final GameAudio audio;
  final WorkshopController workshop;
  /// Device-only customer notifications (26번 5-1단계); null in tests.
  final CustomerNotifier? notifier;
  /// The first-run login, owner name and character (26번 2-1단계). Null
  /// (tests of the game screens) goes straight to the game.
  final OwnerAccount? owner;
  /// A debug build made without the online settings shows [DevBuildBand]
  /// (main.dart; 4차 피드백 IC10). Tests leave it off.
  final bool devBuildBand;
  const GameApp(
      {super.key, required this.controller, this.audio = const SilentAudio(), required this.workshop, this.notifier, this.owner,
      this.devBuildBand = false});
  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _foreground = true;
  bool? _audioActive;
  Timer? _connectionTimer;
  /// 4차 피드백 IC10: an online build without a connection stops here.
  bool get _connectionLost => widget.owner?.connectionLost ?? false;
  /// The shop runs only in front and while connected.
  bool get _playing => _foreground && !_connectionLost;
  bool? _wasLost;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncAudio);
    widget.workshop.addListener(_syncAudio);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _foreground = false;
    }
    _watchConnection();
    _syncAudio();
    widget.audio.init().then((_) {
      if (mounted) _syncAudio();
    });
  }

  // Settings live in the controller; the audio follows them. Cheap no-op
  // when nothing changed, so it is fine on every controller notification.
  // An explicit music selection stays independent of background/time changes.
  Set<String> get _cookingIds {
    final workshop = widget.workshop;
    if (workshop.gameplayPaused || workshop.error != null) return {};
    final state = workshop.state;
    return {
      if (state.session?.phase == CookingPhase.cooking) 'manual:${state.session!.id}',
      if (state.session == null && workshop.gridVisible && state.business.permitsProducts(workshop.now()))
        ...state.grid.cookingSourceIds,
    };
  }
  void _syncAudio() {
    // Refresh sources before resuming: an ad can finish while backgrounded.
    widget.audio
    ..configure(widget.controller.state.settings)
    ..setCookingSources(_cookingIds)
    // Night plays the night mood whatever the season.
    ..setScene(isNightTime(widget.workshop.state.sceneTime, sceneClock()) == true ? 'night' : 'clear');
    final active = _playing && !widget.workshop.adPaused;
    if (_audioActive != active) {
      _audioActive = active;
      if (active) {
        widget.audio.resumeMusic();
      } else {
        widget.audio.pauseMusic();
      }
    }
  }

  /// Online-only play (4차 피드백 IC10): follow the owner's connection and
  /// look again every few seconds while in front.
  void _watchConnection() {
    widget.owner?.addListener(_ownerChanged);
    _wasLost = _connectionLost;
    if (!_playing) widget.workshop.setForeground(false);
    _connectionTimer?.cancel();
    _connectionTimer = (widget.owner?.loginRequired ?? false)
        ? Timer.periodic(connectionCheckInterval, (_) {
            if (_foreground) widget.owner?.checkConnection();
          })
        : null;
  }

  @override
  void didUpdateWidget(GameApp old) {
    super.didUpdateWidget(old);
    if (old.owner != widget.owner || old.workshop != widget.workshop) {
      old.owner?.removeListener(_ownerChanged);
      _watchConnection();
    }
  }

  /// The connection went or came back: pause or resume the shop like
  /// leaving or returning to the app (the time away is settled the same way).
  void _ownerChanged() {
    final lost = _connectionLost;
    if (lost == _wasLost) return;
    _wasLost = lost;
    if (_foreground) widget.workshop.setForeground(!lost);
    _syncAudio();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    widget.owner?.removeListener(_ownerChanged);
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncAudio);
    widget.workshop.removeListener(_syncAudio);
    widget.workshop.dispose();
    widget.owner?.dispose();
    widget.audio.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  /// Notifier calls run one after another so a late schedule never lands
  /// after the cancel of a quick return.
  Future<void> _notices = Future.value();
  int _noticeGeneration = 0;
  void _queueNotices(Future<void> Function() action) {
    _notices = _notices.then((_) => action()).catchError((Object e) => debugPrint('손님 알림 오류: $e'));
  }
  /// Leaving the app (paused/hidden, not inactive): once the workshop is
  /// saved, schedule one notice per guest the clocks will bring.
  void _scheduleNotices(Future<void>? saved) {
    final notifier = widget.notifier, workshop = widget.workshop;
    if (notifier == null) return;
    final generation = _noticeGeneration;
    _queueNotices(() async {
      await saved;
      if (generation != _noticeGeneration || _foreground || workshop.disposed) return;
      final horizon = DevelopmentBalance.integer(workshop.config.section('customer_notifications'), 'preview_horizon_ms');
      await notifier.schedule(planCustomerNotices(workshop.upcomingArrivals(Duration(milliseconds: horizon)),
          settings: widget.controller.state.settings, config: workshop.config, catalog: workshop.customerCatalog,
          completedStories: workshop.state.relationships.stories));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _noticeGeneration++;
      final notifier = widget.notifier;
      if (notifier != null) _queueNotices(notifier.cancelAll);
      if (!_connectionLost) widget.workshop.setForeground(true);
      _syncAudio();
      widget.controller.resume();
      widget.owner?.checkConnection();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _syncAudio();
      final saved = widget.workshop.setForeground(false);
      if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _scheduleNotices(saved);
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
          child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, child) => CozyMotion(
                  reduce: widget.controller.state.settings.reduceMotion,
                  child: child!),
              child: _covered(CelebrationHost(
                  controller: widget.controller, child: child!)))),
      home: _workshopHome());

  /// Above the navigator: the connection notice covers every route.
  Widget _covered(Widget child) {
    final owner = widget.owner;
    if (owner == null && !widget.devBuildBand) return child;
    return Stack(fit: StackFit.expand, children: [
      child,
      if (widget.devBuildBand) const DevBuildBand(),
      if (owner != null)
        ListenableBuilder(
            listenable: owner,
            builder: (context, _) => owner.connectionLost
                ? Positioned.fill(
                    child: ConnectionLostNotice(checking: owner.checkingConnection, onRetry: owner.checkConnection))
                : const SizedBox.shrink()),
    ]);
  }

  Widget _workshopHome() {
    Widget page() => WorkshopPage(controller: widget.workshop, accountController: widget.controller,
        notifier: widget.notifier, owner: widget.owner);
    final owner = widget.owner;
    return owner == null ? page() : OwnerGate(owner: owner, game: page);
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
  int? _sfxDrag, _musicDrag, _cookingDrag;

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
      // 26번 4-6단계: one song for every mood, so no '배경음 선택' dropdown.
      CozySettingRow(
          key: const Key('setting-cooking-sound'),
          icon: const PixelIcon('sfx', size: 28),
          label: '굽는 소리',
          value: s.cookingSound,
          onChanged: (value) => c.updateSettings(cookingSound: value)),
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
              Text('음량', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 20)),
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
                'setting-cooking-volume',
                '굽는 소리',
                s.cookingSound,
                s.cookingVolume,
                _cookingDrag,
                (value) => _cookingDrag = value,
                (value) => c.updateSettings(cookingVolume: value)),
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
