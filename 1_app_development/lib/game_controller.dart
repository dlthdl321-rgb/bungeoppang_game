import 'dart:async';
import 'dart:math' as math;
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
import 'billing_service.dart';
import 'online_backend.dart';
import 'premium_config.dart';
import 'online_ranking.dart';
import 'feedback_config.dart';
import 'game_events.dart';
import 'prestige_rules.dart';
import 'ranking_config.dart';

part 'invite_controller.dart';
part 'boost_controller.dart';
part 'online_controller.dart';
part 'premium_controller.dart';
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
  // How long the player was actually away (no cap).
  Duration lastAwayDuration = Duration.zero;
  RankingStatus rankingStatus = RankingStatus.unavailable;
  int? _lastRankingSubmitMs;
  Map<String, int>? _lastRankingScores;
  Future<void>? _rankingSubmission;
  bool _inviteLoading = false, _disposed = false;
  String? inviteError;
  late GameState state;
  int _lastMono = 0;
  bool _away = false, busy = false;
  Timer? _ticker, _periodicSave;
  String? error;
  BigInt lastOfflineReward = BigInt.zero;

  /// Whether [gain] from the last [resume] earns the welcome-back screen.
  bool welcomesBack(BigInt gain) =>
      gain > BigInt.zero && lastAwayDuration >= offlineWelcomeAfter;
  // Combo is session-only; the best value is kept in records.
  int _combo = 0, _lastComboMs = 0;
  int get currentCombo =>
      clock.monotonicMilliseconds - _lastComboMs <= comboWindowMilliseconds
          ? _combo
          : 0;
  Completer<void>? _commitDone;
  // Golden chance (boost_controller.dart): session-only, never saved.
  final math.Random _goldenRandom;
  GoldenChance? goldenChance;
  int? _nextGoldenMs;

  /// Visitors whose boost started and whose arrival is still to be shown.
  final guestArrivals = <GuestVisit>[];

  /// Firebase backend (online_controller.dart): friends, visits, invites.
  final OnlineBackend online;
  bool _onlineSyncing = false, _levelOneReported = false, _signingIn = false;
  int? _lastOnlineSyncMs;

  /// Google Play Billing for 황금 붕어빵 packs (premium_controller.dart).
  final BillingService billing;
  StreamSubscription<BillingPurchase>? _billingSub;

  /// Last wallet message for the shop ('충전 완료', ...), or null.
  String? premiumNotice;
  DateTime get gameNow => state.support.now(clock.utcNow);
  BigInt get currentTapRate =>
      tapRate(state) *
      state.support.multiplier(gameNow) *
      BigInt.from(prestigePermille(state)) ~/
      BigInt.from(effectScale * 1000);
  BigInt get currentAutoRate =>
      autoRate(state) *
      BigInt.from(prestigePermille(state)) ~/
      BigInt.from(1000) *
      state.support.multiplier(gameNow) ~/
      BigInt.from(effectScale);
  GameController(this.repository, this.clock,
      {InvitationRepository? invitationRepository,
      this.cosmetics = cosmeticDefinitions,
      this.ranking = const NoRankingService(),
      this.comboBonusRule = comboBonus,
      bool? developerTools,
      math.Random? goldenRandom,
      this.online = const NoOnlineBackend(),
      this.billing = const NoBillingService()})
      : developerTools = developerTools ?? !kReleaseMode,
        _goldenRandom = goldenRandom ?? math.Random(),
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
      error = '저장 데이터 손상: ${e.message}';
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
    _billingSub ??= billing.purchases.listen((p) => unawaited(_onPurchase(p)));
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    _periodicSave = Timer.periodic(const Duration(seconds: 10), (_) => save());
  }

  void tick() {
    if (_away || busy) return;
    final now = clock.monotonicMilliseconds;
    settleActive(now - _lastMono);
    _lastMono = now;
    _updateGoldenChance(now);
    _syncOnlineIfDue(now);
    _markPlayed();
    submitRankingIfDue();
    // _autoLevelUp(now);
    notifyListeners();
  }

  // Set while an automatic level-up runs (claimLevelUp ticks again).
  bool _autoLeveling = false;
  // A failed save is retried after a pause, not on every 100ms tick.
  int? _autoLevelRetryMs;

  /// Levels up by itself once every goal is met; the levelUp event shows the
  /// reward banner. The level advances synchronously, so the "미션 달성"
  /// notice never sees the level as claimable.
  void _autoLevelUp(int nowMs) {
    if (_autoLeveling || !canClaimLevel(state)) return;
    if (_autoLevelRetryMs case final retry? when nowMs < retry) return;
    _autoLeveling = true;
    final target = activeLevelMission(state)!.level;
    claimLevelUp(target).then((ok) {
      _autoLevelRetryMs = ok ? null : nowMs + autoLevelRetryMs;
      _autoLeveling = false;
    });
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
    var factor = support.multiplier(gameNow) *
        BigInt.from(prestigePermille(state)) ~/
        BigInt.from(1000);
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
    // After a prestige the record exists, so coins are paid only once.
    final paying = !state.levelRewards.containsKey(target.level);
    if (paying) {
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
      // Cosmetics this level unlocks, one line per category.
      final unlocked = <CosmeticCategory, List<String>>{};
      for (final d in cosmetics) {
        if (d.collectible && d.unlockLevel == target.level) {
          (unlocked[d.slot.category] ??= []).add(d.name);
        }
      }
      _emit(GameEvent(GameEventKind.levelUp, 'Lv.${target.level} 달성',
          amount: paying ? target.reward : null,
          unit: '코인',
          details: [
            for (final c in CosmeticCategory.values)
              if (unlocked[c] case final names?)
                '새 ${cosmeticCategoryLabel(c)} 꾸미기 · ${names.take(levelUpNamesShown).join(', ')}'
                    '${names.length > levelUpNamesShown ? ' 외 ${names.length - levelUpNamesShown}개' : ''}'
          ]));
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

  Future<bool> buyUpgrade(UpgradeDefinition u, int requested) async {
    // Only catalog definitions can authorize a purchase. A caller must not be
    // able to substitute a cheaper definition under the same persisted ID.
    if (busy || _away || !upgrades.contains(u) || requested <= 0) return false;
    settleActive(clock.monotonicMilliseconds - _lastMono);
    _lastMono = clock.monotonicMilliseconds;
    if (!skillUnlocked(state, u)) return false;
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

  /// "새 노점 열기": resets this run (buns, skills, level) for permanent stars.
  /// Coins, items, cosmetics, achievements, titles, records and all-time
  /// production stay. Level-up coins are never paid twice.
  Future<bool> prestige() async {
    if (busy || _away) return false;
    tick();
    if (!canPrestige(state)) return false;
    final before = state.copy();
    final gained = prestigeStarsAvailable(state).toInt();
    final s = state;
    s.buns = BigInt.zero;
    for (final id in s.upgradeCounts.keys.toList()) {
      s.upgradeCounts[id] = 0;
    }
    s.level = 1;
    s.missions =
        MissionState.forLevel(1, clock.utcNow, seasonId: s.missions.seasonId);
    s.savedAutoRate = BigInt.zero;
    s.activeRemainder = BigInt.zero;
    s.support
      ..autoFraction = BigInt.zero
      ..tapFraction = BigInt.zero;
    s.prestige
      ..stars += gained
      ..count += 1
      ..lastAtUtc = clock.utcNow;
    final ok = await _commitWith(
        before,
        GameEvent(GameEventKind.prestige,
            '새 노점 개업 · 생산 +${(prestigePermille(s) - 1000) ~/ 10}%',
            amount: BigInt.from(gained), unit: '명성 별'));
    if (ok) submitRankingIfDue(force: true);
    return ok;
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
      error = '저장 실패. 다시 시도해 주세요.';
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
      error = '저장 실패. 다시 시도해 주세요.';
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
    lastAwayDuration = Duration(milliseconds: ms);
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
    lastOfflineReward = BigInt.zero;
    if (gain > BigInt.zero && !await _commit(before)) return BigInt.zero;
    lastOfflineReward = gain;
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
      if (!await repository.restoreBackup()) return '복구할 이전 저장이 없어요.';
    } on FormatException catch (e) {
      return '이전 저장도 손상됨: ${e.message}';
    } catch (_) {
      return '복구 저장 실패. 다시 시도해 주세요.';
    }
    return _startAfterRecovery();
  }

  /// Recovery screen: delete every snapshot and start a new game.
  Future<String?> resetAndStart() async {
    try {
      await reset();
    } catch (_) {
      return '초기화 실패. 다시 시도해 주세요.';
    }
    return _startAfterRecovery();
  }

  Future<String?> _startAfterRecovery() async {
    error = null;
    try {
      await initialize();
      return null;
    } on FormatException catch (e) {
      return '저장 데이터를 열 수 없어요: ${e.message}';
    } catch (_) {
      return '게임 시작 실패. 다시 시도해 주세요.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _billingSub?.cancel();
    _events.close();
    _ticker?.cancel();
    _periodicSave?.cancel();
    super.dispose();
  }
}
