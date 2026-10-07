import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_controller.dart';
import '../online_backend.dart';
import '../support_config.dart';
import 'avatar_painter.dart';
import 'boost_effects.dart';
import 'cozy_style.dart';

/// 친구: my ID, the invitation ID I was given, adding friends by ID and the
/// daily visit that gives a friend a 5-minute boost.
class FriendsPanel extends StatefulWidget {
  final GameController controller;
  const FriendsPanel({super.key, required this.controller});
  @override
  State<FriendsPanel> createState() => _FriendsPanelState();
}

class _FriendsPanelState extends State<FriendsPanel> {
  final _invite = TextEditingController(), _friend = TextEditingController();
  String? _myId, _message;
  List<FriendInfo>? _friends;
  bool _working = false;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (c.online.configured) _refresh();
  }

  @override
  void dispose() {
    _invite.dispose();
    _friend.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = await c.myOnlineId();
    final list = await c.loadFriends();
    if (mounted) {
      setState(() {
        _myId = id;
        _friends = list;
      });
    }
  }

  Future<void> _run(Future<String?> Function() work, String done) async {
    setState(() => _working = true);
    final error = await work();
    await _refresh();
    if (mounted) {
      setState(() {
        _working = false;
        _message = error ?? done;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = c.online.configured;
    final visit = boostOf(BoostKind.visit), invite = boostOf(BoostKind.invite);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!online)
          const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('온라인 기능을 준비 중이에요',
                  key: Key('friends-offline'))),
        CozyPanel(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
                child: Text('내 아이디  ${_myId ?? '-'}',
                    key: const Key('my-online-id'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900))),
            IconButton(
                tooltip: '아이디 복사',
                onPressed: _myId == null
                    ? null
                    : () => Clipboard.setData(ClipboardData(text: _myId!)),
                icon: const Icon(Icons.copy, color: Cozy.wood)),
          ]),
        ),
        const SizedBox(height: 4),
        Text(
            '친구가 하루 한 번 내 가게에 들르면 ${visit.durationSeconds ~/ 60}분 동안 생산 ${visit.multiplierPermille ~/ 1000}배'),
        if (_message case final m?)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(m,
                  key: const Key('friends-message'),
                  style: const TextStyle(
                      color: Cozy.brick, fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        _field(
            key: 'friend-add',
            controller: _friend,
            label: '친구 아이디',
            button: '친구 추가',
            enabled: online && !_working,
            onPressed: () => _run(() => c.addFriend(_friend.text), '친구가 됐어요')),
        const SizedBox(height: 12),
        for (final f in _friends ?? const <FriendInfo>[])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: CozyPanel(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                SizedBox(
                    width: 40,
                    height: 46,
                    child: CustomPaint(
                        painter: AvatarPainter(lookFromServer(f.look)))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(f.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800))),
                FilledButton(
                    key: Key('friend-visit-${f.playerId}'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Cozy.orange,
                        foregroundColor: Cozy.ink),
                    onPressed: f.visitedToday || _working
                        ? null
                        : () => _run(() => c.visitFriend(f.playerId),
                            '${f.name}님 가게에 다녀왔어요'),
                    child: Text(f.visitedToday ? '오늘 방문함' : '방문하기')),
              ]),
            ),
          ),
        const Divider(height: 28),
        Text(
            '초대받았나요? 친구 아이디를 입력하고 Lv.1을 달성하면, 그 친구가 손님으로 와서 '
            '${invite.durationSeconds ~/ 60}분 동안 생산 ${invite.multiplierPermille ~/ 1000}배'),
        const SizedBox(height: 6),
        _field(
            key: 'invite-accept',
            controller: _invite,
            label: '초대 아이디',
            button: '입력',
            enabled: online && !_working,
            onPressed: () => _run(() => c.acceptInvite(_invite.text),
                '초대를 받았어요. Lv.1을 달성해 보세요')),
      ]),
    );
  }

  Widget _field(
          {required String key,
          required TextEditingController controller,
          required String label,
          required String button,
          required bool enabled,
          required VoidCallback onPressed}) =>
      Row(children: [
        Expanded(
            child: TextField(
                key: Key('$key-field'),
                controller: controller,
                enabled: enabled,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                    labelText: label,
                    hintText: 'BB로 시작하는 10자리',
                    border: const OutlineInputBorder()))),
        const SizedBox(width: 8),
        FilledButton(
            key: Key('$key-button'),
            onPressed: enabled ? onPressed : null,
            child: Text(button)),
      ]);
}
