import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'widget_test.dart' show mountGame, FixedTime;
import 'level_missions_widget_test.dart' show tapVisible;
import 'support_system_test.dart' show fund, completeDaily;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('보조 진행 ${size.width}/$scale 일일 보상→아이템→코인 구매→업적·칭호',
          (tester) async {
        final clock = FixedTime();
        final c = await mountGame(tester, size, textScale: scale, clock: clock);
        c.state.level = 10;
        c.state.missions = MissionState.forLevel(10, clock.utcNow);
        fund(c);
        completeDaily(c);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-daily'));
        expect(find.textContaining('한국 시각 00:00'), findsOneWidget);
        await tapVisible(tester, const Key('daily-claim-all'));
        expect(c.state.support.coins, BigInt.from(105));
        expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('daily-claim-all')))
                .onPressed,
            isNull);
        await tapVisible(tester, const Key('daily-claim-taps'));
        expect(c.state.support.coins, BigInt.from(107));
        await tapVisible(tester, const Key('daily-store'));
        await tapVisible(tester, const Key('item-use-butter'));
        expect(find.textContaining('초 동안 적용'), findsWidgets);
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.currentTapRate, BigInt.from(2));
        expect(c.state.support.inventory['butter'], BigInt.one);
        expect(find.textContaining('활성 · 남은 시간'), findsOneWidget);
        clock.advance(const Duration(seconds: 60));
        c.tick();
        await tester.pumpAndSettle();
        expect(c.currentTapRate, BigInt.one);
        await tapVisible(tester, const Key('support-shop'));
        await tapVisible(tester, const Key('coin-buy-fairy'));
        expect(find.textContaining('구매만으로 효과가 활성화되지 않습니다'), findsOneWidget);
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.state.support.coins, BigInt.from(104));
        expect(c.state.support.inventory['fairy'], BigInt.from(3));
        await tapVisible(tester, const Key('coin-skin-cocoa'));
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.state.equippedSkin, 'cocoa');
        expect(c.state.support.coins, BigInt.from(92));
        // Stage 8: the final mock exchange became achievements and titles.
        while (find.byTooltip('닫기').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
        }
        await tapVisible(tester, const Key('menu-achievements'));
        await tapVisible(tester, const Key('achievement-claim-bake-1e4'));
        expect(c.state.support.coins, BigInt.from(94));
        expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('achievement-claim-bake-1e4')))
                .onPressed,
            isNull);
        await tapVisible(tester, const Key('achievement-claim-level-10'));
        expect(c.state.support.coins, BigInt.from(94));
        await tapVisible(tester, const Key('achievement-tab-collection'));
        await tapVisible(tester, const Key('title-level-10'));
        expect(c.state.achievements.equippedTitle, '골목 명장');
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('home-title')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets('구매 취소는 코인과 수량을 변경하지 않는다', (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    fund(c);
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('menu-shop'));
    await tapVisible(tester, const Key('support-entry'));
    await tapVisible(tester, const Key('support-shop'));
    await tapVisible(tester, const Key('coin-buy-butter'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(c.state.support.coins, BigInt.from(100));
    expect(c.state.support.inventory['butter'], BigInt.one);
    expect(c.state.support.purchaseSequence, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
