import 'dart:async';

import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../online_backend.dart';
import '../online_ranking.dart';
import '../ranking_config.dart';
import 'avatar_painter.dart';
import 'boost_effects.dart' show lookFromServer;
import 'cozy_style.dart';

/// The Kakao account line shared by the online screens: the login button
/// while signed out (no message when the player backs out), the nickname and
/// a logout button once signed in.
class OnlineAccountBar extends StatefulWidget {
  final GameController controller;

  /// What logging in is for, shown above the button.
  final String guide;
  const OnlineAccountBar(
      {super.key, required this.controller, required this.guide});
  @override
  State<OnlineAccountBar> createState() => _OnlineAccountBarState();
}

class _OnlineAccountBarState extends State<OnlineAccountBar> {
  String? _error;

  GameController get c => widget.controller;

  Future<void> _signIn() async {
    setState(() => _error = null);
    final error = await c.signInOnline();
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    if (!c.online.configured) {
      return const Text('온라인 기능을 준비 중이에요', key: Key('online-unavailable'));
    }
    if (c.online.signedIn) {
      return CozyPanel(
        key: const Key('online-account'),
        padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
        child: Row(children: [
          Expanded(
              child: Text('카카오 계정 · ${c.online.displayName ?? '친구'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          TextButton(
              key: const Key('online-sign-out'),
              onPressed: c.signOutOnline,
              child: const Text('로그아웃')),
        ]),
      );
    }
    return CozyPanel(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.guide),
        const SizedBox(height: 8),
        FilledButton(
            key: const Key('online-sign-in'),
            style: FilledButton.styleFrom(
                backgroundColor: Cozy.orange, foregroundColor: Cozy.ink),
            onPressed: c.signingIn ? null : _signIn,
            child: const Text('카카오 계정으로 로그인')),
        if (_error case final e?)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(e,
                  key: const Key('online-sign-in-error'),
                  style: const TextStyle(
                      color: Cozy.brick, fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

const _boardLabels = {
  rankingBestAutoRate: '초당 생산',
  rankingLifetime: '누적 생산',
  rankingBestCombo: '콤보',
};

String rankingScoreLabel(String board, BigInt score) => switch (board) {
      rankingBestAutoRate => '초당 ${compactNumber(score)}개',
      rankingBestCombo => '${compactNumber(score)}콤보',
      _ => '${compactNumber(score)}개',
    };

/// 온라인 랭킹: three boards of the top [rankingTopCount] players, with my
/// own rank pinned under the list.
class RankingPanel extends StatefulWidget {
  final GameController controller;
  const RankingPanel({super.key, required this.controller});
  @override
  State<RankingPanel> createState() => _RankingPanelState();
}

class _RankingPanelState extends State<RankingPanel> {
  String _board = rankingBestAutoRate;
  RankingBoard? _data;
  bool _loading = false, _failed = false, _signedIn = false;

  GameController get c => widget.controller;

  Future<void> _load() async {
    final board = _board;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final data = await c.loadRanking(board);
    if (!mounted || board != _board) return;
    setState(() {
      _loading = false;
      _data = data;
      _failed = data == null;
    });
  }

  void _select(String board) {
    if (board == _board) return;
    setState(() {
      _board = board;
      _data = null;
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final status = c.rankingStatus;
    // Load on sign-in (also when the screen opens signed in), clear on
    // sign-out.
    if (status.authenticated != _signedIn) {
      _signedIn = status.authenticated;
      _data = null;
      _failed = false;
      if (_signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _signedIn) unawaited(_load());
        });
      }
    }
    if (!status.configured) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('온라인 랭킹을 준비 중이에요', key: Key('ranking-unavailable')));
    }
    if (!status.authenticated) {
      return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OnlineAccountBar(
              controller: c,
              guide: '카카오 계정으로 로그인하면 초당 생산·누적 생산·콤보 순위를 '
                  '다른 플레이어와 겨뤄요.'));
    }
    final capped = _board == rankingLifetime && lifetimeExceedsRanking(c.state);
    // The account line and tabs scroll away with the list (large text
    // leaves little room); my rank stays pinned below.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnlineAccountBar(controller: c, guide: ''),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: [
                      for (final board in rankingBoards)
                        ChoiceChip(
                            key: Key('ranking-tab-$board'),
                            label: Text(_boardLabels[board]!),
                            selected: _board == board,
                            onSelected: (_) => _select(board)),
                    ]),
                    if (capped)
                      const Text('누적 생산은 순위표 최대치로 올라가요.',
                          key: Key('ranking-lifetime-capped')),
                    const SizedBox(height: 6),
                  ]),
            ),
            _list(),
          ]),
        ),
        const SizedBox(height: 6),
        _mine(),
      ]),
    );
  }

  Widget _list() {
    final data = _data;
    Widget message(Widget child) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Padding(padding: const EdgeInsets.all(8), child: child)));
    if (data == null) {
      return message(_failed
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('순위를 불러오지 못했어요', key: Key('ranking-failed')),
              TextButton(
                  key: const Key('ranking-retry'),
                  onPressed: _loading ? null : _load,
                  child: const Text('다시 시도')),
            ])
          : const Text('불러오는 중…', key: Key('ranking-loading')));
    }
    if (data.entries.isEmpty) {
      return message(
          const Text('아직 순위가 없어요. 첫 기록을 올려 보세요!', key: Key('ranking-empty')));
    }
    return SliverList.builder(
      key: const Key('ranking-list'),
      itemCount: data.entries.length,
      itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _row(data.entries[i])),
    );
  }

  Widget _row(RankingEntry e) => CozyPanel(
        key: Key('ranking-row-${e.rank}-${e.playerId}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 40,
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${e.rank}',
                      style: const TextStyle(
                          fontFamily: 'Jua', fontSize: 20, color: Cozy.wood)))),
          SizedBox(
              width: 32,
              height: 37,
              child: e.look.isEmpty
                  ? null
                  : CustomPaint(
                      painter: AvatarPainter(lookFromServer(e.look)))),
          const SizedBox(width: 8),
          // Name over score, so long scores fit with large text.
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(e.me ? '${e.name} (나)' : e.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: e.me ? FontWeight.w900 : FontWeight.w700,
                        color: e.me ? Cozy.brick : Cozy.ink)),
                Text(rankingScoreLabel(_board, e.score),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: Cozy.inkSoft)),
              ])),
        ]),
      );

  Widget _mine() {
    final me = _data?.me;
    return CozyPanel(
      key: const Key('ranking-me'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child:
          Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
        Text(me == null ? '내 순위 · 아직 기록이 없어요' : '내 순위 · ${me.rank}위',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        if (me != null)
          Text(rankingScoreLabel(_board, me.score),
              key: const Key('ranking-me-score'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
