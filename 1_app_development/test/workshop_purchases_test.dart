import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';

void main() {
  late DevelopmentBalance config;
  late PurchaseJournal intent;
  late WorkshopPurchases book;
  Map<String, dynamic> response(String status) => {...intent.toJson(), 'status': status,
    'receiptId': status == 'reserved' ? '' : 'receipt-fixed', 'grantId': status == 'committed' ? 'grant-fixed' : ''};
  setUp(() {
    config = DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    intent = PurchaseJournal.start('account', 'transaction_0001', quoteCompositeSkill(config, 'tap_1', owned: 0, quantity: 1));
    book = WorkshopPurchases.empty().prepare(config, intent, buns: BigInt.from(100), lifetime: BigInt.from(100));
  });
  test('예약·차감·확정·상품 지급은 같은 거래로 각1회이며 환생 누적은 차감하지 않는다', () {
    expect(book.available(BigInt.from(100)), BigInt.from(85));
    book = book.response(intent.transactionId, response('reserved'));
    var change = book.debit(intent.transactionId, BigInt.from(100));
    expect(change.buns, BigInt.from(85));
    expect(change.purchases.debit(intent.transactionId, change.buns).buns, change.buns);
    book = change.purchases.response(intent.transactionId, response('committed'));
    change = book.settle(intent.transactionId, change.buns);
    expect(change.purchases.owned, {'tap_1':1});
    expect(change.purchases.rate(config, 'tap'), BigInt.from(2));
    expect(change.purchases.settle(intent.transactionId, change.buns).purchases.owned, {'tap_1':1});
    expect(WorkshopPurchases.fromJson(change.purchases.toJson(), config).toJson(), change.purchases.toJson());
  });
  test('서버 취소 증거가 있을 때만 차감액을1회 복원한다', () {
    book = book.response(intent.transactionId, response('reserved'));
    final debit = book.debit(intent.transactionId, BigInt.from(100));
    expect(() => debit.purchases.settle(intent.transactionId, debit.buns), throwsFormatException);
    book = debit.purchases.response(intent.transactionId, response('canceled'));
    final restored = book.settle(intent.transactionId, debit.buns);
    expect(restored.buns, BigInt.from(100));
    expect(restored.purchases.settle(intent.transactionId, restored.buns).buns, restored.buns);
    expect(restored.purchases.owned, isEmpty);
  });
  test('로컬 차감 근거 없이 도착한 서버 성공은 상품으로 바꾸지 않는다', () {
    book = book.response(intent.transactionId, response('committed'));
    expect(() => book.settle(intent.transactionId, BigInt.from(100)), throwsFormatException);
    expect(book.owned, isEmpty);
  });
  test('응답 유실은 취소/환불로 해석하지 않고 미정산 거래를 유지한다', () {
    final unchanged = book.response(intent.transactionId, {'account':'account','transaction':intent.transactionId,'status':'unknown'});
    expect(unchanged.available(BigInt.from(100)), BigInt.from(85));
    final another = PurchaseJournal.start('account', 'transaction_0002', intent.quote);
    expect(() => unchanged.prepare(config, another, buns: BigInt.from(100), lifetime: BigInt.from(100)), throwsFormatException);
    expect(() => book.response(intent.transactionId, {...response('reserved'), 'account':'other'}), throwsFormatException);
  });
  test('보유 개수와 지급 원장의 누락·중복·회차 변경을 거부한다', () {
    book = book.response(intent.transactionId, response('reserved'));
    final debit = book.debit(intent.transactionId, BigInt.from(100));
    book = debit.purchases.response(intent.transactionId, response('committed')).settle(intent.transactionId, debit.buns).purchases;
    final corrupted = book.toJson(); corrupted['owned'] = {'tap_1':2};
    expect(() => WorkshopPurchases.fromJson(corrupted, config), throwsFormatException);
    final missing = book.toJson(); missing['journals'] = <String,dynamic>{};
    expect(() => WorkshopPurchases.fromJson(missing, config), throwsFormatException);
  });
  test('임시 가격 변경은 이미 확정된 영수증과 효과를 다시 계산하지 않는다', () {
    book = book.response(intent.transactionId, response('reserved'));
    final debit = book.debit(intent.transactionId, BigInt.from(100));
    book = debit.purchases.response(intent.transactionId, response('committed')).settle(intent.transactionId, debit.buns).purchases;
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>;
    raw['skill_purchase']['entries']['tap_1']['buns'] = '999';
    final changed = DevelopmentBalance.fromJson(raw);
    expect(WorkshopPurchases.fromJson(book.toJson(), changed).journals[intent.transactionId]!.quote.buns, BigInt.from(15));
  });
  test('유료 아바타도 두 재화 견적·레벨·1회 보유 계약을 사용한다', () {
    final quote=quoteWorkshopProduct(config,'cosmetic:short',owned:0,quantity:1);
    final cosmetic=PurchaseJournal.start('account','cosmetic_0001',quote);
    var wardrobe=WorkshopPurchases.empty().prepare(config,cosmetic,buns:BigInt.from(2000),lifetime:BigInt.from(2000),level:50);
    final receipt={...cosmetic.toJson(),'status':'reserved'};
    wardrobe=wardrobe.response(cosmetic.transactionId,receipt);
    final debit=wardrobe.debit(cosmetic.transactionId,BigInt.from(2000));
    wardrobe=debit.purchases.response(cosmetic.transactionId,{...receipt,'status':'committed','receiptId':'cosmetic-receipt','grantId':'cosmetic-grant'})
      .settle(cosmetic.transactionId,debit.buns).purchases;
    expect(wardrobe.owned['cosmetic:short'],1);
    expect(WorkshopPurchases.fromJson(wardrobe.toJson(),config).owned,wardrobe.owned);
    expect(()=>quoteWorkshopProduct(config,'cosmetic:short',owned:1,quantity:1),throwsFormatException);
    expect(()=>quoteWorkshopProduct(config,'cosmetic:boy',owned:0,quantity:1),throwsFormatException);
  });
  test('신규 아바타 구매로 배경/붕어빵 꾸미기 범위를 몰래 열지 않는다', () {
    expect(()=>quoteWorkshopProduct(config,'cosmetic:forest',owned:0,quantity:1),throwsFormatException);
    expect(()=>quoteWorkshopProduct(config,'cosmetic:choco',owned:0,quantity:1),throwsFormatException);
  });

}
