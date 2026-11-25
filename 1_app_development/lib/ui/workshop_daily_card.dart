import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import '../development_balance.dart';
import '../economy.dart';
import '../workshop_controller.dart';
import '../workshop_feature_unlocks.dart';
import 'center_toast.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';

/// 26번 7단계 — 매일 돌아올 이유 on the home (MASTER 10장).
///
/// The '오늘' button under the HUD's settings button (an icon only, 3차
/// 피드백 H36) opens [WorkshopDailyCard]: the seven-box attendance card,
/// 오늘의 주문서 (S7-Q1), during a seasonal event its greeting (S7-Q3) and,
/// since H36, the daily missions and 주간 도전 that used to be menu rows. A
/// red dot shows while today's stamp or order still waits or a mission
/// reward is ready. Locked during the first-run guide (4차 g5) and hidden
/// while the big mold is in use, like the counter.
class WorkshopDailyTicket extends StatelessWidget {
  final WorkshopController controller;
  final VoidCallback onOpen;
  /// Mission rewards ready to take (they live in the '오늘' window).
  final int claimable;
  const WorkshopDailyTicket({super.key, required this.controller, required this.onOpen, this.claimable = 0});

  static const width = 52.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.state.session != null) return const SizedBox.shrink();
    // 4차 g5: during the first-run guide it is listed locked (one stripe,
    // the padlock in the corner like the bottom menu) and a tap says why.
    if (c.state.tutorialActive) {
      final reason = c.featureLock(WorkshopFeature.wardrobe) ?? '첫 영업 안내가 끝나면 열려요';
      return SizedBox.square(
        dimension: width,
        child: LockedOverlay(
          key: const Key('daily-ticket-locked'),
          caption: '오늘: $reason',
          showCaption: false,
          maxLock: 18,
          lockAlignment: const Alignment(.82, -.78),
          onTap: () => showCenterToast(context, '오늘: $reason'),
          child: const CozyPanel(padding: EdgeInsets.all(6), child: Center(child: PixelIcon('daily', size: 34))),
        ),
      );
    }
    final waiting = c.dailyWaiting || claimable > 0;
    return Semantics(
      button: true,
      label: '오늘: 출석 도장·오늘의 주문서·미션${waiting ? ', 확인할 것이 있어요' : ''}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('daily-ticket'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: width,
          child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
            const CozyPanel(
              padding: EdgeInsets.all(6),
              child: Center(child: PixelIcon('daily', size: 34)),
            ),
            if (waiting)
              Positioned(
                key: const Key('daily-ticket-dot'),
                top: -3, right: -3,
                child: Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Cozy.brick, border: Border.all(color: Cozy.cream, width: 2))),
              ),
          ]),
        ),
      ),
    );
  }
}

const _title = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 19, color: Cozy.ink);
const _body = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: Cozy.ink);
const _small = TextStyle(fontSize: 12, color: Cozy.inkSoft);
const _meta = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: Cozy.inkSoft);

/// One block of the '오늘' window: a light card with an icon, a title and a
/// note on the right (count, dates).
class TodaySection extends StatelessWidget {
  final Widget icon;
  final String title;
  final Widget? trailing;
  final Widget child;
  const TodaySection({super.key, required this.icon, required this.title, this.trailing, required this.child});

  /// The section card's face: lighter than the window so blocks stand apart.
  static const face = Color(0xfffffaf0);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Cozy.tan, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 28, height: 28, child: Center(child: icon)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: _title)),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

