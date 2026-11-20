import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cooking_session.dart';
import '../development_orders.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'workshop_counter.dart' show missingFlavor, orderSummary, workshopGuestAction;
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
/// text scroll view would otherwise swallow the taps). Tapping a guest
/// opens the customer window.
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
        final inLine = {for (final o in s.customers) o.customerId};
        // What a guest just said, while it shows (IA5).
        final spoken = c.guestSpeech != null && c.guestSpeechAgeMs < WorkshopHomeLayout.speechMs ? c.guestSpeech : null;
        // 태오's photo reaction waits for '반응 확인': he stays at the front,
        // happy, with his words over him (IA5), instead of the counter saying them.
        final photo = c.photoReactionSale != null && !inLine.contains(WorkshopController.photoGuest);
        final departure = c.guestDeparture;
        // A guest who leaves with words stays until they are read, fading
        // only at the end.
        final stay = departure != null && spoken?.customerId == departure.customerId
            ? math.max(WorkshopHomeLayout.departureMs, WorkshopHomeLayout.speechMs) : WorkshopHomeLayout.departureMs;
        final leaving = photo ? null : departure != null && c.departureAgeMs < stay &&
            !inLine.contains(departure.customerId) ? departure : null;
        // While someone leaves from the front, the line waits one place back.
        final shift = leaving == null && !photo ? 0 : 1;
        // The picture at [slot]: the guest leaving or lingering at the front,
        // else the guest at that place in the line.
        String? artAt(int slot) {
          if (slot == 0 && (photo || leaving != null)) {
            return c.guestArtId(photo ? WorkshopController.photoGuest : leaving!.customerId);
          }
          final i = slot - shift;
          return i >= 0 && i < s.customers.length ? c.guestArtId(s.customers[i].customerId) : null;
        }
        // 4차 피드백 IA4: the first in line stands front and centre at the
        // counter, the later ones farther back (smaller, higher, dimmer —
        // [WorkshopHomeLayout.backShade]). A full-body picture (25번 주문
        // 대기, [PixelSprites.guestFull]) stands with its waist on the
        // counter's top and, behind, its feet on the street; the bust
        // pictures in the app now keep their cut edge behind the counter and
        // the clicker (no visible cut).
        Rect place(int slot) {
          final full = switch (artAt(slot)) { final art? => PixelSprites.guestFull(art, 'normal'), _ => null };
          final aspect = full == null ? 1.25 : full.height / full.width;
          if (slot == 0) {
            final h = frontW * aspect;
            if (full != null) {
              // Waist on the counter, the head kept under the HUD.
              final top = math.max(WorkshopHomeLayout.hudClearance, bottom - h * PixelSprites.guestWaistShare);
              return Rect.fromLTWH((w - frontW) / 2, top, frontW, h);
            }
            // Short screens: the head stays just under the HUD and the
            // clicker covers more of the body.
            final top = math.max(math.min(WorkshopHomeLayout.hudClearance, bottom - h), bottom - WorkshopHomeLayout.frontLift - h);
            return Rect.fromLTWH((w - frontW) / 2, top, frontW, h);
          }
          final places = WorkshopHomeLayout.backPlaces;
          final (dx, scale, raise) = places[math.min(slot - 1, places.length - 1)];
          final gw = frontW * scale, gh = gw * aspect;
          final cx = w / 2 + dx * frontW;
          // Full bodies stand farther up the street (feet visible).
          final lift = full == null ? raise : WorkshopHomeLayout.fullBackRaise[math.min(slot - 1, places.length - 1)];
          return Rect.fromLTWH(cx - gw / 2, bottom - lift - gh, gw, gh);
        }
        final session = s.session;
        final reactionOrder = session?.phase == CookingPhase.result ? c.resultReactionOrderId : null;
        String? reaction;
        if (reactionOrder != null && session != null) {
          final look = ResultLook.of(c.config, session, difficulty: c.difficulty(session.flavor));
          reaction = c.resultReaction(look.grade);
        }
        // The ordering guest whose flavor is missing (nothing to hand over
        // yet): a small '눌러서 팥 만들기' cue on them; tapping it, like
        // tapping the guest, opens their window with '주문 제작' (4차 사용자
        // 결정: 주문 제작은 손님을 눌러서).
        final front = s.customers.isEmpty ? null : s.customers.first;
        final missing = front == null || session != null || c.photoReactionSale != null || c.saleReadyCount(front) > 0
            ? null : missingFlavor(c, front);
        // Who speaks now and where: the leaving (or lingering) guest at the
        // front, or a guest still in line.
        Rect? speaker;
        String? words;
        if (photo) {
          speaker = place(0); words = WorkshopController.photoReactionWords;
        } else if (spoken != null) {
          final i = s.customers.indexWhere((o) => o.customerId == spoken.customerId);
          if (leaving?.customerId == spoken.customerId) {
            speaker = place(0);
          } else if (i >= 0) {
            speaker = place(i + shift);
          }
          words = spoken.text;
        }
        if (taps) {
          Rect head(int i) {
            final rect = place(i + shift);
            final over = clicker != null && rect.center.dx > clicker!.left && rect.center.dx < clicker!.right;
            final end = math.min(rect.top + rect.height * WorkshopHomeLayout.headShare,
                over ? clicker!.top : double.infinity);
            return Rect.fromLTRB(rect.left, rect.top, rect.right, math.max(rect.top, end));
          }
          // The front guest's small button at the centre of their figure
          // (4차 사용자 결정: sell / 태오's reaction on the guest).
          final action = workshopGuestAction(c) ??
              (missing == null ? null : GestureDetector(
                  onTap: () => onOpenCustomer(front!.id),
                  child: Semantics(button: true, child: GuestSpeechBubble(key: const Key('customer-produce-cue'),
                      text: '눌러서 ${c.flavorLabel(missing)} 만들기', tone: CozyTone.reward, small: true, tail: false))));
          final at = photo ? place(0) : place(shift);
          return Stack(key: const Key('customer-guest-taps'), clipBehavior: Clip.none, children: [
            for (var i = 0; i < s.customers.length; i++)
              if (head(i).height > 0)
                Positioned.fromRect(
                    rect: head(i),
                    child: _GuestTap(key: Key('customer-$i'), controller: c, order: s.customers[i],
                        onTap: () => onOpenCustomer(s.customers[i].id))),
            if (action != null)
              Positioned(
                  left: at.left - 40,
                  width: at.width + 80,
                  top: at.center.dy - WorkshopHomeLayout.guestButtonHeight,
                  height: WorkshopHomeLayout.guestButtonHeight * 2,
                  child: Center(child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.2,
                      child: KeyedSubtree(key: const Key('guest-action'), child: IntrinsicHeight(child: IntrinsicWidth(child: action)))))),
            // Over the stage too, so the clicker never hides the words.
            if (speaker != null && words != null)
              _over(w, bottom, speaker, -WorkshopHomeLayout.bubbleDrop,
                  IgnorePointer(child: GuestSpeechBubble(key: const Key('guest-speech'), text: words))),
          ]);
        }
        final guests = <Widget>[];
        // Back to front: the last in line first, so the front guest is on top.
        for (var i = s.customers.length - 1; i >= 0; i--) {
          final order = s.customers[i], slot = i + shift, rect = place(slot);
          final guest = _Guest(key: Key('customer-art-$i'), controller: c, order: order);
          final places = WorkshopHomeLayout.backPlaces.length;
          guests.add(Positioned.fromRect(
              rect: rect,
              // Farther back, a little greyer and darker (IA4).
              child: slot == 0 ? guest : ColorFiltered(key: Key('customer-depth-$i'),
                  colorFilter: guestDepthFilter(WorkshopHomeLayout.backShade[math.min(slot - 1, places - 1)]),
                  child: guest)));
        }
        if (photo || leaving != null) {
          final t = photo ? 0.0 : ((c.departureAgeMs - (stay - WorkshopHomeLayout.departureMs)) / WorkshopHomeLayout.departureMs).clamp(0.0, 1.0);
          final id = photo ? WorkshopController.photoGuest : leaving!.customerId;
          guests.add(Positioned.fromRect(
              rect: place(0),
              child: IgnorePointer(
                  child: Opacity(
                      key: const Key('customer-leaving'),
                      opacity: reduceMotion ? 1 : (1 - t * t).clamp(0.0, 1.0),
                      child: _GuestPicture(art: c.guestArtId(id),
                          mood: photo || leaving!.happy ? 'happy' : 'sad', name: c.customerShortName(id))))));
        }
        final reactionIndex = reactionOrder == null ? -1 : s.customers.indexWhere((o) => o.id == reactionOrder);
        return IgnorePointer(child: Stack(key: const Key('customer-guests'), clipBehavior: Clip.none, children: [
          Positioned.fill(
              child: Opacity(
                  // The big mold is in use: the guests step back.
                  opacity: session != null ? WorkshopHomeLayout.sessionOpacity : 1,
                  child: Stack(clipBehavior: Clip.none, children: guests))),
          if (reaction != null && reactionIndex >= 0)
            _over(w, bottom, place(reactionIndex + shift), -WorkshopHomeLayout.bubbleDrop,
                GuestSpeechBubble(key: const Key('guest-reaction'), text: _withoutName(reaction))),
        ]));
      });
}

