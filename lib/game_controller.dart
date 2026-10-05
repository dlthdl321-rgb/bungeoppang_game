import 'dart:async';
import 'package:flutter/foundation.dart';
import 'balance.dart';
import 'economy.dart';
import 'models.dart';
import 'repository.dart';
import 'time_service.dart';
import 'mission_config.dart';
import 'mission_state.dart';
import 'missions.dart';
import 'support_config.dart';
import 'support_state.dart';
import 'support_rules.dart';
import 'invite_models.dart';
import 'invite_repository.dart';
import 'mock_invite_repository.dart';
import 'invite_config.dart';
import 'invite_rules.dart';
import 'achievement_config.dart';
import 'cosmetic_config.dart';
import 'menu_rules.dart';
import 'progress_rules.dart';
import 'weekly_config.dart';
import 'online_ranking.dart';
import 'feedback_config.dart';
import 'game_events.dart';
import 'ranking_config.dart';

part 'invite_controller.dart';
part 'menu_controller.dart';
part 'ranking_controller.dart';

class GameController extends ChangeNotifier {
  final GameRepository repository;
  final TimeService clock;
  final InvitationRepository invitationRepository;
  // Purchasable catalog. Injectable so tests can exercise future catalog rows.
  final List<CosmeticDefinition> cosmetics;
  // Debug-only invite simulator, referral code and test tools. Release builds
  // show plain game sharing instead. Injectable so tests can check both.
  final bool developerTools;
  final RankingService ranking;
  final ComboBonus comboBonusRule;
  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;
  // How long the last offline settlement covered (after the cap).
  Duration lastOfflineDuration = Duration.zero;
  RankingStatus rankingStatus = RankingStatus.unavailable;
  bool _rankingBusy = false;
  int? _lastRankingSubmitMs;
  Map<String, int>? _lastRankingScores;
  bool _inviteLoading = false, _disposed = false;
  String? inviteError;
  late GameState state;
  int _lastMono = 0;
  bool _away = false, busy = false;
  Timer? _ticker, _periodicSave;
  String? error;
  BigInt lastOfflineReward = BigInt.zero;
  // Combo is session-only; the best value is kept in records.
  int _combo = 0, _lastComboMs = 0;
  int get currentCombo =>
      clock.monotonicMilliseconds - _lastComboMs <= comboWindowMilliseconds
          ? _combo
          : 0;
  Completer<void>? _commitDone;
  DateTime get gameNow => state.support.now(clock.utcNow);
  BigInt get currentTapRate =>
      tapRate(state) *
      state.support.multiplier(EffectChannel.tap, gameNow) ~/
      BigInt.from(effectScale);
  BigInt get currentAutoRate =>
      autoRate(state) *
      state.support.multiplier(EffectChannel.automatic, gameNow) ~/
      BigInt.from(effectScale);
  GameController(this.repository, this.clock,
      {InvitationRepository? invitationRepository,
      this.cosmetics = cosmeticDefinitions,
      this.ranking = const NoRankingService(),
      this.comboBonusRule = comboBonus,
      bool? developerTools})
      : developerTools = developerTools ?? !kReleaseMode,
        invitationRepository =
            invitationRepository ?? MockInvitationRepository();

  void _notifyInviteChanged() {
    if (!_disposed) notifyListeners();
  }

  // For command extensions (ranking), which cannot call notifyListeners.
  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  void _emit(GameEvent event) {
    if (!_disposed) _events.add(event);
  }

  Future<void> initialize() async {
    try {
      state = await repository.load() ?? GameState.initial(clock.utcNow);
    } on FormatException catch (e) {
      error = '저장 데이터가 손상되었습니다: ${e.message}';
      rethrow;
    }
    _lastMono = clock.monotonicMilliseconds;
    // Initialization is a transition from an inactive session. A real
    // stopwatch is usually non-zero after loading, so it cannot identify it.
    _away = true;
    await resume();
    if (state.missions.activatedAtUtc == null) {
      state.missions.activatedAtUtc = clock.utcNow;
      await save();
    }
    unawaited(refreshRanking());
    _ticker?.cancel();
    _periodicSave?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    _periodicSave = Timer.periodic(const Duration(seconds: 10), (_) => save());
  }

