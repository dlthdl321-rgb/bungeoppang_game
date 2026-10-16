import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/weather_layer.dart';
import 'level_missions_widget_test.dart' show tapVisible;
import 'stage8_widget_test.dart' show closeSheets, sizes;
import 'widget_test.dart' show CountingRepository, mountGame;

Iterable<CosmeticDefinition> inSlot(CosmeticSlot slot) =>
    cosmeticDefinitions.where((d) => d.slot == slot);

void main() {
  group('날씨', () {
    test('배경마다 날씨가 있고, 어느 시각이든 예외 없이 그린다', () {
      final canvas = ui.Canvas(ui.PictureRecorder());
      for (final bg in inSlot(CosmeticSlot.background)) {
        final weather = weatherFor(bg.id);
        expect(weather, isNotNull, reason: bg.id);
        for (final t in [0.0, 1.7, 3600.0]) {
          for (final size in const [Size(360, 800), Size(412, 915)]) {
            WeatherPainter(weather!, t).paint(canvas, size);
          }
        }
      }
    });

    for (final reduced in [false, true]) {
      testWidgets('홈 날씨는 모션 감소면 꺼진다 ($reduced)', (tester) async {
        await mountGame(tester, const Size(390, 844), reduced: reduced);
        expect(find.byKey(const Key('weather')),
            reduced ? findsNothing : findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  test('그림 대기 목록과 대체 그림은 실제 꾸미기 ID만 가리킨다', () {
    final ids = cosmeticDefinitions.map((d) => d.id).toSet();
    expect(ids.containsAll(PixelSprites.artPending), isTrue);
    expect(ids.containsAll(PixelSprites.artStandIns.keys), isTrue);
    expect(ids.containsAll(PixelSprites.artStandIns.values), isTrue);
    // Every new default is either drawn or borrows art.
    for (final id in defaultCosmetics.values) {
      if (PixelSprites.artPending.contains(id) &&
          !blankCosmetics.contains(id) &&
          !PixelSprites.artStandIns.containsKey(id)) {
        // Clothes layers may stay empty until drawn; the body still shows.
        expect(['tee', 'shorts', 'flats', 'apron'], contains(id));
      }
    }
  });

  test('그림이 없는 예전 배경은 폴더의 시안 배경을 빌려 쓴다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await PixelSprites.load();
    for (final id in ['clear', 'rain', 'autumn', 'snowday', 'snow', 'cherry',
        'night', 'dusk', 'forest', 'seaside']) {
      expect(PixelSprites.cosmetic(CosmeticSlot.background, id), isNotNull,
          reason: id);
    }
    for (final character in ['girl', 'boy']) {
      expect(PixelSprites.avatarBase(character), isNotNull, reason: character);
    }
  });

  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('상점 장비·꾸미기·테마 ${size.width}/$scale', (tester) async {
        final c = await mountGame(tester, size,
            textScale: scale, reduced: true, maxLevel: true);
        c.state.support
            .transact('test:fund', BigInt.from(40), 'test', c.gameNow);
        c.tick();
        await tester.pump();
        await tapVisible(tester, const Key('menu-shop'));
        // 장비: griddle and tongs, plus the way to coins and boosts.
        expect(find.byKey(const Key('support-entry')), findsOneWidget);
        expect(find.byKey(const Key('shop-buy-ribbon')), findsNothing);
        await tapVisible(tester, const Key('shop-buy-castiron'));
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.state.equippedCosmetic(CosmeticSlot.stove), 'castiron');
        expect(c.state.support.coins, BigInt.from(34));
        // 꾸미기: buying wears it.
        await tapVisible(tester, const Key('shop-tab-cosmetics'));
        await tapVisible(tester, const Key('shop-buy-ribbon'));
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.state.equippedCosmetic(CosmeticSlot.accessory), 'ribbon');
        expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('shop-buy-ribbon')))
                .onPressed,
            isNull);
        // 테마: stall items only.
        await tapVisible(tester, const Key('shop-tab-theme'));
        expect(find.byKey(const Key('shop-buy-ribbon')), findsNothing);
        await tapVisible(tester, const Key('shop-buy-rain'));
        await tapVisible(tester, const Key('confirm-support'));
        expect(c.state.equippedCosmetic(CosmeticSlot.background), 'rain');
        expect(c.state.support.coins, BigInt.from(24));
        expect(tester.takeException(), isNull);
        await closeSheets(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('꾸미기 의상·소품 탭: 고르면 미리보기만, 잠긴 항목은 적용 불가',
      (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    await tapVisible(tester, const Key('menu-skins'));
    await tapVisible(tester, const Key('cosmetic-category-outfit'));
    for (final slot in [
      CosmeticSlot.top,
      CosmeticSlot.bottom,
      CosmeticSlot.shoes,
      CosmeticSlot.outfit
    ]) {
      expect(find.byKey(Key('cosmetic-slot-${slot.name}')), findsOneWidget);
    }
    await tapVisible(tester, const Key('preview-cardigan'));
    expect(find.text('미리보기 · 미장착'), findsOneWidget);
    expect(c.state.equippedCosmetic(CosmeticSlot.top), 'tee');
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('buy-cosmetic-cardigan')))
            .onPressed,
        isNull); // Lv.6 item at Lv.1
    await tapVisible(tester, const Key('cosmetic-category-props'));
    expect(find.byKey(const Key('cosmetic-slot-accessory')), findsOneWidget);
    expect(find.byKey(const Key('cosmetic-slot-tool')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await closeSheets(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('설정의 저장 버튼은 저장하고 닫는다', (tester) async {
    final repo = CountingRepository();
    await mountGame(tester, const Size(390, 844), repository: repo);
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    final before = repo.saves;
    await tapVisible(tester, const Key('settings-save'));
    expect(repo.saves, before + 1);
    expect(find.byKey(const Key('settings-save')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
