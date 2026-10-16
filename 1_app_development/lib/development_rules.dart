import 'dart:convert';
import 'development_balance.dart';

/// Calculations for new contracts only. No wallet calls, state mutation,
/// random reward draw, migration defaults or game-flow policy is implied.
class CompositeQuote {
  final String revision, skillId;
  final int owned, quantity;
  final BigInt buns, gold;
  const CompositeQuote(this.revision, this.skillId, this.owned, this.quantity,
      this.buns, this.gold);
  bool affordable(BigInt availableBuns, BigInt availableGold) =>
      availableBuns >= buns && availableGold >= gold;
}

CompositeQuote quoteCompositeSkill(DevelopmentBalance config, String id,
    {required int owned, required int quantity}) {
  final purchase = config.section('skill_purchase');
  final limit = DevelopmentBalance.integer(purchase, 'max_owned_per_skill');
  if (owned < 0 || quantity < 0 || owned > limit || quantity > limit - owned) {
    throw const FormatException('구매 수량 범위 오류');
  }
  final row = config.skill(id);
  final num = BigInt.from(DevelopmentBalance.integer(row, 'ratio_numerator'));
  final den = BigInt.from(DevelopmentBalance.integer(row, 'ratio_denominator'));
  var numerator = DevelopmentBalance.decimal(row, 'buns') * num.pow(owned);
  var denominator = den.pow(owned);
  var buns = BigInt.zero, gold = BigInt.zero;
  final step = DevelopmentBalance.integer(purchase, 'gold_step_purchase_count');
  final increment = DevelopmentBalance.integer(purchase, 'gold_step_amount');
  final initialGold = DevelopmentBalance.integer(row, 'gold');
  for (var n = owned; n < owned + quantity; n++) {
    buns += (numerator + denominator - BigInt.one) ~/ denominator;
    gold += BigInt.from(initialGold) + BigInt.from(n ~/ step) * BigInt.from(increment);
    numerator *= num;
    denominator *= den;
  }
  return CompositeQuote(config.revision, id, owned, quantity, buns, gold);
}

