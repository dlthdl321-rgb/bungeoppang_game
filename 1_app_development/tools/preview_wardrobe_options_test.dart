// 26번 4-5단계 시안 비교 (★ = 구현한 안): 창 배치 3안, 꾸미기 분위기(G8) 3안,
// 타일 2안(G5·F28·F29), 미리보기 상태 표시(G15) 3안, 가게 미리보기(F33) 3안,
// 창 제목 장식(F36·G13) 크기 4안.
// flutter test tools/preview_wardrobe_options_test.dart
// Writes build/preview/wardrobe_options.png (1100 wide at 2x).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/currency_amount.dart';
import 'package:todays_bungeoppang/ui/lock_overlay.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/workshop_wardrobe.dart';

String _worn(CosmeticSlot s) => defaultCosmetics[s]!;

Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Cozy.wood)));

Widget _label(String text) =>
    Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)));

Widget _room({double h = 120, Widget? overlay}) => SizedBox(
    height: h,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover, child: PixelArt(PixelSprites.screenArt('wardrobe_room'), width: 240, height: 144)),
        Padding(padding: const EdgeInsets.all(6), child: CustomPaint(painter: AvatarPainter(AvatarLook.of(_worn)))),
        if (overlay != null) overlay,
      ]),
    ));

Widget _btn(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Cozy.honey, borderRadius: BorderRadius.circular(14), border: Border.all(color: Cozy.wood, width: 1.5)),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)));

Widget _tabs() => Wrap(spacing: 4, children: [
      WardrobePill(label: '헤어', icon: 'tab_hair', selected: true, onTap: () {}, small: true),
      WardrobePill(label: '의상', icon: 'tab_outfit', selected: false, onTap: () {}, small: true),
    ]);

/// Window layouts: where '모두 적용' sits (F25·S45-Q3).
Widget _layout(String name, int kind) => SizedBox(
    width: 250,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: _tabs()), if (kind == 1) _btn('모두 적용(2)')]),
      const SizedBox(height: 4),
      _room(overlay: kind == 0 ? Positioned(right: 6, bottom: 6, child: _btn('모두 적용(2)')) : null),
      if (kind == 2) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Expanded(child: Text('2개 바꿔 입는 중')), _btn('모두 적용(2)')])),
      const SizedBox(height: 4),
      Container(height: 40, color: Cozy.creamDeep, alignment: Alignment.center, child: const Text('칸 칩 · 격자(여기만 스크롤)')),
      _label(name),
    ]));

/// Chip and tile mood (G8).
Widget _mood(String name, int kind) {
  Widget chip(String t, bool on) => switch (kind) {
        0 => WardrobePill(label: t, selected: on, onTap: () {}, small: true),
        1 => Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            decoration: BoxDecoration(
                color: on ? Cozy.peach : Cozy.cream,
                border: Border.all(color: Cozy.woodLight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800))),
        _ => Container(
            margin: const EdgeInsets.only(right: 4),
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: on ? Cozy.woodLight : Cozy.wood, shape: BoxShape.circle, border: Border.all(color: Cozy.woodDark, width: 2)),
            alignment: Alignment.center,
            child: Text(t.substring(0, 1), style: const TextStyle(color: Cozy.cream, fontWeight: FontWeight.w900))),
      };
  Widget tile(String id, bool on) {
    final d = cosmeticDefinitions.firstWhere((d) => d.id == id);
    final pic = PixelArt(PixelSprites.cosmeticIcon(id), width: 44, height: 44);
    return switch (kind) {
      0 => SizedBox(width: 78, child: WardrobeTile(name: d.name, state: on ? WardrobeTileState.worn : WardrobeTileState.owned, picture: pic, onTap: () {})),
      1 => Container(
          width: 78,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Cozy.cream, border: Border.all(color: on ? Cozy.brick : Cozy.tan, width: 2), borderRadius: BorderRadius.circular(4)),
          child: Column(children: [pic, Text(d.name, style: const TextStyle(fontSize: 12))])),
      _ => Container(
          width: 78,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          decoration: const BoxDecoration(color: Cozy.creamDeep, border: Border(bottom: BorderSide(color: Cozy.wood, width: 6))),
          child: Column(children: [pic, Text(d.name, style: const TextStyle(fontSize: 12))])),
    };
  }

  return SizedBox(
      width: 260,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [chip('캐릭터', true), const SizedBox(width: 4), chip('머리', false), const SizedBox(width: 4), chip('모자', false)]),
        const SizedBox(height: 6),
        Row(children: [tile('long', true), const SizedBox(width: 6), tile('short', false), const SizedBox(width: 6), tile('curly', false)]),
        _label(name),
      ]));
}

