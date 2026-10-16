import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'widget_test.dart' show mountGame, FixedTime;
import 'controller_test.dart' show catchPlacedGoldenChance;
import 'level_missions_widget_test.dart' show tapVisible;
import 'support_system_test.dart' show fund, completeDaily;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('보조 진행 ${size.width}/$scale 일일 보상→부스트 시간→업적·칭호',
          (tester) async {
        final clock = FixedTime();
        final c = await mountGame(tester, size, textScale: scale, clock: clock);
        c.state.level = 10;
        c.state.missions = MissionState.forLevel(10, clock.utcNow);
        fund(c);
        completeDaily(c);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-menu'));
        await tapVisible(tester, const Key('menu-daily'));
        expect(find.textContaining('한국 시각 00:00'), findsOneWidget);
        await tapVisible(tester, const Key('daily-claim-all'));
        expect(c.state.support.coins, BigInt.from(110));
        expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('daily-claim-all')))
                .onPressed,
            isNull);
        await tapVisible(tester, const Key('daily-claim-taps'));
        expect(c.state.support.coins, BigInt.from(112));
        await tapVisible(tester, const Key('daily-store'));
        expect(find.text('보유 코인 112개'), findsWidgets);
        for (final boost in boostDefinitions) {
          await tester.ensureVisible(find.byKey(Key('boost-time-${boost.id}')));
          expect(
              tester
                  .widget<Text>(find.byKey(Key('boost-time-${boost.id}')))
                  .data,
              '대기');
        }
        expect(await catchPlacedGoldenChance(c), isTrue);
        await tester.pumpAndSettle();
        expect(c.currentTapRate, BigInt.from(3));
        expect(
            tester
                .widget<Text>(find.byKey(const Key('boost-time-golden')))
                .data,
            startsWith('진행 중 · 남은 시간'));
        clock.advance(const Duration(seconds: 60));
        c.tick();
        await tester.pumpAndSettle();
        expect(c.currentTapRate, BigInt.one);
        expect(
            tester
                .widget<Text>(find.byKey(const Key('boost-time-golden')))
                .data,
            '대기');
        // Stage 8: the final mock exchange became achievements and titles.
        while (find.byTooltip('닫기').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
        }
        await tapVisible(tester, const Key('menu-menu'));
        await tapVisible(tester, const Key('menu-achievements'));
        await tapVisible(tester, const Key('achievement-claim-bake-1e4'));
        expect(c.state.support.coins, BigInt.from(114));
        expect(
            tester
                .widget<FilledButton>(
                    find.byKey(const Key('achievement-claim-bake-1e4')))
                .onPressed,
            isNull);
        await tapVisible(tester, const Key('achievement-claim-level-10'));
        expect(c.state.support.coins, BigInt.from(114));
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
  testWidgets('상점의 코인·부스트 화면은 아이템 구매·사용 없이 시간과 기록만 보여 준다',
      (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    fund(c);
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('menu-shop'));
    await tapVisible(tester, const Key('support-entry'));
    expect(find.byKey(const Key('coin-balance')), findsOneWidget);
    for (final boost in boostDefinitions) {
      expect(find.byKey(Key('boost-time-${boost.id}')), findsOneWidget);
    }
    for (final gone in ['support-shop', 'support-items', 'coin-buy-butter',
        'coin-buy-fairy', 'item-use-butter', 'item-use-fairy']) {
      expect(find.byKey(Key(gone)), findsNothing, reason: gone);
    }
    await tester.ensureVisible(find.text('코인 거래 기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('코인 거래 기록'));
    await tester.pumpAndSettle();
    expect(find.text('test:fund'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('구매 취소는 코인과 꾸미기를 변경하지 않는다', (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    fund(c);
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('menu-shop'));
    await tapVisible(tester, const Key('shop-tab-theme'));
    await tapVisible(tester, const Key('shop-buy-night'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(c.state.support.coins, BigInt.from(100));
    expect(
        c.state.ownsCosmetic(
            cosmeticDefinitions.firstWhere((d) => d.id == 'night')),
        isFalse);
    expect(c.state.equippedCosmetic(CosmeticSlot.background), 'clear');
    expect(c.state.support.ledger.keys, ['test:fund']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
