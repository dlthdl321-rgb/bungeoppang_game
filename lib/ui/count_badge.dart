import 'package:flutter/material.dart';
import 'cozy_style.dart';

/// A red count bubble on the top-right corner of [child] (claimable mission
/// rewards). Shows nothing for 0, "9+" above 9. Never takes taps, so the
/// child's own button and key keep working.
class CountBadge extends StatelessWidget {
  final int count;
  final Widget child;

  /// Key of the bubble, for tests; null leaves it unkeyed.
  final Key? badgeKey;
  const CountBadge(
      {super.key, required this.count, required this.child, this.badgeKey});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(
        top: -4,
        right: -4,
        child: IgnorePointer(
          child: Semantics(
            label: '받을 보상 $count개',
            child: Container(
              key: badgeKey,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Cozy.brick,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Cozy.cream, width: 2)),
              child: Text(count > 9 ? '9+' : '$count',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    ]);
  }
}