/// [bubble] centred over [guest] (kept inside the screen), its tail's tip
/// [rise] above the guest's top edge (negative: hanging down over the head).
/// On short screens it never rises into the HUD
/// ([WorkshopHomeLayout.bubbleTopRoom]); it hangs further over the head
/// instead.
Widget _over(double w, double bottom, Rect guest, double rise, Widget bubble) {
  final margin = WorkshopHomeLayout.bubbleMargin, minHalf = WorkshopHomeLayout.bubbleMinHalf;
  // The right edge keeps clear of the HUD's settings button and '오늘' slip.
  final right = w - WorkshopHomeLayout.bubbleRightRoom;
  final cx = guest.center.dx.clamp(margin + minHalf, right - minHalf);
  final half = math.min(WorkshopHomeLayout.bubbleMaxWidth / 2, math.min(cx - margin, right - cx));
  return Positioned(
      left: cx - half,
      width: half * 2,
      top: 0,
      height: bottom,
      child: CustomSingleChildLayout(delegate: _BubbleLayout(guest.top - rise), child: bubble));
}

class _BubbleLayout extends SingleChildLayoutDelegate {
  /// Where the tail's tip should be.
  final double tip;
  const _BubbleLayout(this.tip);
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();
  @override
  Offset getPositionForChild(Size size, Size child) => Offset((size.width - child.width) / 2,
      math.max(WorkshopHomeLayout.bubbleTopRoom, tip - child.height));
  @override
  bool shouldRelayout(_BubbleLayout old) => old.tip != tip;
}

