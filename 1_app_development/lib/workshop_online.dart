import 'dart:convert';
import 'development_purchase_journal.dart';
import 'workshop_purchases.dart';

/// Authenticated Firebase implementation is provided by FirebaseOnlineBackend.
/// NoOnlineBackend is deliberately not an implementation.
abstract class WorkshopTransport {
  String get authenticatedAccount;
  Future<Map<String,dynamic>> callWorkshop(String name, Map<String,dynamic> data);
}
class WorkshopOnline implements WorkshopPurchaseGateway {
  final WorkshopTransport transport;
  String? _account, _progress;
  int? _epoch;
  WorkshopOnline(this.transport);
  @override
  String get authenticatedAccount => transport.authenticatedAccount;
  Future<Map<String,dynamic>> _call(String name,Map<String,dynamic> data) async {
    final account=authenticatedAccount;
    if (account.isEmpty) throw const FormatException('로그인 후 이용할 수 있어요.');
    final result=await transport.callWorkshop(name,data);
    if (authenticatedAccount != account || result['account'] != account) throw const FormatException('확인 중인 계정이 변경됐어요.');
    return result;
  }
  @override
  Future<void> requireActiveProgress(String progressId) async {
    final account=authenticatedAccount;
    final result=await _call('workshopProgressClaim',{'progress':progressId});
    final epoch=result['epoch'];
    if (result['progressId'] != progressId || epoch is! int || epoch <= 0) throw const FormatException('다른 기기의 진행을 먼저 확인해 주세요.');
    _account=account; _progress=progressId; _epoch=epoch;
  }
  Map<String,dynamic> _context() {
    if (_account != authenticatedAccount || _account == null || _progress == null || _epoch == null) {
      throw const FormatException('활성 진행을 먼저 확인해 주세요.');
    }
    return {'progress':_progress,'epoch':_epoch};
  }
  void _accountMatches(String account) {
    if (account != authenticatedAccount) throw const FormatException('원래 계정으로 확인해 주세요.');
  }
  @override
  Future<Map<String,dynamic>> reserve(PurchaseJournal intent) {
    _accountMatches(intent.accountId);
    return _call('workshopPurchaseReserve',{..._context(),'intent':intent.toJson()});
  }
  @override
  Future<Map<String,dynamic>> commit(PurchaseJournal intent) {
    _accountMatches(intent.accountId);
    return _call('workshopPurchaseCommit',{..._context(),'intent':intent.toJson()});
  }
  @override
  Future<Map<String,dynamic>> query(String accountId,String transactionId) {
    _accountMatches(accountId);
    return _call('workshopPurchaseQuery',{..._context(),'transaction':transactionId});
  }
  @override
  Future<Map<String,dynamic>> cancel(String accountId,String transactionId) {
    _accountMatches(accountId);
    return _call('workshopPurchaseCancel',{..._context(),'transaction':transactionId});
  }
  Future<Map<String,dynamic>> reward(String claim,String kind,Map<String,dynamic> payload,{bool query=false}) =>
      _call(query ? 'workshopRewardQuery' : 'workshopRewardSubmit',
        {..._context(),'claim':claim,'kind':kind,'payload':payload});
  Future<Map<String,dynamic>> startAd(String attempt) => _call('workshopAdStart',{..._context(),'attempt':attempt});
  Future<Map<String,dynamic>> queryAd(String attempt) => _call('workshopAdQuery',{..._context(),'attempt':attempt});
}
Object? _canonical(Object? value) {
  if (value is Map<String,dynamic>) {
    final keys=value.keys.toList()..sort();return {for (final k in keys) k:_canonical(value[k])};
  }
  if (value is List) return value.map(_canonical).toList();
  if (value==null || value is String || value is bool || value is int) return value;
  throw const FormatException('보상 증거 형식 오류');
}
String workshopRewardFingerprint(String account,String progress,String claim,String kind,Map<String,dynamic> payload) =>
    jsonEncode([account,progress,claim,kind,_canonical(payload)]);

/// A persisted SERVER outcome, not a local wallet operation. Eligible receipts
/// only acknowledge an already-committed server payment.
Map<String,dynamic> validateWorkshopRewardReceipt(Map<String,dynamic> receipt,{
    required String account,required String progress,required String claim,required String kind,
    required Map<String,dynamic> payload}) {
  final outcome=receipt['outcome'],gold=receipt['gold'],id=receipt['receiptId'];
  if (receipt['account'] != account || receipt['progress'] != progress || receipt['claim'] != claim ||
      receipt['kind'] != kind || receipt['fingerprint'] != workshopRewardFingerprint(account,progress,claim,kind,payload) ||
      !['pending','eligible','noWin','unverifiable'].contains(outcome) ||
      (kind=='mission' && outcome=='noWin') || gold is! int || gold < 0 || id is! String ||
      (outcome=='eligible' ? gold==0 : gold!=0) ||
      (outcome=='pending' ? id.isNotEmpty : id.isEmpty)) throw const FormatException('서버 보상 수신 근거가 일치하지 않아요.');
  return Map<String,dynamic>.from(receipt);
}