  void tick() {
    if (_away || busy) return;
    final now = clock.monotonicMilliseconds;
    settleActive(now - _lastMono);
    _lastMono = now;
    _markPlayed();
    submitRankingIfDue();
    notifyListeners();
  }

  // In memory only; persisted by the periodic/command saves.
  void _markPlayed() {
    final day = state.support.daily.day;
    state.records.touchDay(day);
    state.weekly.touchDay(day);
  }

  void settleActive(int elapsedMs) {
    if (elapsedMs < 0) return;
    final stepped =
        state.support.observedUtc.add(Duration(milliseconds: elapsedMs));
    final end = clock.utcNow.isAfter(stepped) ? clock.utcNow : stepped;
    settleProduction(state, end.subtract(Duration(milliseconds: elapsedMs)),
        end, autoRate(state));
    state.lastSettledUtc = end;
    state.savedAutoRate = autoRate(state);
  }

  /// [direct] is false for hold-to-bake repeats, which never build combos.
  BigInt tap({bool direct = true}) {
    if (_away || busy) return BigInt.zero;
    tick();
    if (direct) {
      final now = clock.monotonicMilliseconds;
      _combo = _combo > 0 && now - _lastComboMs <= comboWindowMilliseconds
          ? _combo + 1
          : 1;
      _lastComboMs = now;
      if (_combo > state.records.todayBestCombo) {
        state.records.todayBestCombo = _combo;
      }
    }
    state.records.lifetimeTaps += BigInt.one;
    state.weekly.taps += BigInt.one;
    final support = state.support;
    var factor = support.multiplier(EffectChannel.tap, gameNow);
    final rule = comboBonusRule;
    if (rule.enabled && direct && _combo >= rule.threshold) {
      factor = factor * BigInt.from(rule.permille) ~/ BigInt.from(1000);
    }
    final numerator = tapRate(state) * factor + support.tapFraction;
    final gain = numerator ~/ BigInt.from(effectScale);
    support.tapFraction = numerator % BigInt.from(effectScale);
    state.buns += gain;
    state.lifetime += gain;
    support.daily.taps += BigInt.one;
    support.daily.production += gain;
    notifyListeners();
    return gain;
  }

  Future<bool> claimLevelUp(int expectedTargetLevel) async {
    if (busy || _away || state.level + 1 != expectedTargetLevel) return false;
    tick();
    if (!canClaimLevel(state)) return false;
    final target = activeLevelMission(state)!;
    final before = state.copy();
    // Level is the idempotency key across seasons, including legacy records.
    if (!state.levelRewards.containsKey(target.level)) {
      state.levelRewards[target.level] = LevelRewardRecord(
          level: target.level,
          seasonId: state.missions.seasonId,
          source: 'claim',
          amount: target.reward,
          claimedAtUtc: clock.utcNow);
      if (!grantReward(
          state,
          'level:${target.level}',
          RewardDefinition('${target.reward}'),
          gameNow,
          '레벨 ${target.level} 보상')) {
        state = before;
        return false;
      }
    }
    state.level = target.level;
    state.missions = state.missions.advance(state.level, clock.utcNow);
    final ok = await _commit(before);
    if (ok) {
      submitRankingIfDue(force: true);
      _emit(GameEvent(GameEventKind.levelUp, 'Lv.${target.level} 달성',
          amount: target.reward, unit: '코인'));
    }
    return ok;
  }

  Future<bool> recordMockInvite(MockInviteSuccess event) async {
    return importMockSuccess(event);
  }

  Future<bool> createMockInvite() {
    var serial = state.missions.seenInvitePlayers.length + 1;
    while (state.missions.seenInvitePlayers.contains('mock-$serial')) {
      serial++;
    }
    final now = clock.utcNow;
    return recordMockInvite(MockInviteSuccess(
        playerId: 'mock-$serial',
        activationToken: state.missions.token,
        invitedAtUtc: now,
        completedAtUtc: now));
  }

