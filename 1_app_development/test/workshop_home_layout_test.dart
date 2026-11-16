import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/night_stall_painter.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

/// 24번 4단계: 숙련된 붕어빵 틀 폭, 판매 카운터 높이(행주 윗변), 빈 굽는 판.
void main() {
  late DevelopmentBalance config;
  setUpAll(() => config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>));

  Future<WorkshopController> mount(WidgetTester tester, Size size) async {
    final account = await mountGame(tester, size, reduced: true);
    final c = WorkshopController(config, MemoryRepository(),
        now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
    await c.initialize();
    await c.command(() => c.state.tutorial = 'done');
    await tester.pumpWidget(GameApp(controller: account, workshop: c));
    await tester.pump();
    await tester.pump();
    return c;
  }

  GriddlePainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(const Key('griddle'))).painter! as GriddlePainter;

  Future<void> master(WorkshopController c) => c.command(() {
        final rule = config.mastery(0);
        var mastery = c.state.mastery;
        final count = DevelopmentBalance.integer(rule, 'practice_required') + 5;
        for (var i = 0; i < count; i++) {
          mastery = mastery.record(MasteryResult(id: 'practice-$i', flavor: 'redbean',
              variant: i < 5 ? i : 2, completed: true, practice: true, techniquePassed: i >= 5));
        }
        c.state.mastery = mastery;
        c.state.masteryAward = {
          'revision': config.revision,
          'resultId': 'practice-0',
          'practiceRequired': DevelopmentBalance.integer(rule, 'practice_required'),
          'techniqueRequired': DevelopmentBalance.integer(rule, 'technique_passes_required'),
        };
      });

  for (final size in const [Size(360, 640), Size(360, 800), Size(390, 844), Size(412, 915)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('숙련된 붕어빵 틀 폭 = 화면 폭 − 16, 카운터 윗변 = 행주 윗변, 겹침 없음 $tag', (tester) async {
      final c = await mount(tester, size);
      // The griddle art fills its box: 8 from each side, the art's shape.
      final griddle = tester.getRect(find.byKey(const Key('griddle')));
      expect(griddle.left, 8);
      expect(griddle.width, size.width - 16);
      final stove = PixelSprites.cosmetic(CosmeticSlot.stove, 'iron')!;
      expect(griddle.height, closeTo(griddle.width * stove.height / stove.width, .01));
      // The counter's top is the towel's top of the shown background.
      final counter = tester.getRect(find.byKey(const Key('sale-counter')));
      final towel = NightStallPainter.towelTopOnScreen(size, 'clear', null,
          clean: PixelSprites.hasCleanBackground('clear', null));
      expect(towel, isNotNull);
      expect(counter.top, closeTo(towel!, .01));
      // Before opening: the practice button ends 4 above the counter.
      final pill = tester.getRect(find
          .ancestor(of: find.text('스페셜 붕어빵 제작 시작'), matching: find.byType(Container))
          .first);
      expect(pill.bottom, closeTo(counter.top - 4, .5));
      // The counter stays above the griddle's cells, the cells above the menu.
      await c.openBusiness();
      await tester.pump();
      final nav = tester.getRect(find.byKey(const Key('home-nav')));
      for (var i = 0; i < 6; i++) {
        final cell = tester.getRect(find.byKey(Key('workshop-cell-$i')));
        expect(cell.top, greaterThan(counter.bottom), reason: 'cell $i');
        expect(cell.bottom, lessThan(nav.top), reason: 'cell $i');
        expect(cell.left, greaterThanOrEqualTo(griddle.left));
        expect(cell.right, lessThanOrEqualTo(griddle.right));
      }
      final queue = tester.getRect(find.byKey(const Key('customer-queue')));
      expect(queue.bottom, lessThanOrEqualTo(counter.top));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('빈 굽는 판: 영업 준비 중 칸 없음, 영업 중 굽는 칸만 붕어빵', (tester) async {
    final c = await mount(tester, const Size(390, 844));
    for (final id in ['iron', 'copper', 'castiron', 'golden']) {
      final full = PixelSprites.cosmetic(CosmeticSlot.stove, id)!;
      final empty = PixelSprites.emptyStove(id);
      expect(empty, isNotNull, reason: id);
      // Same canvas, so griddleCavities and the fish clips line up.
      expect((empty!.width, empty.height), (full.width, full.height), reason: id);
    }
    expect(painter(tester).filled, isEmpty);
    await c.openBusiness();
    await tester.pump();
    expect(painter(tester).filled, isEmpty);
    await master(c);
    expect(await c.startCell(1), isTrue);
    expect(await c.startCell(4), isTrue);
    await tester.pump();
    expect(painter(tester).filled, {1, 4});
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
