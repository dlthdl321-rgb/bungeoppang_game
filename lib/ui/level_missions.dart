import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../mission_config.dart';
import '../missions.dart';
import '../support_config.dart';
import '../prestige_rules.dart';
import 'support_panels.dart';

class LevelMissions extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;
  const LevelMissions(
      {super.key, required this.controller, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state;
    final active = activeLevelMission(s);
    final catalogue = levelsForSeason(s.missions.seasonId);
    final preview = active != null && active.level < catalogue.last.level
        ? catalogue[active.level]
        : null;
    final reward = active == null || s.levelRewards.containsKey(active.level)
        ? BigInt.zero
        : active.reward;
    return SingleChildScrollView(
      key: const Key('mission-scroll'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('현재 Lv.${s.level}', style: Theme.of(context).textTheme.titleLarge),
        const Text('조건을 모두 채우고 코인 보상을 받아요.'),
        const SizedBox(height: 12),
        if (active == null) ...[
          const Text('최고 레벨 달성', key: Key('missions-finished')),
          PrestigeCard(controller: c),
        ] else ...[
          Text('Lv.${s.level} → Lv.${active.level} 미션',
              key: const Key('active-mission-title'),
              style: Theme.of(context).textTheme.titleMedium),
          for (final p in missionProgress(s, active)) _missionCard(context, p),
          const SizedBox(height: 8),
          Text('레벨업 보상: 코인 ${compactNumber(reward)}개'),
          if (c.error != null)
            Text(c.error!,
                key: const Key('mission-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(
            key: const Key('claim-level'),
            onPressed: canClaimLevel(s) && !c.busy
                ? () async {
                    final target = active.level;
                    final ok = await c.claimLevelUp(target);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Lv.$target 달성 · 코인 ${compactNumber(reward)}개 수령'
                              : c.error ?? '조건을 확인해 주세요.')));
                    }
                  }
                : null,
            child: Text('Lv.${active.level} 레벨업 · 보상 받기'),
          ),
        ],
        if (preview != null) ...[
          const Divider(height: 28),
          Text('다음 단계 미리보기 · Lv.${preview.level}',
              key: const Key('mission-preview')),
          const Text('열리면 진행이 시작돼요.'),
          for (final m in preview.missions)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${m.title}: ${compactNumber(m.target)} · 미활성')),
          Text('보상: 코인 ${compactNumber(preview.reward)}개'),
        ],
        const Divider(height: 28),
        ExpansionTile(
          key: const Key('reward-history'),
          title: Text('레벨 보상 기록 ${s.levelRewards.length}건'),
          children: [
            for (final record in s.levelRewards.values)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(record.source == 'legacy'
                      ? 'Lv.${record.level} · 기존 수령 기록 이전 (금액·시각 미상)'
                      : 'Lv.${record.level} · 코인 ${compactNumber(record.amount!)}개 수령 완료')),
          ],
        ),
      ]),
    );
  }

  Widget _missionCard(BuildContext context, MissionProgress p) {
    final m = p.definition, c = controller;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(m.title, style: Theme.of(context).textTheme.titleMedium),
        Text(
            '${compactNumber(p.current)} / ${compactNumber(m.target)} · ${p.complete ? '완료' : '진행 중'}',
            key: Key('mission-${m.id}-status')),
        const SizedBox(height: 6),
        LinearProgressIndicator(
            value: p.permille / 1000,
            semanticsLabel: m.title,
            semanticsValue: '${p.permille ~/ 10}%'),
        if (c.state.missions.waivedGoals.contains(m.id))
          const Text('이전 버전 초대 기록으로 완료 인정',
              key: Key('mission-waived')),
        if (m.kind == MissionKind.newPlayerInvites && c.developerTools) ...[
          const Text('개발자 도구 · 활성화 후 신규 초대의 Lv.1 달성만 인정'),
          TextButton(
              key: const Key('mission-invites'),
              onPressed: () => onOpen('invite'),
              child: const Text('초대 시스템 열기')),
        ],
        if (_shortcut(m.kind) case (final String id, final String label))
          TextButton(
              key: Key('mission-open-${m.id}'),
              onPressed: () => onOpen(id),
              child: Text(label)),
        if (m.kind == MissionKind.goldenButterUses) ...[
          Text(
              '황금버터 ${c.state.support.inventory['butter']}개 보유 · 쓰면 클릭 생산 증가'),
          TextButton(
              key: const Key('mock-butter'),
              onPressed: p.complete ||
                      c.busy ||
                      c.state.support.inventory['butter'] == BigInt.zero
                  ? null
                  : () async {
                      final token = c.state.missions.token;
                      final item =
                          itemDefinitions.firstWhere((i) => i.id == 'butter');
                      final current = c.currentTapRate;
                      final after = tapRate(c.state) *
                          BigInt.parse(item.multiplierPermille) ~/
                          BigInt.from(effectScale);
                      if (!await confirmAction(
                          context,
                          '황금버터 사용',
                          '황금버터 ${c.state.support.inventory['butter']} → ${c.state.support.inventory['butter']! - BigInt.one}개\n현재 클릭 생산 ${exactNumber(current)} → 사용 후 ${exactNumber(after)}\n${item.durationSeconds}초 적용',
                          '사용')) {
                        return;
                      }
                      final ok = await c.simulateButterUse(token);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(c.error ?? '현재 미션을 확인해 주세요.')));
                      }
                    },
              child: const Text('황금버터 1개 사용')),
          TextButton(
              onPressed: () => onOpen('support'),
              child: const Text('아이템 확인 · 코인 상점')),
        ],
      ]),
    ));
  }

  static (String, String)? _shortcut(MissionKind kind) => switch (kind) {
        MissionKind.cosmeticsOwned => ('skins:avatar', '사장님 꾸미기 열기'),
        MissionKind.itemUses => ('support', '아이템 사용하기'),
        MissionKind.skillLevel => ('shop', '상점 열기'),
        MissionKind.achievements => ('achievements', '업적 보기'),
        _ => null,
      };
}