  Future<bool> simulateButterUse(String expectedToken) async {
    final target = activeLevelMission(state);
    if (busy ||
        _away ||
        state.missions.token != expectedToken ||
        state.missions.activatedAtUtc == null ||
        target == null) {
      return false;
    }
    final goals = missionProgress(state, target)
        .where((p) => p.definition.kind == MissionKind.goldenButterUses);
    if (goals.isEmpty || goals.every((p) => p.complete)) return false;
    return useItem('butter');
  }

  Future<bool> buyUpgrade(UpgradeDefinition u, int requested) async {
    // Only catalog definitions can authorize a purchase. A caller must not be
    // able to substitute a cheaper definition under the same persisted ID.
    if (busy || _away || !upgrades.contains(u) || requested <= 0) return false;
    settleActive(clock.monotonicMilliseconds - _lastMono);
    _lastMono = clock.monotonicMilliseconds;
    if (state.lifetime < u.unlockTotal) return false;
    final owned = state.upgradeCounts[u.id] ?? 0;
    final amount = requested.clamp(0, maxUpgradeCount - owned);
    if (amount == 0) return false;
    final cost = bundlePrice(u, owned, amount);
    if (state.buns < cost) return false;
    final before = state.copy();
    state.buns -= cost;
    state.upgradeCounts[u.id] = owned + amount;
    state.support.daily.purchases += BigInt.from(amount);
    state.weekly.purchases += BigInt.from(amount);
    observeSupport(state, gameNow);
    state.savedAutoRate = autoRate(state);
    if (!await _commit(before)) return false;
    _emit(GameEvent(GameEventKind.purchase, u.name));
    notifyListeners();
    return true;
  }

  Future<bool> buyMaximum(UpgradeDefinition u) async {
    if (busy || _away || !upgrades.contains(u)) return false;
    settleActive(clock.monotonicMilliseconds - _lastMono);
    _lastMono = clock.monotonicMilliseconds;
    return buyUpgrade(u, quoteUpgrade(state, u, PurchaseMode.maximum).amount);
  }

  // Legacy entry point; the cosmetic command owns unlock and payment rules.
  Future<bool> buyOrEquip(SkinDefinition skin) async =>
      skins.contains(skin) && await buyOrEquipCosmetic(skin.id);

  Future<bool> claimDaily(String expectedDay, String id) async {
    if (busy || _away) return false;
    tick();
    final daily = state.support.daily;
    if (daily.day != expectedDay) return false;
    final all = id == 'all';
    final matches = dailyDefinitions.where((d) => d.id == id);
    if (all
        ? daily.allClaimed || !dailyAllComplete(state)
        : matches.isEmpty ||
            daily.claimed.contains(id) ||
            !dailyComplete(state, matches.first)) {
      return false;
    }
    final before = state.copy();
    if (!grantReward(
        state,
        'daily:$expectedDay:$id',
        all ? dailyAllReward : matches.first.reward,
        gameNow,
        all ? '일일 전체 완료' : '일일 미션 $id')) {
      return false;
    }
    if (all) {
      daily.allClaimed = true;
      state.weekly.dailyAllClears += BigInt.one;
    } else {
      daily.claimed.add(id);
    }
    return _commitWith(
        before,
        GameEvent(GameEventKind.missionReward, all ? '일일 미션 전체 완료' : '일일 미션 완료',
            amount: BigInt.parse(
                (all ? dailyAllReward : matches.first.reward).coins),
            unit: '코인'));
  }

  Future<bool> useItem(String id, {BigInt? expectedUses}) async {
    if (busy || _away) return false;
    tick();
    final matches = itemDefinitions.where((i) => i.id == id);
    if (matches.isEmpty) return false;
    final item = matches.first, support = state.support;
    if (support.inventory[id]! <= BigInt.zero ||
        (expectedUses != null && support.itemUses[id] != expectedUses) ||
        (itemRepeatPolicy == 'rejectWhileActive' &&
            support.effects[id]?.activeAt(gameNow) == true)) {
      return false;
    }
    final before = state.copy();
    support.inventory[id] = support.inventory[id]! - BigInt.one;
    support.itemUses[id] = support.itemUses[id]! + BigInt.one;
    support.effects[id] = ActiveItem(
        id,
        item.channel,
        BigInt.parse(item.multiplierPermille),
        gameNow,
        gameNow.add(Duration(seconds: item.durationSeconds)));
    if (id == 'butter' &&
        activeLevelMission(state)
                ?.missions
                .any((m) => m.kind == MissionKind.goldenButterUses) ==
            true) {
      state.missions.butterUses += BigInt.one;
    }
    return _commitWith(
        before,
        GameEvent(
            GameEventKind.itemUsed,
            '${item.name} · ${item.channel == EffectChannel.tap ? '클릭' : '자동'} 생산 '
            '${BigInt.parse(item.multiplierPermille) * BigInt.from(100) ~/ BigInt.from(effectScale)}%',
            amount: BigInt.from(item.durationSeconds),
            unit: '초 동안'));
  }

