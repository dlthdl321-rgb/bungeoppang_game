import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/repository.dart';
import 'package:todays_bungeoppang/time_service.dart';

class FakeTime implements TimeService {
  DateTime now = DateTime.utc(2026);
  int mono = 0;
  @override
  DateTime get utcNow => now;
  @override
  int get monotonicMilliseconds => mono;
  void advance(int ms) {
    mono += ms;
    now = now.add(Duration(milliseconds: ms));
  }
}

GameState autoState(FakeTime t, int rate) {
  final s = GameState.initial(t.now);
  if (rate == 1) {
    s.upgradeCounts['auto_1'] = 1;
  } else {
    s.upgradeCounts['auto_3'] = rate ~/ 100;
  }
  s.savedAutoRate = BigInt.from(rate);
  return s;
}

void main() {
  test('초기 탭은 보유량과 누적량에 각각 1을 더한다', () async {
    final t = FakeTime(), r = MemoryGameRepository(), c = GameController(r, t);
    await c.initialize();
    c.tap();
    expect(c.state.buns, BigInt.one);
    expect(c.state.lifetime, BigInt.one);
    c.dispose();
  });
  test('100ms 열 번과 1000ms 한 번 정산이 같다', () {
    final t = FakeTime(),
        a = GameController(MemoryGameRepository(), t)..state = autoState(t, 1),
        b = GameController(MemoryGameRepository(), t)..state = autoState(t, 1);
    for (var i = 0; i < 10; i++) {
      a.settleActive(100);
    }
    b.settleActive(1000);
    expect(a.state.buns, b.state.buns);
    expect(a.state.activeRemainder, b.state.activeRemainder);
  });
  test('미접속 시간 상한과 정산식', () async {
    for (final item in [
      (Duration.zero, 0),
      (const Duration(hours: 1), 180000),
      (const Duration(hours: 8), 1440000),
      (const Duration(hours: 24), 1440000)
    ]) {
      final t = FakeTime(), r = MemoryGameRepository();
      r.current = autoState(t, 100);
      t.now = t.now.add(item.$1);
      final c = GameController(r, t);
      await c.initialize();
      expect(c.state.buns, BigInt.from(item.$2));
      c.dispose();
    }
  });
  test('저장 실패한 중요 변경은 롤백한다', () async {
    final t = FakeTime(), r = MemoryGameRepository(), c = GameController(r, t);
    await c.initialize();
    c.state.buns = BigInt.from(100);
    r.failNextSave = true;
    final ok = await c.buyUpgrade(upgrades.first, 1);
    expect(ok, isFalse);
    expect(c.state.buns, BigInt.from(100));
    c.dispose();
  });
  test('단조 시계가 이미 진행된 앱 시작에서도 미접속 보상을 정산한다', () async {
    final t = FakeTime()..mono = 12345;
    final r = MemoryGameRepository();
    r.current = autoState(t, 100);
    t.now = t.now.add(const Duration(hours: 1));
    final c = GameController(r, t);
    await c.initialize();
    expect(c.state.buns, BigInt.from(180000));
    c.dispose();
  });
}
