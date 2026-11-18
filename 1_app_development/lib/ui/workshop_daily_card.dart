import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import '../workshop_controller.dart';
import '../workshop_feature_unlocks.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'pixel_sprites.dart';

/// 26번 7단계 — 매일 돌아올 이유 on the home (MASTER 10장).
///
/// The small '오늘' slip at the right end of the sale counter opens
/// [WorkshopDailyCard]: the seven-box attendance card, 오늘의 주문서 (S7-Q1)
/// and, during a seasonal event, its greeting (S7-Q3). A red dot shows while
/// today's stamp or order still waits. Hidden during the first-run guide and
/// while the big mold is in use, like the counter.
class WorkshopDailyTicket extends StatelessWidget {
  final WorkshopController controller;
  final VoidCallback onOpen;
  const WorkshopDailyTicket({super.key, required this.controller, required this.onOpen});

  static const width = 52.0;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.state.tutorialActive || c.state.session != null) return const SizedBox.shrink();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: '오늘의 주문서와 출석${c.dailyWaiting ? ', 확인할 것이 있어요' : ''}',
        excludeSemantics: true,
        child: InkWell(
          key: const Key('daily-ticket'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: width,
            child: Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
              CozyPanel(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 3),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const PixelIcon('daily', size: 26),
                  Text('오늘', maxLines: 1, softWrap: false,
                      style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 13, color: Cozy.ink)),
                ]),
              ),
              if (c.dailyWaiting)
                Positioned(
                  key: const Key('daily-ticket-dot'),
                  top: -3, right: -3,
                  child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Cozy.brick, border: Border.all(color: Cozy.cream, width: 2))),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

const _title = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 20, color: Cozy.ink);
const _body = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: Cozy.ink);
const _small = TextStyle(fontSize: 12, color: Cozy.inkSoft);

/// What the '오늘' slip opens: the event, the attendance card and the order.
class WorkshopDailyCard extends StatelessWidget {
  final WorkshopController controller;
  /// After the seventh stamp asked for gold: hand it to the server now.
  final Future<void> Function()? onGoldClaim;
  const WorkshopDailyCard({super.key, required this.controller, this.onGoldClaim});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (context, _) {
        final c = controller, event = c.seasonalEvent;
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (event != null) ...[
            Container(
              key: const Key('daily-event'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Cozy.honeyLight, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Cozy.woodLight, width: 1.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${event.label} 행사 중 (${_md(event.start)}~${_md(event.end)})', style: _body),
                Text(event.greeting, style: const TextStyle(fontSize: 13, color: Cozy.ink)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          _Attendance(controller: c, onGoldClaim: onGoldClaim),
          const Divider(height: 22),
          _Order(controller: c),
          if (c.notice != null)
            Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(c.notice!, key: const Key('daily-notice'), style: const TextStyle(fontSize: 12, color: Cozy.brick))),
        ]);
      });

  static String _md(String day) => '${int.parse(day.substring(5, 7))}/${int.parse(day.substring(8))}';
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
    final box = c.nextStamp;
    final idle = !c.inputBusy && c.error == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('출석 도장', style: _title)),
        Text('$filled/$cycle', key: const Key('attendance-count'), style: _body),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 1; i <= cycle; i++)
          Container(
            key: Key('attendance-box-$i'),
            width: 34, height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= filled ? Cozy.honey : Cozy.cream,
              border: Border.all(color: i == box && ready ? Cozy.brick : Cozy.wood, width: i == box && ready ? 2.5 : 1.5),
            ),
            child: i == cycle
                ? const PixelIcon('gold_bun', size: 22)
                : i <= filled
                    ? const PixelIcon('check', size: 18)
                    : Text('$i', style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: Cozy.inkSoft)),
          ),
      ]),
      const SizedBox(height: 6),
      if (ready)
        Row(children: [
          const Text('오늘 도장: ', style: TextStyle(fontSize: 13, color: Cozy.ink)),
          if (c.stampGivesGold(box)) ...[
            CurrencyAmount(Currency.gold, BigInt.from(c.attendanceGold), key: const Key('attendance-reward-gold')),
            const Flexible(child: Text(' (서버 확인 후 지급)', style: _small)),
          ] else
            CurrencyAmount(Currency.buns, c.stampBuns(box), key: const Key('attendance-reward-buns')),
        ]),
      const SizedBox(height: 6),
      ready
          ? CozyPrimaryButton(key: const Key('attendance-stamp'), minHeight: 44, fontSize: 16, label: '도장 찍기',
              onPressed: idle ? () async {
                final gold = c.stampGivesGold(box);
                if (await c.stampAttendance() && gold) await onGoldClaim?.call();
              } : null)
          : const Text('오늘 출석 완료! 내일 또 만나요.', key: Key('attendance-done'), textAlign: TextAlign.center, style: _body),
      const SizedBox(height: 4),
      const Text('하루를 걸러도 이어져요. 7칸을 채우면 처음부터 다시 시작해요.', style: _small, textAlign: TextAlign.center),
    ]);
  }
}