/// Endgame: open a new stall (prestige) for permanent production stars.
class PrestigeCard extends StatelessWidget {
  final GameController controller;
  const PrestigeCard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state;
    final gain = prestigeStarsAvailable(s).toInt();
    final now = prestigePermille(s),
        after = prestigePermilleWith(s.prestige.stars + gain);
    return Card(
        key: const Key('prestige-card'),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('새 노점 열기',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('명성 별 ${s.prestige.stars}개 · 생산 +${(now - 1000) ~/ 10}%',
                      key: const Key('prestige-stars')),
                  Text(gain > 0
                      ? '지금 열면 별 +$gain · 생산 +${(after - 1000) ~/ 10}%'
                      : '누적 생산이 늘면 별이 더 쌓여요.'),
                  const Text('붕어빵·스킬·레벨만 초기화 (레벨업 코인 재지급 없음)'),
                  FilledButton(
                      key: const Key('prestige-open'),
                      onPressed: !c.busy && canPrestige(s)
                          ? () async {
                              if (await confirmAction(
                                  context,
                                  '새 노점을 열까요?',
                                  '초기화: 붕어빵 ${exactNumber(s.buns)}개, 스킬, Lv.${s.level} → Lv.1\n'
                                      '유지: 코인·아이템·꾸미기·업적·칭호·기록·누적 생산\n'
                                      '명성 별 ${s.prestige.stars} → ${s.prestige.stars + gain}개\n'
                                      '생산 +${(now - 1000) ~/ 10}% → +${(after - 1000) ~/ 10}%',
                                  '새 노점 열기')) {
                                await c.prestige();
                              }
                            }
                          : null,
                      child: Text(
                          gain > 0 ? '새 노점 열기 · 별 +$gain' : '별을 더 모아야 해요')),
                ])));
  }
}
