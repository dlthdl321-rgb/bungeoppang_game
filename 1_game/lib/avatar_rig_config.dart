import 'avatar_atlas.dart';
import 'cosmetic_config.dart';

// The vendor is drawn as separate layers on one rig (stage 17). Everything
// that decides where a layer goes, which frame it shows and how a motion
// plays lives here as data; lib/ui/avatar_painter.dart only follows it.
//
// Coordinates are rig pixels: the pixels of the pose's own picture (the
// 280x520 front canvas, or a 506x506 cooking frame). A layer is placed by
// the anchor it hangs on, so moving, scaling or mirroring the vendor moves
// every layer together.

/// Draw order of the vendor's layers, back to front.
enum RigLayer {
  /// Back halves of items (`<slot>_<id>_back.png`), behind the body.
  behind,

  /// The pose's picture: body, face, default hair and clothes.
  base,
  eyes,
  mouth,
  bottom,
  shoes,
  top,
  outfit,
  hat,
  accessory,
  tool,

  /// Front halves of items (`<slot>_<id>_front.png`), over everything.
  front,
}

/// The layer each worn slot draws on (character, skin and hair change the
/// base picture itself).
const rigSlotLayers = {
  CosmeticSlot.bottom: RigLayer.bottom,
  CosmeticSlot.shoes: RigLayer.shoes,
  CosmeticSlot.top: RigLayer.top,
  CosmeticSlot.outfit: RigLayer.outfit,
  CosmeticSlot.hat: RigLayer.hat,
  CosmeticSlot.accessory: RigLayer.accessory,
  CosmeticSlot.tool: RigLayer.tool,
};

/// Halves an item may add besides its main picture, by file suffix. An item
/// that wraps around the body (a scarf, long hair over a hood) ships
/// `<slot>_<id>_back.png` and/or `_front.png`; [PixelSprites] finds them in
/// the asset list, so adding one needs no code.
const rigItemHalves = {'back': RigLayer.behind, 'front': RigLayer.front};

/// The anchor of the canvas itself: (0, 0) of the pose's picture.
const rigOrigin = 'origin';

/// How one picture sits on the rig, beyond its anchor. Pictures are drawn at
/// their own pixel size: (dx, dy) nudges it, [scale] and [rotation]
/// (radians, clockwise) turn it around its pivot, and [order] breaks ties
/// inside a layer (higher draws later).
class RigPlacement {
  final String anchor;
  final double dx, dy, scale, rotation;
  final int order;
  const RigPlacement(
      {this.anchor = rigOrigin,
      this.dx = 0,
      this.dy = 0,
      this.scale = 1,
      this.rotation = 0,
      this.order = 0});
}

/// Placement overrides by asset path (under assets/images/). Pictures not
/// listed sit at the origin unchanged, which is right for every full-canvas
/// layer cut by tools/concept_avatar.py.
const rigPlacements = <String, RigPlacement>{};

/// A face feature that can change on its own: the eyes blink and the mouth
/// talks. [frames] lists its pictures; the [rest] frame is the art itself
/// (no file), so a missing picture always falls back to the face as drawn.
class RigChannel {
  final String id;
  final RigLayer layer;
  final String rest;
  final List<String> frames;
  const RigChannel(this.id, this.layer, this.rest, this.frames);
}

const eyesChannel =
    RigChannel('eyes', RigLayer.eyes, 'open', ['open', 'half', 'closed']);
const mouthChannel =
    RigChannel('mouth', RigLayer.mouth, 'closed', ['closed', 'small', 'wide']);
const rigChannels = [eyesChannel, mouthChannel];

/// One way the vendor stands: [view] picks the face pictures (front or
/// side) and [wearsItems] whether the worn items are drawn over it (the
/// cooking frames are drawn with their clothes on).
class RigPose {
  final String id, view;
  final bool wearsItems;
  final String Function(String character) picture;
  const RigPose(this.id, this.view, this.picture, {this.wearsItems = true});

  /// Where [character]'s face features sit in this pose, in rig pixels, or
  /// null when the picture has not been measured (features keep the art).
  (double, double)? anchor(String character, String channel) =>
      avatarFaceAnchors[picture(character)]?[channel];
}

String _frontPicture(String character) => 'avatar/$character/base.png';

const frontPose = RigPose('front', 'front', _frontPicture);

/// Size of the front canvas every front layer is cut to.
const rigFrontCanvas = (280.0, 520.0);

/// The cooking frames: one pose per frame (`cook/<character>_<n>.png`), in
/// the side view and wearing their own clothes.
const cookPoses = [
  RigPose('cook1', 'side', _cook1, wearsItems: false),
  RigPose('cook2', 'side', _cook2, wearsItems: false),
  RigPose('cook3', 'side', _cook3, wearsItems: false),
  RigPose('cook4', 'side', _cook4, wearsItems: false),
  RigPose('cook5', 'side', _cook5, wearsItems: false),
  RigPose('cook6', 'side', _cook6, wearsItems: false),
];
String _cook1(String c) => 'cook/${c}_1.png';
String _cook2(String c) => 'cook/${c}_2.png';
String _cook3(String c) => 'cook/${c}_3.png';
String _cook4(String c) => 'cook/${c}_4.png';
String _cook5(String c) => 'cook/${c}_5.png';
String _cook6(String c) => 'cook/${c}_6.png';

/// The picture of [channel] at [frame] for [character] seen from [view]:
/// `parts/<character>_<view>_<channel>_<frame>.png`, cut by
/// tools/avatar_layers.py with its pivot in [avatarPartPivots].
String rigFeaturePicture(
        String character, String view, String channel, String frame) =>
    'parts/${character}_${view}_${channel}_$frame.png';

/// A motion: per channel, frames held for some milliseconds. Channels in one
/// clip share its clock, so they stay in step; separate clips run side by
/// side. After the last key the channel goes back to rest.
class MotionClip {
  final String id;
  final Map<String, List<(String, int)>> tracks;
  const MotionClip(this.id, this.tracks);

  int get durationMs {
    var longest = 0;
    for (final keys in tracks.values) {
      final sum = keys.fold(0, (sum, k) => sum + k.$2);
      if (sum > longest) longest = sum;
    }
    return longest;
  }
}

/// Talking: the mouth opens and closes; looped while someone speaks.
const talkClip = MotionClip('talk', {
  'mouth': [
    ('small', 90),
    ('wide', 110),
    ('small', 80),
    ('closed', 70),
    ('wide', 100),
    ('small', 90),
    ('closed', 120),
  ],
});

/// One blink: half shut, shut, half shut.
const blinkClip = MotionClip('blink', {
  'eyes': [('half', 40), ('closed', 70), ('half', 40)],
});

/// A happy squint: eyes shut and mouth open together, on one clock.
const cheerClip = MotionClip('cheer', {
  'eyes': [('closed', 520)],
  'mouth': [('wide', 520)],
});

/// Gap between automatic blinks, picked at random in this range.
const blinkGapMs = (2400, 5200);