  Future<bool> buyCoinItem(String id, int expectedSequence) async {
    if (busy || _away || expectedSequence != state.support.purchaseSequence) {
      return false;
    }
    tick();
    final matches = itemDefinitions.where((i) => i.id == id);
    if (matches.isEmpty) return false;
    final item = matches.first, before = state.copy();
    if (!state.support.transact('shop:$expectedSequence',
        -BigInt.parse(item.coinPrice), '${item.name} 구매', gameNow)) {
      return false;
    }
    state.support.inventory[id] = state.support.inventory[id]! + BigInt.one;
    state.support.purchaseSequence++;
    return _commitWith(before, GameEvent(GameEventKind.purchase, item.name));
  }

  Future<bool> claimWeekly(String expectedWeek, String goalId) async {
    if (busy || _away) return false;
    tick();
    final weekly = state.weekly;
    final matches = weeklyGoals.where((g) => g.id == goalId);
    if (weekly.week != expectedWeek ||
        matches.isEmpty ||
        weekly.claimed.contains(goalId) ||
        !weeklyGoalComplete(state, matches.first)) {
      return false;
    }
    final before = state.copy();
    if (!grantReward(state, 'weekly:$expectedWeek:$goalId',
        matches.first.reward, gameNow, '주간 도전 ${matches.first.title}')) {
      return false;
    }
    weekly.claimed.add(goalId);
    return _commitWith(
        before,
        GameEvent(GameEventKind.missionReward, '주간 도전 · ${matches.first.title}',
            amount: BigInt.parse(matches.first.reward.coins), unit: '코인'));
  }

  Future<bool> claimAchievement(String id) async {
    if (busy || _away) return false;
    tick();
    final matches = achievementDefinitions.where((d) => d.id == id);
    if (matches.isEmpty ||
        state.achievements.claimed.contains(id) ||
        !achievementMet(state, matches.first)) {
      return false;
    }
    final d = matches.first, before = state.copy();
    if (!grantReward(state, 'achievement:$id', RewardDefinition(d.coins),
        gameNow, '업적 ${d.title}')) {
      return false;
    }
    state.achievements.claimed.add(id);
    return _commitWith(
        before,
        GameEvent(GameEventKind.achievement,
            '업적 · ${d.title}${d.titleReward == null ? '' : ' · 칭호 「${d.titleReward}」'}',
            amount: d.coins == '0' ? null : BigInt.parse(d.coins), unit: '코인'));
  }

  /// Shows an earned title on the home screen; null shows none.
  Future<bool> equipTitle(String? title) async {
    if (busy ||
        _away ||
        (title != null && !state.achievements.titles.contains(title)) ||
        state.achievements.equippedTitle == title) {
      return false;
    }
    final before = state.copy();
    state.achievements.equippedTitle = title;
    return _commit(before);
  }

  Future<bool> _commitWith(GameState before, GameEvent event) async {
    final ok = await _commit(before);
    if (ok) _emit(event);
    return ok;
  }