CompositeQuote maximumCompositeSkill(DevelopmentBalance config, String id,
    {required int owned, required BigInt availableBuns,
    required BigInt availableGold}) {
  if (availableBuns.isNegative || availableGold.isNegative) {
    throw const FormatException('음수 가용 잔액');
  }
  final limit = DevelopmentBalance.integer(
      config.section('skill_purchase'), 'max_owned_per_skill');
  // Also validates the item and owned count when zero can be bought.
  quoteCompositeSkill(config, id, owned: owned, quantity: 0);
  var low = 0, high = limit - owned;
  while (low < high) {
    final mid = low + (high - low + 1) ~/ 2;
    if (quoteCompositeSkill(config, id, owned: owned, quantity: mid)
        .affordable(availableBuns, availableGold)) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return quoteCompositeSkill(config, id, owned: owned, quantity: low);
}

/// Integer cross-products: each threshold belongs to the next stage.
int provisionalDoneness(DevelopmentBalance config,
    {required int elapsedMs, required int difficulty}) {
  if (elapsedMs < 0) throw const FormatException('음수 익힘 시간');
  final target = DevelopmentBalance.integer(config.mastery(difficulty), 'doneness_target_ms');
  final scale = DevelopmentBalance.integer(config.section('doneness'), 'reference_scale');
  if (scale <= 0) throw const FormatException('익힘 배율 오류');
  final elapsed = BigInt.from(elapsedMs) * BigInt.from(scale);
  final boundaries = config.integers('doneness', 'boundary_permille');
  for (var i = 0; i < boundaries.length; i++) {
    if (elapsed < BigInt.from(target) * BigInt.from(boundaries[i])) return i;
  }
  return boundaries.length;
}

class MasteryResult {
  final String id, flavor;
  final int variant;
  final bool completed, practice, techniquePassed;
  const MasteryResult({required this.id, required this.flavor,
      required this.variant, required this.completed, required this.practice,
      required this.techniquePassed});
  String get fingerprint => jsonEncode([flavor, variant, completed, practice, techniquePassed]);
}

/// Detached proposed progress state. It is not a new GameState save format.
class FlavorMasteryProgress {
  final String flavor;
  final int difficulty, practices, techniquePasses;
  final Set<int> discovered, practiceDiscovered;
  final Map<String, String> results;
  FlavorMasteryProgress({required this.flavor, required this.difficulty,
      this.practices = 0, this.techniquePasses = 0, Set<int> discovered = const {},
      Set<int> practiceDiscovered = const {}, Map<String, String> results = const {}})
      : discovered = Set<int>.unmodifiable(discovered),
        practiceDiscovered = Set<int>.unmodifiable(practiceDiscovered),
        results = Map<String, String>.unmodifiable(results) {
    if (flavor.isEmpty || difficulty < 0 || difficulty > 2 || practices < 0 || techniquePasses < 0 ||
        techniquePasses > practices ||
        !this.discovered.containsAll(this.practiceDiscovered) ||
        this.discovered.any((v) => v < 0 || v >= 5)) {
      throw const FormatException('숙련 진행 오류');
    }
  }

  /// Detached schema only: callers must atomically save this with unlocks and
  /// processed result IDs. This does not migrate or modify GameState v13.
  Map<String, dynamic> toJson() => {
    'schema': 1, 'flavor': flavor, 'difficulty': difficulty,
    'practices': practices, 'techniquePasses': techniquePasses,
    'discovered': (discovered.toList()..sort()),
    'practiceDiscovered': (practiceDiscovered.toList()..sort()),
    'results': Map<String, String>.from(results),
  };

  factory FlavorMasteryProgress.fromJson(Map<String, dynamic> json) {
    if (json['schema'] is! int || json['schema'] != 1 ||
        json['flavor'] is! String || json['results'] is! Map<String, dynamic>) {
      throw const FormatException('숙련 저장 형식 오류');
    }
    Set<int> variants(String key) {
      final raw = json[key];
      if (raw is! List || raw.any((v) => v is! int || v < 0 || v >= 5) ||
          raw.toSet().length != raw.length) {
        throw const FormatException('숙련 수집 목록 오류');
      }
      return raw.cast<int>().toSet();
    }
    final records = <String, String>{};
    for (final entry in (json['results'] as Map<String, dynamic>).entries) {
      if (entry.key.isEmpty || entry.value is! String) {
        throw const FormatException('숙련 결과 기록 오류');
      }
      records[entry.key] = entry.value as String;
    }
    final candidate = FlavorMasteryProgress(
      flavor: json['flavor'] as String,
      difficulty: DevelopmentBalance.integer(json, 'difficulty'),
      practices: DevelopmentBalance.integer(json, 'practices'),
      techniquePasses: DevelopmentBalance.integer(json, 'techniquePasses'),
      discovered: variants('discovered'),
      practiceDiscovered: variants('practiceDiscovered'), results: records);
    // Fingerprints must agree with counts and collection. Seeded entry recipes
    // belong to recipe ownership, not this completed-result progress ledger.
    var replay = FlavorMasteryProgress(flavor: candidate.flavor,
        difficulty: candidate.difficulty);
    for (final entry in records.entries) {
      final raw = jsonDecode(entry.value);
      if (raw is! List || raw.length != 5 || raw[0] is! String ||
          raw[1] is! int || raw[2] != true || raw[2] is! bool ||
          raw[3] is! bool || raw[4] is! bool) {
        throw const FormatException('숙련 결과 내용 오류');
      }
      replay = replay.record(MasteryResult(id: entry.key,
          flavor: raw[0] as String, variant: raw[1] as int,
          completed: true, practice: raw[3] as bool,
          techniquePassed: raw[4] as bool));
    }
    if (replay.practices != candidate.practices ||
        replay.techniquePasses != candidate.techniquePasses ||
        !replay.discovered.containsAll(candidate.discovered) ||
        replay.discovered.length != candidate.discovered.length ||
        !replay.practiceDiscovered.containsAll(candidate.practiceDiscovered) ||
        replay.practiceDiscovered.length != candidate.practiceDiscovered.length ||
        records.entries.any((e) => replay.results[e.key] != e.value)) {
      throw const FormatException('숙련 원장과 진행 불일치');
    }
    return candidate;
  }

  bool complete(DevelopmentBalance config) {
    final rule = config.mastery(difficulty);
    return practiceDiscovered.length == DevelopmentBalance.integer(
            config.section('fixed_requirements'), 'mastery_discoveries_required') &&
        practices >= DevelopmentBalance.integer(rule, 'practice_required') &&
        techniquePasses >= DevelopmentBalance.integer(rule, 'technique_passes_required');
  }

  FlavorMasteryProgress record(MasteryResult result) {
    if (result.id.isEmpty || result.flavor != flavor || result.variant < 0 || result.variant >= 5) {
      throw const FormatException('제작 결과 식별 오류');
    }
    if (!result.completed) return this;
    final old = results[result.id];
    if (old != null) {
      if (old != result.fingerprint) throw const FormatException('결과 ID 재사용 충돌');
      return this;
    }
    return FlavorMasteryProgress(flavor: flavor, difficulty: difficulty,
        practices: practices + (result.practice ? 1 : 0),
        techniquePasses: techniquePasses + (result.practice && result.techniquePassed ? 1 : 0),
        discovered: {...discovered, result.variant},
        practiceDiscovered: {...practiceDiscovered, if (result.practice) result.variant},
        results: {...results, result.id: result.fingerprint});
  }
}

bool inventoryExpired(DevelopmentBalance config,
    {required int madeOnBusinessIndex, required int currentBusinessIndex}) {
  if (madeOnBusinessIndex < 0 || currentBusinessIndex < madeOnBusinessIndex) {
    throw const FormatException('영업일 순번 오류');
  }
  return currentBusinessIndex - madeOnBusinessIndex >= DevelopmentBalance.integer(
      config.section('fixed_requirements'), 'inventory_expiry_business_days');
}

/// Only a server-authorized start timestamp is authoritative for ad eligibility.
/// This formatter does not itself authorize a view, grant or daily slot.
String rewardedAdStartDay(DevelopmentBalance config, DateTime authorizedStart) {
  final local = authorizedStart.toUtc().add(Duration(minutes: DevelopmentBalance.integer(
      config.section('fixed_requirements'), 'ad_timezone_offset_minutes')));
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

enum PurchaseRecoveryAction {
  queryServer, finalizeLocally, restoreLocally, releaseReservation, alreadyApplied, needsEvidence
}

/// A proposal for routing recovery. No refunds or grants are performed here.
PurchaseRecoveryAction purchaseRecoveryAction({required String serverStatus,
    required bool localDebitEvidence, required bool localGrantApplied}) {
  if (serverStatus == 'unknown' || serverStatus == 'reserved') {
    return PurchaseRecoveryAction.queryServer;
  }
  if (serverStatus == 'committed') {
    if (!localDebitEvidence) return PurchaseRecoveryAction.needsEvidence;
    return localGrantApplied
        ? PurchaseRecoveryAction.alreadyApplied
        : PurchaseRecoveryAction.finalizeLocally;
  }
  if (serverStatus == 'canceled') {
    if (localGrantApplied) return PurchaseRecoveryAction.needsEvidence;
    return localDebitEvidence
        ? PurchaseRecoveryAction.restoreLocally
        : PurchaseRecoveryAction.releaseReservation;
  }
  throw const FormatException('알 수 없는 서버 거래 상태');
}

/// Snapshot phases supplied by an authenticated server, never SDK callbacks.
/// rejectedFinal means late callbacks are permanently rejected by that server.
enum RewardedAdSlotPhase { reserved, verifying, granted, rejectedFinal }

class RewardedAdSlot {
  final String accountId, attemptId;
  final DateTime authorizedStart;
  final RewardedAdSlotPhase phase;
  RewardedAdSlot({required this.accountId, required this.attemptId,
      required this.authorizedStart, required this.phase}) {
    if (accountId.isEmpty || attemptId.isEmpty || !authorizedStart.isUtc) {
      throw const FormatException('광고 서버 슬롯 식별 오류');
    }
  }
}

/// Display/preflight calculation only. Starting an ad still requires one server
/// transaction that rechecks the account-day limit and reserves the slot.
int rewardedAdRemaining(DevelopmentBalance config, {
    required String accountId, required DateTime serverNow,
    required Iterable<RewardedAdSlot> slots}) {
  if (accountId.isEmpty || !serverNow.isUtc) {
    throw const FormatException('광고 계정 또는 서버 시각 오류');
  }
  final day = rewardedAdStartDay(config, serverNow);
  final seen = <String>{};
  var used = 0;
  for (final slot in slots) {
    if (slot.accountId != accountId) continue;
    if (!seen.add(slot.attemptId) || slot.authorizedStart.isAfter(serverNow)) {
      throw const FormatException('광고 서버 스냅샷 충돌');
    }
    if (rewardedAdStartDay(config, slot.authorizedStart) == day &&
        slot.phase != RewardedAdSlotPhase.rejectedFinal) used++;
  }
  final limit = DevelopmentBalance.integer(
      config.section('fixed_requirements'), 'rewarded_ads_per_account_day');
  if (used > limit) throw const FormatException('광고 서버 한도 불일치');
  return limit - used;
}
