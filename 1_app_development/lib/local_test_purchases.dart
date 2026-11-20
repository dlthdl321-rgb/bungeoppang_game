import 'development_purchase_journal.dart';
import 'workshop_controller.dart';
import 'workshop_purchases.dart';

/// The account a test build's purchases are made with (4차 피드백 IC10 후속,
/// 사용자 결정 2026-11-21). A save whose `purchases.account` is this id was
/// played in a build without the online settings: its skill levels,
/// cosmetics and gold were never checked by the server, so an online build
/// never trusts it (the login refuses to bind it — [isLocalTestSave] — and
/// every server purchase needs the save's own account).
const localTestAccount = 'local-test';

/// Whether [state] was played with [LocalTestPurchaseGateway].
bool isLocalTestSave(WorkshopState state) =>
    state.purchases.account == localTestAccount || state.rewardAccount == localTestAccount;

/// Skill level-ups and cosmetic purchases in a debug or profile build made
/// without the online settings, so the game can be tested on a phone without
/// a server. The price and the conditions are the same ones the app checks
/// before every purchase ([WorkshopPurchases.prepare]: same config, same
/// quote, level and production total); this stands in for the server's side
/// only: it answers at once and takes the gold from this device's test
/// balance. Release builds never use it (main.dart shows
/// `OnlineSetupMissingApp` instead), and the saves it makes are marked with
/// [localTestAccount].
class LocalTestPurchaseGateway implements WorkshopPurchaseGateway {
  /// This device's gold (test only: `GameState.premium.gold`).
  final int Function() gold;

  /// Stores a new test gold balance; false when it could not be stored now.
  final Future<bool> Function(int gold) setGold;

  LocalTestPurchaseGateway({required this.gold, required this.setGold});

  final _receipts = <String, Map<String, dynamic>>{};

  @override
  String get authenticatedAccount => localTestAccount;

  @override
  Future<void> requireActiveProgress(String progressId) async {}

  Map<String, dynamic> _answer(PurchaseJournal intent, String status) => _receipts[intent.transactionId] = {
        ...intent.toJson(),
        'status': status,
        'receiptId': status == 'reserved' ? '' : 'local-test:${intent.transactionId}',
        'grantId': status == 'committed' ? 'local-test:${intent.transactionId}' : '',
      };

  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent) async {
    final known = _receipts[intent.transactionId];
    if (known != null) return known;
    // Not enough test gold: refused before anything is taken.
    if (BigInt.from(gold()) < intent.quote.gold) return _answer(intent, 'canceled');
    return _answer(intent, 'reserved');
  }

  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal intent) async {
    final known = _receipts[intent.transactionId];
    if (known != null && known['status'] != 'reserved') return known;
    final price = intent.quote.gold.toInt();
    if (gold() < price) return _answer(intent, 'canceled');
    if (price > 0 && !await setGold(gold() - price)) {
      throw const FormatException('시험용 황금을 저장하지 못했어요.');
    }
    return _answer(intent, 'committed');
  }

  @override
  Future<Map<String, dynamic>> query(String accountId, String transactionId) async =>
      _receipts[transactionId] ?? {'account': accountId, 'transaction': transactionId, 'status': 'unknown'};

  @override
  Future<Map<String, dynamic>> cancel(String accountId, String transactionId) async {
    final known = _receipts[transactionId];
    if (known == null || known['status'] != 'reserved') {
      return known ?? {'account': accountId, 'transaction': transactionId, 'status': 'unknown'};
    }
    return _receipts[transactionId] = {...known, 'status': 'canceled', 'receiptId': 'local-test:$transactionId', 'grantId': ''};
  }
}
