import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/support_config.dart';
import 'package:todays_bungeoppang/ui/currency_amount.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/lock_overlay.dart';
import 'package:todays_bungeoppang/ui/workshop_windows.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;
import 'workshop_controller_test.dart' show Gateway;

/// 26번 4-3단계: the skill window as a level-up list (F12~F19).
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final cap = DevelopmentBalance.integer(config.section('skill_purchase'), 'max_owned_per_skill');

  group('레벨업 단위', () {
    test('한 번에 올리는 양은 단위와 남은 레벨 중 작은 쪽이고 서버 한도(cap − 보유)와 같다', () {
      expect(skillLevelUpSteps, [1, 10, 100]);
      expect(skillLevelUpQuantity(10, owned: 995, cap: cap), 5);
      expect(skillLevelUpQuantity(100, owned: 0, cap: cap), 100);
      expect(skillLevelUpQuantity(1, owned: cap, cap: cap), 0);
      for (final step in skillLevelUpSteps) {
        for (final owned in [0, 1, 899, 950, 995, 999, 1000]) {
          final q = skillLevelUpQuantity(step, owned: owned, cap: cap);
          // development_contracts.ts: quantity > cap − owned is refused.
          expect(q, lessThanOrEqualTo(cap - owned));
          expect(() => quoteCompositeSkill(config, 'tap_1', owned: owned, quantity: q), returnsNormally);
        }
      }
      // ×10 near the cap prices the five levels left, not ten.
      expect(quoteCompositeSkill(config, 'auto_1', owned: 995, quantity: skillLevelUpQuantity(10, owned: 995, cap: cap)).quantity, 5);
    });

    test('일일 미션 문구는 스킬 레벨업 횟수', () {
      expect(dailyDefinitions.firstWhere((d) => d.id == 'purchases').title, '스킬 레벨업 횟수');
      // The Workshop mission list reads its labels from the config.
      final missions = config.section('mission_targets');
      expect(((missions['daily'] as Map)['purchases'] as Map)['label'], '스킬 레벨업 횟수');
      expect(((missions['weekly'] as Map)['purchases'] as Map)['label'], '주간 스킬 레벨업 횟수');
    });
  });

  group('구매 안내 문구', () {
    test('스킬 확인 실패는 레벨업, 꾸미기는 구매로 말한다', () async {
      final c = WorkshopController(config, MemoryRepository(), purchaseGateway: _Failing());
      await c.initialize();
      await c.command(() => c.state..lifetime = BigInt.from(1000)..buns = BigInt.from(1000));
      expect(await c.purchaseSkill(c.purchaseGateway!, 'tap_1'), isFalse);
      expect(c.notice, startsWith('레벨업 확인이 남아 있어요'));
      expect(await c.purchaseSkill(c.purchaseGateway!, 'cosmetic:beanie'), isFalse);
      expect(c.notice, startsWith('구매 확인이 남아 있어요'));
    });
  });

  testWidgets('창: 자세히 보기·온라인 문장·수량 칩 없음, 오프라인이면 꺼진 +가 이유를 말함', (tester) async {
    final (c, _) = await _open(tester, const Size(390, 844), gateway: false, buns: BigInt.from(1000));
    expect(find.text('자세히 보기'), findsNothing);
    expect(find.textContaining('온라인 연결'), findsNothing);
    for (final old in ['quantity-one', 'quantity-ten', 'quantity-maximum']) {
      expect(find.byKey(Key(old)), findsNothing);
    }
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const Key('skill-step')), findsOneWidget);
    expect(_button(tester, 'tap_1').enabled, isFalse);
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pump();
    expect(find.text('인터넷에 연결하면 레벨업할 수 있어요.'), findsOneWidget);
    expect(c.state.purchases.owned['tap_1'], isNull);
  });

  testWidgets('다음 잠긴 스킬 하나만 실루엣으로, 그 뒤는 숨김', (tester) async {
    await _open(tester, const Size(390, 844), buns: BigInt.from(100));
    // Lifetime 100: tap_1 open, tap_2 (누적 500) is the next locked one.
    expect(find.byKey(const Key('skill-tap_1')), findsOneWidget);
    expect(find.byKey(const Key('skill-tap_2')), findsOneWidget);
    expect(find.byKey(const Key('skill-tap_3')), findsNothing);
    final lock = tester.widget<LockedOverlay>(find.byKey(const Key('skill-lock-tap_2')));
    expect(lock.style, LockStyle.hidden);
    expect(find.descendant(of: find.byKey(const Key('skill-tap_2')), matching: find.byKey(const Key('lock-silhouette'))),
        findsOneWidget);
    expect(find.text('누적 500개 만들면 해금'), findsOneWidget);
    expect(find.byKey(const Key('cost-tap_2')), findsNothing);
    expect(_button(tester, 'tap_2').enabled, isFalse);
    await tester.tap(find.byKey(const Key('buy-tap_2')));
    await tester.pump();
    expect(find.text('누적 500개 만들면 열려요.'), findsOneWidget);
  });

  testWidgets('큰 해금 숫자는 줄여 쓴다(누적 2000조 개)', (tester) async {
    await _open(tester, const Size(390, 844), lifetime: BigInt.from(2) * BigInt.from(10).pow(14));
    await _tap(tester, 'kind-auto');
    await tester.scrollUntilVisible(find.byKey(const Key('unlock-auto_15')), 200, scrollable: find.byType(Scrollable).last);
    expect(tester.widget<Text>(find.byKey(const Key('unlock-auto_15'))).data, '누적 2000조 개 만들면 해금');
    expect(find.textContaining('2000000000000000'), findsNothing);
  });

  testWidgets('돈이 모자라면 + 꺼짐, 모자란 비용은 빨간색, 누르면 모자란 양', (tester) async {
    await _open(tester, const Size(390, 844), buns: BigInt.from(10));
    expect(_button(tester, 'tap_1').enabled, isFalse);
    final cost = tester.widget<CurrencyAmount>(
        find.descendant(of: find.byKey(const Key('cost-tap_1')), matching: find.byType(CurrencyAmount)).first);
    expect(cost.missing, isTrue);
    // tap_1 costs 15 at Lv.0; 10 in hand.
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pump();
    expect(find.text('붕어빵력이 5 모자라요.'), findsOneWidget);
  });

  testWidgets('로그인 전에는 + 꺼짐, 로그인 안내', (tester) async {
    await _open(tester, const Size(390, 844), buns: BigInt.from(1000), account: '');
    expect(_button(tester, 'tap_1').enabled, isFalse);
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pump();
    expect(find.text('카카오 로그인 후 레벨업할 수 있어요.'), findsWidgets);
  });

  testWidgets('×10·×100 레벨업, 남은 레벨이 적으면 남은 만큼, 다 차면 MAX', (tester) async {
    final big = BigInt.from(10).pow(90);
    final (c, account) = await _open(tester, const Size(390, 844), buns: big);
    expect(_button(tester, 'tap_1').enabled, isTrue);
    expect(_level(tester, 'tap_1'), 'Lv.0/1000 · +1/클릭');
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pumpAndSettle();
    expect(c.state.purchases.owned['tap_1'], 1);
    await _tap(tester, 'step-10');
    expect(_button(tester, 'tap_1').quantity, 10);
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pumpAndSettle();
    expect(c.state.purchases.owned['tap_1'], 11);
    await _tap(tester, 'step-100');
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byKey(const Key('buy-tap_1')));
      await tester.pumpAndSettle();
    }
    expect(c.state.purchases.owned['tap_1'], 911);
    await tester.tap(find.byKey(const Key('buy-tap_1')));
    await tester.pumpAndSettle();
    expect(c.state.purchases.owned['tap_1'], 1000);
    expect(find.byKey(const Key('max-tap_1')), findsOneWidget);
    expect(find.byKey(const Key('buy-tap_1')), findsNothing);
    expect(_level(tester, 'tap_1'), 'Lv.1000/1000 · +1/클릭');
    // 995 with ×10 offers five levels.
    await _buy(c, 'auto_1', 995);
    await _tap(tester, 'kind-auto');
    await _tap(tester, 'step-10');
    await _tap(tester, 'step-1');
    await _tap(tester, 'step-10');
    expect(_button(tester, 'auto_1').quantity, 5);
    expect(account.state.premium.gold, 0);
  });

  testWidgets('한 화면에 보이는 스킬 칸 수(F13: 전에는 약 2칸)', (tester) async {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      final huge = BigInt.from(10).pow(90);
      await _open(tester, size, buns: huge, lifetime: huge);
      final list = tester.getRect(find.byType(Scrollable).last);
      final whole = find
          .byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp(r'^skill-tap_\d+$').hasMatch((w.key! as ValueKey<String>).value))
          .evaluate()
          .where((e) {
        final r = tester.getRect(find.byWidget(e.widget));
        return r.top >= list.top && r.bottom <= list.bottom;
      }).length;
      // ignore: avoid_print
      print('skill rows fully visible at ${size.width.toInt()}x${size.height.toInt()}: $whole');
      expect(whole, greaterThanOrEqualTo(size.height > 700 ? 6 : 3));
      await tester.pumpWidget(const SizedBox());
    }
  });

  // Goldens: the window as it opens from the home menu, with the app's own
  // fonts. tap: one of each state (MAX · 올릴 수 있음 · 돈 부족 · 해금됨 Lv.0 ·
  // 잠김); auto: ×10 with a gold-priced tier 5 the player cannot pay; states:
  // 360 wide, ×100, both currencies.
  for (final (name, size, kind, step) in [
    ('tap_390x844', const Size(390, 844), 'tap', 1),
    ('auto_390x844', const Size(390, 844), 'auto', 10),
    ('states_360x800', const Size(360, 800), 'tap', 100),
  ]) {
    testWidgets('스킬 창 골든 $name', (tester) async {
      final huge = BigInt.from(10).pow(90);
      final (c, account) = await _open(tester, size, buns: huge, fonts: true, gold: name.startsWith('states') ? 3 : 0);
      await _buy(c, 'tap_1', 1000);
      await _buy(c, 'tap_2', 3);
      await _buy(c, 'auto_1', 12);
      await c.command(() {
        c.state.lifetime = BigInt.from(name.startsWith('tap') ? 12000 : 250000);
        c.state.buns = BigInt.from(name.startsWith('states') ? 200000 : 450);
      });
      await tester.pumpAndSettle();
      if (kind == 'auto') await _tap(tester, 'kind-auto');
      for (final s in skillLevelUpSteps.where((s) => s > 1 && s <= step)) {
        await _tap(tester, 'step-$s');
      }
      await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/skill_shop_$name.png'));
      expect(tester.takeException(), isNull);
      // 결과 표: rows wholly inside the list at this size.
      final list = tester.getRect(find.byType(Scrollable).last);
      final rows = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('skill-') &&
          RegExp(r'^skill-(tap|auto)_\d+$').hasMatch((w.key! as ValueKey<String>).value));
      final whole = rows.evaluate().where((e) {
        final r = tester.getRect(find.byWidget(e.widget));
        return r.top >= list.top && r.bottom <= list.bottom;
      }).length;
      // ignore: avoid_print
      print('skill rows fully visible in $name: $whole (row height ${tester.getSize(rows.first).height})');
      expect(account.state.premium.gold, name.startsWith('states') ? 3 : 0);
    });
  }
}

