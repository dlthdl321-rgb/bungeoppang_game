import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/development_inventory.dart';
import 'workshop_controller_test.dart' show Gateway;

void main() {
  sqfliteFfiInit();
  late Database db;
  late SqliteWorkshopRepository repository;
  late DevelopmentBalance config;
  late Map<String, dynamic> first;
  setUp(() async {
    config = DevelopmentBalance.fromJson(jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE snapshots(slot TEXT PRIMARY KEY, sequence INTEGER NOT NULL, body TEXT NOT NULL)');
    await db.execute('CREATE TABLE purchase_guard(id INTEGER PRIMARY KEY, body TEXT NOT NULL)');
    repository = SqliteWorkshopRepository.withDatabase(db);
    first = WorkshopState.initial(DateTime.utc(2026, 10, 17), config, 'storage-test').toJson()..['sequence'] = 1;
  });
  tearDown(() => db.close());
  Future<Map<String, dynamic>?> load() => repository.loadValidated((row) { WorkshopState.fromJson(row, config); });
  test('empty database only is a fresh game', () async {
    expect(await load(), isNull);
    await db.insert('snapshots', {'slot':'backup','sequence':1,'body':jsonEncode(first)});
    await expectLater(load(), throwsFormatException);
  });
  test('latest mirror repairs malformed or missing current, repeatedly without rollback', () async {
    await repository.save(first, 0);
    final second = {...first, 'sequence':2, 'buns':'7', 'lifetime':'7'};
    await repository.save(second, 1);
    await db.update('snapshots', {'body':'broken'}, where:'slot = ?', whereArgs:['current']);
    expect(await load(), second);
    expect(await load(), second);
    await db.delete('snapshots', where:'slot = ?', whereArgs:['current']);
    expect(await load(), second);
  });
  test('well formed rolled back current cannot erase latest production', () async {
    await repository.save(first, 0);
    final second = {...first, 'sequence':2, 'buns':'7', 'lifetime':'7'};
    await repository.save(second, 1);
    await db.update('snapshots', {'sequence':1,'body':jsonEncode(first)}, where:'slot = ?', whereArgs:['current']);
    expect(await load(), second);
    await expectLater(repository.save({...second,'sequence':3}, 1), throwsFormatException);
  });
  test('a newer current written without a latest witness is preserved and blocked', () async {
    await repository.save(first,0);
    final newer={...first,'sequence':2,'buns':'9','lifetime':'9'};
    await db.update('snapshots',{'sequence':2,'body':jsonEncode(newer)},where:'slot = ?',whereArgs:['current']);
    await expectLater(load(),throwsFormatException);
    expect((await db.query('snapshots',where:'slot = ?',whereArgs:['current'])).single['body'],jsonEncode(newer));
  });
  test('historical backup and conflicting witness never authorize replay', () async {
    await repository.save(first, 0);
    final second = {...first,'sequence':2};
    await repository.save(second, 1);
    await db.update('snapshots', {'body':'broken'}, where:'slot = ?', whereArgs:['current']);
    await db.update('snapshots', {'sequence':1,'body':jsonEncode(first)}, where:'slot = ?', whereArgs:['recovery']);
    await expectLater(load(), throwsFormatException);
    expect((await db.query('snapshots',where:'slot = ?',whereArgs:['current'])).single['body'], 'broken');
  });
  test('SQL failure after guard/mirror writes rolls back all slots and permits same retry', () async {
    await repository.save(first, 0);
    final before = await db.query('snapshots', orderBy:'slot');
    final guards = await db.query('purchase_guard', orderBy:'id');
    await db.execute("CREATE TRIGGER reject_current BEFORE INSERT ON snapshots WHEN NEW.slot = 'current' BEGIN SELECT RAISE(ABORT, 'disk failure'); END");
    final second = {...first,'sequence':2,'buns':'9','lifetime':'9'};
    await expectLater(repository.save(second, 1), throwsA(isA<DatabaseException>()));
    expect(await db.query('snapshots',orderBy:'slot'), before);
    expect(await db.query('purchase_guard',orderBy:'id'), guards);
    await db.execute('DROP TRIGGER reject_current');
    await repository.save(second, 1);
    expect(await load(), second);
  });
  test('old schema4 SQLite4 adopts recovery rows only on next successful save', () async {
    await repository.save(first, 0);
    await db.delete('purchase_guard',where:'id = ?',whereArgs:[2]);
    await db.delete('snapshots',where:'slot = ?',whereArgs:['recovery']);
    expect(await load(), first);
    await repository.save({...first,'sequence':2}, 1);
    expect((await db.query('purchase_guard')).length, 2);
    await db.delete('purchase_guard',where:'id = ?',whereArgs:[1]);
    await expectLater(load(), throwsFormatException);
  });
  test('controller reload after acknowledged commit loss uses latest sequence once', () async {
    await repository.save(first, 0);
    final c = WorkshopController(config, repository, now:()=>DateTime.utc(2026,10,17));
    addTearDown(c.dispose);
    await c.initialize();
    await c.openBusiness();
    final saved = c.state.toJson();
    await db.update('snapshots',{'body':'broken'},where:'slot = ?',whereArgs:['current']);
    await c.reloadAfterError();
    expect(c.state.business.toJson(), saved['business']);
    expect(c.state.buns.toString(), saved['buns']);
    expect(c.state.sequence, (saved['sequence'] as int)+1);
  });
  test('latest sale, pending reward, relationships and committed purchase recover together', () async {
    final c=WorkshopController(config,repository,now:()=>DateTime.utc(2026,10,17));
    addTearDown(c.dispose);
    await c.initialize(); await c.openBusiness(); await c.welcomeCustomer();
    await c.command(() {
      c.state.buns=BigInt.from(1000); c.state.lifetime=BigInt.from(1000);
      c.state.inventory=c.state.inventory.recordResult(ProductBatch(id:'sale-stock',flavor:'redbean',
        variant:2,quantity:c.state.customers.single.lines.single.quantity,madeOnBusinessIndex:1),keep:true);
    });
    expect(await c.sellToFirstCustomer(), isTrue);
    expect(await c.purchaseSkill(Gateway(),'auto_1'), isTrue);
    final expected=c.state.toJson();
    expect(c.state.sales, isNotEmpty);
    expect(c.state.pendingGold, isNotEmpty);
    await db.update('snapshots', {'body':'broken'},where:'slot = ?',whereArgs:['current']);
    expect(await load(), expected);
    expect(await load(), expected);
  });
  test('concurrent writers with identical expected sequence cannot both commit', () async {
    await repository.save(first,0);
    final other=SqliteWorkshopRepository.withDatabase(db);
    Future<bool> attempt(SqliteWorkshopRepository repo,String buns) async {
      try { await repo.save({...first,'sequence':2,'buns':buns,'lifetime':buns},1); return true; }
      on FormatException { return false; }
    }
    final results=await Future.wait([attempt(repository,'7'),attempt(other,'9')]);
    expect(results.where((ok)=>ok).length,1);
    expect((await load())!['sequence'],2);
  });
  for (final schema in [1,2,3]) {
    test('Workshop schema$schema preserves supported state and adopts latest recovery on save', () async {
      final old={...first,'schema':schema,'buns':'17','lifetime':'17'};
      old.remove('relationships'); old.remove('customerScene');
      if (schema<3) {
        for (final key in ['rewardAccount','rewardReceipts','adAttempts','avatarEquipment','missions','sceneTime']) { old.remove(key); }
      }
      if (schema==1) { old.remove('purchases'); }
      await db.insert('snapshots',{'slot':'current','sequence':1,'body':jsonEncode(old)});
      if (schema>=2) {
        final guard=schema==2 ? old['purchases'] : {
          'purchases':old['purchases'],'rewardAccount':old['rewardAccount'],
          'rewardReceipts':old['rewardReceipts'],'adAttempts':old['adAttempts'],
          'missionClaims':(old['missions'] as Map)['claims']};
        await db.insert('purchase_guard',{'id':1,'body':jsonEncode(guard)});
      }
      final migrated=WorkshopState.fromJson((await load())!,config).toJson()..['sequence']=2;
      await repository.save(migrated,1);
      expect((await load())!['buns'],'17');
      expect((await load())!['schema'],4);
      await db.update('snapshots',{'body':'broken'},where:'slot = ?',whereArgs:['current']);
      expect(await load(),migrated);
    });
  }
}
