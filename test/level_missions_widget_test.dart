import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'widget_test.dart' show mountGame, CountingRepository;
import 'level_missions_test.dart' show setRate;

Future<void> tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Lv.10 복합 미션 ${size.width} / 글자 $scale: 3명 모의 초대 후 수령',
          (tester) async {
        final c = await mountGame(tester, size, textScale: scale);
        c.state.level = 9;
        c.state.missions = MissionState.forLevel(9, c.clock.utcNow);
        setRate(c.state, BigInt.parse('20000000000000'));
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('level-mission-entry'));
        expect(find.textContaining('모의 데이터'), findsOneWidget);
        expect(find.byKey(const Key('mission-preview')), findsNothing);
        expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('claim-level')))
                .onPressed,
            isNull);
        expect(find.text('0 / 3 · 진행 중'), findsOneWidget);
        await tapVisible(tester, const Key('mission-invites'));
        expect(find.byKey(const Key('mock-invite-notice')), findsOneWidget);
        await tapVisible(tester, const Key('invite-debug'));
        for (var i = 1; i <= 3; i++) {
          await tapVisible(tester, const Key('mock-invite-create'));
          expect(c.state.missions.qualifiedInvitePlayers.length, i);
        }
        expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('mock-invite-create')))
                .onPressed,
            isNull);
        await tester.tap(find.byTooltip('닫기').last);
        await tester.pumpAndSettle();
        expect(find.text('3 / 3 · 완료'), findsOneWidget);
        final before = c.state.support.coins;
        await tapVisible(tester, const Key('claim-level'));
        expect(c.state.level, 10);
        expect(c.state.support.coins, before + BigInt.from(3));
        expect(c.state.levelRewards.keys, [10]);
        expect(find.byKey(const Key('claim-level')), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('missions-finished')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('missions-finished')).hitTestable(),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('조건 미리보기/모의 버터 사용/다음 초대 미션 활성화와 저장 실패 재시도', (tester) async {
    final repo = CountingRepository();
    final c = await mountGame(tester, const Size(360, 800),
        textScale: 2, repository: repo);
    c.state.level = 3;
    c.state.missions = MissionState.forLevel(3, c.clock.utcNow);
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('level-mission-entry'));
    expect(find.text('다음 단계 미리보기 · Lv.5'), findsOneWidget);
    expect(find.text('신규 플레이어 초대 성공: 1 · 미활성'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('claim-level')))
            .onPressed,
        isNull);
    await tapVisible(tester, const Key('mock-butter'));
    await tapVisible(tester, const Key('confirm-support'));
    expect(find.text('1 / 1 · 완료'), findsOneWidget);
    repo.failNextSave = true;
    await tapVisible(tester, const Key('claim-level'));
    expect(c.state.level, 3);
    expect(c.state.support.coins, BigInt.zero);
    expect(c.state.missions.butterUses, BigInt.one);
    expect(find.textContaining('저장하지 못했습니다'), findsWidgets);
    await tapVisible(tester, const Key('claim-level'));
    expect(c.state.level, 4);
    expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
    expect(c.state.missions.butterUses, BigInt.zero);
    expect(find.text('0 / 1 · 진행 중'), findsOneWidget);
    expect(find.text('다음 단계 미리보기 · Lv.6'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('현재 초대 미션이 없으면 일반 친구 초대 화면에서도 생성할 수 없다', (tester) async {
    await mountGame(tester, const Size(390, 844));
    await tapVisible(tester, const Key('menu-invite'));
    expect(find.byKey(const Key('mock-invite-notice')), findsOneWidget);
    expect(find.textContaining('미리 채울 수 없습니다'), findsOneWidget);
    await tapVisible(tester, const Key('invite-debug'));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('mock-invite-create')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
