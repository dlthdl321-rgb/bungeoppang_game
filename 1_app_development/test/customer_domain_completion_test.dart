import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/workshop_customer_events.dart';
import 'package:todays_bungeoppang/workshop_customer_orders.dart';
import 'package:todays_bungeoppang/workshop_customers.dart';

void main() {
  late DevelopmentBalance config;
  final catalog = WorkshopCustomerCatalog.bundled();
  setUp(() {
    config = DevelopmentBalance.fromJson(jsonDecode(
        File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  });

  test('태오는 실제 보유한 미경험 신메뉴를 주문하고 판매 이력을 반영한다', () {
    const owned = {'redbean', 'custard', 'cocoa'};
    final first = preferredCustomerFlavor('npc_taeo', config, owned: owned);
    expect(first, isNot('redbean'));
    final second = preferredCustomerFlavor('npc_taeo', config,
        owned: owned, previouslyServed: {first});
    expect(second, isNot(first));
    expect(second, isNot('redbean'));
    expect(preferredCustomerFlavor('npc_taeo', config,
        owned: owned, previouslyServed: {'custard', 'cocoa'}), 'redbean');
    expect(preferredCustomerFlavor('npc_taeo', config, owned: {'redbean'}), 'redbean');
  });
  test('첫 도윤의 팥과 미보유 맛 대체는 숙련과 무관하게 유지된다', () {
    expect(preferredCustomerFlavor('npc_doyun', config,
        owned: {'redbean', 'custard'}, firstCustomer: true), 'redbean');
    expect(preferredCustomerFlavor('npc_doyun', config,
        owned: {'redbean', 'custard'}), 'custard');
    for (final npc in catalog.ids) {
      expect(preferredCustomerFlavor(npc, config, owned: {'redbean'}), 'redbean');
    }
  });

  for (final npc in catalog.ids) {
    final event = 'choice_${npc.substring(4)}_01';
    for (final choice in ['a', 'b', 'c', 'wave']) {
      test('$npc $choice 선택·복원·후일담·재실행 계약', () {
        var state = WorkshopRelationships.empty().visit('visit', npc, 7, catalog)
            .rollChoice(7, [event], 0, config, catalog);
        state = WorkshopRelationships.fromJson(state.toJson(), config, catalog);
        expect(state.active!['event'], event);
        state = state.choose(event, choice, config, catalog);
        state = WorkshopRelationships.fromJson(state.toJson(), config, catalog);
        final expected = {'a': 3, 'b': 2, 'c': 1, 'wave': 0}[choice];
        expect(state.affinity(npc), expected);
        if (choice == 'wave') {
          expect(state.active, isNull);
          expect(state.toJson()['followups'], isEmpty);
          expect(state.toJson()['choices'], isEmpty);
          expect(state.rollChoice(7, [event], 0, config, catalog).active, isNull);
        } else {
          expect((catalog.choice(event)['followups'] as Map)[choice], isA<String>());
          state = state.closeReaction(event);
          expect(state.choose(event, choice, config, catalog).affinity(npc), expected);
          expect(state.toJson()['followups'], {event: choice});
          expect(() => state.consumeFollowup(event, contextMatches: false), throwsFormatException);
          state = state.consumeFollowup(event, contextMatches: true);
          state = WorkshopRelationships.fromJson(state.toJson(), config, catalog);
          expect(state.toJson()['followups'], isEmpty);
          expect(() => state.consumeFollowup(event, contextMatches: true), throwsFormatException);
          expect(state.affinity(npc), expected);
        }
      });
    }
    test('$npc 기본 관계는 선택 사건 없이 진행하며 완료 후 복원한다', () {
      final facts = WorkshopStoryFacts(met: catalog.ids.toSet(),
          affinity: {for (final id in catalog.ids) id: 60},
          successfulVisits: {for (final id in catalog.ids) id: 5},
          drawingConversationSeen: true);
      expect(eligibleCustomerStory(npc, facts, config), isTrue);
      final story = 'story_${npc.substring(4)}_01';
      var state = WorkshopRelationships.empty().visit('visit', npc, 1, catalog)
          .completeStory(npc, story, catalog, eligible: true);
      state = WorkshopRelationships.fromJson(state.toJson(), config, catalog);
      expect(state.stories, contains(story));
      expect(state.completeStory(npc, story, catalog, eligible: true).toJson(), state.toJson());
      expect(state.toJson()['choices'], isEmpty);
    });
  }
}
