import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
    theme: cozyTheme(),
    home: CozyMotion(
        reduce: reduce,
        child: Scaffold(body: Center(child: SizedBox(width: 300, child: child)))));

/// The sink of the pressable under [finder], read from its transform.
double _sink(WidgetTester tester, Finder finder) {
  final box = tester.widget<AnimatedContainer>(find
      .descendant(of: finder, matching: find.byType(AnimatedContainer))
      .first);
  return box.transform?.getTranslation().y ?? 0;
}

void main() {
  testWidgets('주 버튼은 누르는 동안 내려가고 놓으면 눌린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(CozyPrimaryButton(
        key: const Key('buy'), onPressed: () => taps++, label: '구매')));
    final button = find.byKey(const Key('buy'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sink(tester, button), Cozy.pressDepth);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(_sink(tester, button), 0);
  });

  testWidgets('모션 줄이기에서는 눌러도 움직이지 않는다', (tester) async {
    await tester.pumpWidget(_host(
        CozyPrimaryButton(key: const Key('buy'), onPressed: () {}, label: '구매'),
        reduce: true));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byKey(const Key('buy'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sink(tester, find.byKey(const Key('buy'))), 0);
    await gesture.up();
  });

  testWidgets('비활성 버튼은 눌리지 않고 흐린 글자를 쓴다', (tester) async {
    await tester.pumpWidget(_host(const CozyPrimaryButton(
        key: Key('locked'), onPressed: null, label: '잠김')));
    await tester.tap(find.byKey(const Key('locked')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_sink(tester, find.byKey(const Key('locked'))), 0);
    expect(tester.widget<Text>(find.text('잠김')).style?.color, Cozy.inkSoft);
  });

  testWidgets('탭은 각 탭의 Key로 눌리고 선택 상태를 알린다', (tester) async {
    var picked = 'gear';
    await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, set) => CozyTabBar<String>(tabs: const [
              CozyTab('gear', '장비', key: Key('tab-gear')),
              CozyTab('theme', '테마', key: Key('tab-theme')),
            ], selected: picked, onSelected: (v) => set(() => picked = v)))));
    await tester.tap(find.byKey(const Key('tab-theme')));
    await tester.pumpAndSettle();
    expect(picked, 'theme');
    expect(
        tester.getSemantics(find.bySemanticsLabel('테마')),
        matchesSemantics(
            label: '테마',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true));
  });

  testWidgets('메뉴 줄과 칩은 글자를 그대로 보여 준다', (tester) async {
    var opened = false;
    await tester.pumpWidget(_host(Column(children: [
      CozyMenuRow(
          key: const Key('row'),
          icon: const Icon(Icons.star),
          title: '업적',
          subtitle: '진행 중',
          subtitleKey: const Key('row-sub'),
          onPressed: () => opened = true),
      const CozyChip(label: '클릭 +2'),
    ])));
    expect(find.text('클릭 +2'), findsOneWidget);
    expect(find.byKey(const Key('row-sub')), findsOneWidget);
    await tester.tap(find.byKey(const Key('row')));
    expect(opened, isTrue);
  });

  testWidgets('돌아가기 버튼은 이전과 같은 높이(여백 3 + 48)를 유지한다', (tester) async {
    await tester.pumpWidget(_host(Center(child: CozyBackButton(onPressed: () {}))));
    expect(tester.getSize(find.byKey(const Key('sheet-back'))).height, 54);
  });
}
