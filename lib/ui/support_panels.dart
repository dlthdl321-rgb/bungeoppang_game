import 'package:flutter/material.dart';
import '../balance.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../support_config.dart';
import '../support_rules.dart';
import '../support_state.dart';

String rewardLabel(RewardDefinition r) => [
      if (r.coins != '0' || r.items.isEmpty) '코인 ${r.coins}개',
      for (final e in r.items.entries)
        '${itemDefinitions.firstWhere((i) => i.id == e.key).name} ${e.value}개',
    ].join(' · ');
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
              child: const Text('아이템 · 코인 상점 열기')),
          const Text(
              '생산 미션은 접속 중 생산, 스킬 구매는 구매 수량, 초당 목표는 아이템 제외 기본 생산 기준입니다. 받지 않은 보상은 자정에 사라집니다.'),
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
                                  : '미션 보상 받기')),
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

class SupportPanel extends StatefulWidget {
  final GameController controller;
  const SupportPanel({super.key, required this.controller});
  @override
  State<SupportPanel> createState() => _SupportPanelState();
}

class _SupportPanelState extends State<SupportPanel> {
  bool _shop = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller, s = c.state.support;
    return Column(children: [
      Text('보유 코인 ${compactNumber(s.coins)}개', key: const Key('coin-balance')),
      Wrap(spacing: 8, children: [
        ChoiceChip(
            key: const Key('support-items'),
            label: const Text('내 아이템'),
            selected: !_shop,
            onSelected: (_) => setState(() => _shop = false)),
        ChoiceChip(
            key: const Key('support-shop'),
            label: const Text('코인 상점'),
            selected: _shop,
            onSelected: (_) => setState(() => _shop = true)),
      ]),
      Expanded(
          child: SingleChildScrollView(
              key: const Key('support-scroll'),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        '아이템 효과 시간은 앱을 닫아도 흐릅니다. 같은 아이템은 효과가 끝난 뒤 다시 쓸 수 있습니다.'),
                    saveError(c),
                    for (final item in itemDefinitions) _item(context, item),
                    if (_shop) ...[
                      const Text('꾸미기 · 생산 효과 없음'),
                      for (final skin
                          in skins.where((s) => s.cost > BigInt.zero))
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(skin.name),
                                      Text(
                                          '가격 ${skin.cost} 코인 · Lv.${skin.unlockLevel} 해금'),
                                      Text(c.state.ownedSkins.contains(skin.id)
                                          ? '현재 영구 보유'
                                          : '현재 미보유 → 구매 후 영구 보유·장착'),
                                      FilledButton(
                                          key: Key('coin-skin-${skin.id}'),
                                          onPressed: !c.busy &&
                                                  !c.state.ownedSkins
                                                      .contains(skin.id) &&
                                                  c.state.level >=
                                                      skin.unlockLevel &&
                                                  s.coins >= skin.cost
                                              ? () async {
                                                  if (await confirmAction(
                                                      context,
                                                      '${skin.name} 구매',
                                                      '가격 ${skin.cost} 코인\n현재 ${exactNumber(s.coins)} → 구매 후 ${exactNumber(s.coins - skin.cost)} 코인\n미보유 → 영구 보유·장착\n생산 효과 없음',
                                                      '구매')) {
                                                    await c.buyOrEquip(skin);
                                                  }
                                                }
                                              : null,
                                          child: Text(c.state.ownedSkins
                                                  .contains(skin.id)
                                              ? '보유 중'
                                              : '꾸미기 구매')),
                                    ]))),
                    ],
                    ExpansionTile(title: const Text('코인 거래 기록'), children: [
                      for (final entry
                          in s.ledger.values.toList().reversed.take(30))
                        ListTile(
                            title: Text(
                                '${entry.delta.isNegative ? '' : '+'}${exactNumber(entry.delta)} · ${entry.reason}'),
                            subtitle: Text(entry.id)),
                    ]),
                  ]))),
    ]);
  }

  Widget _item(BuildContext context, ItemDefinition item) {
    final c = widget.controller, s = c.state.support;
    final quantity = s.inventory[item.id]!, used = s.itemUses[item.id]!;
    final effect = s.effects[item.id],
        running = effect?.activeAt(c.gameNow) == true;
    final price = BigInt.parse(item.coinPrice), sequence = s.purchaseSequence;
    final current = item.channel == EffectChannel.tap
        ? c.currentTapRate
        : c.currentAutoRate;
    final base = item.channel == EffectChannel.tap
        ? tapRate(c.state)
        : autoRate(c.state);
    final after = base *
        BigInt.parse(item.multiplierPermille) ~/
        BigInt.from(effectScale);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(item.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '보유 ${compactNumber(quantity)}개 · 사용 ${compactNumber(used)}회'),
                  Text(
                      '${item.channel == EffectChannel.tap ? '클릭' : '자동'} 생산 ${BigInt.parse(item.multiplierPermille) * BigInt.from(100) ~/ BigInt.from(effectScale)}% · ${item.durationSeconds}초'),
                  Text(
                      running
                          ? '활성 · 남은 시간 ${remainingLabel(effect!.remainingMs(c.gameNow))}'
                          : '비활성',
                      key: Key('item-time-${item.id}')),
                  if (_shop) ...[
                    Text(
                        '가격 ${item.coinPrice} 코인 · 구매 후 수량 ${compactNumber(quantity + BigInt.one)}개'),
                    FilledButton(
                        key: Key('coin-buy-${item.id}'),
                        onPressed: !c.busy && s.coins >= price
                            ? () async {
                                if (await confirmAction(
                                    context,
                                    '${item.name} 구매',
                                    '가격 $price 코인\n현재 ${exactNumber(s.coins)} → 구매 후 ${exactNumber(s.coins - price)} 코인\n보유 $quantity → ${quantity + BigInt.one}개\n구매만으로 효과가 활성화되지 않습니다.',
                                    '구매')) {
                                  await c.buyCoinItem(item.id, sequence);
                                }
                              }
                            : null,
                        child: const Text('코인으로 1개 구매')),
                  ] else ...[
                    Text(
                        '현재 생산 ${compactNumber(current)} → 사용 후 ${compactNumber(after)}'),
                    FilledButton(
                        key: Key('item-use-${item.id}'),
                        onPressed: !c.busy && quantity > BigInt.zero && !running
                            ? () async {
                                if (await confirmAction(
                                    context,
                                    '${item.name} 사용',
                                    '수량 $quantity → ${quantity - BigInt.one}개\n현재 생산 ${exactNumber(current)} → 사용 후 ${exactNumber(after)}\n${item.durationSeconds}초 동안 적용',
                                    '사용')) {
                                  await c.useItem(item.id, expectedUses: used);
                                }
                              }
                            : null,
                        child: const Text('아이템 1개 사용')),
                  ],
                ])));
  }
}
