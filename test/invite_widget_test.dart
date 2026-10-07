import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/invite_models.dart';
import 'widget_test.dart' show mountGame, FixedTime;
import 'level_missions_widget_test.dart' show tapVisible;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('초대 전체 흐름 ${size.width}/$scale: 공유·단계·중복·다음날',
          (tester) async {
        final clock = FixedTime();
        final c = await mountGame(tester, size,
            textScale: scale, clock: clock, reduced: true);
        c.state.level = 9;
        c.state.missions = MissionState.forLevel(9, clock.utcNow,
            seasonId: legacyInviteMissionSeason);
        c.tick();
        await tester.pump();
        String? copied;
        final shares = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform,
            (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        messenger.setMockMethodCallHandler(shareChannel, (call) async {
          shares.add(call);
          return '';
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          messenger.setMockMethodCallHandler(shareChannel, null);
        });
        await tapVisible(tester, const Key('menu-menu'));
        await tapVisible(tester, const Key('menu-share'));
        await tapVisible(tester, const Key('developer-invites'));
        await tapVisible(tester, const Key('invite-prepare'));
        expect(find.byKey(const Key('referral-code')), findsOneWidget);
        await tapVisible(tester, const Key('invite-copy'));
        expect(copied, contains('example.invalid'));
        expect(copied, contains(c.state.invites.profile!.referralCode));
        await tapVisible(tester, const Key('invite-share'));
        expect(shares.single.method, 'share');
        expect((shares.single.arguments as Map)['text'], copied);
        expect(c.state.invites.visits, isEmpty);
        expect(c.state.support.ledger, isEmpty);
        await tapVisible(tester, const Key('invite-debug'));
        await tapVisible(tester, const Key('invite-click'));
        expect(c.state.invites.visits.values.last.stage, InviteStage.clicked);
        expect(
            tester
                .widget<OutlinedButton>(
                    find.byKey(const Key('invite-level-one')))
                .onPressed,
            isNull);
        await tapVisible(tester, const Key('invite-new'));
        expect(c.state.missions.qualifiedInvitePlayers, isEmpty);
        await tapVisible(tester, const Key('invite-level-one'));
        expect(c.state.missions.qualifiedInvitePlayers, {'friend-1'});
        expect(c.state.support.coins, BigInt.from(5));
        await tapVisible(tester, const Key('invite-replay'));
        expect(find.textContaining('이미 처리한 eventId'), findsOneWidget);
        expect(c.state.support.coins, BigInt.from(5));
        final input = find.byKey(const Key('invite-player'));
        await tester.ensureVisible(input);
        await tester.pumpAndSettle();
        await tester.enterText(input, 'existing-friend');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tapVisible(tester, const Key('invite-click'));
        await tapVisible(tester, const Key('invite-existing'));
        await tapVisible(tester, const Key('invite-click'));
        await tapVisible(tester, const Key('invite-existing'));
        expect(c.state.support.coins, BigInt.from(7));
        expect(find.textContaining('오늘 보상 2명'), findsOneWidget);
        clock.advance(const Duration(days: 1));
        c.tick();
        await tester.pumpAndSettle();
        expect(find.textContaining('오늘 보상 0명'), findsOneWidget);
        await tapVisible(tester, const Key('invite-click'));
        await tapVisible(tester, const Key('invite-existing'));
        expect(c.state.support.coins, BigInt.from(9));
        expect(c.state.missions.qualifiedInvitePlayers, {'friend-1'});
        expect(find.textContaining('오늘 보상 1명'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('공유 실패는 안내하고 성공 보상이나 방문을 생성하지 않는다', (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel, (_) async => throw PlatformException(code: 'unavailable'));
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tapVisible(tester, const Key('menu-menu'));
    await tapVisible(tester, const Key('menu-share'));
    await tapVisible(tester, const Key('developer-invites'));
    await tapVisible(tester, const Key('invite-prepare'));
    await tapVisible(tester, const Key('invite-share'));
    expect(find.textContaining('문구 복사를 이용해 주세요'), findsOneWidget);
    expect(c.state.support.ledger, isEmpty);
    expect(c.state.invites.events, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
