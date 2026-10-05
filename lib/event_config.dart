import 'support_config.dart';

class EventRewardDefinition {
  final String id, title, requiredProduction, capacity, initialClaimed;
  final int requiredLevel;
  final RewardDefinition reward;
  final List<String> prerequisites;
  final bool isFinal;
  const EventRewardDefinition(this.id, this.title, this.requiredLevel,
      this.requiredProduction, this.capacity, this.initialClaimed, this.reward,
      {this.prerequisites = const [], this.isFinal = false});
}

class EventDefinition {
  final String id, title, startsAt, endsAt, initialParticipants;
  final List<EventRewardDefinition> rewards;
  const EventDefinition(this.id, this.title, this.startsAt, this.endsAt,
      this.initialParticipants, this.rewards);
  DateTime get start => DateTime.parse(startsAt);
  DateTime get end => DateTime.parse(endsAt);
}

// Fixed mock season, not a live offer. Change ID for a new event; retain old
// definitions to load old receipts. All targets, counts and rewards estimated.
const eventDefinitions = [
  EventDefinition('night-market-2026', '레벨 10 완성 보상', '2026-09-01T00:00:00Z',
      '2026-11-01T00:00:00Z', '12680', [
    EventRewardDefinition('warmup', '1단계 · 첫 노점', 2, '100', '10000', '8200',
        RewardDefinition('2')),
    EventRewardDefinition('regular', '2단계 · 단골 골목', 5, '10000', '10000', '4800',
        RewardDefinition('3', {'butter': '1'}),
        prerequisites: ['warmup']),
    EventRewardDefinition('master', '3단계 · 달빛 장인', 8, '100000000', '10000',
        '1800', RewardDefinition('5', {'fairy': '1'}),
        prerequisites: ['regular']),
    EventRewardDefinition('final', '최종 · 모의 완주 기록', 10, '20000000000000',
        '10000', '800', RewardDefinition('10', {'fairy': '1', 'butter': '1'}),
        prerequisites: ['master'], isFinal: true),
  ])
];
const currentEventId = 'night-market-2026';