/// What the '오늘' button opens: the event, the attendance card, the order
/// and (with [onClaimMission]) the daily missions and 주간 도전.
class WorkshopDailyCard extends StatelessWidget {
  final WorkshopController controller;
  /// After the seventh stamp asked for gold: hand it to the server now.
  final Future<void> Function()? onGoldClaim;
  /// '보상 받기' on a mission row; null leaves the missions out.
  final Future<void> Function(String scope, String goal)? onClaimMission;
  const WorkshopDailyCard({super.key, required this.controller, this.onGoldClaim, this.onClaimMission});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (context, _) {
        final c = controller, event = c.seasonalEvent;
        const gap = SizedBox(height: 10);
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (event != null) ...[
            Container(
              key: const Key('daily-event'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Cozy.honeyLight, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${event.label} 행사 중 (${_md(event.start)}~${_md(event.end)})', style: _body),
                Text(event.greeting, style: const TextStyle(fontSize: 13, color: Cozy.ink)),
              ]),
            ),
            gap,
          ],
          _Attendance(controller: c, onGoldClaim: onGoldClaim),
          gap,
          _Order(controller: c),
          if (c.notice != null)
            Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(c.notice!, key: const Key('daily-notice'), style: const TextStyle(fontSize: 12, color: Cozy.brick))),
          if (onClaimMission case final claim?) ...[
            gap,
            WorkshopMissionSection(controller: c, scope: 'daily', onClaim: claim),
            gap,
            WorkshopMissionSection(controller: c, scope: 'weekly', onClaim: claim),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('황금붕어빵력 보상은 서버에서 확인한 뒤 들어와요.', key: Key('missions-server-note'),
                  style: _small, textAlign: TextAlign.center),
            ),
          ],
        ]);
      });

  static String _md(String day) => '${int.parse(day.substring(5, 7))}/${int.parse(day.substring(8))}';
}

/// The stamp mark (H40): the attendance's own sign, apart from the order
/// slip and the calendar of the '오늘' button: `icons/stamp.png` (25번 38번).
class AttendanceStampIcon extends StatelessWidget {
  final double size;
  const AttendanceStampIcon({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => PixelIcon('stamp', size: size);
}

/// The order slip's sign (H40): `icons/order.png` (25번 38번).
class DailyOrderIcon extends StatelessWidget {
  final double size;
  const DailyOrderIcon({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => PixelIcon('order', size: size);
}

class _Attendance extends StatelessWidget {
  final WorkshopController controller;
  final Future<void> Function()? onGoldClaim;
  const _Attendance({required this.controller, this.onGoldClaim});

  @override
  Widget build(BuildContext context) {
    final c = controller, cycle = c.attendanceCycle, ready = c.attendanceReady;
    // Before today's stamp the card shows the boxes already filled; a full
    // card starts again at the next stamp.
    final filled = ready && c.state.daily.stamps >= cycle ? 0 : c.state.daily.stamps;
    final next = c.nextStamp;
    final idle = !c.inputBusy && c.error == null;
    final lastGold = c.stampGivesGold(cycle);
    return TodaySection(
      key: const Key('attendance-section'),
      icon: const AttendanceStampIcon(),
      title: '출석 도장',
      trailing: Text('$filled/$cycle', key: const Key('attendance-count'), style: _meta),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, area) {
          // Seven boxes across, as big as fit (at most 40).
          final size = ((area.maxWidth - 6 * (cycle - 1)) / cycle).clamp(26.0, 40.0);
          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 1; i <= cycle; i++)
              _AttendanceBox(key: Key('attendance-box-$i'), day: i, size: size, done: i <= filled,
                  today: i == next && ready, last: i == cycle),
          ]);
        }),
        const SizedBox(height: 10),
        // H39: what the seventh stamp gives, in words (설정값 cycle_days·gold).
        Container(
          key: const Key('attendance-goal'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xfffff3cf), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            PixelIcon(lastGold ? 'gold_bun' : 'bun', size: 28),
            const SizedBox(width: 6),
            Flexible(child: Text(
              lastGold
                  ? '$cycle번 출석하면 황금붕어빵력 ${c.attendanceGold}개'
                  : '$cycle번 출석하면 붕어빵력 ${compactNumber(c.stampBuns(cycle))}',
              key: const Key('attendance-goal-text'),
              style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 15, color: Cozy.ink),
            )),
          ]),
        ),
        const SizedBox(height: 10),
        if (ready)
          Row(children: [
            Expanded(child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('오늘 도장 ', style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
              if (c.stampGivesGold(next))
                CurrencyAmount(Currency.gold, BigInt.from(c.attendanceGold), key: const Key('attendance-reward-gold'))
              else
                CurrencyAmount(Currency.buns, c.stampBuns(next), key: const Key('attendance-reward-buns')),
            ])),
            CozyPrimaryButton(key: const Key('attendance-stamp'), minHeight: 40, fontSize: 16, label: '도장 찍기',
                onPressed: idle ? () async {
                  final gold = c.stampGivesGold(next);
                  if (await c.stampAttendance() && gold) await onGoldClaim?.call();
                } : null),
          ])
        else
          const Text('오늘 출석 완료! 내일 또 만나요.', key: Key('attendance-done'), textAlign: TextAlign.center, style: _body),
      ]),
    );
  }
}

