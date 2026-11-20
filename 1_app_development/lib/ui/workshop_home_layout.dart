import 'package:flutter/painting.dart' show EdgeInsets;
import 'pixel_sprites.dart';

/// The Workshop home's "guests at the stall" layout (26번 4-1단계, MASTER
/// 10장): every size and offset of the guest layer, the lowered clicker and
/// the counter's button and the guests' bubbles lives here.
class WorkshopHomeLayout {
  WorkshopHomeLayout._();

  /// The new layout (stall lowered to the towel, guests standing behind it,
  /// clicker just above the counter). The user's answer (S4-1-Q4): it only
  /// turns on when all 14 lowered backgrounds (assets/images/bg_low) are in
  /// the app. Tests may set it false to see the old layout.
  static bool enabled = true;

  /// Whether this run shows the new layout.
  static bool get active => enabled && PixelSprites.lowStallReady;

  /// The front guest's width: this share of the layout width, at most
  /// [frontMaxWidth]. Guest art is 256x320 (25번 6번), so the height is
  /// width x 1.25. The front guest stands [frontLift] above the counter's
  /// top so the face clears the clicker in front of them; the clicker and
  /// the counter's button hide the body's cut edge.
  static const frontWidthShare = .46;
  static const frontMaxWidth = 220.0;
  static const frontLift = clickerLift + 34;

  /// Room the HUD (level, balance, status badge) takes at the top of the
  /// guest layer: on short screens the front guest shrinks so the head
  /// stays under it rather than behind it.
  static const hudClearance = 122.0;
  static const frontMinWidth = 112.0;

  /// The top share of a guest (the head, over the clicker) that takes taps.
  static const headShare = .42;

  /// Guests behind the first, by place in the line: (side offset in front
  /// widths, scale, how much higher they stand). The second and third stand
  /// left and right on the counter's top; the fourth and fifth (a guest
  /// leaving moves everyone back one place) further back between them.
  /// 4차 피드백 IA4 ('뒤 손님은 멀리'): smaller than before (0.8 → 0.72,
  /// 0.66 → 0.58) so the first guest reads as the one at the counter.
  static const backPlaces = [(-.62, .72, 10.0), (.62, .72, 10.0), (-.3, .58, 40.0), (.3, .58, 40.0)];

  /// How grey and dark each place behind the first is (`guestDepthFilter`:
  /// share of the way to grey, darker by 40% of it), 4차 피드백 IA4.
  static const backShade = [.25, .25, .4, .4];

  /// With full-body pictures (25번 주문 대기, `PixelSprites.guestFull`) the
  /// guests behind stand this far up the street from the counter's top
  /// (feet showing), by place; the bust pictures use [backPlaces]' rise.
  static const fullBackRaise = [36.0, 36.0, 72.0, 72.0];

  /// The order customer's words after an order bake hang this far down
  /// over their head (clear of the stage's caption line).
  static const bubbleDrop = 34.0;

  /// A guest's words (4차 피드백 IA5) show as a bubble over that guest for
  /// as long as they are there (사용자 답 2026-11-21). A guest leaving with
  /// words stays at the front this long, fading in the last [departureMs],
  /// and the words go with them.
  static const speechMs = 3500;

  /// Guest bubbles stay [bubbleMargin] inside the screen, at most
  /// [bubbleMaxWidth] wide; near an edge their centre moves in so they are
  /// at least twice [bubbleMinHalf] wide.
  static const bubbleMargin = 8.0;
  static const bubbleMaxWidth = 280.0;

  /// Earlier words still showing (another guest spoke since) are the small
  /// bubble, at most this wide.
  static const smallBubbleMaxWidth = 140.0;
  static const bubbleMinHalf = 80.0;

  /// Guest bubbles never rise above this (the HUD with the business row,
  /// 360×640 included); on short screens they hang over the head instead.
  static const bubbleTopRoom = 156.0;