class _Order extends StatelessWidget {
  final WorkshopController controller;
  const _Order({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller, order = c.dailyOrder;
    final lock = c.featureLock(WorkshopFeature.specialOrders);
    final header = Row(children: [
      const PixelIcon('daily', size: 26),
      const SizedBox(width: 6),
      const Expanded(child: Text('오늘의 주문서', style: _title)),
    ]);
    if (order == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Text(lock ?? '내일 새 주문서가 와요.', key: const Key('daily-order-locked'), style: _body),
      ]);
    }
    final who = order.npc == null ? '동네 손님' : c.customerShortName(order.npc!);
    final event = c.seasonalEvent;
    final open = c.state.business.permitsProducts(c.now());
    final idle = !c.inputBusy && c.error == null && !c.gameplayPaused && c.state.session == null;
    final stock = c.dailyOrderStock;
    final what = '${c.flavorLabel(order.flavor)} ${provisionalDonenessLabels[order.variant]} ${order.quantity}개';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      const SizedBox(height: 4),
      Text('의뢰: $who', key: const Key('daily-order-from'), style: const TextStyle(fontSize: 13, color: Cozy.inkSoft)),
      if (event != null && order.event == event.id)
        Text(event.orderNote, key: const Key('daily-order-note'), style: const TextStyle(fontSize: 13, color: Cozy.wood)),
      Text(what, key: const Key('daily-order-what'), style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 22, color: Cozy.ink)),
      Row(children: [
        const Text('보상: ', style: TextStyle(fontSize: 13, color: Cozy.ink)),
        CurrencyAmount(Currency.buns, order.done ? BigInt.parse(order.reward!) : c.dailyOrderReward,
            key: const Key('daily-order-reward')),
        if (order.npc != null) Text(' · 친밀도 +${c.dailyOrderAffinity}', style: const TextStyle(fontSize: 13, color: Cozy.ink)),
      ]),
      const SizedBox(height: 6),
      if (order.done)
        const Text('납품 완료! 내일 새 주문서가 와요.', key: Key('daily-order-done'), textAlign: TextAlign.center, style: _body)
      else ...[
        Text('맞는 재고 ${stock < order.quantity ? stock : order.quantity}/${order.quantity}개'
            '${open ? '' : ' · 영업 중에 납품할 수 있어요'}', key: const Key('daily-order-stock'), style: _small),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          if (stock < order.quantity)
            CozyButton(key: const Key('daily-order-bake'), minHeight: 44, fontSize: 15, label: '주문서 굽기',
                onPressed: idle && open ? () async {
                  if (await c.startDailyOrderProduction() && context.mounted) Navigator.maybePop(context);
                } : null),
          CozyPrimaryButton(key: const Key('daily-order-deliver'), minHeight: 44, fontSize: 16, label: '납품하기',
              onPressed: idle && open && stock >= order.quantity ? c.deliverDailyOrder : null),
        ]),
        const SizedBox(height: 4),
        const Text('주문서의 익힘으로 구운 붕어빵을 재고에서 드려요. 황금은 주지 않아요.', style: _small, textAlign: TextAlign.center),
      ],
    ]);
  }
}
