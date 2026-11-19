import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import '../development_orders.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'workshop_home_layout.dart';

/// The sale loop on the home screen (MASTER 10장, 26번 4-1단계): the guests
/// at the stall (workshop_guests.dart; the old left line until the new
/// backgrounds are in), and the counter strip on the towel with its button
/// floating centred above it. Presentation only; commands go through the
/// controller.

/// "팥 바삭함 1/2": what one order line asks for and how much was handed over.
String orderLineLabel(WorkshopController c, CustomerOrder order, int i) {
  final line = order.lines[i];
  final variant = line.variant == null ? '' : ' ${provisionalDonenessLabels[line.variant!]}';
  return '${c.flavorLabel(line.flavor)}$variant ${order.delivered(i)}/${line.quantity}';
}

String orderSummary(WorkshopController c, CustomerOrder order) =>
    [for (var i = 0; i < order.lines.length; i++) orderLineLabel(c, order, i)].join(', ');

/// The flavor the next order production should bake: the first line that
/// stock cannot cover yet.
String? missingFlavor(WorkshopController c, CustomerOrder order) {
  final ready = c.saleReadyCount(order);
  if (ready >= order.remainingQuantity) return null;
  for (var i = 0; i < order.lines.length; i++) {
    if (order.remaining(i) > 0) return order.lines[i].flavor;
  }
  return null;
}

const _captionStyle = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 13, color: Cozy.cream, shadows: [
  Shadow(color: Cozy.woodDark, blurRadius: 4),
  Shadow(color: Cozy.woodDark, offset: Offset(1, 1)),
]);

/// The old layout's waiting line down the left (until the lowered
/// backgrounds are in, WorkshopHomeLayout.active), first at the top. Each
/// badge shows the name's first letter, a ring for the time left and the
/// order in short; no queue numbers (26번 4-1단계 F2).
class WorkshopCustomerQueue extends StatelessWidget {
  final WorkshopController controller;
  final ValueChanged<String> onOpenCustomer;
  const WorkshopCustomerQueue({super.key, required this.controller, required this.onOpenCustomer});

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state;
    if (!s.business.open) return const SizedBox.shrink();
    // 26번 5-1단계: guests come by the real-time clocks; the '맞이' button is
    // only for the first-run guide (S5-1-Q2) and brings one guest when the line is empty.
    final full = !s.tutorialActive || s.customers.isNotEmpty;
    final canWelcome = !c.inputBusy && !full && c.error == null && !c.gameplayPaused && s.business.permitsProducts(c.now());
    return SingleChildScrollView(
      key: const Key('customer-queue'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < s.customers.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: _badge(c, i)),
        if (!full)
          Semantics(
            button: true,
            label: '손님 맞이',
            child: InkWell(
              key: const Key('customer-welcome'),
              customBorder: const CircleBorder(),
              onTap: canWelcome ? () => c.welcomeCustomer(named: s.relationships.met.isEmpty) : null,
              child: Opacity(
                opacity: canWelcome ? 1 : .5,
                child: Column(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Cozy.cream.withValues(alpha: .85),
                        border: Border.all(color: Cozy.woodLight, width: 2)),
                    child: const Icon(Icons.add, color: Cozy.wood),
                  ),
                  const Text('맞이', style: _captionStyle),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _badge(WorkshopController c, int i) {
    final order = c.state.customers[i], name = c.customerShortName(order.customerId);
    final left = order.remainingMs / math.max(1, c.initialWaitMs(order));
    final short = order.lines.map((l) => '${c.flavorLabel(l.flavor).characters.first}${l.quantity}').join(' ');
    return Semantics(
      button: true,
      label: '$name · ${orderSummary(c, order)} · 남은 ${(order.remainingMs / 1000).ceil()}초',
      excludeSemantics: true,
      child: InkWell(
        key: Key('customer-$i'),
        customBorder: const CircleBorder(),
        onTap: () => onOpenCustomer(order.id),
        child: SizedBox(
          width: 60,
          child: Column(children: [
            SizedBox.square(
              dimension: 52,
              child: CustomPaint(
                painter: _WaitRing(left.clamp(0.0, 1.0), front: i == 0),
                child: Center(
                  child: Container(
                    width: 40, height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? Cozy.honeyLight : Cozy.cream,
                        border: Border.all(color: Cozy.wood, width: 2)),
                    child: Text(name.characters.first,
                        style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 20, color: Cozy.ink)),
                  ),
                ),
              ),
            ),
            Text(short, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: _captionStyle),
          ]),
        ),
      ),
    );
  }
}

class _WaitRing extends CustomPainter {
  final double left;
  final bool front;
  const _WaitRing(this.left, {required this.front});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = Cozy.woodDark.withValues(alpha: .6)..style = PaintingStyle.stroke..strokeWidth = 5);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * left, false, Paint()
      ..color = left < .25 ? Cozy.brick : front ? Cozy.amber : Cozy.orange
      ..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_WaitRing old) => old.left != left || old.front != front;
}

