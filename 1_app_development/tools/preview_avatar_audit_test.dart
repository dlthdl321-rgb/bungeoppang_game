// Contact sheet of every avatar item for sale (stage 26 4-4): each item
// worn by the default vendor, girl and boy, drawn by the game's own
// painter, plus every skin tone x hair style. Items the wardrobe hides
// (art not ready, PixelSprites.avatarArtReady) are marked '숨김'.
//   flutter test tools/preview_avatar_audit_test.dart
//   AVATAR_AUDIT_TAG=before flutter test tools/preview_avatar_audit_test.dart
// Writes build/avatar_audit/<girl|boy>[_<tag>].png (2x).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('아바타 아이템 전수 미리보기', () async {
    final jua = await rootBundle.load('assets/fonts/Jua-Regular.ttf');
    await (FontLoader('Jua')..addFont(Future.value(jua))).load();
    await PixelSprites.load();
    final tag = Platform.environment['AVATAR_AUDIT_TAG'] ?? '';
    for (final character in ['girl', 'boy']) {
      await _sheet(character, tag);
    }
  });
}

const _tileW = 74.0, _tileH = 150.0, _cols = 10, _zoom = 2.0;

void _label(Canvas canvas, String text, Offset at, double width,
    {Color color = const Color(0xFFFFF4E0), double size = 10}) {
  final p = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Jua', fontSize: size, color: color)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2)
    ..layout(minWidth: width, maxWidth: width);
  p.paint(canvas, at);
}

Future<void> _sheet(String character, String tag) async {
  final items = cosmeticDefinitions
      .where((d) =>
          d.slot.category == CosmeticCategory.avatar &&
          d.slot != CosmeticSlot.character)
      .toList();
  final rows = (items.length / _cols).ceil();
  const gridTop = 24.0;
  final matrixTop = gridTop + rows * _tileH + 30;
  const skins = ['skin1', 'skin2', 'skin3'];
  const hairs = ['long', 'short', 'ponytail', 'curly'];
  final width = _cols * _tileW;
  final height = matrixTop + skins.length * _tileH;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_zoom);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF3A2C26));
  _label(canvas, '$character/꾸미기 아이템 ${items.length}개 (기본 차림 위에 하나씩)',
      const Offset(0, 4), width, size: 13);
  String Function(CosmeticSlot) look(Map<CosmeticSlot, String> worn) =>
      (s) => s == CosmeticSlot.character
          ? character
          : worn[s] ?? defaultCosmetics[s]!;
  void tile(Offset at, Map<CosmeticSlot, String> worn, String name,
      {bool hidden = false}) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(at.dx + 2, at.dy + 2, _tileW - 4, _tileH - 4),
            const Radius.circular(6)),
        Paint()
          ..color = hidden ? const Color(0xFF6B3A36) : const Color(0xFF6E8F64));
    canvas.save();
    canvas.translate(at.dx + 5, at.dy + 4);
    AvatarPainter(AvatarLook.of(look(worn)))
        .paint(canvas, const Size(_tileW - 10, 118));
    canvas.restore();
    _label(canvas, hidden ? '$name\n(숨김)' : name,
        Offset(at.dx + 2, at.dy + 122), _tileW - 4,
        color: hidden ? const Color(0xFFFFB4A8) : const Color(0xFFFFF4E0));
  }

  for (var i = 0; i < items.length; i++) {
    final d = items[i];
    tile(Offset((i % _cols) * _tileW, gridTop + (i ~/ _cols) * _tileH),
        {d.slot: d.id}, d.name,
        hidden: !PixelSprites.avatarArtReady(character, d.slot, d.id));
  }
  _label(canvas, '피부톤 × 머리', Offset(0, matrixTop - 22), width, size: 13);
  for (var s = 0; s < skins.length; s++) {
    for (var h = 0; h < hairs.length; h++) {
      tile(Offset(h * _tileW, matrixTop + s * _tileH),
          {CosmeticSlot.skin: skins[s], CosmeticSlot.hair: hairs[h]},
          '${skins[s]}/${hairs[h]}');
    }
    // The same skin with a hat on short hair, a coat and an apron.
    tile(Offset(4 * _tileW, matrixTop + s * _tileH),
        {CosmeticSlot.skin: skins[s], CosmeticSlot.hat: 'chefhat'},
        '${skins[s]}/요리사 모자');
    tile(Offset(5 * _tileW, matrixTop + s * _tileH), {
      CosmeticSlot.skin: skins[s],
      CosmeticSlot.hair: 'short',
      CosmeticSlot.hat: 'santa'
    }, '${skins[s]}/짧은 머리+산타');
    tile(Offset(6 * _tileW, matrixTop + s * _tileH), {
      CosmeticSlot.skin: skins[s],
      CosmeticSlot.hair: 'curly',
      CosmeticSlot.hat: 'earmuffs',
      CosmeticSlot.outfit: 'chefcoat'
    }, '${skins[s]}/곱슬+귀마개');
    tile(Offset(7 * _tileW, matrixTop + s * _tileH), {
      CosmeticSlot.skin: skins[s],
      CosmeticSlot.hair: 'ponytail',
      CosmeticSlot.hat: 'redbandana',
      CosmeticSlot.bottom: 'widepants'
    }, '${skins[s]}/묶은+두건');
    tile(Offset(8 * _tileW, matrixTop + s * _tileH), {
      CosmeticSlot.skin: skins[s],
      CosmeticSlot.outfit: 'noapron'
    }, '${skins[s]}/앞치마 없음');
  }
  final image = await recorder
      .endRecording()
      .toImage((width * _zoom).ceil(), (height * _zoom).ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final out = File(
      'build/avatar_audit/$character${tag.isEmpty ? '' : '_$tag'}.png');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(bytes!.buffer.asUint8List());
}
