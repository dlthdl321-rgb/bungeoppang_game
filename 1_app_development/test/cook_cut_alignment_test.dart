import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_atlas.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';

// 26번 4-2단계 F9: the six cooking frames hold the workbench still
// (tools/align_cook_cuts.py), and the face anchors moved with the frames.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(PixelSprites.load);

  /// The wooden crate's box, by the same rule as align_cook_cuts.workbench:
  /// the longest run of rows that are wood across more than 36% of the
  /// width, and the columns that are wood in over 60% of its middle rows.
  (int, int, int, int) workbench(ByteData px, int w, int h) {
    bool wood(int x, int y) {
      final i = (y * w + x) * 4;
      final r = px.getUint8(i), g = px.getUint8(i + 1), b = px.getUint8(i + 2), a = px.getUint8(i + 3);
      return a > 160 && r > g && g > b && r - b > 35 && r < 200 && r > 50;
    }

    var top = 0, bottom = 0, run = 0;
    for (var y = 0; y < h; y++) {
      var n = 0;
      for (var x = 0; x < w; x++) {
        if (wood(x, y)) n++;
      }
      run = n > w * .36 ? run + 1 : 0;
      if (run > bottom - top) {
        top = y - run + 1;
        bottom = y + 1;
      }
    }
    final y0 = top + (bottom - top) ~/ 3, y1 = bottom - (bottom - top) ~/ 4;
    var left = w, right = 0;
    for (var x = 0; x < w; x++) {
      var n = 0;
      for (var y = y0; y < y1; y++) {
        if (wood(x, y)) n++;
      }
      if (n > (y1 - y0) * .6) {
        if (x < left) left = x;
        right = x + 1;
      }
    }
    return (left, top, right, bottom);
  }

  test('조리 컷 6장의 작업대 가운데 ±1px, 아래끝 ±2px (1번 기준)', () async {
    final frames = PixelSprites.cookFrames('girl')!;
    expect(frames, hasLength(PixelSprites.cookFrameCount));
    final boxes = <(int, int, int, int)>[];
    for (final ui.Image f in frames) {
      expect((f.width, f.height), (506, 506));
      boxes.add(workbench((await f.toByteData())!, f.width, f.height));
    }
    final (l1, _, r1, b1) = boxes.first;
    for (var i = 1; i < boxes.length; i++) {
      final (l, _, r, b) = boxes[i];
      // Frame 2 draws the crate's bottom rim 2 px thicker; its front lies
      // exactly on frame 1's (least squares in align_cook_cuts.py).
      expect((b - b1).abs(), lessThanOrEqualTo(2), reason: 'girl_${i + 1} bottom $b vs $b1');
      expect(((l + r) - (l1 + r1)).abs() / 2, lessThanOrEqualTo(1),
          reason: 'girl_${i + 1} middle ${(l + r) / 2} vs ${(l1 + r1) / 2}');
    }
  });

  test('얼굴 기준점은 그림을 옮긴 만큼 같이 옮겨졌다 (cook_cut_alignment.json)', () {
    // tools/avatar_layers.py's measurement before the move (2026-11-18).
    const before = {
      1: ((323.5, 156.0), (323.0, 187.0)),
      2: ((293.5, 157.0), (293.0, 188.0)),
      3: ((285.5, 155.0), (285.0, 186.0)),
      4: ((323.5, 137.0), (323.0, 168.0)),
      5: ((304.5, 135.0), (304.0, 166.0)),
      6: ((305.5, 134.0), (305.0, 165.0)),
    };
    final json = jsonDecode(File('tools/cook_cut_alignment.json').readAsStringSync())
        as Map<String, dynamic>;
    final girl = json['girl'] as Map<String, dynamic>;
    for (final MapEntry(key: n, value: (eyes, mouth)) in before.entries) {
      final move = ((girl['girl_$n'] as Map)['move'] as List).cast<num>();
      final anchors = avatarFaceAnchors['cook/girl_$n.png']!;
      expect(anchors['eyes'], (eyes.$1 + move[0], eyes.$2 + move[1]), reason: 'girl_$n eyes');
      expect(anchors['mouth'], (mouth.$1 + move[0], mouth.$2 + move[1]), reason: 'girl_$n mouth');
    }
  });

  test('남자 사장님 조리 컷은 아직 앱에 없고, 옮길 값만 저장돼 있다', () {
    expect(PixelSprites.cookCharacters, ['girl']);
    final json = jsonDecode(File('tools/cook_cut_alignment.json').readAsStringSync())
        as Map<String, dynamic>;
    final boy = json['boy'] as Map<String, dynamic>;
    expect(boy.keys, containsAll([for (var n = 1; n <= 6; n++) 'boy_$n']));
  });
}
