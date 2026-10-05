import 'package:flutter/material.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../event_config.dart';
import '../game_controller.dart';
import '../menu_rules.dart';
import '../ranking.dart';
import 'fish_painter.dart';
import 'night_stall_painter.dart';
import 'support_panels.dart';

class WardrobePanel extends StatefulWidget {
  final GameController controller;
  const WardrobePanel({super.key, required this.controller});
  @override
  State<WardrobePanel> createState() => _WardrobePanelState();
}

class _WardrobePanelState extends State<WardrobePanel> {
  CosmeticSlot slot = CosmeticSlot.fish;
  String? preview;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    String equipped(CosmeticSlot s) =>
        s == slot && preview != null ? preview! : c.state.equippedCosmetic(s);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('자체 제작 외형 · 가격과 해금 조건은 추정 설정입니다. 생산 효과는 없습니다.'),
          Wrap(spacing: 8, children: [
            for (final s in CosmeticSlot.values)
              ChoiceChip(
                  key: Key('cosmetic-slot-${s.name}'),
                  label: Text(cosmeticSlotLabel(s)),
                  selected: s == slot,
                  onSelected: (_) => setState(() {
                        slot = s;
                        preview = null;
                      }))
          ]),
          const SizedBox(height: 12),
          Semantics(
              label: '꾸미기 미리보기, 구매 전에는 저장되지 않음',
              child: SizedBox(
                  height: 180,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CustomPaint(
                          painter: NightStallPainter(
                              background: equipped(CosmeticSlot.background),
                              stove: equipped(CosmeticSlot.stove),
                              decoration: equipped(CosmeticSlot.decoration)),
                          child: Center(
                              child: SizedBox(
                                  width: 180,
                                  height: 135,
                                  child: CustomPaint(
                                      painter: FishPainter(Colors.brown,
                                          skin: equipped(
                                              CosmeticSlot.fish))))))))),
          Text(preview == null ? '현재 장착 모습' : '미리보기 · 아직 장착되지 않았습니다',
              key: const Key('cosmetic-preview-status')),
          for (final d in cosmeticDefinitions.where((d) => d.slot == slot))
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(d.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('가격 ${compactNumber(d.cost)} 코인 · 생산 효과 없음'),
                          Text(
                              '해금: 레벨 ${d.unlockLevel} · 누적 ${compactNumber(BigInt.parse(d.unlockProduction))}개'),
                          Text(
                              '현재 ${cosmeticDefinitions.firstWhere((item) => item.id == c.state.equippedCosmetic(slot)).name} → ${d.name}'),
                          Wrap(spacing: 8, children: [
                            TextButton(
                                key: Key('preview-${d.id}'),
                                onPressed: () => setState(() => preview = d.id),
                                child: const Text('미리보기')),
                            FilledButton.tonal(
                                key: Key('buy-cosmetic-${d.id}'),
                                onPressed: !c.busy &&
                                        cosmeticUnlocked(c.state, d) &&
                                        c.state.equippedCosmetic(slot) !=
                                            d.id &&
                                        (c.state.ownsCosmetic(d) ||
                                            c.state.support.coins >= d.cost)
                                    ? () async {
                                        if (c.state.ownsCosmetic(d) ||
                                            await confirmAction(
                                                context,
                                                '${d.name} 구매',
                                                '가격 ${d.cost} 코인\n현재 ${exactNumber(c.state.support.coins)} → 구매 후 ${exactNumber(c.state.support.coins - d.cost)} 코인\n미보유 → 영구 보유·장착\n생산 효과 없음',
                                                '구매')) {
                                          final ok =
                                              await c.buyOrEquipCosmetic(d.id);
                                          if (mounted && ok) {
                                            setState(() => preview = null);
                                          }
                                        }
                                      }
                                    : null,
                                child:
                                    Text(c.state.equippedCosmetic(slot) == d.id
                                        ? '장착 중'
                                        : !cosmeticUnlocked(c.state, d)
                                            ? '잠김'
                                            : c.state.ownsCosmetic(d)
                                                ? '장착'
                                                : '구매')),
                          ]),
                        ]))),
          if (c.error != null) Text(c.error!),
        ]));
  }
}

class RankingPanel extends StatefulWidget {
  final GameController controller;
  const RankingPanel({super.key, required this.controller});
  @override
  State<RankingPanel> createState() => _RankingPanelState();
}