class _AttendanceBox extends StatelessWidget {
  final int day;
  final double size;
  final bool done, today, last;
  const _AttendanceBox({super.key, required this.day, required this.size, required this.done, required this.today, required this.last});

  /// Stamp ink.
  static const ink = Color(0xffd2452b);

  @override
  Widget build(BuildContext context) {
    final Widget inner;
    if (done) {
      inner = Icon(Icons.check_rounded, size: size * .72, color: Colors.white, key: Key('attendance-check-$day'));
    } else if (last) {
      inner = PixelIcon('gold_bun', size: size * .66);
    } else {
      inner = Text('$day', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback,
          fontSize: size * .42, color: today ? Cozy.ink : Cozy.inkSoft));
    }
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? ink : last ? const Color(0xfffff3cf) : Colors.white,
        border: Border.all(color: done ? ink : today ? Cozy.brick : Cozy.tan, width: today ? 2.5 : 1.5),
      ),
      child: inner,
    );
  }
}

class _Order extends StatelessWidget {
  final WorkshopController controller;
  const _Order({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller, order = c.dailyOrder;
    final lock = c.featureLock(WorkshopFeature.specialOrders);
    Widget section(Widget child) => TodaySection(key: const Key('daily-order-section'),
        icon: const DailyOrderIcon(), title: '오늘의 주문서', child: child);
    if (order == null) {
      return section(Text(lock ?? '내일 새 주문서가 와요.', key: const Key('daily-order-locked'), style: _body));
    }
    final who = order.npc == null ? '동네 손님' : c.customerShortName(order.npc!);
    final event = c.seasonalEvent;
    final open = c.state.business.permitsProducts(c.now());
    final idle = !c.inputBusy && c.error == null && !c.gameplayPaused && c.state.session == null;
    final stock = c.dailyOrderStock;
    final what = '${c.flavorLabel(order.flavor)} ${provisionalDonenessLabels[order.variant]} ${order.quantity}개';
    return section(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('의뢰: $who', key: const Key('daily-order-from'), style: const TextStyle(fontSize: 13, color: Cozy.inkSoft)),
      if (event != null && order.event == event.id)
        Text(event.orderNote, key: const Key('daily-order-note'), style: const TextStyle(fontSize: 13, color: Cozy.wood)),
      Text(what, key: const Key('daily-order-what'), style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 22, color: Cozy.ink)),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('보상 ', style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
        CurrencyAmount(Currency.buns, order.done ? BigInt.parse(order.reward!) : c.dailyOrderReward,
            key: const Key('daily-order-reward')),
        if (order.npc != null) Text(' · 친밀도 +${c.dailyOrderAffinity}', style: const TextStyle(fontSize: 13, color: Cozy.ink)),
      ]),
      const SizedBox(height: 8),
      if (order.done)
        const Text('납품 완료! 내일 새 주문서가 와요.', key: Key('daily-order-done'), textAlign: TextAlign.center, style: _body)
      else ...[
        Text('맞는 재고 ${stock < order.quantity ? stock : order.quantity}/${order.quantity}개'
            '${open ? '' : ' · 영업 중에 납품할 수 있어요'}', key: const Key('daily-order-stock'), style: _small),
        const SizedBox(height: 6),
        Row(children: [
          if (stock < order.quantity) ...[
            Expanded(child: CozyButton(key: const Key('daily-order-bake'), minHeight: 40, fontSize: 15, label: '주문서 굽기',
                onPressed: idle && open ? () async {
                  if (await c.startDailyOrderProduction() && context.mounted) Navigator.maybePop(context);
                } : null)),
            const SizedBox(width: 8),
          ],
          Expanded(child: CozyPrimaryButton(key: const Key('daily-order-deliver'), minHeight: 40, fontSize: 15, label: '납품하기',
              onPressed: idle && open && stock >= order.quantity ? c.deliverDailyOrder : null)),
        ]),
      ],
    ]));
  }
}

