import 'package:flutter/material.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../home_presentation.dart';
import '../missions.dart';
import '../achievement_config.dart';
import '../cosmetic_config.dart';
import '../prestige_rules.dart';
import '../progress_rules.dart';
import '../weekly_config.dart';
import 'bake_target.dart';
import 'night_stall_painter.dart';

class NightHome extends StatelessWidget {
  final GameController controller;
  final void Function(String destination) onOpen;
  const NightHome({super.key, required this.controller, required this.onOpen});

  static const cream = Color(0xffffe7ac);
  static const muted = Color(0xffc4d0d7);

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final reduce = state.settings.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 19;
    return Scaffold(
      backgroundColor: const Color(0xff111e30),
      body: RepaintBoundary(
          key: const Key('home-capture'),
          child: Stack(children: [
            Positioned.fill(
                child: RepaintBoundary(
                    child: CustomPaint(
                        painter: NightStallPainter(
                            background:
                                state.equippedCosmetic(CosmeticSlot.background),
                            stove: state.equippedCosmetic(CosmeticSlot.stove),
                            decoration: state
                                .equippedCosmetic(CosmeticSlot.decoration))))),
            SafeArea(
                child: Center(
                    child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                child: LayoutBuilder(builder: (context, box) {
                  final scroll = largeText || box.maxHeight < 680;
                  final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        _production(context),
                        if (controller.error != null)
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(controller.error!),
                                    TextButton(
                                        onPressed: controller.save,
                                        child: const Text('저장 재시도')),
                                  ])),
                        if (scroll)
                          SizedBox(
                              height: largeText ? 460 : 320,
                              child: _stage(reduce, largeText))
                        else
                          Expanded(child: _stage(reduce, largeText)),
                        _level(context),
                        _event(),
                      ]);
                  return scroll
                      ? SingleChildScrollView(
                          key: const Key('home-scroll'), child: content)
                      : content;
                }),
              ),
            ))),
          ])),
    );
  }

  Widget _header() => Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
      child: Row(children: [
        _MenuButton(
            id: 'daily',
            label: '일일 미션',
            icon: Icons.assignment_turned_in_outlined,
            onPressed: () => onOpen('daily'),
            horizontal: true),
        const SizedBox(width: 6),
        _MenuButton(
            id: 'achievements',
            label: '업적',
            icon: Icons.military_tech_outlined,
            onPressed: () => onOpen('achievements'),
            horizontal: true),
        const Spacer(),
        const Flexible(
            child: Text('오늘의 붕어빵',
                textAlign: TextAlign.end,
                style: TextStyle(color: muted, fontSize: 12))),
        IconButton(
            tooltip: '설정',
            onPressed: () => onOpen('settings'),
            icon: const Icon(Icons.settings_outlined, color: muted, size: 22)),
      ]));

  Widget _production(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(children: [
          const Text('보유 붕어빵', style: TextStyle(color: muted, fontSize: 12)),
          Semantics(
              label: '보유 붕어빵 ${exactNumber(controller.state.buns)}개',
              onTap: () => onOpen('balance'),
              excludeSemantics: true,
              button: true,
              child: InkWell(
                  onTap: () => onOpen('balance'),
                  child: Text(compactNumber(controller.state.buns),
                      key: const Key('balance-value'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: cream)))),
          Text('누적 생산 ${compactNumber(controller.state.lifetime)}개',
              key: const Key('lifetime-value'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
          if (controller.state.prestige.stars > 0)
            Text(
                '명성 별 ${controller.state.prestige.stars} · 생산 +${(prestigePermille(controller.state) - 1000) ~/ 10}%',
                key: const Key('home-prestige'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: cream, fontSize: 12)),
          if (controller.state.achievements.equippedTitle case final title?)
            Text('칭호 · $title',
                key: const Key('home-title'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: cream, fontSize: 12)),
          const SizedBox(height: 9),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text('클릭당 +${compactNumber(controller.currentTapRate)}',
                    key: const Key('tap-rate'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('초당 +${compactNumber(controller.currentAutoRate)}',
                    key: const Key('auto-rate'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xffa3dbc9))),
              ]),
        ]),
      );

  Widget _stage(bool reduce, bool largeText) => Stack(children: [
        Positioned.fill(
            right: largeText ? 100 : 82,
            child: Column(children: [
              const SizedBox(height: 14),
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('골목을 채우는 따뜻한 한 판',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 12))),
              Expanded(
                  child:
                      BakeTarget(controller: controller, reduceMotion: reduce)),
              Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: controller.currentCombo >= comboDisplayMinimum
                      ? _ComboLabel(
                          combo: controller.currentCombo, reduce: reduce)
                      : const Text('붕어빵을 눌러 구워요',
                          style: TextStyle(color: cream, fontSize: 13))),
            ])),
        Positioned(
            right: 6,
            top: 12,
            bottom: 12,
            width: largeText ? 94 : 72,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final item in const [
                ('shop', '상점', Icons.storefront_outlined),
                ('skins', '꾸미기', Icons.checkroom_outlined),
                ('records', '내 기록', Icons.insights_outlined),
                ('share', '공유', Icons.share_outlined),
              ]) ...[
                _MenuButton(
                    id: item.$1,
                    label: item.$2,
                    icon: item.$3,
                    onPressed: () => onOpen(item.$1)),
                const SizedBox(height: 8),
              ],
            ])),
      ]);

  Widget _level(BuildContext context) {
    final s = controller.state;
    final next = activeLevelMission(s);
    final goals = next == null ? null : missionProgress(s, next);
    final progress = levelProgressPermille(s);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
          key: const Key('level-mission-entry'),
          onTap: () => onOpen('missions'),
          child: _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text('Lv.${s.level}',
                          key: const Key('current-level'),
                          style: const TextStyle(
                              color: cream,
                              fontSize: 19,
                              fontWeight: FontWeight.w900)),
                      Text(
                          next == null
                              ? '최고 레벨 달성'
                              : '다음 레벨까지 ${progress ~/ 10}%',
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    key: const Key('level-progress'),
                    value: progress / 1000,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xff91d5c0),
                    backgroundColor: const Color(0xff394958),
                    semanticsLabel: '레벨 진행 상태',
                    semanticsValue: '${progress ~/ 10}%'),
                const SizedBox(height: 7),
                Text(
                    next == null
                        ? '모든 성장 목표를 달성했어요'
                        : '미션 ${goals!.where((p) => p.complete).length}/${goals.length} 완료 · '
                            '${canClaimLevel(s) ? '보상 받기' : '조건 보기'}  ›',
                    style: const TextStyle(color: muted, fontSize: 11)),
              ]))),
    );
  }

  Widget _event() {
    final weekly = controller.state.weekly;
    final theme = seasonThemeForMonth(DateTime.parse(weekly.week).month);
    final done = weeklyGoals.where((g) => weekly.claimed.contains(g.id)).length;
    final ready = weeklyGoals
        .where((g) =>
            !weekly.claimed.contains(g.id) &&
            weeklyGoalComplete(controller.state, g))
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
          button: true,
          child: InkWell(
            key: const Key('event-entry'),
            onTap: () => onOpen('event'),
            child: _Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '주간 도전 · ${weeklyCountdownLabel(weekly.week, controller.gameNow)}',
                      key: const Key('event-countdown'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: cream,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${theme.title}  ›',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                      '보상 수령 $done/${weeklyGoals.length}${ready > 0 ? ' · 받을 보상 $ready개' : ''}',
                      key: const Key('event-summary'),
                      style: const TextStyle(color: muted, fontSize: 10)),
                ])),
          )),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xeb172635),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xff49545a))),
        child: child,
      );
}

