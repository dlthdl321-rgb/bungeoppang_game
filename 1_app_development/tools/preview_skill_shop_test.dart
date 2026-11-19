// 26번 4-3단계 시안 비교: the skill row layouts (A = 구현한 안, B = 두 줄 안)
// in the five states, the step pickers (돌림판 = 구현 / ×1·×10·×100 버튼) and
// the three lock looks (빗금 / 실루엣 = 구현 / 자물쇠만).
// flutter test tools/preview_skill_shop_test.dart
// Writes build/preview/skill_shop_options.png (920 wide at 2x).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/currency_amount.dart';
import 'package:todays_bungeoppang/ui/lock_overlay.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/workshop_skill_shop.dart';

class _State {
  final String label, name, level;
  final BigInt buns, gold;
  final bool on, missing, locked, maxed;
  const _State(this.label, this.name, this.level, this.buns, this.gold,
      {this.on = false, this.missing = false, this.locked = false, this.maxed = false});
}

final _states = [
  _State('해금됨(Lv.0)', '노릇한 손놀림', 'Lv.0/1000 · +60/클릭', BigInt.from(4000), BigInt.zero, on: true),
  _State('올릴 수 있음', '진한 반죽', 'Lv.3/1000 · +8/클릭', BigInt.from(411), BigInt.zero, on: true),
  _State('돈 부족', '황동 빵틀', 'Lv.0/1000 · +3,300/클릭', BigInt.from(78280000), BigInt.from(650), missing: true),
  _State('잠김', '겹겹이 반죽', '누적 100만 개 만들면 해금', BigInt.zero, BigInt.zero, locked: true),
  _State('최대 레벨', '반짝이는 틀', 'Lv.1000/1000 · +1/클릭', BigInt.zero, BigInt.zero, maxed: true),
];

const _pictures = ['tap_3', 'tap_2', 'tap_5', 'tap_6', 'tap_1'];

Widget _picture(int i, _State s, {LockStyle style = LockStyle.hidden}) {
  final picture = PixelImage(PixelSprites.skill(_pictures[i]), size: 40);
  return SizedBox.square(
      dimension: 40,
      child: s.locked
          ? LockedOverlay(caption: s.level, style: style, showCaption: false, maxLock: 30, child: picture)
          : picture);
}

Widget _cost(_State s) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      CurrencyAmount(Currency.buns, s.buns, missing: s.missing),
      if (s.gold > BigInt.zero) CurrencyAmount(Currency.gold, s.gold, missing: s.missing),
    ]);

Widget _box(_State s, Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
          color: s.locked ? Cozy.creamDeep : Cozy.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: s.on ? Cozy.honeyDeep : Cozy.tan, width: s.on ? 2 : 1)),
      child: child,
    );

const _max = Text('MAX', style: TextStyle(fontWeight: FontWeight.w900, color: Cozy.ink));
Widget _maxBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Cozy.honey, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.wood)),
    child: _max);

/// A: one line of text beside the picture, price and '+' on the right.
Widget _rowA(int i, _State s) => _box(
    s,
    Row(children: [
      _picture(i, s),
      const SizedBox(width: 8),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        Text(s.level,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.locked ? Cozy.brick : Cozy.inkSoft)),
      ])),
      if (s.maxed)
        _maxBadge()
      else ...[
        if (!s.locked) _cost(s),
        const SizedBox(width: 6),
        LevelUpButton(enabled: s.on, quantity: 1, onPressed: () {}),
      ],
    ]));

/// B: name and level on top, a wide price bar with the '+' under it.
Widget _rowB(int i, _State s) => _box(
    s,
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _picture(i, s),
        const SizedBox(width: 8),
        Expanded(child: Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        Text(s.level.startsWith('Lv.') ? s.level.split(' · ').first : '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cozy.inkSoft)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
            child: Text(s.locked ? s.level : s.level.split(' · ').last,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.locked ? Cozy.brick : Cozy.inkSoft))),
        if (s.maxed)
          _maxBadge()
        else ...[
          if (!s.locked) _cost(s),
          const SizedBox(width: 6),
          SizedBox(height: 32, child: FilledButton(onPressed: s.on ? () {} : null, child: const Text('레벨업'))),
        ],
      ]),
    ]));

Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Cozy.wood)));

Widget _segmented(int value) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (final step in [1, 10, 100])
        Container(
          width: 46,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: step == value ? Cozy.honey : Cozy.cream,
              border: Border.all(color: Cozy.wood, width: 1.5),
              borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(step == 1 ? 10 : 0), right: Radius.circular(step == 100 ? 10 : 0))),
          child: Text('×$step', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
    ]);

Widget _lockSample(String label, Widget lock) => Column(children: [
      SizedBox.square(dimension: 84, child: lock),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
    ]);

void main() {
  testWidgets('스킬 창 시안 비교', (tester) async {
    await tester.runAsync(() async {
      await PixelSprites.load();
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    });
    await tester.binding.setSurfaceSize(const Size(920, 1200));
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final picture = PixelImage(PixelSprites.skill('tap_6'), size: 64);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: cozyTheme(),
      home: Material(child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(
        key: const Key('sheet'),
        child: ColoredBox(
          color: const Color(0xfffff8ea),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('26번 4-3단계 스킬 창 시안 (★ = 구현한 안)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _title('칸 A ★ 한 줄 + 둥근 \'+\''),
                  for (var i = 0; i < _states.length; i++) _rowA(i, _states[i]),
                ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _title('칸 B 두 줄 + \'레벨업\' 버튼'),
                  for (var i = 0; i < _states.length; i++) _rowB(i, _states[i]),
                ])),
              ]),
              Text('위에서부터: ${_states.map((s) => s.label).join(' · ')}',
                  style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _title('단위 고르기'),
                  Row(children: [
                    SkillStepWheel(skillId: 'tap_1', value: 10, onChanged: (_) {}),
                    const SizedBox(width: 8),
                    const Text('★ 작은 돌림판', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _segmented(10),
                    const SizedBox(width: 8),
                    const Text('버튼 3개', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ])),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _title('공통 잠금 표시'),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _lockSample('빗금+자물쇠\n(기능·꾸미기)',
                        LockedOverlay(caption: 'Lv.5에 열려요', child: picture)),
                    _lockSample('★ 실루엣+자물쇠\n(스킬)',
                        LockedOverlay(caption: '누적 1만 개', style: LockStyle.hidden, child: picture)),
                    _lockSample('자물쇠만',
                        LockedOverlay(caption: '잠김', style: LockStyle.hidden, child: const SizedBox.expand())),
                  ]),
                ])),
              ]),
            ]),
          ),
        ),
      ))),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('sheet')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/preview/skill_shop_options.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
