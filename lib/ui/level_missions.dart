import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../mission_config.dart';
import '../missions.dart';
import '../support_config.dart';
import 'support_panels.dart';

class LevelMissions extends StatelessWidget {
  final GameController controller;
  final VoidCallback onInvites;
  final VoidCallback onItems;
  const LevelMissions(
      {super.key,
      required this.controller,
      required this.onInvites,
      required this.onItems});

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
        const Text(
            '모의 데이터 · 초대 판정은 테스트 입력, 아이템 효과는 추정 설정입니다. 공유는 직접 선택하며 현금 지급은 없습니다.'),
        const SizedBox(height: 12),
        if (active == null) ...[
          const Text('최고 레벨 달성 · 모든 레벨 미션 완료', key: Key('missions-finished')),
        ] else ...[
          Text('Lv.${s.level} → Lv.${active.level} 미션',
              key: const Key('active-mission-title'),
              style: Theme.of(context).textTheme.titleMedium),
          const Text('모든 조건을 달성한 뒤 직접 레벨업 보상을 받으세요.'),
          for (final p in missionProgress(s, active)) _missionCard(context, p),
          const SizedBox(height: 8),
          Text('레벨업 보상: 코인 ${compactNumber(reward)}개 · 수량은 추정 설정'),
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
                              : c.error ?? '조건을 다시 확인해 주세요.')));
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
          const Text('아직 활성화되지 않아 진행을 계산하지 않습니다. 초대는 미리 채울 수 없습니다.'),
          for (final m in preview.missions)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${m.title}: ${compactNumber(m.target)} · 미활성')),
          Text('예상 보상: 코인 ${compactNumber(preview.reward)}개 (추정)'),
        ],
        const Divider(height: 28),
        Text('미션 시즌: ${s.missions.seasonId}',
            style: Theme.of(context).textTheme.bodySmall),
        const Text('공개 후기 기준이며 시즌에 따라 조건이 다를 수 있습니다.'),
        ExpansionTile(
          key: const Key('reward-history'),
          title: Text('레벨 보상 기록 ${s.levelRewards.length}건'),
          children: [
            for (final record in s.levelRewards.values)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(record.source == 'legacy'
                      ? 'Lv.${record.level} · 기존 수령 기록 이전 (금액·시각 미상)'
                      : 'Lv.${record.level} · 코인 ${compactNumber(record.amount!)}개 수령 완료 (기존 별사탕 포함)')),
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
        Text(m.evidence == 'estimated' ? '추정 조건 · estimated' : '공개 후기에서 관찰된 조건',
            style: Theme.of(context).textTheme.bodySmall),
        if (m.kind == MissionKind.newPlayerInvites) ...[
          const Text('활성화 후 초대한 신규 플레이어의 레벨 1 달성만 인정 · 모의'),
          TextButton(
              key: const Key('mission-invites'),
              onPressed: onInvites,
              child: const Text('친구 초대 현황 열기')),
        ],
        if (m.kind == MissionKind.goldenButterUses) ...[
          Text(
              '황금버터 ${c.state.support.inventory['butter']}개 보유 · 사용 시 수량을 소비하고 추정 효과가 적용됩니다.'),
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
                          '황금버터 ${c.state.support.inventory['butter']} → ${c.state.support.inventory['butter']! - BigInt.one}개\n현재 클릭 생산 ${exactNumber(current)} → 사용 후 ${exactNumber(after)}\n${item.durationSeconds}초 적용 · 추정 효과',
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
          TextButton(onPressed: onItems, child: const Text('아이템 확인 · 코인 상점')),
        ],
      ]),
    ));
  }
}
