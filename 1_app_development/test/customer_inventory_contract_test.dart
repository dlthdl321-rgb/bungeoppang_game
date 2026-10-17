import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_orders.dart';

void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(jsonDecode(
      File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));
  ProductBatch batch(String id, int day, {int count = 1, int variant = 2}) =>
      ProductBatch(id:id,flavor:'redbean',variant:variant,quantity:count,madeOnBusinessIndex:day);
  CustomerOrder order({int wait = 1, int quantity = 1}) => CustomerOrder(
      id:'order',remainingMs:wait,lines:[CustomerOrderLine(flavor:'redbean',quantity:quantity)]);
  CustomerSalesProgress sales(InventoryProgress stock) => CustomerSalesProgress(
      inventory:stock,ordinaryBuns:BigInt.zero,lifetimeSalesBuns:BigInt.zero);

  test('age4 납품 가능·age5 소멸·미래 묶음과 탄 제품은 자동 선택 제외', () {
    var stock=InventoryProgress.empty();
    for(final b in [batch('old',1),batch('expired',0),batch('future',7),batch('burnt',5,variant:4)]) {
      stock = b.madeOnBusinessIndex==0 ? stock.recordPreparedResult(b,keep:true).acceptPrepared(1) : stock.recordResult(b,keep:true);
    }
    expect(selectCustomerInventory(order(),stock,businessIndex:5),[{'expired':1}]);
    expect(()=>selectCustomerInventory(order(),stock,businessIndex:6),throwsFormatException);
    expect(()=>stock.expire(config,6),throwsFormatException);
    final validStock=InventoryProgress.empty().recordResult(batch('old',1),keep:true);
    expect(validStock.expire(config,6).batches,isEmpty);
  });
  test('동일 날짜 묶음은 ID로 안정 정렬하며 복합 행에서 수량을 이중 배정하지 않는다', () {
    final stock=InventoryProgress.empty().recordResult(batch('b',1),keep:true)
        .recordResult(batch('a',1,count:2),keep:true);
    final composite=CustomerOrder(id:'multi',remainingMs:100,lines:[
      CustomerOrderLine(flavor:'redbean',quantity:2),CustomerOrderLine(flavor:'redbean',quantity:1)]);
    final selected=selectCustomerInventory(composite,stock,businessIndex:1);
    expect(selected,[{'a':2},{'b':1}]);
    final sold=sales(stock).sell(config,composite,selectedByLine:selected,
        businessIndex:1,flavorDifficulties:{'redbean':0});
    expect(sold.inventory.batches,isEmpty);
    expect(validateStoredCustomerSale('multi',sold.sales['multi']!)['businessIndex'],1);
  });
  test('만료 경계 0ms는 무소비·1ms는 판매 가능하고 재시도는 재지급하지 않는다', () {
    final stock=InventoryProgress.empty().recordResult(batch('stock',1),keep:true);
    final initial=sales(stock);
    expect(()=>initial.sell(config,order(wait:0),selectedByLine:[{'stock':1}],
        businessIndex:1,flavorDifficulties:{'redbean':0}),throwsFormatException);
    expect(initial.inventory.batches['stock']!.quantity,1);
    final sold=initial.sell(config,order(),selectedByLine:[{'stock':1}],
        businessIndex:1,flavorDifficulties:{'redbean':0});
    expect(sold.sell(config,order(wait:0),selectedByLine:[{'stock':1}],
        businessIndex:1,flavorDifficulties:{'redbean':0}),same(sold));
    expect(sold.sales.length,1);
  });
  test('공유 묶음 과소 재고와 만료 제품 수동 납품은 전량 실패', () {
    final stock=InventoryProgress.empty().recordResult(batch('stock',1),keep:true);
    final composite=CustomerOrder(id:'multi',remainingMs:100,lines:[
      CustomerOrderLine(flavor:'redbean',quantity:1),CustomerOrderLine(flavor:'redbean',quantity:1)]);
    expect(()=>prepareCustomerSale(config,composite,stock,selectedByLine:[{'stock':1},{'stock':1}],
        businessIndex:1,flavorDifficulties:{'redbean':0}),throwsFormatException);
    expect(()=>prepareCustomerSale(config,order(),stock,selectedByLine:[{'stock':1}],
        businessIndex:6,flavorDifficulties:{'redbean':0}),throwsFormatException);
    expect(stock.batches['stock']!.quantity,1);
  });
  test('준비품 최초 귀속과 부분 판매 후 복원은 제작일과 결과 중복 방지를 보존한다', () {
    final prepared=batch('prepared',0,count:2);
    var stock=InventoryProgress.empty().recordPreparedResult(prepared,keep:true);
    expect(()=>selectCustomerInventory(order(),stock,businessIndex:1),throwsFormatException);
    stock=stock.acceptPrepared(3).consume({'prepared':1});
    stock=InventoryProgress.fromJson(jsonDecode(jsonEncode(stock.toJson())) as Map<String,dynamic>);
    stock=stock.acceptPrepared(4).recordPreparedResult(prepared,keep:true);
    expect(stock.batches['prepared']!.madeOnBusinessIndex,3);
    expect(stock.batches['prepared']!.quantity,1);
    expect(stock.expire(config,8).batches,isEmpty);
    expect(stock.expire(config,8).recordPreparedResult(prepared,keep:true).batches,isEmpty);
  });
}