/// What the sale counter says and its one next action (sell, or bake what
/// is missing, open, close…), for [WorkshopSaleCounter] and the floating
/// [WorkshopCounterAction]. Null while the big mold is in use.
class _CounterContent {
  final String title, detail;
  final Widget action;
  const _CounterContent(this.title, this.detail, this.action);

  static _CounterContent? of(WorkshopController c, VoidCallback onCloseBusiness) {
    final s = c.state;
    if (s.session != null) return null;
    final now = c.now(), idle = !c.inputBusy && c.error == null && !c.gameplayPaused;
    final stock = s.inventory.batches.values.fold<int>(0, (n, b) => n + b.quantity);
    Widget primary(Key key, String label, VoidCallback? onPressed) => CozyPrimaryButton(key: key,
        onPressed: onPressed, label: label, minHeight: WorkshopHomeLayout.actionHeight, fontSize: 17,
        padding: const EdgeInsets.symmetric(horizontal: 18));
    Widget secondary(Key key, String label, VoidCallback? onPressed) => CozyButton(key: key,
        onPressed: onPressed, label: label, minHeight: WorkshopHomeLayout.actionHeight, fontSize: 17,
        padding: const EdgeInsets.symmetric(horizontal: 18));
    if (c.error != null) {
      return _CounterContent('저장 확인이 필요해요', '진행은 그대로 있어요',
          primary(const Key('counter-reload'), '다시 확인', c.busy ? null : c.reloadAfterError));
    }
    if (!s.business.open || s.business.needsContinuation(now)) {
      final continuing = s.business.open;
      return _CounterContent(continuing ? '새 영업일이 밝았어요' : '오늘 영업 준비',
          '재고 $stock개 · 준비품 ${s.inventory.prepared.length}묶음',
          primary(const Key('business-open'), continuing ? '이어서 영업' : '영업 시작', idle ? c.openBusiness : null));
    }
    if (c.photoReactionSale case final sale?) {
      return _CounterContent('태오: 와, 냄새 좋다.', '……아! 또 사진 전에 먹었네.',
          secondary(const Key('photo-reaction'), '반응 확인', idle ? () => c.acknowledgePhotoReaction(sale) : null));
    }
    if (s.customers.isEmpty) {
      return _CounterContent(c.lastSaleFeedback ?? '손님을 기다리는 중이에요', '재고 $stock개',
          secondary(const Key('business-close'), '영업 종료', idle ? onCloseBusiness : null));
    }
    final order = s.customers.first, ready = c.saleReadyCount(order), missing = missingFlavor(c, order);
    // The name and what they want; the time left is the bar over the guest
    // (S4-1-Q3), not seconds in the text.
    return _CounterContent('${c.customerShortName(order.customerId)} · ${orderSummary(c, order)}', '재고 $stock개',
        // Short stock with nothing to hand over: bake the missing flavor first.
        ready == 0 && missing != null
            ? secondary(const Key('order-produce'), '${c.flavorLabel(missing)} 제작',
                idle ? () => c.startOrderProduction(order.id, missing) : null)
            : primary(const Key('sale-button'), ready >= order.remainingQuantity ? '판매 완료' : '$ready개 먼저 판매',
                idle && ready > 0 ? () => c.sellToCustomer(order.id) : null));
  }
}

/// The counter strip on the towel (DEC-038): one line of who and what
/// (26번 4-1단계 F6: the short name and the order, no seconds) and a small
/// line under it for the stock or a notice. Text wraps rather than being
/// cut (no fade). Tapping it opens the stock. Hidden while the big
/// mold is in use. Its button floats apart ([WorkshopCounterAction]).
class WorkshopSaleCounter extends StatelessWidget {
  final WorkshopController controller;
  final VoidCallback onOpenStock, onCloseBusiness;
  const WorkshopSaleCounter({super.key, required this.controller, required this.onOpenStock,
      required this.onCloseBusiness});

