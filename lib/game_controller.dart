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
import 'cosmetic_config.dart';
import 'event_config.dart';
import 'menu_rules.dart';

part 'invite_controller.dart';
part 'menu_controller.dart';

class GameController extends ChangeNotifier {
  final GameRepository repository;
  final TimeService clock;
  final InvitationRepository invitationRepository;
  bool _inviteLoading = false, _disposed = false;
  String? inviteError;
  late GameState state;
  int _lastMono = 0;
  bool _away = false, busy = false;
  Timer? _ticker, _periodicSave;
  String? error;
  BigInt lastOfflineReward = BigInt.zero;
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
      {InvitationRepository? invitationRepository})
      : invitationRepository =
            invitationRepository ?? MockInvitationRepository();

  void _notifyInviteChanged() {
    if (!_disposed) notifyListeners();
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
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    _periodicSave = Timer.periodic(const Duration(seconds: 10), (_) => save());
  }

  void tick() {
    if (_away || busy) return;
    final now = clock.monotonicMilliseconds;
    settleActive(now - _lastMono);
    _lastMono = now;
    notifyListeners();
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

  BigInt tap() {
    if (_away || busy) return BigInt.zero;
    tick();
    final support = state.support;
    final numerator =
        tapRate(state) * support.multiplier(EffectChannel.tap, gameNow) +
            support.tapFraction;
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
    return _commit(before);
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
    observeSupport(state, gameNow);
    state.savedAutoRate = autoRate(state);
    if (!await _commit(before)) return false;
    notifyListeners();
    return true;
  }

  Future<bool> buyMaximum(UpgradeDefinition u) async {
    if (busy || _away || !upgrades.contains(u)) return false;
    settleActive(clock.monotonicMilliseconds - _lastMono);
    _lastMono = clock.monotonicMilliseconds;
    return buyUpgrade(u, quoteUpgrade(state, u, PurchaseMode.maximum).amount);
  }

  Future<bool> buyOrEquip(SkinDefinition skin) async {
    if (busy ||
        _away ||
        !skins.contains(skin) ||
        state.level < skin.unlockLevel) {
      return false;
    }
    tick();
    final before = state.copy();
    if (!state.ownedSkins.contains(skin.id)) {
      if (!state.support.transact(
          'skin:${skin.id}', -skin.cost, '${skin.name} 구매', gameNow)) {
        return false;
      }
      state.ownedSkins.add(skin.id);
    }
    state.equippedSkin = skin.id;
    if (!await _commit(before)) return false;
    notifyListeners();
    return true;
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
    } else {
      daily.claimed.add(id);
    }
    return _commit(before);
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
    return _commit(before);
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
    return _commit(before);
  }

  Future<bool> exchangeFinalReward() async {
    if (busy ||
        _away ||
        state.level < finalExchangeLevel ||
        state.support.ledger.containsKey(finalExchangeId)) {
      return false;
    }
    tick();
    final before = state.copy();
    if (!state.support.transact(finalExchangeId,
        -BigInt.parse(finalExchangeCost), finalExchangeTitle, gameNow)) {
      return false;
    }
    return _commit(before);
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
    await save();
  }

  Future<BigInt> resume() async {
    if (busy) await _commitDone?.future;
    if (!_away && _lastMono != 0) return BigInt.zero;
    final now = gameNow;
    var ms = now.difference(state.lastSettledUtc).inMilliseconds;
    if (ms < 0) ms = 0;
    if (ms > maxOfflineMs) ms = maxOfflineMs;
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
    lastOfflineReward = gain;
    if (gain > BigInt.zero && !await _commit(before)) return BigInt.zero;
    notifyListeners();
    return gain;
  }

  Future<void> updateSettings(
      {bool? vibration, bool? hold, bool? reduceMotion}) async {
    state.settings.vibration = vibration ?? state.settings.vibration;
    state.settings.holdToBake = hold ?? state.settings.holdToBake;
    state.settings.reduceMotion = reduceMotion ?? state.settings.reduceMotion;
    await save();
    notifyListeners();
  }

  Future<void> finishTutorial() async {
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

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _periodicSave?.cancel();
    super.dispose();
  }
}