/// 일일 미션 or 주간 도전 in the '오늘' window (3차 피드백 H33~H35): the
/// period in words ('11월 16일(월) ~ 11월 22일(일)'), one card per mission
/// with its progress bar and reward, and '보상 받기'.
class WorkshopMissionSection extends StatelessWidget {
  final WorkshopController controller;
  final String scope;
  final Future<void> Function(String scope, String goal) onClaim;
  const WorkshopMissionSection({super.key, required this.controller, required this.scope, required this.onClaim});

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  static String _date(DateTime d) => '${d.month}월 ${d.day}일(${_weekdays[d.weekday - 1]})';

  /// The period line: the day, or the week from Monday to Sunday.
  static String period(String scope, String start) {
    final from = DateTime.parse('${start}T00:00:00Z');
    if (scope == 'daily') return _date(from);
    return '${_date(from)} ~ ${_date(from.add(const Duration(days: 6)))}';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller, missions = c.state.missions, daily = scope == 'daily';
    final start = daily ? missions.day : missions.week;
    final goals = missions.goals(c.config, scope);
    final rows = <Widget>[
      for (final e in goals.entries)
        _row(e.key, (e.value as Map<String, dynamic>)['label'] as String,
            missions.progress(scope, (e.value as Map<String, dynamic>)['metric'] as String),
            DevelopmentBalance.decimal(e.value as Map<String, dynamic>, 'target'),
            (e.value as Map<String, dynamic>)['reward_key'] as String),
      if (daily)
        _row('all', '오늘 미션 모두 끝내기', BigInt.from(goals.keys.where((g) => missions.complete(c.config, scope, g)).length),
            BigInt.from(goals.length), 'daily_all'),
    ];
    String? left;
    if (!daily) {
      final end = DateTime.parse('${start}T00:00:00Z').add(const Duration(days: 6));
      final days = end.difference(DateTime.parse('${c.today}T00:00:00Z')).inDays + 1;
      if (days > 0) left = days == 1 ? '오늘까지' : '$days일 남음';
    }
    return TodaySection(
      key: Key('missions-$scope'),
      icon: PixelIcon(daily ? 'daily' : 'weekly', size: 26),
      title: daily ? '일일 미션' : '주간 도전',
      trailing: left == null ? null : Text(left, key: const Key('weekly-left'), style: _meta),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(period(scope, start), key: Key('missions-$scope-period'),
            style: const TextStyle(fontSize: 13, color: Cozy.inkSoft, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final (i, row) in rows.indexed) ...[if (i > 0) const SizedBox(height: 8), row],
      ]),
    );
  }

  static const _green = Color(0xff3f9b5a);

  Widget _row(String goal, String label, BigInt current, BigInt target, String rewardKey) {
    final c = controller, missions = c.state.missions;
    final claimed = missions.claims.containsKey(missions.claimKey(scope, goal));
    final complete = missions.complete(c.config, scope, goal);
    final gold = DevelopmentBalance.integer(c.config.section('mission_gold_rewards'), rewardKey);
    final shown = current > target ? target : current;
    final ratio = target == BigInt.zero ? 1.0 : (shown * BigInt.from(1000) ~/ target).toInt() / 1000;
    final ready = complete && !claimed;
    final Widget? action = claimed
        ? Row(key: Key('mission-$scope-$goal-claimed'), mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.check_circle_rounded, size: 18, color: _green),
            SizedBox(width: 3),
            Text('받았어요', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: _green)),
          ])
        // Only a finished mission shows '보상 받기' (H35); others show the reward alone.
        : complete
            ? CozyPrimaryButton(key: Key('mission-$scope-$goal-claim'), minHeight: 34, fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), label: '보상 받기',
                onPressed: c.inputBusy ? null : () => onClaim(scope, goal))
            : null;
    return Container(
      key: Key('mission-$scope-$goal'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: ready ? const Color(0xfffff3cf) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ready ? Cozy.honeyDeep : const Color(0xfff1dcc0)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 15, color: Cozy.ink)),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: ratio, minHeight: 7,
                  backgroundColor: const Color(0xfff3e4cf), color: complete ? _green : Cozy.tangerine),
            )),
            const SizedBox(width: 8),
            Text('${compactNumber(shown)}/${compactNumber(target)}', key: Key('mission-$scope-$goal-progress'),
                style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          CurrencyAmount(Currency.gold, BigInt.from(gold), key: Key('mission-$scope-$goal-gold')),
          if (action != null) ...[const SizedBox(height: 4), action],
        ]),
      ]),
    );
  }
}
