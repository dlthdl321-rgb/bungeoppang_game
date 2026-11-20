import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cooking_session.dart';
import '../development_orders.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'workshop_counter.dart' show orderSummary;
import 'workshop_home_layout.dart';
import 'workshop_mold_stage.dart' show ResultLook;

/// The guests standing at the stall (26번 4-1단계 F2, MASTER 10장 '손님
/// 표시'): the first in the line big and centred, the others behind at 0.8
/// to the left and right in turn. Their bottom edge is the counter's top
/// (the towel), so the counter hides their waist. A time bar over each head
/// turns red near the end; a guest who just left shows happy (sale) or sad
/// (time out) for a moment. Presentation only.
///
/// The pictures sit under the stage (the clicker covers their waist), so
/// they take no touches; with [taps] the same layout gives only the tap
/// targets instead, over each guest's head, laid above the stage (a large
/// text scroll view would otherwise swallow the taps), but none while a
/// bake is in the mold (IC3). Tapping a guest opens the customer window.
class WorkshopGuestLayer extends StatelessWidget {
  final WorkshopController controller;
  final ValueChanged<String> onOpenCustomer;
  final bool reduceMotion, taps;
  /// The clicker's place in this layer: a guest standing over it (centre
  /// inside its width) takes taps only above its top.
  final Rect? clicker;
  const WorkshopGuestLayer({super.key, required this.controller, required this.onOpenCustomer,
      this.reduceMotion = false, this.taps = false, this.clicker});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final c = controller, s = c.state;
        if (!s.business.open) return SizedBox.shrink(key: Key(taps ? 'customer-guest-taps' : 'customer-guests'));
        final w = box.maxWidth, bottom = box.maxHeight;
        final frontW = math.max(WorkshopHomeLayout.frontMinWidth, math.min(math.min(w * WorkshopHomeLayout.frontWidthShare, WorkshopHomeLayout.frontMaxWidth),
            (bottom - WorkshopHomeLayout.frontLift - WorkshopHomeLayout.hudClearance) / 1.25));
        final departure = c.guestDeparture;
        final leaving = departure != null && c.departureAgeMs < WorkshopHomeLayout.departureMs &&
            !s.customers.any((o) => o.customerId == departure.customerId) ? departure : null;
        // While someone leaves from the front, the line waits one place back.
        final shift = leaving == null ? 0 : 1;
        Rect place(int slot) {
          if (slot == 0) {
            final h = frontW * 1.25;
            // Short screens: the head stays just under the HUD and the
            // clicker covers more of the body.
            final top = math.max(math.min(WorkshopHomeLayout.hudClearance, bottom - h), bottom - WorkshopHomeLayout.frontLift - h);
            return Rect.fromLTWH((w - frontW) / 2, top, frontW, h);
          }
          final places = WorkshopHomeLayout.backPlaces;
          final (dx, scale, raise) = places[math.min(slot - 1, places.length - 1)];
          final gw = frontW * scale, gh = gw * 1.25;
          final cx = w / 2 + dx * frontW;
          return Rect.fromLTWH(cx - gw / 2, bottom - raise - gh, gw, gh);
        }
        final session = s.session;
        final reactionOrder = session?.phase == CookingPhase.result ? c.resultReactionOrderId : null;
        String? reaction;
        if (reactionOrder != null && session != null) {
          final look = ResultLook.of(c.config, session, difficulty: c.difficulty(session.flavor));
          reaction = c.resultReaction(look.grade);
        }
        if (taps) {
          // 4차 피드백 IC3: while the big mold is in use the guests step
          // back and take no taps — their head targets lay over the mold
          // (the front guest's over its top, the next one's over its left
          // side) and swallowed about a third of the batter and flip
          // touches.
          if (session != null && !session.finished) {
            return const SizedBox.shrink(key: Key('customer-guest-taps'));
          }
          Rect head(int i) {
            final rect = place(i + shift);
            final over = clicker != null && rect.center.dx > clicker!.left && rect.center.dx < clicker!.right;
            final end = math.min(rect.top + rect.height * WorkshopHomeLayout.headShare,
                over ? clicker!.top : double.infinity);
            return Rect.fromLTRB(rect.left, rect.top, rect.right, math.max(rect.top, end));
          }
          return Stack(key: const Key('customer-guest-taps'), clipBehavior: Clip.none, children: [
            for (var i = 0; i < s.customers.length; i++)
              if (head(i).height > 0)
                Positioned.fromRect(
                    rect: head(i),
                    child: _GuestTap(key: Key('customer-$i'), controller: c, order: s.customers[i],
                        onTap: () => onOpenCustomer(s.customers[i].id))),
          ]);
        }
        final guests = <Widget>[];
        // Back to front: the last in line first, so the front guest is on top.
        for (var i = s.customers.length - 1; i >= 0; i--) {
          final order = s.customers[i], rect = place(i + shift);
          guests.add(Positioned.fromRect(
              rect: rect,
              child: _Guest(
                  key: Key('customer-art-$i'),
                  controller: c,
                  order: order)));
        }
        if (leaving != null) {
          final t = c.departureAgeMs / WorkshopHomeLayout.departureMs;
          guests.add(Positioned.fromRect(
              rect: place(0),
              child: IgnorePointer(
                  child: Opacity(
                      key: const Key('customer-leaving'),
                      opacity: reduceMotion ? 1 : (1 - t * t).clamp(0.0, 1.0),
                      child: _GuestPicture(art: c.guestArtId(leaving.customerId),
                          mood: leaving.happy ? 'happy' : 'sad', name: c.customerShortName(leaving.customerId))))));
        }
        final reactionIndex = reactionOrder == null ? -1 : s.customers.indexWhere((o) => o.id == reactionOrder);
        return IgnorePointer(child: Stack(key: const Key('customer-guests'), clipBehavior: Clip.none, children: [
          Positioned.fill(
              child: Opacity(
                  // The big mold is in use: the guests step back.
                  opacity: session != null ? WorkshopHomeLayout.sessionOpacity : 1,
                  child: Stack(clipBehavior: Clip.none, children: guests))),
          if (reaction != null && reactionIndex >= 0)
            Positioned(
                left: 8,
                right: 8,
                bottom: bottom - place(reactionIndex + shift).top - WorkshopHomeLayout.bubbleDrop,
                child: Center(child: GuestSpeechBubble(key: const Key('guest-reaction'), text: reaction))),
        ]));
      });
}

