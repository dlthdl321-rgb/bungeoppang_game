/// SDK boundary: a completion callback is NOT a reward receipt. Production
/// AdMob/SSV integration must implement this after SDK/data/consent review.
enum WorkshopAdFinish { completed, dismissed, unavailable }
abstract class WorkshopAdDriver {
  bool get ready;
  Future<WorkshopAdFinish> show({required String customData});
}
class UnconfiguredWorkshopAdDriver implements WorkshopAdDriver {
  const UnconfiguredWorkshopAdDriver();
  @override
  bool get ready => false;
  @override
  Future<WorkshopAdFinish> show({required String customData}) async => WorkshopAdFinish.unavailable;
}
Map<String,dynamic> validateWorkshopAd(Map<String,dynamic> value,String account,String attempt) {
  if (value['account'] != account || value['attempt'] != attempt ||
      !['unknown','reserved','verifying','verified','rejectedFinal'].contains(value['status'])) throw const FormatException('광고 승인 대상이 일치하지 않아요.');
  if (value['status']=='unknown') return Map<String,dynamic>.from(value);
  final start=value['startedAtMs'],gold=value['gold'],revision=value['revision'];
  if (start is! int || start < 0 || gold is! int || gold <= 0 || revision is! String || revision.isEmpty) throw const FormatException('광고 승인 근거 오류');
  final day=DateTime.fromMillisecondsSinceEpoch(start,isUtc:true).add(const Duration(hours:9)).toIso8601String().substring(0,10);
  if ((value['status']=='verified' && (value['providerProofKey'] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['providerProofKey'] as String))) ||
      value['day'] != day || (value.containsKey('customData') &&
      (value['customData'] is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['customData'] as String))) ||
      (value['paid']==true && (value['status']!='verified' || value['receiptId'] is! String || (value['receiptId'] as String).isEmpty))) {
    throw const FormatException('광고 귀속일/검증 수신 근거 오류');
  }
  return Map<String,dynamic>.from(value);
}
