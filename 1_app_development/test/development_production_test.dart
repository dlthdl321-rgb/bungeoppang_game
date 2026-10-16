import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_business.dart';
import 'package:todays_bungeoppang/development_griddle.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/development_sale_quality.dart';

void main() {
  late DevelopmentBalance config;
  setUp(() => config = DevelopmentBalance.fromJson(jsonDecode(
      File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));
  test('KST 영업일은 같은 날 재개에 노화0, 달력 공백도 실제 이어가기1회다', () {
    final start = DateTime.utc(2026, 10, 16, 14);
    var state = BusinessProgress.initial(start).beginOrContinue(start);
    expect(state.businessIndex, 1);
    state = state.close(start).beginOrContinue(start);
    expect(state.businessIndex, 1);
    final next = DateTime.utc(2026, 10, 20, 15);
    final settlement = state.settle(config, next, bunsPerSecond: BigInt.from(10), offline: true);
    state = settlement.state;
    expect(state.needsContinuation(next), isTrue);
    expect(state.businessIndex, 1);
    state = state.beginOrContinue(next);
    expect(state.businessIndex, 2);
    expect(state.permitsProducts(next), isTrue);
  });
  test('닫힌 영업 생산0, 열린 부재는8시간50%, 재정산은0이다', () {
    final start = DateTime.utc(2026, 10, 16);
    final later = start.add(const Duration(hours: 10));
    final closed = BusinessProgress.initial(start).settle(config, later,
        bunsPerSecond: BigInt.from(10), offline: true);
    expect(closed.buns, BigInt.zero);
    final open = BusinessProgress.initial(start).beginOrContinue(start);
    final settlement = open.settle(config, later, bunsPerSecond: BigInt.from(10), offline: true);
    expect(settlement.buns, BigInt.from(144000));
    expect(settlement.state.settle(config, later, bunsPerSecond: BigInt.from(10), offline: true).buns, BigInt.zero);
    final restored = BusinessProgress.fromJson(jsonDecode(jsonEncode(settlement.state.toJson())) as Map<String, dynamic>);
    expect(restored.toJson(), settlement.state.toJson());
  });
  test('소멸/판매 후에도 결과 기록은 남아 같은 제품을 다시 보관하지 않는다', () {
    final batch = ProductBatch(id: 'result-1', flavor: 'redbean', variant: 2,
        quantity: 1, madeOnBusinessIndex: 1);
    var inventory = InventoryProgress.empty().recordResult(batch, keep: true);
    inventory = inventory.consume({'result-1': 1});
    expect(inventory.recordResult(batch, keep: true), same(inventory));
    expect(inventory.batches, isEmpty);
    expect(() => inventory.recordResult(batch, keep: false), throwsFormatException);
    final restored = InventoryProgress.fromJson(jsonDecode(jsonEncode(inventory.toJson())) as Map<String, dynamic>);
    expect(restored.recordResult(batch, keep: true).batches, isEmpty);
  });
  test('신선도는 달력이 아닌 실제 영업일5에서 소멸한다', () {
    final batch = ProductBatch(id: 'result-1', flavor: 'redbean', variant: 0,
        quantity: 1, madeOnBusinessIndex: 2);
    final inventory = InventoryProgress.empty().recordResult(batch, keep: true);
    expect(inventory.expire(config, 6).batches.length, 1);
    expect(inventory.expire(config, 7).batches, isEmpty);
    final damaged = inventory.toJson();
    ((damaged['batches'] as Map)['result-1'] as Map)['madeOnBusinessIndex'] = 6;
    expect(() => InventoryProgress.fromJson(damaged), throwsFormatException);
  });
  test('6구는 보유/숙련 맛만 배정하고 꺼내기 전에는 제품을 만들지 않는다', () {
    var grid = GriddleProgress.empty('run-1', config);
    expect(() => grid.start(0, config, ownedAndMastered: {}, choose: (ids) => 'redbean'), throwsFormatException);
    grid = grid.start(0, config, ownedAndMastered: {'redbean': 0}, choose: (ids) => ids.single);
    expect(grid.cookingSourceIds.length, 1);
    final harvest = grid.harvest(0, config, businessIndex: 1);
    expect(harvest.product!.variant, 0);
    expect(harvest.state.cookingSourceIds, isEmpty);
    expect(() => harvest.state.harvest(0, config, businessIndex: 1), throwsFormatException);
  });
  test('탄 칸은 직접 폐기하며 재시작에도 맛/회차/경과를 다시 뽑지 않는다', () {
    var grid = GriddleProgress.empty('run-1', config).start(1, config,
        ownedAndMastered: {'redbean': 0}, choose: (ids) => ids.single);
    grid = grid.advanceActive(100000);
    final restored = GriddleProgress.fromJson(jsonDecode(jsonEncode(grid.toJson())) as Map<String, dynamic>, config);
    expect(restored.toJson(), grid.toJson());
    final discarded = restored.harvest(1, config, businessIndex: 1);
    expect(discarded.product, isNull);
    expect(discarded.resultId, 'griddle:run-1:1:1');
  });
  test('준비품은 실제 영업 시작 전 판매 재고가 아니며 최초1회만 귀속한다', () {
    final batch = ProductBatch(id: 'prepared-1', flavor: 'redbean', variant: 2,
        quantity: 1, madeOnBusinessIndex: 0);
    final pending = InventoryProgress.empty().recordPreparedResult(batch, keep: true);
    expect(pending.batches, isEmpty);
    final accepted = pending.acceptPrepared(4);
    expect(accepted.batches[batch.id]!.madeOnBusinessIndex, 4);
    expect(accepted.acceptPrepared(5).batches[batch.id]!.madeOnBusinessIndex, 4);
    final restored = InventoryProgress.fromJson(jsonDecode(jsonEncode(accepted.toJson())) as Map<String, dynamic>);
    expect(restored.recordPreparedResult(batch, keep: true).batches[batch.id]!.madeOnBusinessIndex, 4);
  });
  test('특별 주문의 덜 익음은 품질 감점하지 않고 일반 주문은 차단한다', () {
    final special = evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 0, requestedVariant: 0, specialOrder: true, quantity: 1, age: 0, difficulty: 0)]);
    final medium = evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 2, quantity: 1, age: 0, difficulty: 0)]);
    expect(special.scorePermille, medium.scorePermille);
    expect(() => evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 0, quantity: 1, age: 0, difficulty: 0)]), throwsFormatException);
  });
  test('별점은 일반 대금에 다시 곱하지 않고 만료 제품은 견적도 거부한다', () {
    final soft = evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 1, quantity: 2, age: 0, difficulty: 0)]);
    final medium = evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 2, quantity: 2, age: 0, difficulty: 0)]);
    expect(soft.provisionalOrdinaryBuns, medium.provisionalOrdinaryBuns);
    expect(soft.stars, lessThan(medium.stars));
    expect(() => evaluateSaleQuality(config, [SaleQualityPortion(
        variant: 2, quantity: 1, age: 5, difficulty: 0)]), throwsFormatException);
  });

}
