import 'package:flutter/material.dart';
import '../achievement_config.dart';
import '../cosmetic_config.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../home_presentation.dart';
import '../invite_config.dart';
import '../invite_sharing.dart';
import '../progress_rules.dart';
import '../weekly_config.dart';
import 'support_panels.dart' show rewardLabel, saveError;

TextStyle? _heading(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium;

Widget _statRow(String label, String value, {Key? key}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [Text(label), Text(value, key: key)]));

/// Personal records on this device. Nothing here is a ranking.
class RecordsPanel extends StatelessWidget {
  final GameController controller;
  const RecordsPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final s = controller.state, r = s.records;
    final today = s.support.daily.production, pastDay = r.pastBestDayProduction;
    final title = s.achievements.equippedTitle;
    return SingleChildScrollView(
        key: const Key('records-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('이 기기에서 플레이한 내 기록입니다. 다른 사람의 기록과 비교하지 않습니다.'),
          if (title != null)
            Text('칭호 · $title', key: const Key('records-title')),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('개인 최고 기록', style: _heading(context)),
                        _statRow('오늘 생산', '${compactNumber(today)}개'),
                        _statRow(
                            '지난 최고 하루 생산',
                            pastDay == BigInt.zero
                                ? '기록 없음'
                                : '${compactNumber(pastDay)}개 (${r.pastBestDay})'),
                        if (pastDay > BigInt.zero && today > pastDay)
                          const Text('오늘 하루 생산 신기록!',
                              key: Key('record-new-day')),
                        _statRow('오늘 최고 콤보', '${r.todayBestCombo}'),
                        _statRow(
                            '지난 최고 콤보',
                            r.pastBestCombo == 0
                                ? '기록 없음'
                                : '${r.pastBestCombo}'),
                        if (r.pastBestCombo > 0 &&
                            r.todayBestCombo > r.pastBestCombo)
                          const Text('콤보 신기록!', key: Key('record-new-combo')),
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('전체 기록', style: _heading(context)),
                        _statRow('최고 초당 생산 (아이템 제외)',
                            '${compactNumber(r.bestAutoRate)}개',
                            key: const Key('record-best-auto')),
                        _statRow('누적 생산', '${compactNumber(s.lifetime)}개',
                            key: const Key('record-lifetime')),
                        _statRow('누적 굽기', '${compactNumber(r.lifetimeTaps)}번'),
                        _statRow('플레이 일수', '${r.playDays}일',
                            key: const Key('record-play-days')),
                        _statRow('최고 콤보',
                            r.bestCombo == 0 ? '기록 없음' : '${r.bestCombo}',
                            key: const Key('record-best-combo')),
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('레벨 도달', style: _heading(context)),
                        for (var level = 2; level <= s.level; level++)
                          _statRow(
                              'Lv.$level',
                              switch (s.levelRewards[level]?.claimedAtUtc) {
                                final DateTime at => kstLabel(at),
                                null => '이전 버전 기록 · 시각 없음',
                              }),
                        if (s.level == 1) const Text('아직 레벨업 기록이 없습니다.'),
                      ]))),
        ]));
  }
}

class WeeklyPanel extends StatelessWidget {
  final GameController controller;
  const WeeklyPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller, weekly = c.state.weekly;
    final theme = seasonThemeForMonth(DateTime.parse(weekly.week).month);
    return SingleChildScrollView(
        key: const Key('weekly-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(theme.title, style: Theme.of(context).textTheme.titleLarge),
          Text(theme.description),
          Text(weeklyCountdownLabel(weekly.week, c.gameNow),
              key: const Key('weekly-countdown')),
          const Text(
              '매주 월요일 00:00(한국 시각)에 새 도전이 자동으로 시작됩니다. 받지 않은 보상은 주가 바뀌면 사라집니다.'),
          saveError(c),
          for (final g in weeklyGoals)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(g.title, style: _heading(context)),
                          Text(
                              '${compactNumber(weekly.progress(g.metric))} / ${compactNumber(g.targetAmount)}',
                              key: Key('weekly-progress-${g.id}')),
                          Text(rewardLabel(g.reward)),
                          FilledButton(
                              key: Key('weekly-claim-${g.id}'),
                              onPressed: !c.busy &&
                                      weeklyGoalComplete(c.state, g) &&
                                      !weekly.claimed.contains(g.id)
                                  ? () => c.claimWeekly(weekly.week, g.id)
                                  : null,
                              child: Text(weekly.claimed.contains(g.id)
                                  ? '수령 완료'
                                  : '보상 받기')),
                        ]))),
        ]));
  }
}

class AchievementPanel extends StatefulWidget {
  final GameController controller;
  const AchievementPanel({super.key, required this.controller});
  @override
  State<AchievementPanel> createState() => _AchievementPanelState();
}