  @override
  Widget build(BuildContext context) {
    final c = controller, content = _CounterContent.of(c, onCloseBusiness);
    if (content == null) return const SizedBox.shrink();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: CozyPanel(
        key: const Key('sale-counter'),
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
        child: Semantics(
          button: true,
          label: '재고 보기',
          child: InkWell(
            key: const Key('stock-open'),
            onTap: onOpenStock,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(content.title, key: const Key('counter-title'), maxLines: 2,
                  style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: Cozy.ink)),
              // A notice (a guest's parting words, a refused command) takes
              // the small line's place.
              Text(c.notice ?? content.detail, key: Key(c.notice == null ? 'counter-order' : 'counter-notice'), maxLines: 2,
                  style: TextStyle(fontSize: 12, color: c.notice == null ? Cozy.inkSoft : Cozy.brick)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The counter's one action, floating centred on the screen above the
/// counter (S4-1-Q6): at least 160 wide and 44 tall. Hidden with the
/// counter while the big mold is in use.
class WorkshopCounterAction extends StatelessWidget {
  final WorkshopController controller;
  final VoidCallback onCloseBusiness;
  const WorkshopCounterAction({super.key, required this.controller, required this.onCloseBusiness});

  @override
  Widget build(BuildContext context) {
    final content = _CounterContent.of(controller, onCloseBusiness);
    if (content == null) return const SizedBox.shrink();
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ConstrainedBox(
        key: const Key('counter-action'),
        constraints: const BoxConstraints(minWidth: WorkshopHomeLayout.actionMinWidth, maxWidth: 260),
        child: content.action,
      ),
    );
  }
}

/// One customer's order and words in a small window over the stall.
class WorkshopCustomerCard extends StatelessWidget {
  final WorkshopController controller;
  final String orderId;
  const WorkshopCustomerCard({super.key, required this.controller, required this.orderId});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (context, _) {
        final c = controller, s = c.state;
        final index = s.customers.indexWhere((o) => o.id == orderId);
        if (index < 0) {
          return const Text('주문이 끝났어요.', key: Key('customer-card-gone'));
        }
        final order = s.customers[index], named = c.customerCatalog.contains(order.customerId);
        final idle = !c.inputBusy && c.error == null && !c.gameplayPaused && s.session == null;
        final words = [
          // 26번 7단계(S7-Q3): the seasonal greeting comes first.
          c.seasonalEvent?.greeting,
          c.customerOrderSpeech(order),
          c.customerWaitingAction(order),
          c.waitingLine(order),
          c.customerDelaySpeech(order),
          if (named && c.customerConversation(order) != c.waitingLine(order)) c.customerConversation(order),
        ].whereType<String>().toList();
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(c.customerName(order.customerId), key: const Key('customer-card-title'),
              style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 22, color: Cozy.ink)),
          Text('남은 ${(order.remainingMs / 1000).ceil()}초', style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
          const SizedBox(height: 8),
          for (var i = 0; i < order.lines.length; i++)
            Text(orderLineLabel(c, order, i), style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 17, color: Cozy.ink)),
          const SizedBox(height: 8),
          for (final line in words)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line)),
          if (index > 0)
            const Text('판매는 맨 앞 손님부터 해요.', style: TextStyle(fontSize: 12, color: Cozy.inkSoft)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (named)
              CozyButton(key: const Key('customer-observe'), minHeight: 40, fontSize: 15,
                  onPressed: idle ? () => c.observeWaiting(order.id) : null, label: '이웃 이야기 확인'),
            for (final flavor in order.lines.map((l) => l.flavor).toSet())
              CozyButton(key: Key('customer-produce-$flavor'), minHeight: 40, fontSize: 15,
                  onPressed: idle && s.business.permitsProducts(c.now()) ? () async {
                    final started = await c.startOrderProduction(order.id, flavor);
                    if (started && context.mounted) Navigator.pop(context);
                  } : null,
                  label: '${c.flavorLabel(flavor)} 주문 제작'),
          ]),
        ]);
      });
}

/// What is in stock, oldest first, for the stock window.
class WorkshopStockList extends StatelessWidget {
  final WorkshopController controller;
  const WorkshopStockList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller, builder: (context, _) {
        final c = controller, s = c.state;
        final batches = s.inventory.batches.values.toList()
          ..sort((a, b) => a.madeOnBusinessIndex != b.madeOnBusinessIndex
              ? a.madeOnBusinessIndex.compareTo(b.madeOnBusinessIndex) : a.id.compareTo(b.id));
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('재고 ${batches.fold<int>(0, (n, b) => n + b.quantity)}개',
              style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 22, color: Cozy.ink)),
          if (s.inventory.prepared.isNotEmpty)
            Text('영업 전 준비품 ${s.inventory.prepared.length}묶음. 영업을 시작하면 재고에 들어가요.',
                style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
          const SizedBox(height: 8),
          if (batches.isEmpty) const Text('아직 보관한 붕어빵이 없어요.'),
          for (final b in batches)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(child: Text('${c.flavorLabel(b.flavor)} ${provisionalDonenessLabels[b.variant]}',
                    style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 17, color: Cozy.ink))),
                Text('${b.quantity}개, ${s.business.businessIndex - b.madeOnBusinessIndex}영업일 경과'),
              ]),
            ),
          const SizedBox(height: 4),
          const Text('오래된 붕어빵부터 손님에게 드려요. 5영업일이 지나면 사라져요.',
              style: TextStyle(fontSize: 12, color: Cozy.inkSoft)),
        ]);
      });
}
