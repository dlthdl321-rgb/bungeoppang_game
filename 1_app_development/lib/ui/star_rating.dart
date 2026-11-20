import 'package:flutter/material.dart';
import '../feedback_config.dart';
import 'pixel_sprites.dart';

/// One star row for every rating in the game (4차 피드백 IC9 '별은 다섯
/// 개까지', 2026-11-20 사용자: 별이 나오는 곳은 모두 같은 5개 만점): the
/// bake result card ([cookingStars]) and the order customer's quality stars
/// (ordinary_sale `stars_min`~`stars_max`, the sale praise). [stars] of
/// [ratingStarsMax] are lit (`icons/star`), the rest the same picture grey
/// at 0.4. The screen reader reads '별 5개 중 N개'.
class StarRating extends StatelessWidget {
  final int stars;
  final double size;

  /// The lit stars' key (tests), e.g. 'mold-result-star-on'.
  final String? onKey;
  const StarRating({super.key, required this.stars, this.size = 22, this.onKey});

  static String label(int stars) => '별 $ratingStarsMax개 중 $stars개';

  @override
  Widget build(BuildContext context) => Semantics(
        label: label(stars),
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < ratingStarsMax; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * .07),
              child: i < stars
                  ? PixelIcon('star', key: onKey == null ? null : Key(onKey!), size: size)
                  : Opacity(
                      opacity: .4,
                      child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(Color(0xffd9cfc4), BlendMode.srcIn),
                          child: PixelIcon('star', size: size))),
            ),
        ]),
      );
}