class _RankingPanelState extends State<RankingPanel> {
  bool friends = false;
  @override
  Widget build(BuildContext context) {
    final entries =
        rankingFor(widget.controller.state.lifetime, friendsOnly: friends);
    final me = entries.firstWhere((e) => e.isMe);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              '모의 랭킹 · 다른 이름·점수·친구 관계는 가상 데이터입니다. 실제 사용자나 연락처에 연결되지 않습니다.'),
          Wrap(spacing: 8, children: [
            for (final f in [false, true])
              ChoiceChip(
                  key: Key(f ? 'ranking-friends' : 'ranking-all'),
                  label: Text(f ? '친구 순위' : '전체 순위'),
                  selected: f == friends,
                  onSelected: (_) => setState(() => friends = f))
          ]),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      '내 순위 ${me.rank}위 · 누적 생산 ${compactNumber(me.score)}개',
                      key: const Key('ranking-my-rank')))),
          const Text('누적 생산량 기준 · 동점은 공동 순위'),
          for (final e in entries)
            Card(
                color: e.isMe
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.rank}위 · ${e.name}${e.isMe ? ' (나)' : ''}'),
                          Text('${compactNumber(e.score)}개')
                        ]))),
        ]));
  }
}

class EventPanel extends StatelessWidget {
  final GameController controller;
  final VoidCallback onExchange;
  const EventPanel(
      {super.key, required this.controller, required this.onExchange});
  @override
  Widget build(BuildContext context) {
    final c = controller,
        d = eventDefinitions.firstWhere((d) => d.id == currentEventId),
        saved = c.state.events[currentEventId]!;
    final phase = eventPhase(d, c.gameNow);
    final remaining =
        (phase == EventPhase.upcoming ? d.start : d.end).difference(c.gameNow);
    String date(DateTime v) =>
        '${v.add(const Duration(hours: 9)).toIso8601String().substring(0, 16).replaceFirst('T', ' ')} KST';
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              '모의 이벤트 · 일정·수량·참여자·보상은 추정 설정입니다. 이 기기 안에서만 기록되며 실제 돈·상품·포인트는 지급되지 않습니다.'),
          Text(d.title, style: Theme.of(context).textTheme.titleLarge),
          Text('${date(d.start)} ~ ${date(d.end)}'),
          Text(phase == EventPhase.ended
              ? '이벤트 종료'
              : '${phase == EventPhase.upcoming ? '시작' : '종료'}까지 ${remaining.inDays}일 ${remaining.inHours % 24}시간 ${remaining.inMinutes % 60}분'),
          Text('모의 참여자 ${compactNumber(saved.participants)}명'),
          FilledButton(
              key: const Key('event-join'),
              onPressed: !c.busy && !saved.joined && phase == EventPhase.active
                  ? () => c.joinEvent(d.id)
                  : null,
              child: Text(saved.joined ? '참여 완료' : '모의 이벤트 참여')),
          for (final r in d.rewards)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(r.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              '레벨 ${c.state.level}/${r.requiredLevel} · 누적 ${compactNumber(c.state.lifetime)}/${compactNumber(BigInt.parse(r.requiredProduction))}개'),
                          Text(
                              '보상 ${r.reward.coins} 코인${r.reward.items.isEmpty ? '' : ' · ${r.reward.items.entries.map((e) => '${e.key == 'fairy' ? '요정' : '황금버터'} ${e.value}개').join(' · ')}'}'),
                          Text(
                              '선착순 잔여 ${eventRemaining(c.state, d, r)} / ${r.capacity}명'),
                          if (r.prerequisites.isNotEmpty)
                            const Text('앞 단계 보상을 수령해야 합니다.'),
                          FilledButton(
                              key: Key('event-claim-${r.id}'),
                              onPressed: !c.busy &&
                                      canClaimEvent(c.state, d, r, c.gameNow)
                                  ? () => c.claimEventReward(d.id, r.id)
                                  : null,
                              child: Text(saved.receipts.containsKey(r.id)
                                  ? '수령 완료'
                                  : eventRemaining(c.state, d, r) == BigInt.zero
                                      ? '수량 소진'
                                      : phase == EventPhase.ended
                                          ? '종료'
                                          : r.isFinal
                                              ? '최종 모의 보상 수령'
                                              : '모의 보상 수령')),
                        ]))),
          TextButton(
              key: const Key('event-exchange'),
              onPressed: onExchange,
              child: const Text('코인으로 모의 완주 기록 교환')),
          ExpansionTile(title: const Text('개발자 도구 · 모의 선착순'), children: [
            TextButton(
                key: const Key('event-exhaust'),
                onPressed: !c.busy && phase == EventPhase.active
                    ? () => c.simulateEventClaims(
                        d.id, 'final', BigInt.parse(d.rewards.last.capacity))
                    : null,
                child: const Text('가상 다른 참여자로 최종 수량 소진'))
          ]),
          if (c.error != null) Text(c.error!),
        ]));
  }
}
