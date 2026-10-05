import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/event_config.dart';
import 'widget_test.dart' show mountGame;
import 'level_missions_widget_test.dart' show tapVisible;

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('꾸미기·랭킹·이벤트 ${size.width}/$scale 확대와 모션 감소', (tester) async {
        final c = await mountGame(tester, size,
            textScale: scale, reduced: true, maxLevel: true);
        c.state.lifetime = BigInt.parse('20000000000000');
        c.state.support
            .transact('test:fund', BigInt.from(100), 'test', c.gameNow);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-skins'));
        for (final pair in [
          (CosmeticSlot.background, 'dusk'),
          (CosmeticSlot.stove, 'copper'),
          (CosmeticSlot.decoration, 'lantern')
        ]) {
          await tapVisible(tester, Key('cosmetic-slot-${pair.$1.name}'));
          final old = c.state.equippedCosmetic(pair.$1);
          await tapVisible(tester, Key('preview-${pair.$2}'));
          expect(c.state.equippedCosmetic(pair.$1), old);
          await tapVisible(tester, Key('buy-cosmetic-${pair.$2}'));
          await tapVisible(tester, const Key('confirm-support'));
          expect(c.state.equippedCosmetic(pair.$1), pair.$2);
        }
        expect(c.state.support.coins, BigInt.from(84));
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tapVisible(tester, const Key('menu-ranking'));
        expect(find.textContaining('모의 랭킹'), findsOneWidget);
        await tapVisible(tester, const Key('ranking-friends'));
        c.state.lifetime = BigInt.parse('1000000000000000000');
        c.tick();
        await tester.pumpAndSettle();
        expect(find.textContaining('내 순위 1위'), findsOneWidget);
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tapVisible(tester, const Key('event-entry'));
        await tapVisible(tester, const Key('event-join'));
        for (final r in eventDefinitions.first.rewards) {
          await tapVisible(tester, Key('event-claim-${r.id}'));
        }
        expect(c.state.events[currentEventId]!.receipts.length, 4);
        expect(c.state.support.coins, BigInt.from(104));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
