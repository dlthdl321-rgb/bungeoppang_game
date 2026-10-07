import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/feedback_config.dart';
import 'package:todays_bungeoppang/game_audio.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/game_events.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/tap_effects.dart';
import 'controller_test.dart' show FakeTime, catchPlacedGoldenChance;
import 'level_missions_widget_test.dart' show tapVisible;
import 'stage8_progress_test.dart' show asVersion, progressed, plainJson;
import 'widget_test.dart' show CountingRepository, FixedTime;

class FakeAudio extends SoundPolicy {
  final sounds = <Sfx>[];
  final musicStates = <bool>[];
  bool get musicPlaying => musicStates.isNotEmpty && musicStates.last;
  @override
  Future<void> init() async {}
  @override
  void output(Sfx sfx, double volume) => sounds.add(sfx);
  @override
  void musicOutput({required bool playing, required double volume}) =>
      musicStates.add(playing);
  @override
  Future<void> dispose() async {}
}

const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];

Future<GameController> mountApp(WidgetTester tester, Size size,
    {double textScale = 1,
    bool reduced = false,
    FakeAudio? audio,
    CountingRepository? repository,
    FixedTime? clock,
    void Function(GameState)? setUp}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() async {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
  final time = clock ?? FixedTime();
  final repo = repository ?? CountingRepository();
  repo.current = GameState.initial(time.utcNow)
    ..tutorialDone = true
    ..settings.vibration = false
    ..settings.reduceMotion = reduced;
  setUp?.call(repo.current!);
  final c = GameController(repo, time);
  await c.initialize();
  await tester.pumpWidget(GameApp(controller: c, audio: audio ?? FakeAudio()));
  await tester.pump();
  return c;
}

void main() {
  group('저장 v8: 소리 설정', () {
    final now = DateTime.utc(2026, 10, 5, 3);
    test('v1~v7 저장은 기본 소리 설정으로 v8이 되고 진행도를 잃지 않는다', () {
      final original = progressed();
      for (var version = 2; version <= 7; version++) {
        final json = version == 7
            ? (plainJson(original)..['formatVersion'] = 7)
            : asVersion(original, version);
        final settings = json['settings'] as Map
          ..remove('soundEffects')
          ..remove('music')
          ..remove('sfxVolume')
          ..remove('musicVolume');
        expect(settings, isNotEmpty);
        final restored = GameState.fromJson(json);
        expect(restored.buns, original.buns, reason: 'v$version');
        expect(restored.level, original.level, reason: 'v$version');
        expect(restored.support.coins, BigInt.from(42), reason: 'v$version');
        expect(restored.ownedSkins, original.ownedSkins, reason: 'v$version');
        if (version >= 4) {
          expect(restored.support.boostUses, original.support.boostUses);
        }
        if (version >= 6) {
          expect(restored.wardrobe.toJson(), original.wardrobe.toJson());
        }
        final s = restored.settings;
        expect([
          s.soundEffects,
          s.music,
          s.sfxVolume,
          s.musicVolume
        ], [
          true,
          true,
          defaultSfxVolume,
          defaultMusicVolume
        ], reason: 'v$version');
        expect(plainJson(GameState.fromJson(plainJson(restored))),
            plainJson(restored));
      }
    });

    test('v8 소리 설정 왕복과 손상값 거부', () {
      final s = GameState.initial(now)
        ..settings.soundEffects = false
        ..settings.musicVolume = 0
        ..settings.sfxVolume = 100;
      final restored = GameState.fromJson(plainJson(s));
      expect(restored.settings.toJson(), s.settings.toJson());
      for (final bad in <String, Object>{
        'sfxVolume': 101,
        'musicVolume': -1,
        'music': 'yes',
      }.entries) {
        final json = plainJson(s);
        (json['settings'] as Map)[bad.key] = bad.value;
        expect(() => GameState.fromJson(json), throwsFormatException,
            reason: bad.key);
      }
    });

    test('설정 변경은 호출당 한 번만 저장한다', () async {
      final repo = CountingRepository();
      final c = GameController(repo, FakeTime()..now = now);
      await c.initialize();
      final saves = repo.saves;
      await c.updateSettings(music: false, musicVolume: 150);
      expect(repo.saves, saves + 1);
      expect((await repo.load())!.settings.music, isFalse);
      expect(c.state.settings.musicVolume, 100);
      c.dispose();
    });
  });

  group('콤보 경제 보너스', () {
    Future<List<BigInt>> gains(ComboBonus rule, {bool direct = true}) async {
      final clock = FakeTime();
      final c =
          GameController(MemoryGameRepository(), clock, comboBonusRule: rule);
      await c.initialize();
      final result = [for (var i = 0; i < 5; i++) c.tap(direct: direct)];
      c.dispose();
      return result;
    }

    test('기본값은 꺼져 있어 콤보가 생산을 바꾸지 않는다', () async {
      expect(comboBonus.enabled, isFalse);
      expect(await gains(comboBonus), List.filled(5, BigInt.one));
    });
    test('켜면 기준 콤보부터 직접 탭에만 적용', () async {
      const rule = ComboBonus(enabled: true, threshold: 3, permille: 2000);
      expect(await gains(rule),
          [BigInt.one, BigInt.one, BigInt.two, BigInt.two, BigInt.two]);
      expect(await gains(rule, direct: false), List.filled(5, BigInt.one));
    });
  });

  group('연출 이벤트', () {
    late FakeTime clock;
    late MemoryGameRepository repo;
    late GameController c;
    late List<GameEvent> events;
    setUp(() async {
      clock = FakeTime();
      repo = MemoryGameRepository();
      c = GameController(repo, clock);
      await c.initialize();
      events = [];
      c.events.listen(events.add);
    });
    tearDown(() => c.dispose());

    test('레벨업·업적·부스트·구매는 성공했을 때만 알린다', () async {
      c.state.tutorialDone = true;
      c.state.lifetime = BigInt.from(10);
      repo.failNextSave = true;
      expect(await c.claimLevelUp(2), isFalse);
      expect(await c.claimLevelUp(2), isTrue);
      expect(await c.claimAchievement('bake-1'), isTrue);
      expect(await catchPlacedGoldenChance(c), isTrue);
      c.state.buns = BigInt.from(1000);
      expect(await c.buyUpgrade(upgrades.first, 1), isTrue);
      await pumpEventQueue();
      expect(events.map((e) => e.kind), [
        GameEventKind.levelUp,
        GameEventKind.achievement,
        GameEventKind.boostStarted,
        GameEventKind.purchase,
      ]);
      expect(events.first.amount, BigInt.from(3));
      expect(events[2].amount, BigInt.one); // 황금 찬스: 1분 동안
    });
  });

  group('소리 정책', () {
    test('효과음 끄기·볼륨 0·탭 소리 간격', () {
      final audio = FakeAudio()..configure(GameSettings());
      audio
        ..play(Sfx.tap)
        ..play(Sfx.tap);
      expect(audio.sounds, [Sfx.tap]); // Second tap inside the interval.
      audio.play(Sfx.reward);
      expect(audio.sounds, [Sfx.tap, Sfx.reward]);
      audio.configure(GameSettings(soundEffects: false));
      audio.play(Sfx.reward);
      audio.configure(GameSettings(sfxVolume: 0));
      audio.play(Sfx.reward);
      expect(audio.sounds.length, 2);
    });
    test('배경 음악은 설정과 앱 전경 여부를 따른다', () {
      final audio = FakeAudio()..configure(GameSettings());
      expect(audio.musicPlaying, isTrue);
      audio.pauseMusic();
      expect(audio.musicPlaying, isFalse);
      audio.resumeMusic();
      expect(audio.musicPlaying, isTrue);
      audio.configure(GameSettings(music: false));
      expect(audio.musicPlaying, isFalse);
      audio.configure(GameSettings(musicVolume: 0));
      expect(audio.musicPlaying, isFalse);
    });
  });

  testWidgets('200회 연속 탭: DB 저장 0회, 파티클·떠오르는 숫자 상한 유지', (tester) async {
    final repo = CountingRepository();
    final audio = FakeAudio();
    final c = await mountApp(tester, const Size(360, 800),
        repository: repo, audio: audio);
    final saves = repo.saves, before = c.state.buns;
    var peak = 0;
    for (var i = 0; i < 200; i++) {
      await tester.tap(find.byKey(const Key('fish-button')));
      await tester.pump(const Duration(milliseconds: 16));
      final pool = (tester
              .widget<CustomPaint>(find.byKey(const Key('crumbs')))
              .painter! as CrumbPainter)
          .pool;
      expect(pool.activeCount, lessThanOrEqualTo(maxCrumbParticles));
      if (pool.activeCount > peak) peak = pool.activeCount;
      expect(find.byKey(const Key('tap-burst')).evaluate().length,
          lessThanOrEqualTo(maxFloatingGains));
    }
    expect(peak, maxCrumbParticles); // The cap is actually reached.
    expect(c.state.buns - before, BigInt.from(200));
    expect(repo.saves, saves);
    expect(audio.sounds.where((s) => s == Sfx.tap), isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    final pool = (tester
            .widget<CustomPaint>(find.byKey(const Key('crumbs')))
            .painter! as CrumbPainter)
        .pool;
    expect(pool.activeCount, 0);
    expect(find.byKey(const Key('combo-label')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('모션 줄이기: 파티클·색종이 없이 정적 표시와 즉시 숫자', (tester) async {
    final c = await mountApp(tester, const Size(390, 844),
        reduced: true, setUp: (s) => s.lifetime = BigInt.from(10));
    await tester.tap(find.byKey(const Key('fish-button')));
    await tester.pump();
    expect(find.byKey(const Key('crumbs')), findsNothing);
    expect(find.byKey(const Key('static-gain')), findsOneWidget);
    expect(await c.claimLevelUp(2), isTrue);
    await tester.pump();
    expect(find.byKey(const Key('celebration')), findsOneWidget);
    expect(find.byKey(const Key('confetti')), findsNothing);
    expect(find.text('3 코인'), findsOneWidget); // Instant, no count-up.
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('백그라운드에서 BGM 정지, 복귀 시 재생', (tester) async {
    final audio = FakeAudio();
    await mountApp(tester, const Size(390, 844), audio: audio);
    expect(audio.musicPlaying, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(audio.musicPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.musicPlaying, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('슬라이더는 끄는 동안 저장하지 않고 놓을 때 한 번 저장', (tester) async {
    final repo = CountingRepository();
    final c = await mountApp(tester, const Size(390, 844), repository: repo);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    final slider = find.byKey(const Key('setting-music-volume'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final saves = repo.saves;
    final gesture = await tester.startGesture(tester.getCenter(slider));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump();
    }
    expect(repo.saves, saves);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.saves, saves + 1);
    expect(c.state.settings.musicVolume, lessThan(defaultMusicVolume));
    await tapVisible(tester, const Key('setting-sfx'));
    expect(c.state.settings.soundEffects, isFalse);
    expect((await repo.load())!.settings.soundEffects, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in sizes) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('연출 화면 overflow 없음 ${size.width}/$scale', (tester) async {
        final clock = FixedTime();
        final c = await mountApp(tester, size,
            textScale: scale,
            clock: clock,
            setUp: (s) => s
              ..lifetime = BigInt.from(10)
              ..upgradeCounts['auto_3'] = 2
              ..savedAutoRate = BigInt.from(200));
        // Level-up and achievement celebrations, queued.
        expect(await c.claimLevelUp(2), isTrue);
        expect(await c.claimAchievement('bake-1'), isTrue);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('celebration')), findsOneWidget);
        expect(find.byKey(const Key('confetti')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: countUpMs + 50));
        expect(find.text('3 코인'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('celebration')), findsNothing);
        // Settings sheet with the sound controls.
        await tester.tap(find.byTooltip('설정'));
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const Key('setting-music-volume')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byKey(const Key('setting-sfx'))))
            .pop();
        await tester.pumpAndSettle();
        // 2 hours away pays out without the welcome-back screen.
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        clock.advance(const Duration(hours: 2));
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(c.lastOfflineReward, greaterThan(BigInt.zero));
        expect(find.byKey(const Key('offline-reward')), findsNothing);
        // A golden chance may have landed; let it expire (test pumps never
        // move the monotonic clock).
        if (c.goldenChance case final chance?) {
          clock.advance(
              Duration(milliseconds: chance.expiresAtMs - clock.mono));
          c.tick();
        }
        // Offline reward screen after a day away.
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        clock.advance(offlineWelcomeAfter);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('offline-reward')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: countUpMs + 50));
        expect(
            tester
                .widget<Text>(find.descendant(
                    of: find.byKey(const Key('offline-reward-amount')),
                    matching: find.byType(Text)))
                .data,
            '${_digits(c.lastOfflineReward)}개');
        expect(c.lastAwayDuration, offlineWelcomeAfter);
        expect(c.lastOfflineDuration, const Duration(milliseconds: maxOfflineMs));
        // A day on the monotonic clock put a golden chance on the griddle;
        // let it expire, since test pumps never move this clock.
        if (c.goldenChance case final chance?) {
          clock.advance(
              Duration(milliseconds: chance.expiresAtMs - clock.mono));
          c.tick();
        }
        expect(c.goldenChance, isNull);
        await tapVisible(tester, const Key('offline-reward-close'));
        expect(find.byKey(const Key('offline-reward')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final (away, shown) in [
    (offlineWelcomeAfter - const Duration(minutes: 1), false),
    (offlineWelcomeAfter, true),
  ]) {
    testWidgets('앱을 새로 켤 때 ${away.inMinutes}분 비웠으면 보상 화면 $shown',
        (tester) async {
      final clock = FixedTime();
      final c = await mountApp(tester, sizes.first,
          clock: clock,
          setUp: (s) => s
            ..upgradeCounts['auto_3'] = 2
            ..savedAutoRate = BigInt.from(200)
            ..lastSettledUtc = clock.utcNow.subtract(away));
      await tester.pump();
      // Paid either way; only the screen depends on the time away.
      expect(c.lastOfflineReward, greaterThan(BigInt.zero));
      expect(c.lastAwayDuration, away);
      expect(find.byKey(const Key('offline-reward')),
          shown ? findsOneWidget : findsNothing);
      if (shown) {
        await tester.pump(const Duration(milliseconds: countUpMs + 50));
        expect(
            tester
                .widget<Text>(find.descendant(
                    of: find.byKey(const Key('offline-reward-amount')),
                    matching: find.byType(Text)))
                .data,
            '${_digits(c.lastOfflineReward)}개');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('합성 효과음 자산: WAV 22.05kHz 모노 16비트, 길이 범위', () {
    final limits = {
      'tap': (0.05, 0.2),
      'purchase': (0.2, 0.6),
      'reward': (0.3, 0.8),
      'levelup': (1.0, 2.0),
      'bgm': (23.9, 24.1),
    };
    for (final e in limits.entries) {
      final bytes = File('assets/audio/${e.key}.wav').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16);
      final seconds = data.getUint32(40, Endian.little) / 2 / 22050;
      expect(seconds, inInclusiveRange(e.value.$1, e.value.$2), reason: e.key);
    }
  });
}

String _digits(BigInt v) =>
    v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
