import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/local_test_purchases.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/online_texts.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pantry_shop.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/workshop_skill_shop.dart' show SkillStepWheel;
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_purchases.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;
import 'workshop_controller_test.dart' show Gateway;

// 재료 타이쿤 C: the shop's '재료' tab. Basic ingredients are bought on this
// device with 붕어빵력 (same save); special ingredients through the server
// purchase path `ingredient:<id>` (a keyless test build: the local gateway).

DevelopmentBalance _config() => DevelopmentBalance.fromJson(
    jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  final config = _config();
  final premium = config.section('ingredients')['premium'] as Map<String, dynamic>;
  final packGold = premium['pack_gold'] as int, packCount = premium['pack_count'] as int;
  final unlock = premium['unlock_level'] as int;

  group('특별한 재료 견적', () {
    test('황금만(묶음 × pack_gold), 붕어빵력 0, 한 번에 max_stock까지', () {
      final q = quoteWorkshopProduct(config, 'ingredient:cultured_butter', owned: 7, quantity: 3);
      expect(q.buns, BigInt.zero);
      expect(q.gold, BigInt.from(packGold * 3));
      final limit = ingredientPackLimit(config, 'cultured_butter');
      expect(limit, 99 ~/ packCount);
      expect(() => quoteWorkshopProduct(config, 'ingredient:cultured_butter', owned: 0, quantity: limit + 1), throwsFormatException);
      expect(() => quoteWorkshopProduct(config, 'ingredient:flour', owned: 0, quantity: 1), throwsFormatException);
      expect(workshopProductRequirements(config, 'ingredient:cultured_butter')['unlock_level'], unlock);
    });

    test('붕어빵력 0 거래는 특별한 재료만(황금 > 0)', () {
      final ingredient = quoteWorkshopProduct(config, 'ingredient:vanilla_bean', owned: 0, quantity: 1);
      expect(() => PurchaseJournal.start('a', 't', ingredient), returnsNormally);
      expect(() => PurchaseJournal.start('a', 't', CompositeQuote(config.revision, 'tap_1', 0, 1, BigInt.zero, BigInt.zero)),
          throwsFormatException);
      expect(() => PurchaseJournal.start('a', 't',
          CompositeQuote(config.revision, 'ingredient:vanilla_bean', 0, 1, BigInt.zero, BigInt.zero)), throwsFormatException);
    });
  });

  group('컨트롤러 (시험용 빌드: 서버 없이)', () {
    late WorkshopController c;
    late MemoryRepository repository;
    var gold = 0;
    late LocalTestPurchaseGateway gateway;
    setUp(() async {
      gold = 0;
      gateway = LocalTestPurchaseGateway(gold: () => gold, setGold: (g) async {
        gold = g;
        return true;
      });
      repository = MemoryRepository();
      c = WorkshopController(config, repository, purchaseGateway: gateway,
          now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
      await c.initialize();
      await c.command(() {
        c.state.tutorial = 'done';
        c.state.lifetime = BigInt.from(100000);
        c.state.buns = BigInt.from(50000);
      });
    });
    tearDown(() => c.dispose());

    test('기본 재료는 앱에서 사고, 붕어빵력이 같은 저장에서 빠진다', () async {
      final p = c.pantryConfig, before = c.state.pantry.basic['flour'] ?? 0, buns = c.state.buns;
      final cost = p.basicCost('flour', 10, c.pantryRate);
      expect(cost, p.basicPrice('flour', c.pantryRate) * BigInt.from(10));
      expect(await c.buyIngredient('flour', 10), isTrue, reason: c.notice);
      expect(c.state.pantry.basic['flour'], before + 10);
      expect(c.state.buns, buns - cost);
      // One save holds both.
      final saved = WorkshopState.fromJson((await repository.load())!, config);
      expect(saved.pantry.basic['flour'], before + 10);
      expect(saved.buns, buns - cost);
      // No server purchase record for a basic ingredient.
      expect(c.state.purchases.journals, isEmpty);
    });

    test('코코아 가루는 초코 레시피 전에는 목록에 없고 살 수 없다', () async {
      expect(c.shopBasicIngredients, isNot(contains('cocoa_powder')));
      expect(c.shopBasicIngredients, ['flour', 'milk', 'egg', 'sugar', 'salt', 'adzuki']);
      final buns = c.state.buns;
      expect(await c.buyIngredient('cocoa_powder', 1), isFalse);
      expect(c.notice, '코코아 가루는 초코 레시피를 얻으면 살 수 있어요.');
      expect(c.state.buns, buns);
      expect(await c.command(() => _grant(c, recipes: ['cocoa'])), isTrue, reason: c.error);
      expect(c.shopBasicIngredients.last, 'cocoa_powder');
    });

    test('붕어빵력이 모자라거나 99개를 넘으면 아무것도 바뀌지 않는다', () async {
      await c.command(() => c.state.buns = BigInt.zero);
      expect(c.basicBuyBlocker('flour', 1), '붕어빵력이 모자라요.');
      expect(await c.buyIngredient('flour', 1), isFalse);
      expect(c.notice, '붕어빵력이 모자라요.');
      await c.command(() => c.state.buns = BigInt.from(50000));
      final room = c.state.pantry.basicRoom(c.pantryConfig, 'salt');
      expect(c.basicBuyBlocker('salt', room + 1), '소금은 99개까지 보관할 수 있어요.');
      expect(await c.buyIngredient('salt', room + 1), isFalse);
      expect(c.state.pantry.basic['salt'] ?? 0, 99 - room);
    });

    test("돌림판 ×1·×10은 그만큼(남은 자리까지), 가장 큰 단계는 '최대': 자리와 붕어빵력만큼", () async {
      final p = c.pantryConfig;
      expect(p.buySteps, [1, 10, 100]);
      expect([for (final s in p.buySteps) PantryShop.stepLabel(s, 99)], ['×1', '×10', 'MAX']);
      expect([for (final s in p.buySteps) PantryShop.stepSpoken(s, 99)], ['×1', '×10', '최대']);
      expect(c.basicBuyQuantity('milk', 10), 10);
      final price = p.basicPrice('milk', c.pantryRate), room = c.state.pantry.basicRoom(p, 'milk');
      await c.command(() => c.state.buns = price * BigInt.from(37) + BigInt.one);
      expect(c.basicBuyQuantity('milk', 100), 37);
      await c.command(() => c.state.buns = price * BigInt.from(1000));
      expect(c.basicBuyQuantity('milk', 100), room);
      await c.command(() => c.state.buns = BigInt.zero);
      expect(c.basicBuyQuantity('milk', 100), 1, reason: '못 사도 1개 가격을 보여 줌');
      expect(await c.buyIngredient('milk', 9), isFalse);
      await c.command(() => c.state.buns = price * BigInt.from(1000));
      expect(await c.buyIngredient('milk', c.basicBuyQuantity('milk', 100)), isTrue);
      expect(c.state.pantry.basic['milk'], 99);
      expect(c.basicBuyQuantity('milk', 10), 1);
      expect(c.basicBuyBlocker('milk', 1), '우유는 99개까지 보관할 수 있어요.');
    });

    test('특별한 재료는 Lv.5부터, 서버 구매 경로(시험용 게이트웨이)로 황금을 쓰고 받는다', () async {
      expect(c.premiumBuyBlocker('cultured_butter', 1, 10), '특별한 재료는 Lv.$unlock부터 살 수 있어요.');
      expect(await c.buyPremiumIngredient('cultured_butter', 1), isFalse);
      expect(await c.command(() => _grant(c, level: unlock)), isTrue, reason: c.error);
      // Not enough test gold: refused, nothing taken.
      expect(c.premiumBuyBlocker('cultured_butter', 1, 0), '황금붕어빵력이 모자라요.');
      expect(await c.buyPremiumIngredient('cultured_butter', 1), isTrue);
      expect(c.state.pantry.premium['cultured_butter'] ?? 0, 0);
      expect(c.state.purchases.journals.values.every((j) => j.settled), isTrue);
      gold = packGold * 3;
      expect(c.premiumBuyBlocker('cultured_butter', 2, gold), isNull);
      final buns = c.state.buns;
      expect(await c.buyPremiumIngredient('cultured_butter', 2), isTrue, reason: c.notice);
      expect(c.state.pantry.premium['cultured_butter'], 2 * packCount);
      expect(gold, packGold, reason: '황금 ${packGold * 2} 사용');
      expect(c.state.buns, buns, reason: '붕어빵력은 그대로');
      expect(c.state.purchases.owned['ingredient:cultured_butter'], 2);
      // Again: the owned count of packs only grows.
      expect(await c.buyPremiumIngredient('cultured_butter', 1), isTrue, reason: c.notice);
      expect(c.state.pantry.premium['cultured_butter'], 3 * packCount);
      expect(c.state.purchases.owned['ingredient:cultured_butter'], 3);
      expect(isLocalTestSave(c.state), isTrue);
      // The save with the purchase ledger and the pantry reads back.
      final saved = WorkshopState.fromJson((await repository.load())!, config);
      expect(saved.pantry.premium['cultured_butter'], 3 * packCount);
      expect(saved.purchases.owned['ingredient:cultured_butter'], 3);
    });

    test("특별한 재료 '최대'는 들어갈 만큼과 황금만큼, 99개를 넘는 구매는 서버에 가기 전에 막는다", () async {
      expect(await c.command(() {
        _grant(c, level: unlock);
        c.state.pantry.premium['fresh_adzuki'] = 95;
      }), isTrue, reason: c.error);
      expect(c.premiumBuyPacks('fresh_adzuki', 1, 100), 1);
      expect(c.premiumBuyPacks('fresh_adzuki', 10, 100), 2, reason: '4개 자리 = 2묶음');
      expect(c.premiumBuyPacks('fresh_adzuki', 100, 100), 2);
      expect(c.premiumBuyPacks('fresh_adzuki', 100, packGold), 1);
      await c.command(() => c.state.pantry.premium['fresh_adzuki'] = 98);
      expect(c.premiumBuyBlocker('fresh_adzuki', 1, 100), '국산 햇팥은 99개까지 보관할 수 있어요.');
      gold = 100;
      expect(await c.buyPremiumIngredient('fresh_adzuki', 1), isFalse);
      expect(c.state.purchases.journals, isEmpty);
      expect(gold, 100);
    });

    test('온라인 설정 없는 빌드(게이트웨이 없음)·로그인 전에는 이유를 말한다', () async {
      final offline = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
      await offline.initialize();
      await offline.command(() => _grant(offline, level: unlock));
      expect(offline.premiumBuyBlocker('vanilla_bean', 1, 10), OnlineTexts.premiumIngredientNotSetUp);
      offline.dispose();
      final signedOut = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway()..authenticatedAccount = '',
          now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
      await signedOut.initialize();
      await signedOut.command(() => _grant(signedOut, level: unlock));
      expect(signedOut.premiumBuyBlocker('vanilla_bean', 1, 10), OnlineTexts.premiumIngredientSignIn);
      signedOut.dispose();
    });
  });

  group('상점 재료 탭', () {
    testWidgets("꾸미기와 충전 사이 '재료' 탭: 기본 재료 칸, 사기, 잠긴 특별한 재료", (tester) async {
      final (c, _) = await _open(tester, const Size(390, 844));
      final chips = [for (final k in ['cosmetics', 'ingredients', 'gold']) tester.getTopLeft(find.byKey(Key('shop-tab-$k'))).dx];
      expect(chips[0] < chips[1] && chips[1] < chips[2], isTrue, reason: '$chips');
      expect(find.text('재료'), findsOneWidget);
      await _tap(tester, 'shop-tab-ingredients');
      expect(find.byType(PantryShop), findsOneWidget);
      for (final id in ['flour', 'milk', 'egg', 'sugar', 'salt', 'adzuki']) {
        expect(find.byKey(Key('ingredient-$id')), findsOneWidget, reason: id);
        expect(PixelSprites.ingredientIcons[id], isNotNull);
      }
      expect(find.byKey(const Key('ingredient-cocoa_powder')), findsNothing);
      expect(find.text('밀가루'), findsOneWidget);
      final p = c.pantryConfig, have = c.state.pantry.basic['flour'] ?? 0;
      expect(find.text('보유 $have/99개'), findsWidgets);
      // The wheel is the skill window's one.
      expect(tester.getSize(find.byKey(const Key('ingredient-step-flour'))), const Size(SkillStepWheel.width, 46));
      await _tap(tester, 'step-flour-10');
      final buns = c.state.buns;
      await _tap(tester, 'buy-ingredient-flour');
      expect(c.state.pantry.basic['flour'], have + 10);
      expect(c.state.buns, buns - p.basicCost('flour', 10, c.pantryRate));
      // Special ingredients: locked rows until Lv.5; 바닐라 빈·고급 초콜릿
      // wait for their recipe.
      expect(find.byKey(const Key('ingredient-lock-cultured_butter')), findsOneWidget);
      expect(find.byKey(const Key('ingredient-lock-fresh_adzuki')), findsOneWidget);
      expect(find.byKey(const Key('ingredient-vanilla_bean')), findsNothing);
      expect(find.byKey(const Key('ingredient-fine_chocolate')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(390, 844), Size(360, 800)]) {
      testWidgets('Lv.5 특별한 재료 칸이 황금 가격으로, 넘침 없이 (${size.width.toInt()})', (tester) async {
        final (c, account) = await _open(tester, size, level: unlock, gold: 3, recipes: const ['custard', 'cocoa']);
        await _tap(tester, 'shop-tab-ingredients');
        expect(find.byKey(const Key('ingredient-cocoa_powder')), findsOneWidget);
        for (final id in ['cultured_butter', 'fresh_adzuki', 'vanilla_bean', 'fine_chocolate']) {
          await tester.ensureVisible(find.byKey(Key('ingredient-$id')));
          await tester.pumpAndSettle();
          expect(find.byKey(Key('buy-ingredient-$id')), findsOneWidget, reason: id);
        }
        expect(account.state.premium.gold, 3);
        await _tap(tester, 'buy-ingredient-vanilla_bean');
        expect(c.state.pantry.premium['vanilla_bean'], packCount, reason: c.notice);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Lv.[level] (each level's claim recorded) and [recipes] with their 도감
/// progress, as a saved shop needs them.
void _grant(WorkshopController c, {int? level, List<String> recipes = const []}) {
  if (level != null) {
    c.state.level = level;
    c.state.claimedLevels.addAll([for (var n = 2; n <= level; n++) n]);
  }
  for (final flavor in recipes) {
    c.state.recipes.add(flavor);
    c.state.flavorMasteries[flavor] = FlavorMasteryProgress(flavor: flavor,
        difficulty: DevelopmentBalance.integer(c.config.section('active_recipes')[flavor] as Map<String, dynamic>, 'difficulty'));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The Workshop home at [level] with the shop opened from 'menu-shop'.
Future<(WorkshopController, GameController)> _open(WidgetTester tester, Size size,
    {int level = 2, int gold = 0, List<String> recipes = const []}) async {
  final online = FakeOnlineBackend(products: const {}, prices: const {})
    ..signedIn = true
    ..gold = gold;
  final game = await mountGame(tester, size, reduced: true, online: online);
  final c = WorkshopController(_config(), MemoryRepository(),
      purchaseGateway: _Server(), now: () => DateTime.utc(2026, 11, 21), monotonicMs: () => 0);
  await c.initialize();
  await c.command(() {
    c.state.tutorial = 'done';
    _grant(c, level: level, recipes: recipes);
    // 4차 병합 3: E's '재료 준비' card (Lv.2) too, so it does not cover the menu.
    c.state.featureIntros.addAll(['wardrobe', 'skills', 'pantry', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'stallCosmetics']);
    c.state.lifetime = BigInt.from(1000000);
    c.state.buns = BigInt.from(500000);
  });
  game.state.premium.gold = gold;
  await tester.pumpWidget(GameApp(controller: game, workshop: c));
  await tester.pump();
  await _tap(tester, 'menu-shop');
  return (c, game);
}

/// A fresh receipt for each transaction (like the skill window test's).
class _Server extends Gateway {
  @override
  Future<Map<String, dynamic>> reserve(PurchaseJournal intent) {
    if (receipt?['transaction'] != intent.transactionId) receipt = null;
    return super.reserve(intent);
  }

  @override
  Future<Map<String, dynamic>> commit(PurchaseJournal intent) async {
    commits++;
    return receipt = {...intent.toJson(), 'status': 'committed',
      'receiptId': 'receipt-${intent.transactionId}', 'grantId': 'grant-${intent.transactionId}'};
  }
}
