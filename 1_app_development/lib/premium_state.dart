import 'premium_config.dart';

/// The app's copy of the 황금 붕어빵 wallet. The server owns the balance;
/// this keeps the last balance it reported (for display) and which grants
/// were already applied to this save, so each one applies once.
class PremiumState {
  /// Last balance the server reported (a build without the online settings:
  /// this device's test gold).
  int gold;
  PremiumState({this.gold = 0});

  Map<String, dynamic> toJson() => {'configVersion': premiumConfigVersion, 'gold': gold};

  /// Saves before the wallet existed have no 'premium' entry: [m] is null.
  /// Older saves also kept the old clicker's applied grants, early skill
  /// unlocks and a sync flag; those are ignored now (32번 3단계).
  factory PremiumState.fromJson(Map<String, dynamic>? m) {
    if (m == null) return PremiumState();
    final gold = m['gold'];
    if (m['configVersion'] != premiumConfigVersion || gold is! int || gold < 0) {
      throw const FormatException('황금 붕어빵 저장 손상');
    }
    return PremiumState(gold: gold);
  }
}