/// A guest farther back (4차 피드백 IA4 '뒤로 음영·회색빛'): [shade] of the
/// way to grey, and darker by 40% of [shade]. 0 leaves the picture as is.
ColorFilter guestDepthFilter(double shade) {
  final keep = 1 - shade, dark = 1 - shade * .4;
  // Luminance weights (Rec. 709).
  const r = .2126, g = .7152, b = .0722;
  List<double> row(double own, int channel) => [
        for (var k = 0; k < 3; k++) dark * ((k == channel ? own : 0) + shade * [r, g, b][k]),
        0, 0,
      ];
  return ColorFilter.matrix([
    ...row(keep, 0), ...row(keep, 1), ...row(keep, 2),
    0, 0, 0, 1, 0,
  ]);
}

/// '도윤: 고마워요' → '고마워요': by the guest, the bubble needs no name.
String _withoutName(String line) {
  final i = line.indexOf(': ');
  return i < 0 ? line : line.substring(i + 2);
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
    // The full-body picture once it is drawn (IA4), else the bust.
    final image = PixelSprites.guestFull(art, mood) ?? PixelSprites.guest(art, mood);
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
/// the shared [CozyBubble], no thick brown outline). [small] is the hint
/// size (the produce cue).
class GuestSpeechBubble extends StatelessWidget {
  final String text;
  final CozyTone tone;
  final bool small, tail;
  const GuestSpeechBubble({super.key, required this.text, this.tone = CozyTone.neutral, this.small = false,
      this.tail = true});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: small ? 13 : 15,
        color: tone == CozyTone.neutral ? Cozy.ink : tone.text);
    return CozyBubble(
      tone: tone,
      tail: tail,
      padding: small ? const EdgeInsets.fromLTRB(10, 3, 10, 4) : const EdgeInsets.fromLTRB(12, 6, 12, 7),
      // A hint (the produce cue) is one short line and may sit in an
      // intrinsic-size box, which a LayoutBuilder cannot.
      child: small
          ? Text(text, textAlign: TextAlign.center, style: style)
          : LayoutBuilder(builder: (context, box) => Text(
              balancedLines(text, style, box.maxWidth, MediaQuery.textScalerOf(context)),
              textAlign: TextAlign.center, style: style)),
    );
  }
}

/// [text] with a line break at the space nearest its middle when it does
/// not fit on one line of [width], so a two-line bubble never leaves one
/// syllable alone on its second line ('… 올게 / 요!', 4차 확인). Text that
/// already has a break, or no space, stays as it is.
String balancedLines(String text, TextStyle style, double width, TextScaler scaler) {
  if (!width.isFinite || text.contains('\n')) return text;
  double measure(String s) {
    final painter = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr,
        textScaler: scaler)..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }
  if (measure(text) <= width) return text;
  final middle = text.length / 2;
  int? best;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == ' ' && (best == null || (i - middle).abs() < (best - middle).abs())) best = i;
  }
  if (best == null) return text;
  final first = text.substring(0, best), second = text.substring(best + 1);
  return measure(first) <= width && measure(second) <= width ? '$first\n$second' : text;
}
