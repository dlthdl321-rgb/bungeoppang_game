import 'pixel_sprites.dart';

/// The Workshop home's "guests at the stall" layout (26번 4-1단계, MASTER
/// 10장): every size and offset of the guest layer, the lowered clicker and
/// the centred counter button lives here.
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
  /// left and right at 0.8 on the counter's top; the fourth and fifth (a
  /// guest leaving moves everyone back one place) further back between them.
  static const backPlaces = [(-.62, .8, 10.0), (.62, .8, 10.0), (-.3, .66, 40.0), (.3, .66, 40.0)];

  /// The order customer's words after an order bake hang this far down
  /// over their head (clear of the stage's caption line).
  static const bubbleDrop = 34.0;

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
  /// (S4-1-Q5), its bottom [clickerLift] above the counter's top so the
  /// centred counter button (44 tall, 6 above the counter) stays clear.
  static const clickerScale = .8;
  static const clickerLift = 54.0;

  /// The counter's action button floats centred on the screen (S4-1-Q6),
  /// its bottom [actionGap] above the counter's top, at least [actionMinWidth]
  /// wide and [actionHeight] tall.
  static const actionGap = 6.0;
  static const actionMinWidth = 160.0;
  static const actionHeight = 44.0;

  /// '영업 시작'·'이어서 영업'·'영업 종료' are not the floating button: a
  /// small button beside the business-state sign in the HUD (26번 시안 확인
  /// 2차, 2026-11-19 '너무 큼 → 작게, 화면 상단으로'), [businessHeight] tall
  /// with [businessFontSize] text.
  static const businessHeight = 32.0;
  static const businessFontSize = 14.0;

  /// The '오늘' slip hangs this far under the HUD's settings button, right
  /// edges lined up (26번 시안 확인 2차).
  static const slipGap = 6.0;

  /// Room the practice start pill leaves under itself before opening: the
  /// floating counter button's place (empty before opening since '영업 시작'
  /// moved to the HUD, kept so the pill does not jump).
  static const practiceLift = actionHeight + actionGap + 10;

  /// The special bungeoppang mold (26번 3차 피드백 H18 '조리 컷과 6구를
  /// 가리지 않게'): its whole picture stays [moldGap] above the higher of
  /// the sale counter's top and the cooking cut's top, rising at most until
  /// its top is [moldTopRoom] under the HUD (the bake's title line). The
  /// keep / throw away / cancel buttons sit [moldButtonGap] under it, left
  /// of the cooking cut ([cookCutShare] of the width, 8 from the right).
  static const moldGap = 8.0;
  static const moldTopRoom = 34.0;
  static const moldButtonGap = 6.0;
  static const cookCutShare = .32;

  /// The first-run guide card's left edge: clear of the old left queue
  /// (72), or the plain screen margin in the new layout.
  static double guideLeft(bool active) => active ? 12.0 : 72.0;
}
