import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/economy.dart';
import 'widget_test.dart' show mountGame;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('상점 ${size.width} / 글자 $scale: 수량별 견적·구매·자동 스킬',
          (tester) async {
        final c = await mountGame(tester, size, textScale: scale);
        c.state.buns = BigInt.from(10000);
        c.tick();
        await tester.ensureVisible(find.byKey(const Key('menu-shop')));
        await tester.tap(find.byKey(const Key('menu-shop')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('quantity-ten')));
        await tester.pumpAndSettle();
        expect(find.text('10개 구매 후 클릭당 11'), findsOneWidget);
        final before = c.state.buns;
        final cost = bundlePrice(upgrades.first, 0, 10);
        await tester.ensureVisible(find.byKey(const Key('buy-tap_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('buy-tap_1')));
        await tester.pumpAndSettle();
        expect(c.state.upgradeCounts['tap_1'], 10);
        expect(c.state.buns, before - cost);
        await tester.tap(find.byKey(const Key('quantity-maximum')));
        await tester.pumpAndSettle();
        final max = maxAffordable(upgrades.first, 10, c.state.buns);
        expect(max, greaterThan(0));
        await tester.ensureVisible(find.byKey(const Key('buy-tap_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('buy-tap_1')));
        await tester.pumpAndSettle();
        expect(c.state.upgradeCounts['tap_1'], 10 + max);
        expect(c.state.buns, lessThan(priceAt(upgrades.first, 10 + max)));
        await tester.tap(find.byKey(const Key('kind-auto')));
        await tester.tap(find.byKey(const Key('quantity-one')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('current-auto_1')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('잠금 조건과 구매 가능 강조, 큰 수의 정확한 가격 표시', (tester) async {
    final c = await mountGame(tester, const Size(360, 800));
    c.state.lifetime = BigInt.zero;
    c.state.buns = BigInt.from(100);
    c.tick();
    await tester.tap(find.byKey(const Key('menu-shop')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('status-tap_1'))).data,
        '구매 가능');
    expect(tester.widget<Card>(find.byKey(const Key('skill-tap_1'))).color,
        const Color(0xffedf7ed));
    await tester.scrollUntilVisible(find.byKey(const Key('buy-tap_2')), 180,
        scrollable: find.descendant(
            of: find.byKey(const Key('skills-tap')),
            matching: find.byType(Scrollable)));
    expect(find.textContaining('잠김 · 누적 500'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('buy-tap_2')))
            .onPressed,
        isNull);

    c.state.lifetime = BigInt.from(10).pow(100);
    c.state.buns = c.state.lifetime;
    c.state.upgradeCounts['tap_2'] = 999;
    c.tick();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quantity-ten')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1개 구매 후 클릭당'), findsWidgets);
    final details = find.descendant(
        of: find.byKey(const Key('skill-tap_2')),
        matching: find.text('자세히 보기'));
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.textContaining(exactNumber(priceAt(upgrades[1], 999))),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