  /// Room guest bubbles leave on the right for the HUD's column of round
  /// buttons (settings, the '오늘' slip) on short screens.
  static const bubbleRightRoom = 64.0;

  /// The time bar over a guest's head: width share of the guest, height,
  /// and the share of time left under which it turns red.
  static const timeBarShare = .46;
  static const timeBarHeight = 7.0;
  static const timeBarLow = .25;

  /// A guest who just left (sale: happy, time out: sad) stays this long at
  /// the front, fading out (no fade with reduced motion).
  static const departureMs = 1500;

  /// While the special bungeoppang mold is in use the guests fade to this.
  static const sessionOpacity = .4;

  /// The clicker in the new layout: this scale of the mold's place
  /// (S4-1-Q5), its bottom [clickerLift] above the counter's top (room the
  /// floating counter button had until 4차 사용자 결정; kept so the clicker
  /// and the guests do not move).
  static const clickerScale = .8;
  static const clickerLift = 54.0;

  /// 4차 사용자 결정(2026-11-20): the big button that floated over the
  /// guests (S4-1-Q6) is gone. '판매 완료'·'N개 먼저 판매'·'반응 확인' are a
  /// small button ([guestButtonHeight] tall, [guestButtonFont] text) at the
  /// centre of that guest's figure (so is the ordering guest's '눌러서 팥
  /// 만들기' cue while nothing can be handed over); '다시 확인' (no guest) sits in the
  /// counter card on its right, [counterButtonHeight] tall, at most
  /// [counterButtonMaxWidth] wide.
  static const guestButtonHeight = 30.0;

  /// The small button's middle sits this share down the guest's picture:
  /// on the chest, under the face (사용자 답 2026-11-21; the bust art's
  /// chin is at about half).
  static const guestButtonShare = .64;

  /// The width guest bubbles keep clear around that button.
  static const guestButtonRoom = 150.0;
  static const guestButtonFont = 14.0;
  static const counterButtonHeight = 36.0;
  static const counterButtonMaxWidth = 128.0;

  /// '영업 시작'·'이어서 영업'·'영업 종료' are not the floating button: a
  /// small button beside the business-state sign in the HUD (26번 시안 확인
  /// 2차, 2026-11-19 '너무 큼 → 작게, 화면 상단으로'), [businessHeight] tall
  /// with [businessFontSize] text.
  static const businessHeight = 32.0;
  static const businessFontSize = 14.0;

  /// The '오늘' slip hangs this far under the HUD's settings button, right
  /// edges lined up (26번 시안 확인 2차).
  static const slipGap = 6.0;

  /// Room the practice start pill leaves under itself before opening (the
  /// old floating counter button's place, 44 + 6 + 10; kept so the pill
  /// does not jump).
  static const practiceLift = 60.0;

  /// The special bungeoppang mold (26번 3차 피드백 H18 '조리 컷과 6구를
  /// 가리지 않게'): its whole picture stays [moldGap] above the higher of
  /// the sale counter's top and the cooking cut's top, rising at most until
  /// its top is [moldTopRoom] under the HUD (the bake's title line). The
  /// keep / throw away / cancel buttons sit [moldButtonGap] under it, left
  /// of the cooking cut ([cookCutShare] of the width, 8 from the right).
  static const moldGap = 8.0;
  static const moldTopRoom = 34.0;
  static const moldButtonGap = 6.0;

  /// 4차 피드백 IC3·IC4: how far the hand steps' touch area (batter,
  /// filling, flip) reaches past the mold's fish box — over the mold's rim
  /// and handles and a little past them, so a stroke started on the edge
  /// or outside still counts (paste there is spilled).
  static const moldTouchOutset = EdgeInsets.symmetric(horizontal: 48, vertical: 32);
  static const cookCutShare = .32;

  /// The first-run guide card's left edge: clear of the old left queue
  /// (72), or the plain screen margin in the new layout.
  static double guideLeft(bool active) => active ? 12.0 : 72.0;
}
