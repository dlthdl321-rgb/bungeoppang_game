import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_fairy.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 4차 피드백 g12: 붕어빵 요정의 넓은 헤엄(위아래·대각선·곡선, 가끔 화면
/// 밖으로 나갔다가 다른 곳에서 다시 들어옴)과, 그동안에도 탭이 그대로
/// 세어지는지.
void main() {
  // A 390×844 stage like the game's (below the HUD, above the counter).
  const stage = Size(390, 560);
  final home = Rect.fromCenter(center: const Offset(195, 470), width: 110, height: 120);
  final path = FairyPath(stage, home, 500, wander: true);
  final xMin = home.width / 2 + FairyMotion.sideMargin, xMax = stage.width - xMin;
  final yTop = FairyMotion.topClearance + home.height / 2, yBottom = home.center.dy;
  const step = 50, span = 240000;

  test('제자리에서 떠나 위아래·옆으로 넓게 헤엄침', () {
    expect(path.swim(0).center, home.center);
    var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
    var verticalMoves = 0;
    Offset? last;
    var lastOut = false;
    for (var ms = 0; ms <= span; ms += step) {
      final pose = path.swim(ms);
      final c = pose.center;
      final out = path.offStage(pose);
      if (last != null && !(out && lastOut)) {
        // Smooth: never a jump (out of sight it moves to where it comes in).
        expect((c - last).distance, lessThan(FairyMotion.speed * 2 * step / 1000 + 2), reason: '$ms');
      }
      // Only past the sides, never behind the counter or under the HUD.
      expect(c.dy, inInclusiveRange(yTop - FairyMotion.bob - .01, yBottom + FairyMotion.bob + .01), reason: '$ms');
      if (!path.offStage(pose)) {
        minX = math.min(minX, c.dx);
        maxX = math.max(maxX, c.dx);
        minY = math.min(minY, c.dy);
        maxY = math.max(maxY, c.dy);
      }
      if (ms % 500 == 0 && ms > 0) {
        final d = c - path.swim(ms - 500).center;
        if (d.dy.abs() > 15 && d.dy.abs() > d.dx.abs() * 2) verticalMoves++;
      }
      last = c;
      lastOut = out;
    }
    expect(minX, lessThan(xMin + 20));
    expect(maxX, greaterThan(xMax - 20));
    expect(maxY - minY, greaterThan((yBottom - yTop) * .85));
    expect(verticalMoves, greaterThan(20), reason: '위아래로도 헤엄침');
  });

  test('가끔 화면 밖으로 나갔다가 잠깐 뒤 다른 곳에서 다시 들어옴', () {
    final trips = <(int, int, Offset, Offset)>[];
    int? outAt;
    Offset? before;
    var prev = path.swim(0);
    for (var ms = step; ms <= span; ms += step) {
      final pose = path.swim(ms);
      final out = path.offStage(pose);
      if (out && outAt == null) {
        outAt = ms;
        before = prev.center;
      } else if (!out && outAt != null) {
        trips.add((outAt, ms, before!, pose.center));
        outAt = null;
      }
      prev = pose;
    }
    // About one trip a round (a round is roughly 20–30 s).
    expect(trips.length, inInclusiveRange(span ~/ 40000, span ~/ 12000));
    var lefts = 0, rights = 0;
    for (final (from, to, exit, entry) in trips) {
      // Out for a moment: at least the wait, not long.
      expect(to - from, inInclusiveRange(FairyMotion.offMinMs, FairyMotion.offMaxMs + 2500));
      final exitLeft = exit.dx < stage.width / 2, entryLeft = entry.dx < stage.width / 2;
      exitLeft ? lefts++ : rights++;
      // Back in somewhere else: the other side or another height.
      expect(exitLeft != entryLeft || (exit.dy - entry.dy).abs() > 30, isTrue, reason: '$from');
    }
    expect(lefts, greaterThan(0));
    expect(rights, greaterThan(0));
  });

  test('가는 쪽을 봄, 같은 시각이면 같은 길(미리보기)', () {
    var right = 0, rightFacing = 0, left = 0, leftFacing = 0;
    for (var ms = 1000; ms <= span; ms += 250) {
      final d = path.swim(ms + 40).center - path.swim(ms - 40).center;
      final face = path.swim(ms).face;
      if (d.dx > 4 && d.dx.abs() > d.dy.abs()) {
        right++;
        if (face < 0) rightFacing++;
      } else if (d.dx < -4 && d.dx.abs() > d.dy.abs()) {
        left++;
        if (face > 0) leftFacing++;
      }
    }
    expect(rightFacing / right, greaterThan(.85));
    expect(leftFacing / left, greaterThan(.85));
    final again = FairyPath(stage, home, 500, wander: true);
    for (final ms in [0, 7777, 33333, 123456]) {
      expect(again.swim(ms).center, path.swim(ms).center);
    }
    // Not swimming (reduced motion, the first-run guide): its place.
    expect(FairyPath(stage, home, 500, wander: false).swim(33333).center, home.center);
    // The tap box is at least 56 either way.
    final small = FairyPath(stage, Rect.fromCenter(center: const Offset(100, 300), width: 40, height: 30), 500,
        wander: true);
    final box = small.hitBox(small.swim(5000));
    expect(math.min(box.width, box.height), greaterThanOrEqualTo(FairyMotion.minHit));
  });

  group('헤엄치는 요정 탭', () {
    tearDown(() {
      FairyMotion.previewMs = null;
      FairyMotion.previewSwitchMs = null;
    });

    testWidgets('헤엄 중에도, 화면 밖에 다녀온 뒤에도 탭이 세어짐', (tester) async {
      const size = Size(390, 844);
      final account = await mountGame(tester, size);
      final config = DevelopmentBalance.fromJson(
          jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
      var mono = 0;
      final c = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 10, 18),
          monotonicMs: () => mono);
      await c.initialize();
      await c.command(() => c.state..tutorial = 'done'..featureIntros.add('fairy'));
      await c.openBusiness();
      await tester.pumpWidget(GameApp(controller: account, workshop: c));
      await tester.pump();

      Future<Rect> at(int ms) async {
        FairyMotion.previewMs = ms;
        tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
        await tester.pump();
        return tester.getRect(find.byKey(const Key('workshop-clicker')));
      }

      Future<void> tapFairy(Rect r) async {
        mono += 1000;
        await tester.tapAt(r.center);
        await tester.pump();
      }

      // Find moments: swimming in the open, and wholly out of the stage.
      int? inside, outside, back;
      for (var ms = 2000; ms <= 90000 && (back == null); ms += 250) {
        final r = await at(ms);
        final out = r.right <= 0 || r.left >= size.width;
        if (!out && r.left > 0 && r.right < size.width && inside == null) inside = ms;
        if (out && inside != null && outside == null) outside = ms;
        if (!out && r.left > 0 && r.right < size.width && outside != null) back = ms;
      }
      expect([inside, outside, back], everyElement(isNotNull));

      final taps = c.state.taps, missionsBefore = jsonEncode(c.state.missions.toJson());
      final swimRect = await at(inside!);
      expect(swimRect.center, isNot(const Offset(195, 0)));
      await tapFairy(swimRect);
      expect(c.state.taps, taps + 1, reason: '헤엄 중 탭');

      // Out of the stage: nothing there to tap (a tap at its old spot misses).
      final outRect = await at(outside!);
      expect(outRect.right <= 0 || outRect.left >= size.width, isTrue);
      await tapFairy(swimRect);
      expect(c.state.taps, taps + 1);

      // Back in elsewhere: taps count as before, missions see them.
      final backRect = await at(back!);
      await tapFairy(backRect);
      await tapFairy(backRect);
      expect(c.state.taps, taps + 3);
      expect(jsonEncode(c.state.missions.toJson()), isNot(missionsBefore));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
