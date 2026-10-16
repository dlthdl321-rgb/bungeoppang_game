import 'development_balance.dart';

String businessDayKst(DateTime utc) {
  final local = utc.toUtc().add(const Duration(hours: 9));
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

class BusinessSettlement {
  final BusinessProgress state;
  final BigInt buns;
  BusinessSettlement(this.state, this.buns);
}

/// Explicit business days are independent from ad days and app presence.
/// Caller atomically saves the returned state AND adds settlement.buns once.
class BusinessProgress {
  final bool open;
  final int businessIndex;
  final String? acceptedDay;
  final DateTime settledUtc;
  final BigInt fractional;
  BusinessProgress._(this.open, this.businessIndex, this.acceptedDay, this.settledUtc, this.fractional);
  factory BusinessProgress.initial(DateTime now) =>
      BusinessProgress._(false, 0, null, now.toUtc(), BigInt.zero);
  DateTime observed(DateTime now) => now.toUtc().isBefore(settledUtc) ? settledUtc : now.toUtc();
  bool needsContinuation(DateTime now) => open && acceptedDay != businessDayKst(observed(now));
  bool permitsProducts(DateTime now) => open && !needsContinuation(now);

  BusinessSettlement settle(DevelopmentBalance config, DateTime now,
      {required BigInt bunsPerSecond, required bool offline}) {
    if (bunsPerSecond.isNegative) throw const FormatException('음수 생산량');
    final end = observed(now);
    var ms = end.difference(settledUtc).inMilliseconds;
    final fixed = config.section('fixed_requirements');
    if (offline) {
      final cap = DevelopmentBalance.integer(fixed, 'offline_cap_ms');
      if (ms > cap) ms = cap;
    }
    final efficiency = offline ? DevelopmentBalance.integer(fixed, 'offline_efficiency_permille') : 1000;
    final total = fractional + (open ? bunsPerSecond * BigInt.from(ms) * BigInt.from(efficiency) : BigInt.zero);
    final scale = BigInt.from(1000000);
    return BusinessSettlement(BusinessProgress._(open, businessIndex, acceptedDay,
        end, total % scale), total ~/ scale);
  }

  /// Foreground economy follows monotonic elapsed time; a changed wall clock
  /// may advance the calendar cursor but cannot fabricate active production.
  BusinessSettlement settleActive(DateTime now,{required BigInt bunsPerSecond,required int elapsedMs}) {
    if(elapsedMs<0 || bunsPerSecond.isNegative) throw const FormatException('전경 생산 시간 오류');
    final total=fractional+(open ? bunsPerSecond*BigInt.from(elapsedMs)*BigInt.from(1000):BigInt.zero);
    final scale=BigInt.from(1000000);
    return BusinessSettlement(BusinessProgress._(open,businessIndex,acceptedDay,observed(now),total%scale),total~/scale);
  }

  /// The caller first settles through the action's timestamp, including when
  /// the business is closed. Same date reopen never ages inventory twice.
  BusinessProgress beginOrContinue(DateTime now) {
    final at = observed(now);
    if (at != settledUtc) throw const FormatException('영업 전 생산 정산 필요');
    final day = businessDayKst(at);
    if (acceptedDay != null && day.compareTo(acceptedDay!) < 0) {
      throw const FormatException('영업일 역행');
    }
    final increment = acceptedDay == day ? 0 : 1;
    return BusinessProgress._(true, businessIndex + increment, day, at, fractional);
  }
  BusinessProgress close(DateTime now) {
    if (observed(now) != settledUtc) throw const FormatException('영업 종료 전 생산 정산 필요');
    return BusinessProgress._(false, businessIndex, acceptedDay, settledUtc, fractional);
  }
  Map<String, dynamic> toJson() => {'schema': 1, 'open': open,
    'businessIndex': businessIndex, 'acceptedDay': acceptedDay,
    'settledUtc': settledUtc.toIso8601String(), 'fractional': fractional.toString()};
  factory BusinessProgress.fromJson(Map<String, dynamic> row) {
    if (row['schema'] is! int || row['schema'] != 1 || row['open'] is! bool || row['settledUtc'] is! String) {
      throw const FormatException('영업 저장 형식 오류');
    }
    final utc = DateTime.tryParse(row['settledUtc'] as String);
    final day = row['acceptedDay'];
    final index = DevelopmentBalance.integer(row, 'businessIndex');
    final fractional = DevelopmentBalance.decimal(row, 'fractional');
    if (utc == null || !utc.isUtc || fractional >= BigInt.from(1000000) ||
        (day != null && (day is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day))) ||
        (day is String && (DateTime.tryParse('${day}T00:00:00Z') == null ||
            DateTime.parse('${day}T00:00:00Z').toIso8601String().substring(0, 10) != day)) ||
        (index == 0) != (day == null) || (row['open'] == true && day == null) ||
        (day is String && day.compareTo(businessDayKst(utc)) > 0)) {
      throw const FormatException('영업일/정산 상태 오류');
    }
    return BusinessProgress._(row['open'] as bool, index, day as String?, utc, fractional);
  }
}
