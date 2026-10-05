import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/achievement_config.dart';
import 'package:todays_bungeoppang/invite_config.dart';
import 'package:todays_bungeoppang/mission_state.dart';
import 'package:todays_bungeoppang/missions.dart';
import 'widget_test.dart' show mountGame;
import 'level_missions_widget_test.dart' show tapVisible;
import 'level_missions_test.dart' show setRate;

// Prototype wording that must not reach players in a release build.
const _prototypeWords = ['모의', '실제 지급', '예시', '가상', '추정', 'estimated'];

void expectNoPrototypeText(WidgetTester tester, String where) {
  final texts = <String>[
    for (final t in tester.widgetList<Text>(find.byType(Text)))
      t.data ?? t.textSpan?.toPlainText() ?? '',
    for (final t
        in tester.widgetList<SelectableText>(find.byType(SelectableText)))
      t.data ?? '',
  ];
  for (final text in texts) {
    for (final word in _prototypeWords) {
      expect(text.contains(word), isFalse, reason: '$where: "$text"');
    }
  }
}

Future<void> closeSheets(WidgetTester tester) async {
  while (find.byTooltip('닫기').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
  }
}

const sizes = [Size(360, 800), Size(390, 844), Size(412, 915)];

void main() {
  for (final size in sizes) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('배포 모드 ${size.width}/$scale: 시제품 문구 없음·새 화면 overflow 없음',
          (tester) async {
        final c = await mountGame(tester, size,
            textScale: scale, maxLevel: true, developerTools: false);
        c.state.records.todayBestCombo = 50;
        c.tick();
        await tester.pump();
        expectNoPrototypeText(tester, 'home');
        for (final id in [
          'daily',
          'achievements',
          'shop',
          'skins',
          'records',
          'share'
        ]) {
          await tapVisible(tester, Key('menu-$id'));
          expect(tester.takeException(), isNull, reason: id);
          expectNoPrototypeText(tester, id);
          if (id == 'achievements') {
            await tapVisible(tester, const Key('achievement-claim-combo-50'));
            await tapVisible(tester, const Key('achievement-tab-collection'));
            await tapVisible(tester, const Key('title-combo-50'));
            expect(c.state.achievements.equippedTitle, '번개손');
            expect(tester.takeException(), isNull);
            expectNoPrototypeText(tester, 'collection');
          }
          if (id == 'share') {
            expect(find.byKey(const Key('developer-invites')), findsNothing);
            expect(find.textContaining(storeUrl), findsOneWidget);
          }
          await closeSheets(tester);
        }
        await tapVisible(tester, const Key('event-entry'));
        expect(tester.takeException(), isNull);
        expectNoPrototypeText(tester, 'weekly');
        await closeSheets(tester);
        await tapVisible(tester, const Key('level-mission-entry'));
        expectNoPrototypeText(tester, 'missions');
        await closeSheets(tester);
        expect(find.byKey(const Key('home-title')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('디버그 모드는 공유 화면에서 개발자 초대 도구로 들어간다', (tester) async {
    await mountGame(tester, const Size(390, 844), developerTools: true);
    await tapVisible(tester, const Key('menu-share'));
    await tapVisible(tester, const Key('developer-invites'));
    expect(find.byKey(const Key('mock-invite-notice')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('게임 공유는 OS 공유 창만 열고 보상을 주지 않는다', (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final c =
        await mountGame(tester, const Size(390, 844), developerTools: false);
    final before = c.state.toJson();
    await tapVisible(tester, const Key('menu-share'));
    await tapVisible(tester, const Key('share-game'));
    expect(calls, isNotEmpty);
    expect(find.byKey(const Key('share-message')), findsOneWidget);
    final after = c.state.toJson();
    expect(after['support'], before['support']);
    expect(after['invites'], before['invites']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('빠른 직접 탭 5번부터 홈에 콤보를 표시한다', (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    for (var i = 0; i < comboDisplayMinimum - 1; i++) {
      await tester.tap(find.byKey(const Key('fish-button')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('combo-label')), findsNothing);
    await tester.tap(find.byKey(const Key('fish-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('$comboDisplayMinimum 콤보'), findsOneWidget);
    expect(c.state.records.todayBestCombo, comboDisplayMinimum);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lv.5 꾸미기 조건은 옷장 바로가기로 이어지고 구매 후 수령된다', (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    c.state.level = 4;
    c.state.missions = MissionState.forLevel(4, c.clock.utcNow);
    c.state.support.transact('test:fund', BigInt.from(10), 'test', c.gameNow);
    setRate(c.state, BigInt.from(5000));
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('level-mission-entry'));
    expect(canClaimLevel(c.state), isFalse);
    await tapVisible(tester, const Key('mission-open-cosmetics'));
    // The shortcut introduces the vendor tab.
    expect(find.byKey(const Key('preview-avatar')), findsOneWidget);
    await tapVisible(tester, const Key('cosmetic-slot-hat'));
    await tapVisible(tester, const Key('buy-cosmetic-beanie'));
    await tapVisible(tester, const Key('confirm-support'));
    expect(canClaimLevel(c.state), isTrue);
    await closeSheets(tester);
    await tapVisible(tester, const Key('level-mission-entry'));
    await tapVisible(tester, const Key('claim-level'));
    expect(c.state.level, 5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('내 기록은 지난 최고와 비교해 신기록을 표시한다', (tester) async {
    final c = await mountGame(tester, const Size(390, 844));
    final r = c.state.records
      ..pastBestDayProduction = BigInt.from(10)
      ..pastBestDay = '2026-09-28'
      ..pastBestCombo = 3
      ..todayBestCombo = 4;
    c.state.support.daily.production = BigInt.from(11);
    c.tick();
    await tester.pump();
    await tapVisible(tester, const Key('menu-records'));
    expect(find.byKey(const Key('record-new-day')), findsOneWidget);
    expect(find.byKey(const Key('record-new-combo')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('record-best-combo'))).data,
        '${r.bestCombo}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