/// A guest's tap target over their head: opens the customer window.
class _GuestTap extends StatelessWidget {
  final WorkshopController controller;
  final CustomerOrder order;
  final VoidCallback onTap;
  const _GuestTap({super.key, required this.controller, required this.order, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Semantics(
      button: true,
      label: '${c.customerShortName(order.customerId)} · ${orderSummary(c, order)} · 남은 ${(order.remainingMs / 1000).ceil()}초',
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
    );
  }
}

/// A guest at the stall: their picture and the time bar over the head.
class _Guest extends StatelessWidget {
  final WorkshopController controller;
  final CustomerOrder order;
  const _Guest({super.key, required this.controller, required this.order});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final left = (order.remainingMs / math.max(1, c.initialWaitMs(order))).clamp(0.0, 1.0);
    final name = c.customerShortName(order.customerId);
    final mood = left < WorkshopHomeLayout.timeBarLow ? 'sad' : 'normal';
    return LayoutBuilder(builder: (context, box) {
          final barW = box.maxWidth * WorkshopHomeLayout.timeBarShare;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: _GuestPicture(art: c.guestArtId(order.customerId), mood: mood, name: name)),
            Positioned(
                top: -WorkshopHomeLayout.timeBarHeight - 4,
                left: (box.maxWidth - barW) / 2,
                width: barW,
                height: WorkshopHomeLayout.timeBarHeight,
                child: CustomPaint(key: Key('customer-time-${order.id}'), painter: GuestTimeBarPainter(left))),
          ]);
        });
  }
}

/// The guest's art, or a round initial badge while it is not drawn.
class _GuestPicture extends StatelessWidget {
  final String art, mood, name;
  const _GuestPicture({required this.art, required this.mood, required this.name});
  @override
  Widget build(BuildContext context) {
    final image = PixelSprites.guest(art, mood);
    if (image != null) {
      return RawImage(image: image, fit: BoxFit.contain, alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.medium);
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: .7,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Cozy.cream,
                border: Border.all(color: Cozy.line, width: 2)),
            child: Text(name.characters.first,
                style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 28, color: Cozy.ink)),
          ),
        ),
      ),
    );
  }
}

/// How much waiting time is left, as a small rounded bar (S4-1-Q3).
class GuestTimeBarPainter extends CustomPainter {
  final double left;
  const GuestTimeBarPainter(this.left);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r),
        Paint()..color = Cozy.woodDark.withValues(alpha: .85));
    final inner = (Offset.zero & size).deflate(1.5);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(inner.left, inner.top, inner.width * left, inner.height), r),
        Paint()..color = left < WorkshopHomeLayout.timeBarLow ? Cozy.brick : Cozy.amber);
  }
  @override
  bool shouldRepaint(GuestTimeBarPainter old) => old.left != left;
}

/// A white speech bubble with a tail pointing down at the guest (H41:
/// the shared [CozyBubble], no thick brown outline).
class GuestSpeechBubble extends StatelessWidget {
  final String text;
  const GuestSpeechBubble({super.key, required this.text});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: CozyBubble(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
          child: Text(text, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 15, color: Cozy.ink)),
        ),
      );
}