class _AchievementPanelState extends State<AchievementPanel> {
  bool _collection = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return SingleChildScrollView(
        key: const Key('achievement-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(
                key: const Key('achievement-tab-list'),
                label: const Text('업적'),
                selected: !_collection,
                onSelected: (_) => setState(() => _collection = false)),
            ChoiceChip(
                key: const Key('achievement-tab-collection'),
                label: const Text('도감'),
                selected: _collection,
                onSelected: (_) => setState(() => _collection = true)),
          ]),
          saveError(c),
          if (_collection) ..._collectionView(context) else ..._list(context),
        ]));
  }

  List<Widget> _list(BuildContext context) {
    final c = widget.controller, s = c.state;
    return [
      Text(
          '달성 ${achievementsMetCount(s)} / ${achievementDefinitions.length} · 수령 ${s.achievements.claimed.length}',
          key: const Key('achievement-summary')),
      for (final d in achievementDefinitions)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(d.title, style: _heading(context)),
                      Text(
                          '${compactNumber(_capped(achievementProgress(s, d), achievementTarget(d)))} / ${compactNumber(achievementTarget(d))}'),
                      Text([
                        if (d.coins != '0') '코인 ${d.coins}개',
                        if (d.titleReward != null) '칭호 「${d.titleReward}」',
                      ].join(' · ')),
                      FilledButton(
                          key: Key('achievement-claim-${d.id}'),
                          onPressed: !c.busy &&
                                  !s.achievements.claimed.contains(d.id) &&
                                  achievementMet(s, d)
                              ? () => c.claimAchievement(d.id)
                              : null,
                          child: Text(s.achievements.claimed.contains(d.id)
                              ? '수령 완료'
                              : achievementMet(s, d)
                                  ? '보상 받기'
                                  : '진행 중')),
                    ]))),
    ];
  }

  static BigInt _capped(BigInt value, BigInt max) => value > max ? max : value;

  List<Widget> _collectionView(BuildContext context) {
    final c = widget.controller, s = c.state, titles = s.achievements.titles;
    return [
      Text(
          '칭호 ${titles.length} / ${achievementDefinitions.where((d) => d.titleReward != null).length}',
          style: _heading(context)),
      Wrap(spacing: 8, runSpacing: 4, children: [
        ChoiceChip(
            key: const Key('title-none'),
            label: const Text('표시 안 함'),
            selected: s.achievements.equippedTitle == null,
            onSelected: c.busy ? null : (_) => c.equipTitle(null)),
        for (final d
            in achievementDefinitions.where((d) => d.titleReward != null))
          ChoiceChip(
              key: Key('title-${d.id}'),
              label: Text(titles.contains(d.titleReward)
                  ? d.titleReward!
                  : '??? (${d.title})'),
              selected: s.achievements.equippedTitle == d.titleReward,
              onSelected: c.busy || !titles.contains(d.titleReward)
                  ? null
                  : (_) => c.equipTitle(d.titleReward)),
      ]),
      const SizedBox(height: 12),
      Text(
          '꾸미기 도감 ${cosmeticsOwnedCount(s)} / $collectibleCosmeticCount (기본 외형 제외)',
          key: const Key('collection-cosmetics'),
          style: _heading(context)),
      for (final slot in CosmeticSlot.values)
        for (final d in cosmeticDefinitions.where((d) => d.slot == slot))
          ListTile(
              dense: true,
              title: Text('${cosmeticSlotLabel(slot)} · ${d.name}'),
              trailing: Text(s.ownsCosmetic(d) ? '보유' : '미보유')),
    ];
  }
}

/// Release sharing: the OS share sheet with the store link. No reward.
class SharePanel extends StatefulWidget {
  final GameController controller;
  final VoidCallback? onDeveloperInvites;
  final InviteSharingService sharing;
  const SharePanel(
      {super.key,
      required this.controller,
      this.onDeveloperInvites,
      this.sharing = const InviteSharingService()});
  @override
  State<SharePanel> createState() => _SharePanelState();
}

class _SharePanelState extends State<SharePanel> {
  String? _message;
  bool _sharing = false;

  Future<void> _share(BuildContext buttonContext, {bool copy = false}) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      if (copy) {
        await widget.sharing.copy(gameShareText);
      } else {
        await widget.sharing.share(gameShareText, origin);
      }
      if (mounted) {
        setState(() => _message = copy ? '소개 문구와 링크를 복사했습니다.' : '공유 창을 닫았습니다.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '공유 기능을 사용할 수 없습니다. 복사하기를 이용해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('친구에게 오늘의 붕어빵을 소개해 보세요. 공유해도 게임 보상은 없으며, '
            '받는 앱과 상대는 직접 고릅니다.'),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(gameShareText,
                    key: const Key('share-text')))),
        Builder(
            builder: (buttonContext) => FilledButton.icon(
                key: const Key('share-game'),
                onPressed: _sharing ? null : () => _share(buttonContext),
                icon: const Icon(Icons.share_outlined),
                label: const Text('공유하기'))),
        Builder(
            builder: (buttonContext) => TextButton(
                key: const Key('share-copy'),
                onPressed:
                    _sharing ? null : () => _share(buttonContext, copy: true),
                child: const Text('문구 복사하기'))),
        if (_message != null) Text(_message!, key: const Key('share-message')),
        if (widget.onDeveloperInvites != null) ...[
          const Divider(height: 28),
          TextButton(
              key: const Key('developer-invites'),
              onPressed: widget.onDeveloperInvites,
              child: const Text('개발자 도구 · 초대 시스템 (디버그 빌드 전용)')),
        ],
      ]));
}
