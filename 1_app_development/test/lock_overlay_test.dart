import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/lock_overlay.dart';

/// 26번 4-3단계: the one lock of the app (S43-Q4), shared by the skill
/// window, the locked home features (2단계) and the wardrobe (4-5단계).
void main() {
  Finder inside(String key, String part) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.byKey(Key(part)));

  testWidgets('잠금 표시: 빗금과 실루엣', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Row(children: [
      SizedBox.square(
          dimension: 80,
          child: LockedOverlay(
              key: const Key('a'), caption: 'Lv.5에 열려요', onTap: () => taps++, child: const ColoredBox(color: Colors.red))),
      const SizedBox.square(
          dimension: 40,
          child: LockedOverlay(
              key: Key('b'),
              caption: '누적 1만 개 만들면 해금',
              style: LockStyle.hidden,
              showCaption: false,
              child: ColoredBox(color: Colors.blue))),
    ])));
    expect(inside('a', 'lock-hatch'), findsOneWidget);
    expect(inside('a', 'lock-silhouette'), findsNothing);
    expect(inside('a', 'lock-caption'), findsOneWidget);
    expect(inside('b', 'lock-silhouette'), findsOneWidget);
    expect(inside('b', 'lock-hatch'), findsNothing);
    expect(inside('b', 'lock-caption'), findsNothing);
    expect(inside('b', 'lock-badge'), findsOneWidget);
    // The silhouette keeps only the picture's shape: every colour becomes the dark brown.
    final filter = tester.widget<ColorFiltered>(inside('b', 'lock-silhouette'));
    expect(filter.colorFilter, const ColorFilter.mode(LockedOverlay.silhouette, BlendMode.srcIn));
    expect(tester.getSemantics(find.byKey(const Key('b'))).label, '잠김, 누적 1만 개 만들면 해금');
    await tester.tap(find.byKey(const Key('a')));
    expect(taps, 1);
  });

  testWidgets('잠긴 것은 누를 수 없고, 자물쇠는 칸 크기와 maxLock 안에 맞춘다', (tester) async {
    var childTaps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Align(
      alignment: Alignment.topLeft,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 200,
            height: 200,
            child: LockedOverlay(
                key: const Key('big'),
                caption: 'Lv.8에 열려요',
                maxLock: 56,
                child: GestureDetector(onTap: () => childTaps++, child: const ColoredBox(color: Colors.green)))),
        const SizedBox.square(
            dimension: 24,
            child: LockedOverlay(key: Key('small'), caption: '잠김', child: ColoredBox(color: Colors.green))),
      ]),
    )));
    await tester.tap(find.byKey(const Key('big')));
    expect(childTaps, 0, reason: '잠긴 칸의 손가락은 아래 그림에 닿지 않는다');
    final big = tester.getSize(inside('big', 'lock-badge'));
    expect(big.width, lessThanOrEqualTo(56));
    final small = tester.getSize(inside('small', 'lock-badge'));
    expect(small.width, lessThanOrEqualTo(24 * .8 + .01));
    // No room for the caption in a 24px box: only screen readers get it.
    expect(inside('small', 'lock-caption'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
