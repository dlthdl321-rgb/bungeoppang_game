import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../support_config.dart';
import '../support_rules.dart';
import '../support_state.dart';
import 'pixel_sprites.dart';

String rewardLabel(RewardDefinition r) => '코인 ${r.coins}개';
String remainingLabel(int ms) {
  final seconds = (ms + 999) ~/ 1000;
  return '${seconds ~/ 60}분 ${(seconds % 60).toString().padLeft(2, '0')}초';
}

Widget saveError(GameController c) => c.error == null
    ? const SizedBox.shrink()
    : Text(c.error!, style: const TextStyle(color: Colors.red));

class DailyMissionsPanel extends StatelessWidget {
  final GameController controller;
  final VoidCallback onStore;
  const DailyMissionsPanel(
      {super.key, required this.controller, required this.onStore});
  @override
  Widget build(BuildContext context) {
    final c = controller, daily = c.state.support.daily;
    final day = daily.day;
    return SingleChildScrollView(
        key: const Key('daily-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$day · 매일 한국 시각 00:00 초기화', key: const Key('daily-date')),
          Text(
              '초기화까지 ${remainingLabel(nextDailyReset(c.gameNow).difference(c.gameNow).inMilliseconds)}'),
          Text('보유 코인 ${compactNumber(c.state.support.coins)}개'),
          TextButton(
              key: const Key('daily-store'),
              onPressed: onStore,
              child: const Text('코인 · 부스트 보기')),
          const Text(
              '초당 목표는 부스트 제외 · 안 받은 보상은 자정에 사라져요'),
          saveError(c),
          for (final d in dailyDefinitions)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(d.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              '${compactNumber(daily.progress(d.metric))} / ${compactNumber(BigInt.parse(d.target))} · ${dailyComplete(c.state, d) ? '완료' : '진행 중'}',
                              key: Key('daily-progress-${d.id}')),
                          LinearProgressIndicator(
                              value: dailyComplete(c.state, d)
                                  ? 1
                                  : (daily.progress(d.metric) *
                                              BigInt.from(1000) ~/
                                              BigInt.parse(d.target))
                                          .toInt() /
                                      1000),
                          Text(rewardLabel(d.reward)),
                          FilledButton(
                              key: Key('daily-claim-${d.id}'),
                              onPressed: !c.busy &&
                                      dailyComplete(c.state, d) &&
                                      !daily.claimed.contains(d.id)
                                  ? () => c.claimDaily(day, d.id)
                                  : null,
                              child: Text(daily.claimed.contains(d.id)
                                  ? '수령 완료'
                                  : '보상 받기')),
                        ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('전체 미션 완료 보상'),
                        Text(rewardLabel(dailyAllReward)),
                        FilledButton(
                            key: const Key('daily-claim-all'),
                            onPressed: !c.busy &&
                                    dailyAllComplete(c.state) &&
                                    !daily.allClaimed
                                ? () => c.claimDaily(day, 'all')
                                : null,
                            child: Text(daily.allClaimed
                                ? '전체 보상 수령 완료'
                                : '전체 완료 보상 받기')),
                      ]))),
        ]));
  }
}

Future<bool> confirmAction(BuildContext context, String title, String details,
        String label) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                scrollable: true,
                title: Text(title),
                content: Text(details),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소')),
                  FilledButton(
                      key: const Key('confirm-support'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(label)),
                ])) ??
    false;

/// Coins and boosts: the coin balance and ledger, and every boost with how
/// to get it and how long the running one lasts.
class SupportPanel extends StatelessWidget {
  final GameController controller;
  const SupportPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state.support;
    return SingleChildScrollView(
        key: const Key('support-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('보유 코인 ${compactNumber(s.coins)}개',
              key: const Key('coin-balance')),
          const Text('부스트가 겹치면 가장 큰 배율 하나만 적용돼요 · 앱을 닫아도 시간이 흘러요'),
          saveError(c),
          for (final boost in boostDefinitions) _boost(context, boost),
          ExpansionTile(title: const Text('코인 거래 기록'), children: [
            for (final entry in s.ledger.values.toList().reversed.take(30))
              ListTile(
                  title: Text(
                      '${entry.delta.isNegative ? '' : '+'}${exactNumber(entry.delta)} · ${entry.reason}'),
                  subtitle: Text(entry.id)),
          ]),
        ]));
  }

  Widget _boost(BuildContext context, BoostDefinition boost) {
    final c = controller, effect = c.state.support.effects[boost.id];
    final running = effect?.activeAt(c.gameNow) == true;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(boost.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '클릭·자동 생산 ${boost.multiplierPermille ~/ effectScale}배 · ${boost.durationSeconds ~/ 60}분'),
                  Text(switch (boost.kind) {
                    BoostKind.invite => '나를 초대한 친구가, 내가 Lv.1을 달성하면 손님으로 와요',
                    BoostKind.visit => '친구가 하루 한 번 내 가게에 들러요',
                    BoostKind.golden => '틀 위 황금 붕어빵을 반짝일 때 눌러요',
                    BoostKind.bought => '상점에서 황금 붕어빵으로 사요',
                  }),
                  Text(
                      running
                          ? '진행 중 · 남은 시간 ${remainingLabel(effect!.remainingMs(c.gameNow))}'
                          : '대기',
                      key: Key('boost-time-${boost.id}')),
                ])));
  }
}