Widget _state(String name, int kind) => SizedBox(
    width: 250,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: kind == 2 ? BoxDecoration(border: Border.all(color: Cozy.honeyDeep, width: 4), borderRadius: BorderRadius.circular(16)) : null,
        child: _room(
            overlay: switch (kind) {
          0 => const Positioned(left: 6, top: 6, child: WardrobeRibbon(label: '입어 보는 중')),
          1 => Positioned(
              left: 6,
              top: 6,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Cozy.cream, borderRadius: BorderRadius.circular(12)),
                  child: const Text('2개 바꿔 입는 중', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
          _ => Positioned(right: 6, bottom: 6, child: _btn('모두 적용(2)')),
        }),
      ),
      _label(name),
    ]));

Widget _stall(String name, int kind) {
  final painter = NightStallPainter(avatar: AvatarLook.of(_worn));
  final box = switch (kind) {
    0 => Container(
        height: 150,
        color: Cozy.woodDark,
        alignment: Alignment.center,
        child: AspectRatio(aspectRatio: 180 / 400, child: CustomPaint(painter: painter))),
    1 => Container(height: 300, color: Cozy.woodDark, alignment: Alignment.center, child: AspectRatio(aspectRatio: 180 / 400, child: CustomPaint(painter: painter))),
    _ => Container(
        height: 150,
        color: Cozy.woodDark,
        alignment: Alignment.center,
        child: PixelArt(PixelSprites.cosmetic(CosmeticSlot.stove, 'iron'), width: 200, height: 100)),
  };
  return SizedBox(width: 170, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ClipRRect(borderRadius: BorderRadius.circular(12), child: box), _label(name)]));
}

Widget _fishTitle(double w) => Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Transform.flip(flipX: true, child: PixelArt(PixelSprites.screenArt('title_fish'), width: w, height: w * .75)),
        const SizedBox(width: 6),
        const Text('꾸미기', style: TextStyle(fontFamily: 'Jua', fontSize: 28)),
        const SizedBox(width: 6),
        PixelArt(PixelSprites.screenArt('title_fish'), width: w, height: w * .75),
      ]),
      _label('${w.toInt()}×${(w * .75).toInt()}${w == 48 ? ' ★' : ''}'),
    ]);