/// [Gateway] keeps one receipt; this one starts fresh for each new
/// transaction, so a test can level up many times.
class _Server extends Gateway {
  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent) {
    if (receipt?['transaction'] != intent.transactionId) receipt = null;
    return super.reserve(intent);
  }

  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal intent) async {
    commits++;
    // Each grant needs its own id (one receipt per transaction).
    return receipt = {...intent.toJson(), 'status': 'committed',
      'receiptId': 'receipt-${intent.transactionId}', 'grantId': 'grant-${intent.transactionId}'};
  }
}

class _Failing extends Gateway {
  @override
  Future<void> requireActiveProgress(String progressId) async => throw Exception('끊김');
}

LevelUpButton _button(WidgetTester tester, String id) => tester.widget<LevelUpButton>(find.byKey(Key('buy-$id')));
String? _level(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('level-$id'))).data;

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Levels [id] up [count] times through the real purchase path.
Future<void> _buy(WorkshopController c, String id, int count) async {
  var left = count;
  while (left > 0) {
    final n = left > 100 ? 100 : left;
    expect(await c.purchaseSkill(c.purchaseGateway!, id, quantity: n), isTrue, reason: '$id ${c.notice}');
    left -= n;
  }
}

Future<void> _loadFonts(WidgetTester tester) => tester.runAsync(() async {
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    });

