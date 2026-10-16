import 'premium_config.dart';

/// The app's copy of the 황금 붕어빵 wallet. The server owns the balance;
/// this keeps the last balance it reported (for display) and which grants
/// were already applied to this save, so each one applies once.
class PremiumState {
  /// Last balance the server reported.
  int gold;

  /// Server grant ids already applied (WalletGrant.id).
  final Set<String> appliedGrants;

  /// Skills unlocked early with gold: buyable before their production goal.
  final Set<String> skillUnlocks;

  /// Whether the first wallet sync of this save happened. On a fresh save
  /// (reinstall) permanent grants are restored but consumed boosts are not
  /// given again.
  bool synced;

  PremiumState(
      {this.gold = 0,
      Set<String>? appliedGrants,
      Set<String>? skillUnlocks,
      this.synced = false})
      : appliedGrants = appliedGrants ?? {},
        skillUnlocks = skillUnlocks ?? {};

  static const grantLimit = 5000;

  Map<String, dynamic> toJson() => {
        'configVersion': premiumConfigVersion,
        'gold': gold,
        'appliedGrants': appliedGrants.toList(),
        'skillUnlocks': skillUnlocks.toList(),
        'synced': synced,
      };

  /// Saves before the wallet existed have no 'premium' entry: [m] is null.
  factory PremiumState.fromJson(Map<String, dynamic>? m,
      {required bool Function(String id) isSkill}) {
    if (m == null) return PremiumState();
    Set<String> ids(String key, int limit) {
      final v = m[key];
      if (v is! List ||
          v.length > limit ||
          v.any((e) => e is! String || e.isEmpty || e.length > 128) ||
          v.toSet().length != v.length) {
        throw const FormatException('황금 붕어빵 기록 손상');
      }
      return v.cast<String>().toSet();
    }

    final gold = m['gold'];
    if (m['configVersion'] != premiumConfigVersion ||
        gold is! int ||
        gold < 0 ||
        m['synced'] is! bool) {
      throw const FormatException('황금 붕어빵 저장 손상');
    }
    final skills = ids('skillUnlocks', 1000);
    if (skills.any((id) => !isSkill(id))) {
      throw const FormatException('알 수 없는 스킬 해금');
    }
    return PremiumState(
        gold: gold,
        appliedGrants: ids('appliedGrants', grantLimit),
        skillUnlocks: skills,
        synced: m['synced'] as bool);
  }
}