  Future<bool> _commit(GameState before) async {
    busy = true;
    _commitDone = Completer<void>();
    state.snapshotSequence++;
    try {
      await repository.save(state.copy());
      error = null;
      return true;
    } catch (_) {
      state = before;
      error = '저장하지 못했습니다. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _commitDone!.complete();
      _commitDone = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> save() async {
    if (busy) return;
    state.snapshotSequence++;
    try {
      await repository.save(state.copy());
      error = null;
    } catch (_) {
      error = '저장하지 못했습니다. 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  Future<void> leaveActive() async {
    if (busy) await _commitDone?.future;
    if (_away) return;
    settleActive(clock.monotonicMilliseconds - _lastMono);
    _away = true;
    state.lastSettledUtc = gameNow;
    state.savedAutoRate = autoRate(state);
    submitRankingIfDue(force: true);
    await save();
  }

  Future<BigInt> resume() async {
    if (busy) await _commitDone?.future;
    if (!_away && _lastMono != 0) return BigInt.zero;
    final now = gameNow;
    var ms = now.difference(state.lastSettledUtc).inMilliseconds;
    if (ms < 0) ms = 0;
    if (ms > maxOfflineMs) ms = maxOfflineMs;
    lastOfflineDuration = Duration(milliseconds: ms);
    final before = state.copy();
    final gain = settleProduction(
        state,
        state.lastSettledUtc,
        state.lastSettledUtc.add(Duration(milliseconds: ms)),
        state.savedAutoRate,
        offline: true);
    observeSupport(state, now);
    state.lastSettledUtc =
        now.isAfter(state.lastSettledUtc) ? now : state.lastSettledUtc;
    state.savedAutoRate = autoRate(state);
    _away = false;
    _lastMono = clock.monotonicMilliseconds;
    _markPlayed();
    if (_ticker != null) unawaited(refreshRanking());
    lastOfflineReward = gain;
    if (gain > BigInt.zero && !await _commit(before)) return BigInt.zero;
    notifyListeners();
    return gain;
  }

  /// Waits out in-flight commits: a change made mid-commit would miss that
  /// snapshot, be skipped by [save], and be erased if the commit rolls back.
  Future<void> _untilIdle() async {
    while (busy) {
      final done = _commitDone;
      if (done == null) return;
      await done.future;
    }
  }

  /// One save per call: sliders should call this on release, not per frame.
  Future<void> updateSettings(
      {bool? vibration,
      bool? hold,
      bool? reduceMotion,
      bool? soundEffects,
      bool? music,
      int? sfxVolume,
      int? musicVolume}) async {
    await _untilIdle();
    final s = state.settings;
    s.vibration = vibration ?? s.vibration;
    s.holdToBake = hold ?? s.holdToBake;
    s.reduceMotion = reduceMotion ?? s.reduceMotion;
    s.soundEffects = soundEffects ?? s.soundEffects;
    s.music = music ?? s.music;
    s.sfxVolume = (sfxVolume ?? s.sfxVolume).clamp(0, 100);
    s.musicVolume = (musicVolume ?? s.musicVolume).clamp(0, 100);
    await save();
    notifyListeners();
  }

  Future<void> finishTutorial() async {
    await _untilIdle();
    state.tutorialDone = true;
    await save();
    notifyListeners();
  }

  Future<void> reset() async {
    if (busy) await _commitDone?.future;
    await repository.clear();
    state = GameState.initial(clock.utcNow);
    _lastMono = clock.monotonicMilliseconds;
    await save();
    notifyListeners();
  }

  /// Recovery screen: promote the backup snapshot and start the game.
  /// Returns null on success, otherwise a reason to show the player.
  Future<String?> restoreBackupAndStart() async {
    try {
      if (!await repository.restoreBackup()) return '복구할 이전 저장이 없습니다.';
    } on FormatException catch (e) {
      return '이전 저장도 손상되어 복구할 수 없습니다: ${e.message}';
    } catch (_) {
      return '복구한 저장을 기록하지 못했습니다. 다시 시도해 주세요.';
    }
    return _startAfterRecovery();
  }

  /// Recovery screen: delete every snapshot and start a new game.
  Future<String?> resetAndStart() async {
    try {
      await reset();
    } catch (_) {
      return '데이터를 초기화하지 못했습니다. 다시 시도해 주세요.';
    }
    return _startAfterRecovery();
  }

  Future<String?> _startAfterRecovery() async {
    error = null;
    try {
      await initialize();
      return null;
    } on FormatException catch (e) {
      return '저장 데이터를 열 수 없습니다: ${e.message}';
    } catch (_) {
      return '게임을 시작하지 못했습니다. 다시 시도해 주세요.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events.close();
    _ticker?.cancel();
    _periodicSave?.cancel();
    super.dispose();
  }
}
