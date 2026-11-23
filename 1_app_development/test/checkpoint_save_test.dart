import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

/// 28번 8절 (2026-11-24): the checkpoint no longer writes the whole save every
/// second. It saves when a level-up, a new day, an expired tub, a rescue pack
/// or a 도감 cell is due, and otherwise once every [checkpointSafetyMs].
/// `safetySaveMs: 0` reproduces the old once-a-second save for comparison.
class CountingSaves implements WorkshopRepository {
  Map<String, dynamic>? stored;
  int saves = 0, bytes = 0;
  @override
  Future<Map<String, dynamic>?> load() async =>
      stored == null ? null : jsonDecode(jsonEncode(stored)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> next, int expectedSequence) async {
    if ((stored?['sequence'] ?? 0) != expectedSequence) throw const FormatException('stale');
    final body = jsonEncode(next);
    saves++;
    bytes += utf8.encode(body).length;
    stored = jsonDecode(body) as Map<String, dynamic>;
  }
}

void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  /// Saves during [seconds] of play after setup, one checkpoint check a second.
  Future<CountingSaves> play(WidgetTester tester, {required int safetySaveMs, required bool open, int seconds = 60}) async {
    var mono = 0;
    final repo = CountingSaves();
    final c = WorkshopController(config, repo, now: () => DateTime.utc(2026, 11, 24, 3),
        monotonicMs: () => mono, safetySaveMs: safetySaveMs);
    await c.initialize();
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
    if (open) await c.openBusiness();
    // Let what the setup made due (the day's order, …) save first.
    mono += 1010;
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    repo..saves = 0..bytes = 0;
    for (var i = 0; i < seconds; i++) {
      mono += 1000;
      await tester.pump(const Duration(milliseconds: 150));
    }
    c.dispose();
    return repo;
  }

  testWidgets('할 일이 없으면 1초마다 저장하지 않고, 60초 안전 저장만 한다 (영업 전)', (tester) async {
    final before = await play(tester, safetySaveMs: 0, open: false);
    final after = await play(tester, safetySaveMs: checkpointSafetyMs, open: false);
    expect(before.saves, greaterThanOrEqualTo(55), reason: '예전 방식: 1초마다 전체 저장');
    expect(after.saves, lessThanOrEqualTo(2), reason: '새 방식: 60초 안전 저장만');
    _record('closed', before, after);
  });

  testWidgets('영업 중에도 저장 횟수가 크게 준다', (tester) async {
    final before = await play(tester, safetySaveMs: 0, open: true);
    final after = await play(tester, safetySaveMs: checkpointSafetyMs, open: true);
    expect(after.saves, lessThan(before.saves));
    _record('open', before, after);
  });

  testWidgets('승급할 수 있게 되면 60초를 기다리지 않고 바로 저장·승급한다', (tester) async {
    var mono = 0;
    final repo = CountingSaves();
    final c = WorkshopController(config, repo, now: () => DateTime.utc(2026, 11, 24, 3), monotonicMs: () => mono);
    await c.initialize();
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
    mono += 1010;
    await tester.pump(const Duration(milliseconds: 150));
    final level = c.state.level;
    // Meet this level's goals outside a command, as production in memory does.
    for (final r in c.levelRequirements) {
      if (r.current < r.target) {
        c.state.soldPieces += (r.target - r.current).toInt();
        c.state.taps += (r.target - r.current).toInt();
      }
    }
    c.state.buns += c.levelCostBuns;
    expect(c.canLevelUp, isTrue);
    mono += 1010;
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(c.state.level, level + 1, reason: '다음 1초 확인에서 바로 승급');
    expect(repo.stored!['level'], level + 1, reason: '승급이 바로 저장됨');
    c.dispose();
  });
}

/// The comparison for the 28번 report (only when asked: SAVE_MEASURE=<file>).
void _record(String scene, CountingSaves before, CountingSaves after) {
  final out = Platform.environment['SAVE_MEASURE'];
  if (out == null) return;
  File(out).writeAsStringSync(
      '$scene before saves=${before.saves} bytes=${before.bytes} after saves=${after.saves} bytes=${after.bytes}\n',
      mode: FileMode.append);
}
