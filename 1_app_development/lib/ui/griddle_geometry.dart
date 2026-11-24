import 'dart:math' as math;
import 'dart:ui';

/// The stove art's griddle geometry (32번 0단계: moved unchanged from
/// `boost_effects.dart`, the old clicker's golden-chance file).
/// Centre of each griddle cavity as a fraction of the stove sprite: two
/// rows of three, measured on the concept griddle by
/// tools/concept_griddle.py.
const griddleCavities = [
  Offset(.284, .524),
  Offset(.502, .525),
  Offset(.719, .525),
  Offset(.257, .715),
  Offset(.501, .715),
  Offset(.743, .715),
];

/// The top of the griddle's front rim as a fraction of the stove sprite's
/// height (the art above it is see-through; all four stoves, closed, empty
/// and full, are wide from 163–186 of 470 px). The griddle's lock notice
/// sits on this edge (4차 피드백 IB2).
const griddleRimTop = .38;

/// The bungeoppang in each cavity of the stove art as fractions of the
/// sprite (all four stoves, measured with tools/empty_griddle.py's fish
/// masks). The two rows meet at .6085. GriddlePainter cuts a cooking cell's
/// bungeoppang with these from the stove's fish-only layer (or the full
/// art) over the empty griddle. The drawn empty griddles' fish hollows sit
/// within a few pixels of these and of [griddleCavities] (25번 1번).
const griddleFishClips = [
  Rect.fromLTRB(.188, .430, .380, .6085),
  Rect.fromLTRB(.406, .430, .596, .6085),
  Rect.fromLTRB(.619, .430, .816, .6085),
  Rect.fromLTRB(.149, .6085, .362, .815),
  Rect.fromLTRB(.395, .6085, .603, .815),
  Rect.fromLTRB(.632, .6085, .847, .815),
];

/// Where GriddlePainter draws a [sprite]-sized stove in [box]: fitted and
/// bottom-aligned.
Rect griddleSpriteRect(Size box, Size sprite) {
  final scale =
      math.min(box.width / sprite.width, box.height / sprite.height);
  final w = sprite.width * scale, h = sprite.height * scale;
  return Rect.fromLTWH((box.width - w) / 2, box.height - h, w, h);
}