/// The Workshop home at Lv.2 with the skill window opened from 'menu-skills'.
/// [gateway] false is a build without the online purchase service;
/// [account] '' is a signed-out player.
Future<(WorkshopController, GameController)> _open(WidgetTester tester, Size size,
    {bool gateway = true, String account = 'account', BigInt? buns, BigInt? lifetime, bool fonts = false, int gold = 0}) async {
  // The server owns the gold balance; the app mirrors it on sync.
  final online = FakeOnlineBackend(products: const {}, prices: const {})
    ..signedIn = account.isNotEmpty
    ..gold = gold;
  final game = await mountGame(tester, size, reduced: true, online: online);
  if (fonts) await _loadFonts(tester);
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final WorkshopPurchaseGateway? purchases = gateway ? (_Server()..authenticatedAccount = account) : null;
  final c = WorkshopController(config, MemoryRepository(),
      purchaseGateway: purchases, now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
  await c.initialize();
  await c.command(() {
    c.state.tutorial = 'done';
    c.state.level = 2;
    c.state.claimedLevels.add(2);
    c.state.featureIntros.add('skills');
    // Saved progress needs buns ≤ lifetime.
    if (lifetime != null) c.state.lifetime = lifetime;
    if (buns != null) {
      c.state.buns = buns;
      if (c.state.lifetime < buns) c.state.lifetime = buns;
    }
  });
  game.state.premium.gold = gold;
  await tester.pumpWidget(GameApp(controller: game, workshop: c));
  await tester.pump();
  await _tap(tester, 'menu-skills');
  expect(find.byType(WorkshopSkillShop), findsOneWidget);
  return (c, game);
}
