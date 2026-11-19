// 26번 3차 피드백 H43 공유 사진 시안 세 가지(한글 글꼴). A안은 앱에 들어간 ShareCardView,
// B안(폴라로이드)·C안(얼굴 크게 + 말풍선)은 비교용으로 여기서만 그린다.
// flutter test tools/preview_share_mockups_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
// 결과: build/preview/share_mockup_{A,B,C}_{perfect,shop}.png (1080×1350)
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/share_card.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/cozy_style.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/share_card_view.dart';

const _jua = TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, color: Cozy.ink);

class _Vendor extends CustomPainter {
  final double zoom;
  final double focusY;
  const _Vendor({this.zoom = 1, this.focusY = 0});
  @override
  void paint(Canvas canvas, Size size) {
    const art = AvatarLook.size;
    final scale = math.min(size.width / art.width, size.height / art.height) * zoom;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - art.width * scale) / 2, zoom > 1 ? focusY : size.height - art.height * scale);
    canvas.scale(scale);
    const AvatarLook().paint(canvas, Offset.zero, lift: 1, face: const {'mouth': 'small'});
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

Widget _street() => CustomPaint(painter: NightStallPainter(background: 'clear', night: false, stove: null,
    decoration: 'none', cleanCounter: true, lowStall: true));

/// B안: a tilted polaroid on a soft dotted paper, caption below the photo.
Widget polaroid(ShareCardData d, ShareCardTexts t) => SizedBox.fromSize(
    size: ShareCardView.size,
    child: Material(type: MaterialType.transparency, child: Container(
      color: const Color(0xfff6ead8),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Dots())),
        Center(child: Transform.rotate(angle: -.05, child: Container(
          width: 290, height: 360,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: const BoxDecoration(color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 12, offset: Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(height: 260, child: ClipRect(child: Stack(children: [
              Positioned(left: -40, right: -40, top: -240, height: NightStallPainter.sceneSize.height * 2, child: _street()),
              const Positioned(left: 30, bottom: 6, width: 120, height: 230, child: CustomPaint(painter: _Vendor())),
              Positioned(left: 120, top: 120, width: 120, height: 86,
                  child: Transform.rotate(angle: -.18, child: CustomPaint(painter: ShareFishPainter(variant: d.variant ?? 2, shine: d.shine)))),
            ]))),
            const SizedBox(height: 10),
            Text(d.title, textAlign: TextAlign.center, style: _jua.copyWith(fontSize: 24)),
            Text(d.line ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _jua.copyWith(fontSize: 13, color: Cozy.inkSoft)),
          ]),
        ))),
        Positioned(left: 0, right: 0, bottom: 12, child: Text(t.storeLine, textAlign: TextAlign.center,
            style: _jua.copyWith(fontSize: 13, color: Cozy.woodLight))),
        Positioned(right: 26, top: 16, child: Transform.rotate(angle: .2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          color: const Color(0xccffd054),
          child: Text(d.moment.badge, style: _jua.copyWith(fontSize: 16))))),
      ]),
    )));

class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x22b07a40);
    for (var y = 8.0; y < size.height; y += 18) {
      for (var x = (y ~/ 18).isEven ? 8.0 : 17.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.6, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// C안: the vendor's face and shoulders big, a speech bubble with the line.
Widget closeUp(ShareCardData d, ShareCardTexts t) => SizedBox.fromSize(
    size: ShareCardView.size,
    child: Material(type: MaterialType.transparency, child: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xffffe2b8), Color(0xffffc98a)])),
      child: Stack(children: [
        const Positioned(left: -10, top: 90, width: 230, height: 330,
            child: CustomPaint(painter: _Vendor(zoom: 1.6, focusY: 0))),
        Positioned(right: 14, top: 28, width: 190, child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.moment.badge, style: _jua.copyWith(fontSize: 14, color: Cozy.brick)),
            Text(d.title, style: _jua.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text(d.line ?? '', maxLines: 3, style: _jua.copyWith(fontSize: 14, color: Cozy.inkSoft, height: 1.25)),
          ]),
        )),
        Positioned(right: 30, top: 170, width: 150, height: 106,
            child: Transform.rotate(angle: -.2, child: CustomPaint(painter: ShareFishPainter(variant: d.variant ?? 2, shine: d.shine)))),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          color: const Color(0xeefffaf0),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.storeLine, textAlign: TextAlign.center, style: _jua.copyWith(fontSize: 14, color: Cozy.woodLight)))),
      ]),
    )));

void main() {
  Future<void> fonts(WidgetTester tester) => tester.runAsync(() async {
        Future<void> load(String family, String path) async {
          final file = File(path);
          if (!file.existsSync()) return;
          await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
        }
        const korean = String.fromEnvironment('PREVIEW_FONT');
        await load('Jua', 'assets/fonts/Jua-Regular.ttf');
        await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
        if (korean.isNotEmpty) await load('Roboto', korean);
      });
  const cards = {
    'perfect': ShareCardData(moment: ShareMoment.perfect, title: '팥 붕어빵', speaker: '도윤',
        line: '와, 이건 진짜 반짝반짝해요!', guestArt: 'npc_doyun', variant: 2, shine: true, equipped: {}),
    'shop': ShareCardData(moment: ShareMoment.shop, title: '우리 가게', line: '따끈한 붕어빵 구워 놓고 기다릴게요!', equipped: {}),
  };
  for (final entry in cards.entries) {
    for (final style in ['A', 'B', 'C']) {
      testWidgets('공유 시안 $style ${entry.key}', (tester) async {
        await fonts(tester);
        await tester.runAsync(PixelSprites.load);
        await tester.binding.setSurfaceSize(const Size(400, 500));
        tester.view.devicePixelRatio = 1;
        final config = DevelopmentBalance.fromJson(
            jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
        final texts = ShareCardTexts.of(config);
        final card = switch (style) {
          'A' => ShareCardView(data: entry.value, texts: texts),
          'B' => polaroid(entry.value, texts),
          _ => closeUp(entry.value, texts),
        };
        await tester.pumpWidget(MaterialApp(home: Center(child: RepaintBoundary(key: const Key('cap'), child: card))));
        await tester.pump();
        await tester.runAsync(() async {
          final png = await captureShareCard(tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('cap'))), texts);
          final out = File('build/preview/share_mockup_${style}_${entry.key}.png');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(png);
        });
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