void main() {
  testWidgets('꾸미기·상점 시안 비교', (tester) async {
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
    await tester.binding.setSurfaceSize(const Size(1100, 1700));
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final price = WardrobePrice(BigInt.from(1000), BigInt.two, missingGold: true);
    Widget tileB(String id, String status, {bool locked = false}) {
      final d = cosmeticDefinitions.firstWhere((d) => d.id == id);
      Widget pic = PixelArt(PixelSprites.cosmeticIcon(id), width: 52, height: 52);
      if (locked) pic = SizedBox.square(dimension: 52, child: LockedOverlay(caption: 'Lv.9 해금', showCaption: false, child: pic));
      return Container(
          width: 150,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Cozy.cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.tan)),
          child: Row(children: [pic, const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(status, style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
          ]))]));
    }

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: cozyTheme(),
      home: Material(
          child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const Key('sheet'),
                child: Container(
                  width: 1100,
                  color: const Color(0xfffff8ea),
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('26번 4-5단계 꾸미기·상점 시안 (★ = 구현한 안, answers.md S45-Q3 등)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    _title('1. 창 배치 — 모두 적용 버튼 자리 (F25·F26)'),
                    Wrap(spacing: 16, children: [
                      _layout('★ 미리보기 위 오른쪽 아래 구석', 0),
                      _layout('탭 줄 오른쪽 빈자리', 1),
                      _layout('미리보기 아래 상태 줄', 2),
                    ]),
                    _title('2. 꾸미기 분위기 (G8) — 칩·타일 한 벌'),
                    Wrap(spacing: 16, children: [
                      _mood('★ (가) 크림 알약 칩 + 둥근 카드·동그란 받침', 0),
                      _mood('(나) 책갈피 탭 + 각진 카드', 1),
                      _mood('(다) 나무 단추 + 선반 칸', 2),
                    ]),
                    _title('3. 타일 (G5·F28·F29) — 입는 중 / 보유 / 살 수 있음 / 모자람 / 잠김'),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final (id, state) in [
                        ('long', WardrobeTileState.worn),
                        ('short', WardrobeTileState.owned),
                        ('beanie', WardrobeTileState.buyable),
                        ('earmuffs', WardrobeTileState.short),
                        ('santa', WardrobeTileState.locked),
                      ])
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                                width: 104,
                                child: WardrobeTile(
                                    name: cosmeticDefinitions.firstWhere((d) => d.id == id).name,
                                    state: state,
                                    price: state == WardrobeTileState.buyable ? WardrobePrice(BigInt.from(1000), BigInt.two) : price,
                                    lockCaption: 'Lv.9 해금',
                                    picture: PixelArt(PixelSprites.cosmeticIcon(id)),
                                    onTap: () {}))),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('B안: 가로 카드', style: TextStyle(fontWeight: FontWeight.w800)),
                        tileB('short', '보유'),
                        const SizedBox(height: 4),
                        tileB('beanie', '1,000 + 황금 2'),
                        const SizedBox(height: 4),
                        tileB('santa', 'Lv.9 해금', locked: true),
                      ]),
                    ]),
                    _label('★ A안: 아이콘 68% 동그란 받침, 이름 한 줄, 상태·가격 한 줄(가격은 아이콘+숫자, 모자란 재화 빨강)'),
                    _title('4. 미리보기 상태 표시 (G15)'),
                    Wrap(spacing: 16, children: [
                      _state('★ (가) 왼쪽 위 리본 + 되돌리기 단추 (입은 그대로면 없음)', 0),
                      _state('(나) 바뀐 칸 수 말풍선', 1),
                      _state('(다) 테두리 색 + 버튼의 수', 2),
                    ]),
                    _title('5. 가게 탭 미리보기 (F33) — Lv.8부터 보임'),
                    Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.end, children: [
                      _stall('★ 세로 장면 통째로(작게)', 0),
                      _stall('상자를 세로로 키우기', 1),
                      _stall('칸마다 그 부분만(화로)', 2),
                    ]),
                    _title('6. 창 제목 장식 (F36·G13, 25번 15번 그림, 왼쪽은 뒤집음)'),
                    Wrap(spacing: 24, children: [for (final w in [40.0, 48.0, 56.0, 64.0]) _fishTitle(w)]),
                    _title('7. 잔액 줄 (F31·S45-Q4) — 모든 Workshop 창 위'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Cozy.cream, borderRadius: BorderRadius.circular(16), border: Border.all(color: Cozy.woodLight)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CurrencyAmount(Currency.buns, BigInt.from(12500), size: 24, fontSize: 19),
                        const SizedBox(width: 18),
                        CurrencyAmount(Currency.gold, BigInt.from(7), size: 24, fontSize: 19),
                        const SizedBox(width: 4),
                        const CircleAvatar(radius: 12, backgroundColor: Cozy.honey, child: Icon(Icons.add_rounded, size: 18, color: Cozy.ink)),
                      ]),
                    ),
                  ]),
                ),
              ))),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('sheet')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/preview/wardrobe_options.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
