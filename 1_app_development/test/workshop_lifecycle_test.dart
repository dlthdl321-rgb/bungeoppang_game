import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_business.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'workshop_controller_test.dart' show Repository, Gateway, cookingFixture;

class InterruptedRepository extends Repository {
  bool loseAcknowledgment = false;
  Completer<void>? gate;
  Completer<void>? loadGate;
  @override
  Future<Map<String,dynamic>?> load() async {
    await loadGate?.future;
    return super.load();
  }
  @override
  Future<void> save(Map<String,dynamic> next, int expectedSequence) async {
    await gate?.future;
    await super.save(next, expectedSequence);
    if (loseAcknowledgment) { loseAcknowledgment = false; throw StateError('commit response lost'); }
  }
}

void main() {
  late DevelopmentBalance config;
  late InterruptedRepository repository;
  late WorkshopController c;
  late DateTime at;
  setUp(() async {
    config = DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String,dynamic>);
    at = DateTime.utc(2026,10,17,14,59,59); // KST 23:59:59
    repository = InterruptedRepository();
    c = WorkshopController(config,repository,now:()=>at);
    await c.initialize();
  });
  tearDown(() => c.dispose());
  test('KST boundary requires explicit continuation and counts actual days only', () async {
    await c.openBusiness();
    expect(c.state.business.acceptedDay, '2026-10-17');
    await c.setForeground(false);
    at = at.add(const Duration(days:8,seconds:2));
    await c.setForeground(true);
    expect(c.state.business.open, isTrue);
    expect(c.state.business.businessIndex, 1);
    expect(c.state.business.needsContinuation(at), isTrue);
    expect(c.state.business.permitsProducts(at), isFalse);
    await c.openBusiness();
    expect(c.state.business.businessIndex, 2);
    await c.closeBusiness(); await c.openBusiness();
    expect(c.state.business.businessIndex, 2);
    at = at.subtract(const Duration(days:20));
    await c.openBusiness();
    expect(c.state.business.businessIndex, 2);
    expect(c.state.business.acceptedDay, '2026-10-26');
  });
  test('preparation binding failure rolls back and retry never refreshes age', () async {
    await c.command(() { c.state.inventory = c.state.inventory.recordPreparedResult(
      ProductBatch(id:'prepared',flavor:'redbean',variant:2,quantity:1,madeOnBusinessIndex:0),keep:true); });
    repository.fail = true;
    expect(await c.openBusiness(), isFalse);
    expect(c.state.business.businessIndex, 0);
    expect(c.state.inventory.bindings, isEmpty);
    await c.reloadAfterError(); await c.openBusiness();
    expect(c.state.inventory.bindings['prepared'], 1);
    for (var day=0;day<5;day++) { at=at.add(const Duration(days:1)); await c.openBusiness(); }
    expect(c.state.inventory.batches, isEmpty);
    expect(c.state.inventory.bindings['prepared'], 1);
    expect(c.state.inventory.dispositions, contains('prepared'));
  });
  test('background and process restart preserve open business and freeze cooking/customer timers', () async {
    await c.openBusiness(); await c.welcomeCustomer();
    await c.command(() { c.state.session=cookingFixture(); });
    await c.setForeground(false);
    final customers = c.state.customers.map((x)=>x.toJson()).toList();
    final phase = c.state.phaseMs;
    c.dispose(); at=at.add(const Duration(hours:3));
    c=WorkshopController(config,repository,now:()=>at); await c.initialize();
    expect(c.state.business.open, isTrue);
    expect(c.state.business.businessIndex, 1);
    expect(c.state.customers.map((x)=>x.toJson()).toList(), customers);
    expect(c.state.phaseMs, phase);
    expect(c.state.session, isNotNull);
    await c.closeBusiness();
    expect(c.state.business.open, isFalse);
    expect(c.state.customers, isEmpty);
    expect(c.state.session, isNull);
  });
  test('closed business earns nothing and open absence is capped and idempotent', () {
    final start=BusinessProgress.initial(at);
    final closed=start.settle(config,at.add(const Duration(days:2)),bunsPerSecond:BigInt.one,offline:true);
    expect(closed.buns, BigInt.zero);
    final open=start.beginOrContinue(at);
    final end=at.add(const Duration(days:2));
    final settlement=open.settle(config,end,bunsPerSecond:BigInt.one,offline:true);
    expect(settlement.buns, BigInt.from(14400));
    expect(settlement.state.settle(config,end,bunsPerSecond:BigInt.one,offline:true).buns, BigInt.zero);
  });
  test('commit acknowledgment loss reloads durable mutation without applying it twice', () async {
    repository.loseAcknowledgment=true;
    expect(await c.openBusiness(), isFalse);
    expect(c.state.business.businessIndex, 0);
    expect(c.error, isNotNull);
    await c.reloadAfterError();
    expect(c.state.business.businessIndex, 1);
    expect(await c.openBusiness(), isTrue);
    expect(c.state.business.businessIndex, 1);
  });
  test('overlapping pause/resume waits for save and latest lifecycle intent wins', () async {
    await c.openBusiness();
    repository.gate=Completer<void>();
    final command=c.command(() { c.state.buns+=BigInt.one; c.state.lifetime+=BigInt.one; });
    final pause=c.setForeground(false);
    final resume=c.setForeground(true);
    final lastPause=c.setForeground(false);
    repository.gate!.complete();
    await Future.wait([command,pause,resume,lastPause]);
    expect(c.foreground, isFalse);
    expect(c.state.business.open, isTrue);
    expect(c.error, isNull);
  });
  test('future inventory binding is rejected rather than making fresh stock', () async {
    await c.openBusiness();
    expect(await c.command(() { c.state.inventory=c.state.inventory.recordResult(
      ProductBatch(id:'future',flavor:'redbean',variant:2,quantity:1,madeOnBusinessIndex:2),keep:true); }), isFalse);
    expect(c.state.inventory.batches, isEmpty);
  });
  test('failed resume remains blocked until reload and cannot duplicate offline yield', () async {
    await c.openBusiness();
    await c.command(() { c.state.buns=BigInt.from(100); c.state.lifetime=BigInt.from(100); });
    expect(await c.purchaseSkill(Gateway(),'auto_1'), isTrue);
    await c.setForeground(false);
    at=at.add(const Duration(seconds:10)); repository.fail=true;
    await c.setForeground(true);
    expect(c.error, isNotNull);
    await c.reloadAfterError();
    final recovered=c.state.buns;
    await c.reloadAfterError();
    expect(c.state.buns, recovered);
  });
  test('recovery read excludes other commands and lifecycle waits for durable recovery', () async {
    await c.openBusiness();
    repository.loadGate=Completer<void>();
    final reload=c.reloadAfterError();
    expect(c.busy, isTrue);
    expect(await c.closeBusiness(), isFalse);
    final pause=c.setForeground(false);
    repository.loadGate!.complete();
    await Future.wait([reload,pause]);
    expect(c.state.business.open, isTrue);
    expect(c.foreground, isFalse);
    expect(c.error, isNull);
  });
}
