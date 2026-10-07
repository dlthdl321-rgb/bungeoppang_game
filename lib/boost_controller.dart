part of 'game_controller.dart';

/// A golden bungeoppang shining in one of the griddle's six cavities.
/// Session-only: it is never saved and disappears if not caught in time.
class GoldenChance {
  /// Cavity 0-5, row by row from the top left.
  final int slot;
  final int expiresAtMs; // monotonic clock
  const GoldenChance(this.slot, this.expiresAtMs);
}

/// Someone who came to the stall: the inviter once the invited player
/// reached Lv.1 ([BoostKind.invite]), or a friend's daily visit
/// ([BoostKind.visit]). [look] is the visitor's avatar, slot name -> id.
class GuestVisit {
  final String id, name;
  final BoostKind kind;
  final Map<String, String> look;
  const GuestVisit(
      {required this.id,
      required this.name,
      required this.kind,
      this.look = const {}});
}

extension BoostCommands on GameController {
  /// The strongest boost running now, or null.
  ActiveBoost? get activeBoost {
    ActiveBoost? best;
    for (final b in state.support.effects.values) {
      if (b.activeAt(gameNow) &&
          (best == null || b.multiplierPermille > best.multiplierPermille)) {
        best = b;
      }
    }
    return best;
  }

  /// Catches the golden bungeoppang in [slot]: a [BoostKind.golden] boost.
  Future<bool> catchGoldenChance(int slot) async {
    final chance = goldenChance;
    if (busy ||
        _away ||
        chance == null ||
        chance.slot != slot ||
        clock.monotonicMilliseconds >= chance.expiresAtMs) {
      return false;
    }
    tick();
    goldenChance = null;
    _scheduleGoldenChance(clock.monotonicMilliseconds);
    final before = state.copy();
    final boost = boostOf(BoostKind.golden);
    state.support.startBoost(boost, gameNow);
    if (activeLevelMission(state)
            ?.missions
            .any((m) => m.kind == MissionKind.goldenCatches) ==
        true) {
      state.missions.goldenCatches += BigInt.one;
    }
    return _commitWith(before, _boostEvent(boost));
  }

  /// Turns visits the server delivered into boosts, each one once, and
  /// queues the visitors for the guest animation ([guestArrivals]).
  Future<bool> applyGuestVisits(List<GuestVisit> visits) async {
    if (busy || _away) return false;
    tick();
    final before = state.copy();
    final arrived = <GuestVisit>[];
    for (final v in visits) {
      if (v.kind != BoostKind.invite && v.kind != BoostKind.visit) continue;
      if (!state.support.markVisit(v.id)) continue;
      state.support.startBoost(boostOf(v.kind), gameNow);
      arrived.add(v);
    }
    if (arrived.isEmpty) return false;
    final ok =
        await _commitWith(before, _boostEvent(boostOf(arrived.last.kind)));
    if (ok) {
      guestArrivals.addAll(arrived);
      _notifyChanged();
    }
    return ok;
  }

  /// The guest animation finished showing [visit].
  void guestShown(GuestVisit visit) {
    if (guestArrivals.remove(visit)) _notifyChanged();
  }

  GameEvent _boostEvent(BoostDefinition boost) => GameEvent(
      GameEventKind.boostStarted,
      '${boost.name} · 생산 ${boost.multiplierPermille ~/ 1000}배',
      amount: BigInt.from(boost.durationSeconds ~/ 60),
      unit: '분 동안');

  void _scheduleGoldenChance(int nowMs) {
    const span = goldenChanceMaxSeconds - goldenChanceMinSeconds;
    _nextGoldenMs = nowMs +
        (goldenChanceMinSeconds + _goldenRandom.nextInt(span + 1)) * 1000;
  }

  void _updateGoldenChance(int nowMs) {
    final chance = goldenChance;
    if (chance != null) {
      if (nowMs < chance.expiresAtMs) return;
      goldenChance = null;
      _scheduleGoldenChance(nowMs);
      return;
    }
    if (_nextGoldenMs == null) {
      _scheduleGoldenChance(nowMs);
    } else if (nowMs >= _nextGoldenMs!) {
      goldenChance = GoldenChance(_goldenRandom.nextInt(6),
          nowMs + goldenChanceVisibleSeconds * 1000);
    }
  }
}
