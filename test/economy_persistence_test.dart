import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'controller_test.dart' show FakeTime;

// Exercises the exact JSON payload contract used by the SQLite body column.
// It deliberately does not claim to test Android's native SQLite plugin.
class JsonRepository implements GameRepository {
  final Map<String, String> disk;
  JsonRepository(this.disk);
  GameState? _decode(String key) => disk[key] == null
      ? null
      : GameState.fromJson(jsonDecode(disk[key]!) as Map<String, dynamic>);
  @override
  Future<GameState?> load() async => _decode('current');
  @override
  Future<GameState?> recover() async => _decode('backup');
  @override
  Future<bool> restoreBackup() async {
    final backup = _decode('backup');
    if (backup == null) return false;
    disk['current'] = jsonEncode(backup.toJson());
    return true;
  }

  @override
  Future<void> clear() async => disk.clear();
  @override
  Future<void> save(GameState state) async {
    if (disk['current'] != null) disk['backup'] = disk['current']!;
    disk['current'] = jsonEncode(state.toJson());
  }
}

void main() {
  test('실제 v1 형태의 6개 스킬 저장을 최신 버전으로 마이그레이션하고 반복 실행해도 보존', () async {
    final legacy = File('test/fixtures/v1_save.json').readAsStringSync();
    final raw = jsonDecode(legacy) as Map<String, dynamic>;
    final disk = <String, String>{'current': legacy};
    final clock = FakeTime();
    final c = GameController(JsonRepository(disk), clock);
    await c.initialize();
    expect(c.state.buns.toString(), raw['buns']);
    expect(c.state.lifetime.toString(), raw['lifetime']);
    expect(c.state.stars.toString(), raw['stars']);
    expect(c.state.level, 10);
    expect(c.state.upgradeCounts['tap_1'], 25);
    expect(c.state.upgradeCounts['auto_16'], 0);
    expect(c.state.upgradeCounts.length, upgrades.length);
    expect(c.state.equippedSkin, 'cocoa');
    expect(c.state.settings.holdToBake, isTrue);
    expect(c.state.settings.reduceMotion, isTrue);
    expect(c.state.activeRemainder, BigInt.from(321));
    expect(autoRate(c.state), BigInt.from(270));
    await c.save();
    final snapshot = c.state.toJson();
    expect(
        jsonDecode(disk['current']!)['formatVersion'], GameState.formatVersion);
    expect(c.state.levelRewards.keys.toSet(), {2, 3, 4, 5, 6, 7, 8, 9, 10});
    c.dispose();
    final restarted = GameController(JsonRepository(disk), clock);
    await restarted.initialize();
    expect(restarted.state.toJson(), snapshot);
    expect(
        (await restarted.repository.recover())!.buns.toString(), raw['buns']);
    restarted.dispose();
  });

  test('큰 수·확장 스킬 구매 후 다른 repository/controller로 재실행해 동일값 복원', () async {
    final disk = <String, String>{};
    final clock = FakeTime();
    final c = GameController(JsonRepository(disk), clock);
    await c.initialize();
    c.state.buns = BigInt.from(10).pow(100);
    c.state.lifetime = c.state.buns;
    expect(await c.buyUpgrade(upgrades.last, 10), isTrue);
    final before = c.state.toJson();
    final rate = autoRate(c.state);
    final price = priceAt(upgrades.last, 10);
    c.dispose();
    final restart = GameController(JsonRepository(disk), clock);
    await restart.initialize();
    expect(restart.state.toJson(), before);
    expect(autoRate(restart.state), rate);
    expect(
        priceAt(upgrades.last, restart.state.upgradeCounts[upgrades.last.id]!),
        price);
    restart.dispose();
  });

  test('미지원 버전·v2 누락 스킬은 조용히 진행상황을 지우지 않고 거부', () {
    final state = GameState.initial(DateTime.utc(2026));
    expect(() => GameState.fromJson(state.toJson()..['formatVersion'] = 999),
        throwsFormatException);
    final json = state.toJson();
    (json['upgradeCounts'] as Map).remove('tap_16');
    expect(() => GameState.fromJson(json), throwsFormatException);
  });
}
