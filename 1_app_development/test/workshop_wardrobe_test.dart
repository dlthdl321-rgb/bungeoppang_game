import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/ui/avatar_face.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/public_menus.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;
import 'workshop_controller_test.dart' show Gateway;

/// 26번 4-5단계: the wardrobe (wear what is owned) and the shop's avatar tab
/// (F25~F36, G1·G2·G5·G8·G12~G15).
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  group('이름·칸·저장 (F32·G12)', () {
    test('붕어빵 칸은 틀, 기본 아이템은 기본 모양 (id·enum은 그대로)', () {
      expect(cosmeticSlotLabel(CosmeticSlot.pattern), '틀');
      final scales = cosmeticDefinitions.singleWhere((d) => d.id == 'scales');
      expect(scales.name, '기본 모양');
      expect(defaultCosmetics[CosmeticSlot.pattern], 'scales');
    });

    test('요리사 복·패딩 조끼는 상의 칸, 앞치마 칸에는 앞치마만', () {
      for (final id in ['chefcoat', 'padding']) {
        expect(cosmeticDefinitions.singleWhere((d) => d.id == id).slot, CosmeticSlot.top);
        expect((config.section('avatar_catalog')[id] as Map)['slot'], 'top');
        for (final c in ['girl', 'boy']) {
          expect(File('assets/images/avatar/$c/top_$id.png').existsSync(), isTrue);
          expect(File('assets/images/avatar/$c/outfit_$id.png').existsSync(), isFalse);
        }
      }
      expect(cosmeticDefinitions.where((d) => d.slot == CosmeticSlot.outfit).map((d) => d.id).toSet(),
          {'apron', 'noapron', 'darkapron', 'creamapron', 'stripe', 'waistapron'});
      // The generated server copy follows the config.
      final server = jsonDecode(File('firebase/functions/src/generated/development_balance.json').readAsStringSync());
      expect(server['avatar_catalog']['chefcoat']['slot'], 'top');
    });

    test('계정 저장 v13에서 앞치마 칸의 요리사 복은 상의로, 앞치마는 없음으로', () {
      final state = GameState.initial(DateTime.utc(2026, 11, 1));
      final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
      json['formatVersion'] = 13;
      final wardrobe = json['wardrobe'] as Map<String, dynamic>;
      (wardrobe['owned'] as List).add('chefcoat');
      (wardrobe['equipped'] as Map)['outfit'] = 'chefcoat';
      final restored = GameState.fromJson(json);
      expect(restored.equippedCosmetic(CosmeticSlot.top), 'chefcoat');
      expect(restored.equippedCosmetic(CosmeticSlot.outfit), 'noapron');
      expect(restored.toJson()['formatVersion'], 14);
      // v14 is strict: a chef coat in the apron slot is refused.
      final v14 = jsonDecode(jsonEncode(json)) as Map<String, dynamic>..['formatVersion'] = 14;
      expect(() => GameState.fromJson(v14), throwsFormatException);
    });

    test('가게 저장 schema 8에서 앞치마 칸의 패딩 조끼는 상의로, 앞치마는 없음으로', () async {
      final c = WorkshopController(config, MemoryRepository(), purchaseGateway: Gateway());
      await c.initialize();
      await c.command(() => c.state
        ..level = 7
        ..claimedLevels.addAll([2, 3, 4, 5, 6, 7])
        ..buns = BigInt.from(5000)
        ..lifetime = BigInt.from(5000));
      expect(await c.purchaseSkill(c.purchaseGateway!, 'cosmetic:padding'), isTrue, reason: c.notice);
      final saved = c.state.toJson();
      expect(saved['schema'], 10);
      final old = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>
        ..['schema'] = 8
        ..['avatarEquipment'] = {'outfit': 'padding', 'top': 'tee'}
        ..remove('daily');
      final migrated = WorkshopState.fromJson(old, config);
      expect(migrated.avatarEquipment['top'], 'padding');
      expect(migrated.avatarEquipment['outfit'], 'noapron');
      expect(migrated.toJson()['schema'], 10);
      final strict = jsonDecode(jsonEncode(old)) as Map<String, dynamic>..['schema'] = 9;
      expect(() => WorkshopState.fromJson(strict, config), throwsFormatException);
    });

    test('모든 아바타 아이템에 칸 아이콘이 있다(임시 포함, G5)', () {
      expect(File('assets/images/cosmetic_icons/none.png').existsSync(), isTrue);
      for (final d in cosmeticDefinitions.where((d) => d.slot.category == CosmeticCategory.avatar)) {
        if (const {'nohat', 'noapron', 'noacc'}.contains(d.id)) continue;
        expect(File('assets/images/cosmetic_icons/${d.id}.png').existsSync(), isTrue, reason: d.id);
      }
    });
  });

  group('꾸미기 창 (입기)', () {
    testWidgets('360x640에서 모두 적용이 스크롤 없이 보이고, 잔액 줄은 아이콘·큰 숫자·+', (tester) async {
      final (_, _) = await _open(tester, const Size(360, 640));
      await _tap(tester, 'menu-skins');
      final apply = tester.getRect(find.byKey(const Key('wardrobe-apply-all')));
      expect(apply.bottom, lessThanOrEqualTo(640 - 60), reason: '돌아가기 줄 위');
      expect(find.text('모습만 바뀌어요 (생산 효과 없음)'), findsNothing);
      expect(find.byKey(const Key('balance-gold-plus')), findsOneWidget);
      expect(find.byKey(const Key('balance-buns')), findsOneWidget);
      // The window title's fish is the 25번 15번 one, 48 wide.
      expect(tester.getSize(find.byKey(const Key('title-fish-left'))), const Size(48, 36));
      expect(tester.takeException(), isNull);
    });

    testWidgets('여러 칸을 바꿔 입어 보고 한 번에 적용, 입은 것을 다시 누르면 표시 없음', (tester) async {
      final (c, _) = await _open(tester, const Size(390, 844));
      await _tap(tester, 'menu-skins');
      expect(find.byKey(const Key('cosmetic-preview-status')), findsNothing);
      // Wearing what is worn already shows no '입어 보는 중' (G15).
      await _tap(tester, 'preview-girl');
      expect(find.byKey(const Key('cosmetic-preview-status')), findsNothing);
      await _tap(tester, 'preview-boy');
      await _tap(tester, 'cosmetic-slot-skin');
      await _tap(tester, 'preview-skin2');
      await _tap(tester, 'cosmetic-category-outfit');
      await _tap(tester, 'cosmetic-slot-outfit');
      await _tap(tester, 'preview-noapron');
      expect(find.text('입어 보는 중'), findsOneWidget);
      expect(find.text('모두 적용(3)'), findsOneWidget);
      // All picks are drawn together.
      final look = tester.widget<CustomPaint>(find.byKey(const Key('preview-avatar-face'))).painter! as AvatarPainter;
      expect((look.look.character, look.look.skin, look.look.outfit), ('boy', 'skin2', 'noapron'));
      expect(c.state.avatarEquipment['character'], isNot('boy'));
      await _tap(tester, 'wardrobe-apply-all');
      expect(c.state.avatarEquipment['character'], 'boy');
      expect(c.state.avatarEquipment['skin'], 'skin2');
      expect(c.state.avatarEquipment['outfit'], 'noapron');
      expect(find.byKey(const Key('cosmetic-preview-status')), findsNothing);
      expect(find.text('모두 적용'), findsOneWidget);
    });

    testWidgets('꾸미기 창에는 가진 것만, 끝에 상점에서 더 보기 → 상점 같은 칸', (tester) async {
      await _open(tester, const Size(390, 844));
      await _tap(tester, 'menu-skins');
      await _tap(tester, 'cosmetic-slot-hat');
      expect(find.byKey(const Key('preview-nohat')), findsOneWidget);
      expect(find.byKey(const Key('preview-beanie')), findsNothing);
      // The tiles show the item's icon, not a tiny vendor (G5).
      expect(find.byKey(const Key('icon-nohat')), findsOneWidget);
      await _tap(tester, 'wardrobe-more-hat');
      expect(tester.widget<Text>(find.byKey(const Key('workshop-window-title'))).data, '상점');
      expect(find.byKey(const Key('preview-beanie')), findsOneWidget);
      expect(find.byKey(const Key('preview-nohat')), findsNothing);
    });

    testWidgets('미리보기를 눌러도 말하지 않고(G2) 배경은 매대 없는 방(G1)', (tester) async {
      await _open(tester, const Size(390, 844));
      await _tap(tester, 'menu-skins');
      final face = tester.widget<AvatarFace>(
          find.descendant(of: find.byKey(const Key('preview-avatar')), matching: find.byType(AvatarFace)));
      expect(face.onTap, isNull);
      expect(PixelSprites.screenArt('wardrobe_room'), isNotNull);
      expect(find.byKey(const Key('preview-room')), findsOneWidget);
    });

    testWidgets('일부를 적용하지 못하면 이름을 말하고 그 칸은 입어 보는 중으로 남는다', (tester) async {
      final game = await mountGame(tester, const Size(390, 844));
      final worn = <CosmeticSlot, String>{for (final s in CosmeticSlot.values) s: defaultCosmetics[s]!};
      final access = CosmeticMenuAccess(
          equipped: (s) => worn[s]!,
          owned: (d) => true,
          unlocked: (d) => true,
          canApply: (d) => true,
          price: (_) => '',
          action: (_) => '',
          apply: (d) async {
            if (d.id == 'skin3') return false;
            worn[d.slot] = d.id;
            return true;
          },
          listed: (d) => d.slot.category == CosmeticCategory.avatar);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WardrobePanel(controller: game, access: access))));
      await _tap(tester, 'preview-boy');
      await _tap(tester, 'cosmetic-slot-skin');
      await _tap(tester, 'preview-skin3');
      await _tap(tester, 'wardrobe-apply-all');
      expect(worn[CosmeticSlot.character], 'boy');
      expect(find.byKey(const Key('wardrobe-message')), findsOneWidget);
      expect(find.textContaining('피부톤 3'), findsWidgets);
      expect(find.text('모두 적용(1)'), findsOneWidget);
    });
  });

  group('타일 상태 (F28·F29)', () {
    testWidgets('입는 중·보유·살 수 있음·모자람·잠김을 모양으로 구분, 가격은 한 줄', (tester) async {
      final game = await mountGame(tester, const Size(390, 844));
      WardrobePrice price(CosmeticDefinition d) =>
          WardrobePrice(BigInt.from(1000), BigInt.two, missingBuns: d.id == 'earmuffs', missingGold: d.id == 'earmuffs');
      final access = CosmeticMenuAccess(
          equipped: (s) => s == CosmeticSlot.hat ? 'bandana' : defaultCosmetics[s]!,
          owned: (d) => d.free || d.id == 'bandana',
          unlocked: (d) => d.id != 'santa',
          canApply: (d) => d.id == 'beanie',
          price: (_) => '',
          action: (_) => '',
          apply: (_) async => false,
          requirement: (d) => 'Lv.9 해금',
          cost: price,
          forSale: (d) => !d.free,
          listed: (d) => d.slot.category == CosmeticCategory.avatar);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: WardrobePanel(controller: game, access: access, mode: WardrobeMode.shop, initialSlot: CosmeticSlot.hat))));
      await tester.pump();
      Finder inTile(String id, String key) =>
          find.descendant(of: find.byKey(Key('preview-$id')), matching: find.byKey(Key(key)));
      expect(inTile('beanie', 'tile-price'), findsOneWidget);
      expect(inTile('earmuffs', 'tile-price'), findsOneWidget);
      expect(tester.getSize(inTile('beanie', 'tile-price')).height, lessThanOrEqualTo(20));
      await tester.ensureVisible(find.byKey(const Key('preview-santa')));
      expect(inTile('santa', 'lock-hatch'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('산타 모자 Lv.9 해금')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('귀마개 붕어빵력 모자람')), findsOneWidget);
      // Owned items are not in the shop.
      expect(find.byKey(const Key('preview-bandana')), findsNothing);
      // A locked one can still be tried on.
      await _tap(tester, 'preview-santa');
      expect(find.text('입어 보는 중'), findsOneWidget);
      expect(find.text('Lv.9 해금'), findsWidgets);
      // In the wardrobe: worn and owned.
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: WardrobePanel(controller: game, access: access, initialSlot: CosmeticSlot.hat))));
      await tester.pump();
      expect(inTile('bandana', 'tile-worn'), findsOneWidget);
      expect(inTile('nohat', 'tile-state-owned'), findsOneWidget);
    });
  });

  group('상점 꾸미기 탭', () {
    testWidgets('잠긴 것도 입어 보고, 사면 확인 창 뒤 바로 입는다', (tester) async {
      final (c, _) = await _open(tester, const Size(390, 844), gold: 5);
      await _tap(tester, 'menu-shop');
      expect(find.byKey(const Key('shop-tab-gear')), findsNothing);
      expect(find.byKey(const Key('shop-wardrobe')), findsOneWidget);
      await _tap(tester, 'cosmetic-slot-hat');
      await _tap(tester, 'preview-beanie');
      await _tap(tester, 'buy-cosmetic-beanie');
      expect(find.byKey(const Key('wardrobe-buy-dialog')), findsOneWidget);
      await _tap(tester, 'wardrobe-buy-confirm');
      expect(c.ownsAvatar('beanie'), isTrue, reason: c.notice);
      expect(c.state.avatarEquipment['hat'], 'beanie');
      expect(find.byKey(const Key('preview-beanie')), findsNothing);
    });

    testWidgets('황금 옆 +는 충전 창을 연다', (tester) async {
      await _open(tester, const Size(390, 844));
      await _tap(tester, 'menu-shop');
      await _tap(tester, 'balance-gold-plus');
      expect(find.text('황금붕어빵력 충전'), findsOneWidget);
    });
  });

  group('가게 탭 (F33·S45-Q6)', () {
    testWidgets('Lv.7에는 가게 탭이 없고 Lv.8부터, 미리보기는 장면 전체가 상자 안', (tester) async {
      await _open(tester, const Size(390, 844), level: 7);
      await _tap(tester, 'menu-skins');
      expect(find.byKey(const Key('cosmetic-category-stall')), findsNothing);
      expect(find.byKey(const Key('cosmetic-category-bungeoppang')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _open(tester, const Size(390, 844), level: 8);
      await _tap(tester, 'menu-skins');
      await _tap(tester, 'cosmetic-category-stall');
      final box = tester.getRect(find.byKey(const Key('preview-stall')));
      final scene = tester.getRect(find.byKey(const Key('preview-stall-scene')));
      expect(box.contains(scene.topLeft) && box.contains(scene.bottomRight - const Offset(.1, .1)), isTrue);
      expect(scene.height, closeTo(box.height, 1));
    });
  });

  // Goldens: the wardrobe's hair tab with a pick, its stall tab and the
  // shop's avatar tab, with the app's fonts.
  for (final (name, route, tab) in [
    ('wardrobe_hair_390x844', 'menu-skins', null),
    ('wardrobe_stall_390x844', 'menu-skins', 'cosmetic-category-stall'),
    ('shop_avatar_390x844', 'menu-shop', null),
  ]) {
    testWidgets('골든 $name', (tester) async {
      await _open(tester, const Size(390, 844), fonts: true, gold: 1, buns: BigInt.from(1500));
      await _tap(tester, route);
      if (tab != null) await _tap(tester, tab);
      if (name.startsWith('wardrobe_hair')) await _tap(tester, 'preview-boy');
      if (name.startsWith('shop')) {
        await _tap(tester, 'cosmetic-slot-hat');
        await _tap(tester, 'preview-earmuffs');
      }
      await expectLater(find.byType(GameApp), matchesGoldenFile('goldens/$name.png'));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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

/// The Workshop home after the guide at [level], signed in with [gold].
Future<(WorkshopController, GameController)> _open(WidgetTester tester, Size size,
    {int level = 8, int gold = 0, bool fonts = false, BigInt? buns}) async {
  final online = FakeOnlineBackend(products: const {}, prices: const {})
    ..signedIn = true
    ..gold = gold;
  final game = await mountGame(tester, size, reduced: true, online: online);
  if (fonts) {
    await tester.runAsync(() async {
      Future<void> load(String family, String path) async {
        final file = File(path);
        if (!file.existsSync()) return;
        await (FontLoader(family)..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
      await load('Jua', 'assets/fonts/Jua-Regular.ttf');
      await load('BungeoSymbols', 'assets/fonts/BungeoSymbols-Regular.ttf');
      await load('MaterialIcons', 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
    });
  }
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final c = WorkshopController(config, MemoryRepository(),
      purchaseGateway: _Server(), now: () => DateTime.utc(2026, 10, 18), monotonicMs: () => 0);
  await c.initialize();
  await c.command(() {
    c.state.tutorial = 'done';
    c.state.level = level;
    c.state.claimedLevels.addAll([for (var n = 2; n <= level; n++) n]);
    c.state.featureIntros.addAll(['skills', 'collection', 'recipes', 'specialOrders', 'fishCosmetics', 'stallCosmetics']);
    c.state.lifetime = BigInt.from(20000);
    c.state.buns = buns ?? BigInt.from(20000);
  });
  game.state.premium.gold = gold;
  await tester.pumpWidget(GameApp(controller: game, workshop: c));
  await tester.pump();
  return (c, game);
}