class _MenuButton extends StatelessWidget {
  final String id, label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool horizontal;
  const _MenuButton(
      {required this.id,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.horizontal = false});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Icon(icon, color: NightHome.cream, size: horizontal ? 22 : 27),
      SizedBox(width: horizontal ? 6 : 0, height: horizontal ? 0 : 3),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ];
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
          color: const Color(0xd9223343),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: Key('menu-$id'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                    child: horizontal
                        ? Row(
                            mainAxisSize: MainAxisSize.min, children: children)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: children))),
          )),
    );
  }
}

/// Combo counter: colour steps at 20/50 and a short pop per new tap.
class _ComboLabel extends StatelessWidget {
  final int combo;
  final bool reduce;
  const _ComboLabel({required this.combo, required this.reduce});
  @override
  Widget build(BuildContext context) {
    final color = combo >= 50
        ? const Color(0xffffc94d)
        : combo >= 20
            ? const Color(0xffff9f6b)
            : NightHome.cream;
    final text = Text('$combo 콤보',
        key: const Key('combo-label'),
        style: TextStyle(
            color: color,
            fontSize: combo >= 20 ? 16 : 13,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)]));
    if (reduce) return text;
    return TweenAnimationBuilder<double>(
        key: ValueKey(combo),
        tween: Tween(begin: 1.3, end: 1),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: text);
  }
}
