import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_friend_visits.dart';
import 'workshop_controller_test.dart' show Repository;

/// DEC-154 친구 가게 방문 (29번 8절): the boost rules.
void main() {
  final rules = FriendVisitRules.fromConfig(DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));
  const minute = 60 * 1000;
  FriendVisitArrival visit(String id, {bool invite = false}) => FriendVisitArrival(id: id, name: id, invite: invite);

  test('설정: 2배, 방문 5분·초대 10분, 하루 3번', () {
    expect([rules.multiplierPermille, rules.visitMs, rules.inviteMs, rules.dailyLimit], [2000, 5 * minute, 10 * minute, 3]);
  });

  test('방문마다 시간이 이어 붙고(배수는 겹치지 않음), 같은 방문은 한 번만', () {
    final (a, gave) = const FriendBoost().apply([visit('v1'), visit('i1', invite: true)], rules, nowMs: 1000, today: 'd1');
    expect(gave.map((v) => v.id), ['v1', 'i1']);
    expect(a.untilMs, 1000 + 15 * minute);
    final (b, again) = a.apply([visit('v1')], rules, nowMs: 2000, today: 'd1');
    expect(again, isEmpty);
    expect(b.untilMs, a.untilMs);
  });

  test('하루 3번까지만 시간을 주고, 넘친 방문도 다시 받지 않게 표시한다. 다음 날은 새로', () {
    final (a, gave) = const FriendBoost().apply([for (var i = 0; i < 5; i++) visit('v$i')], rules, nowMs: 0, today: 'd1');
    expect(gave.length, 3);
    expect(a.untilMs, 15 * minute);
    expect(a.applied.keys, hasLength(5));
    final (b, next) = a.apply([visit('w')], rules, nowMs: 60 * minute, today: 'd2');
    expect(next.single.id, 'w');
    expect(b.untilMs, 65 * minute, reason: '끝난 뒤에 온 방문은 지금부터');
  });

  test('겹친 시간 계산: 부스트가 덮는 부분만', () {
    const boost = FriendBoost(untilMs: 10 * minute, day: 'd', dayCount: 1, applied: {'v': 0});
    expect(boost.boostedMs(9 * minute, 11 * minute), minute);
    expect(boost.boostedMs(11 * minute, 12 * minute), 0);
    expect(boost.activeAt(10 * minute - 1), isTrue);
    expect(boost.remainingMs(4 * minute), 6 * minute);
  });

  test('오래된 방문 기록은 8일 뒤 잊는다', () {
    final (a, _) = const FriendBoost().apply([visit('old')], rules, nowMs: 0, today: 'd1');
    final (b, _) = a.apply([visit('new')], rules, nowMs: FriendBoost.appliedKeepMs, today: 'd9');
    expect(b.applied.keys, ['new']);
  });

  test('저장: 그대로 읽고, 방문 없이 남은 시간·하루 한도 초과는 거부', () {
    final (a, _) = const FriendBoost().apply([visit('v1')], rules, nowMs: 5000, today: 'd1');
    final back = FriendBoost.fromJson(jsonDecode(jsonEncode(a.toJson())), rules);
    expect(back.toJson(), a.toJson());
    expect(() => FriendBoost.fromJson({...a.toJson(), 'applied': <String, int>{}}, rules), throwsFormatException);
    expect(() => FriendBoost.fromJson({...a.toJson(), 'dayCount': 4}, rules), throwsFormatException);
    expect(() => FriendBoost.fromJson({...a.toJson(), 'untilMs': 5000 + 31 * minute}, rules), throwsFormatException);
  });

  test('컨트롤러: 방문하면 탭이 2배, 저장되고 다시 불러와도 같은 방문은 한 번만', () async {
    var at = DateTime.utc(2026, 11, 25, 3);
    final config = DevelopmentBalance.fromJson(
        jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
    final repository = Repository();
    final c = WorkshopController(config, repository, now: () => at, monotonicMs: () => at.millisecondsSinceEpoch);
    await c.initialize();
    await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
    await c.openBusiness();
    final plain = c.tap()!;
    final gave = await c.applyFriendVisits([visit('v1')]);
    expect(gave.single.id, 'v1');
    expect(c.notice, contains('v1님이 놀러 왔어요'));
    expect(c.friendBoostRemainingMs, 5 * minute);
    expect(c.tap(), plain * BigInt.two);
    expect(await c.applyFriendVisits([visit('v1')]), isEmpty, reason: '같은 방문은 한 번만');
    await c.command(() {});
    final back = WorkshopState.fromJson(jsonDecode(jsonEncode(repository.stored)) as Map<String, dynamic>, config);
    expect(back.friendBoost.applied.keys, ['v1']);
    at = at.add(const Duration(minutes: 6));
    expect(c.tap(), plain, reason: '끝나면 원래대로');
    c.dispose();
  });
}
