import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_controller.dart';
import '../invite_config.dart';
import '../invite_models.dart';
import '../invite_sharing.dart';
import '../mission_config.dart';
import '../missions.dart';
import '../support_state.dart';
import 'support_panels.dart' show rewardLabel, remainingLabel;

class InvitePanel extends StatefulWidget {
  final GameController controller;
  final InviteSharingService sharing;
  const InvitePanel(
      {super.key,
      required this.controller,
      this.sharing = const InviteSharingService()});
  @override
  State<InvitePanel> createState() => _InvitePanelState();
}

class _InvitePanelState extends State<InvitePanel> {
  final _player = TextEditingController(text: 'friend-1');
  String? _selected, _message;
  bool _sharing = false;
  GameController get c => widget.controller;
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _share(bool copy, BuildContext buttonContext) async {
    final text = c.inviteShareText;
    if (text == null || _sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      if (copy) {
        await widget.sharing.copy(text);
      } else {
        await widget.sharing.share(text, origin, subject: '오늘의 붕어빵 모의 초대');
      }
      if (mounted) {
        setState(() => _message = copy
            ? '문구·링크 복사 완료 (보상 없음)'
            : '공유 창 닫힘 (전송 여부 확인 불가)');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '공유 불가. 문구 복사를 이용해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _simulate(InviteEventKind kind) async {
    final visit = c.state.invites.visits[_selected];
    final ok = await c.simulateInvitation(
        kind,
        kind == InviteEventKind.clicked
            ? _player.text.trim()
            : visit?.playerId ?? '',
        visitId: kind == InviteEventKind.clicked ? null : visit?.id,
        ticketId: kind == InviteEventKind.clicked ? null : visit?.ticketId);
    if (!mounted) return;
    setState(() {
      if (ok && kind == InviteEventKind.clicked) {
        _selected = c.state.invites.visits.values.last.id;
      }
      _message = ok
          ? '모의 이벤트 저장 완료 · ${c.state.invites.visits[_selected]?.note ?? ''}'
          : c.error ?? '적용 안 됨. 순서·ID·저장 상태를 확인해 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = c.state.invites,
        ticket = state.latestTicket,
        active = activeLevelMission(c.state);
    final goals = active == null
        ? <MissionProgress>[]
        : missionProgress(c.state, active)
            .where((p) => p.definition.kind == MissionKind.newPlayerInvites)
            .toList();
    final day = dailyKey(c.gameNow);
    final today = state.visits.values
        .where((v) =>
            v.rewardId
                ?.startsWith('invite:${state.profile?.origin.name}:$day:') ==
            true)
        .length;
    final selected = state.visits[_selected];
    final clicked = selected?.stage == InviteStage.clicked,
        classified = selected?.stage == InviteStage.classifiedNew;
    return SingleChildScrollView(
        key: const Key('invite-scroll'),
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(c.canSimulateInvites ? '모의 기능 · 초대 성공 테스트' : '친구 초대 현황',
              key: const Key('mock-invite-notice')),
          Text(c.canSimulateInvites
              ? '이 기기 모의 사용자 · 실제 연결·상대 검증 없음'
              : '참여 결과는 초대 저장소에서 확인해요.'),
          const Text('복사·공유만으론 보상 없음 · 현금·상품 지급 없음'),
          const SizedBox(height: 12),
          if (state.profile != null)
            SelectableText('내 추천 코드\n${state.profile!.referralCode}',
                key: const Key('referral-code')),
          FilledButton(
              key: const Key('invite-prepare'),
              onPressed: c.invitesBusy
                  ? null
                  : () async {
                      final ok = await c.prepareInvitation();
                      if (mounted) {
                        setState(() => _message = ok
                            ? '새 초대 링크 저장 완료'
                            : c.error ?? c.inviteError ?? '초대 링크 생성 실패');
                      }
                    },
              child: Text(
                  ticket == null ? '추천 코드 · 초대 링크 만들기' : '현재 미션용 새 초대 링크 만들기')),
          if (ticket != null) ...[
            SelectableText(c.inviteShareText!,
                key: const Key('invite-share-text')),
            if (ticket.missionToken != c.state.missions.token)
              const Text('이전 미션 링크예요. 새 링크를 만드세요.'),
            Wrap(spacing: 8, children: [
              Builder(
                  builder: (ctx) => OutlinedButton(
                      key: const Key('invite-copy'),
                      onPressed: _sharing ? null : () => _share(true, ctx),
                      child: const Text('문구·링크 복사'))),
              Builder(
                  builder: (ctx) => OutlinedButton(
                      key: const Key('invite-share'),
                      onPressed: _sharing ? null : () => _share(false, ctx),
                      child: const Text('시스템 공유'))),
            ]),
          ],
          TextButton(
              key: const Key('invite-refresh'),
              onPressed: c.invitesBusy
                  ? null
                  : () async {
                      final ok = await c.refreshInvitations();
                      if (mounted) {
                        setState(() => _message = ok
                            ? '초대 현황 갱신 완료'
                            : c.error ??
                                c.inviteError ??
                                '조회 실패. 다시 시도해 주세요.');
                      }
                    },
              child: const Text('초대 현황 새로고침')),
          if (_message != null)
            Text(_message!, key: const Key('invite-message')),
          if (c.error != null || c.inviteError != null)
            Text(c.error ?? c.inviteError!,
                key: const Key('invite-save-error')),
          const Divider(),
          Text('오늘 보상 $today명 · $day', key: const Key('invite-today')),
          Text(
              '한국 시각 자정 초기화까지 ${remainingLabel(nextDailyReset(c.gameNow).difference(c.gameNow).inMilliseconds)}'),
          Text(
              '신규 레벨 1 달성: ${rewardLabel(newInviteReward)}\n기존 사용자 참여: ${rewardLabel(existingInviteReward)}'),
          const Text(
              '같은 상대 하루 1회 · 신규 성공은 1회만 · 기존 사용자는 매일 가능'),
          if (goals.isEmpty)
            const Text('활성 초대 미션 없음 · 다음 단계는 미리 채울 수 없어요')
          else
            for (final p in goals)
              Text(
                  'Lv.${active!.level} 도달 미션 · ${p.current}/${p.definition.target}명 ${p.complete ? '완료' : '진행 중'}',
                  key: const Key('mock-invite-progress')),
          const Text(
              '미션 활성화 후 만든 링크의 신규 참여만 인정'),
          if (c.canSimulateInvites)
            ExpansionTile(
                key: const Key('invite-debug'),
                title: const Text('개발자 도구 · 모의 상태 생성'),
                children: [
                  const Text(
                      '가상 상대 ID 입력 · 결과는 이 기기에만 저장'),
                  TextField(
                      key: const Key('invite-player'),
                      controller: _player,
                      maxLength: 128,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z0-9_-]'))
                      ],
                      decoration: const InputDecoration(
                          labelText: '가상 상대 ID', border: OutlineInputBorder())),
                  FilledButton(
                      key: const Key('invite-click'),
                      onPressed: ticket == null || c.invitesBusy
                          ? null
                          : () => _simulate(InviteEventKind.clicked),
                      child: const Text('링크 클릭 생성')),
                  if (state.visits.isNotEmpty)
                    DropdownButtonFormField<String>(
                        key: ValueKey('invite-select-${selected?.id}'),
                        initialValue: selected?.id,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: '처리할 방문 선택'),
                        items: state.visits.values
                            .toList()
                            .reversed
                            .take(30)
                            .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text(
                                    '${v.playerId} · ${_stage(v.stage)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selected = value)),
                  Wrap(spacing: 8, children: [
                    _action('invite-new', '신규 사용자 판정', clicked,
                        InviteEventKind.classifiedNew),
                    _action('invite-level-one', '레벨 1 달성', classified,
                        InviteEventKind.reachedLevelOne),
                    _action('invite-existing', '기존 사용자 참여', clicked,
                        InviteEventKind.existingParticipated),
                    _action('invite-fail', '실패 처리', clicked || classified,
                        InviteEventKind.failed),
                    _action('invite-duplicate', '중복 초대 처리',
                        clicked || classified, InviteEventKind.duplicate),
                  ]),
                  OutlinedButton(
                      key: const Key('invite-replay'),
                      onPressed: selected == null || c.invitesBusy
                          ? null
                          : () async {
                              final events = c.state.invites.events.values
                                  .where((e) => e.visitId == selected.id);
                              if (events.isEmpty) return;
                              final ok =
                                  await c.replayMockEvent(events.last.eventId);
                              if (mounted) {
                                setState(() => _message = ok
                                    ? '이벤트 반영'
                                    : '이미 처리한 eventId · 변경 없음');
                              }
                            },
                      child: const Text('동일 eventId 재전송')),
                  FilledButton(
                      key: const Key('mock-invite-create'),
                      onPressed: c.canQuickInvite
                          ? () async {
                              final ok = await c.createMockInvite();
                              if (mounted) {
                                setState(() => _message = ok
                                    ? '신규 성공 생성 완료 (모의)'
                                    : c.error ?? '모의 입력 실패');
                              }
                            }
                          : null,
                      child: const Text('신규 1명 초대 성공 생성 · 모의')),
                ]),
          const Divider(),
          Text(
              '초대 방문 ${state.visits.length}건 · 처리 이벤트 ${state.events.length}건'),
          if (state.legacyPlayers.isNotEmpty)
            Text('이전 버전 처리 사용자 ${state.legacyPlayers.length}명 보존 · 추가 보상 없음'),
          for (final visit in state.visits.values.toList().reversed.take(30))
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${visit.playerId} · ${_stage(visit.stage)}'),
                          Text(visit.note),
                          Text(
                              '참여일 ${dailyKey(visit.clickedAtUtc)} · ${state.profile?.origin == InviteOrigin.mock ? '모의 데이터' : '서버 결과'}'),
                        ]))),
          const Text('최근 30개 방문 표시'),
        ]));
  }

  Widget _action(
          String key, String title, bool enabled, InviteEventKind kind) =>
      OutlinedButton(
          key: Key(key),
          onPressed: enabled && !c.invitesBusy ? () => _simulate(kind) : null,
          child: Text(title));
  String _stage(InviteStage stage) => switch (stage) {
        InviteStage.clicked => '클릭',
        InviteStage.classifiedNew => '신규 판정',
        InviteStage.newSuccess => '신규 성공',
        InviteStage.existingSuccess => '기존 참여',
        InviteStage.failed => '실패',
        InviteStage.duplicate => '중복',
      };
}
