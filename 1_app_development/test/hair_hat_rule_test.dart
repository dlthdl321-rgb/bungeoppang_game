import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/avatar_v2.dart';
import 'package:todays_bungeoppang/avatar_v2_atlas.dart';
import 'package:todays_bungeoppang/cosmetic_config.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/ui/avatar_painter.dart';
import 'package:todays_bungeoppang/ui/center_toast.dart';
import 'package:todays_bungeoppang/ui/pixel_sprites.dart';
import 'package:todays_bungeoppang/ui/public_menus.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;
import 'package:todays_bungeoppang/development_purchase_journal.dart';
import 'workshop_controller_test.dart' show Gateway;

/// 26번 3차 AV3 (2026-11-20 사용자 결정): the high ponytail cannot go under
/// a hat over the crown (DEC-TBD-hAV3-3), and the low ponytail is a new hair
/// for both characters, held back until its art is in (DEC-TBD-hAV3-4).
void main() {
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  const crown = {'beanie', 'bandana', 'redbandana', 'chefhat', 'santa', 'newsboy'};
  final hats = [for (final d in cosmeticDefinitions) if (d.slot == CosmeticSlot.hat) d.id];
  final hairs = [for (final d in cosmeticDefinitions) if (d.slot == CosmeticSlot.hair) d.id];

  group('묶은 머리와 모자 (DEC-TBD-hAV3-3)', () {
    test('묶은 머리는 정수리를 덮는 모자 6종과 함께 쓸 수 없고 나머지는 된다', () {
      for (final hat in hats) {
        expect(hairHatClash('ponytail', hat), crown.contains(hat), reason: hat);
      }
      for (final hat in ['ballcap', 'blackcap', 'earmuffs', 'nohat']) {
        expect(hairHatClash('ponytail', hat), isFalse, reason: hat);
      }
      // Every other hair (the low ponytail too) goes with every hat.
      for (final hair in hairs.where((h) => h != 'ponytail')) {
        for (final hat in hats) {
          expect(hairHatClash(hair, hat), isFalse, reason: '$hair $hat');
        }
      }
    });

    test('그리기: 함께 쓸 수 없는 모자는 그리지 않는다', () {
      expect(const AvatarLook(hair: 'ponytail', hat: 'beanie').worn(CosmeticSlot.hat), 'nohat');
      expect(const AvatarLook(hair: 'ponytail', hat: 'ballcap').worn(CosmeticSlot.hat), 'ballcap');
      expect(const AvatarLook(hair: 'long', hat: 'beanie').worn(CosmeticSlot.hat), 'beanie');
      expect(const AvatarLook(hair: 'lowponytail', hat: 'santa').worn(CosmeticSlot.hat), 'santa');
    });

    Future<WorkshopController> owner(List<String> items) async {
      final c = WorkshopController(config, MemoryRepository(), purchaseGateway: _Server());
      addTearDown(c.dispose);
      await c.initialize();
      await c.command(() => c.state
        ..level = 9
        ..claimedLevels.addAll([2, 3, 4, 5, 6, 7, 8, 9])
        // 4차 g7 prices: 20만~60만 each (4차 병합).
        ..buns = BigInt.from(10000000)
        ..lifetime = BigInt.from(10000000));
      for (final id in items) {
        expect(await c.purchaseSkill(c.purchaseGateway!, 'cosmetic:$id'), isTrue, reason: '$id ${c.notice}');
      }
      return c;
    }

    test('입기: 묶은 머리에 그 모자, 그 모자에 묶은 머리는 막고 입던 것은 그대로', () async {
      final c = await owner(['ponytail', 'beanie', 'ballcap', 'curly']);
      expect(await c.equipAvatar('ponytail'), isTrue);
      expect(await c.equipAvatar('beanie'), isFalse);
      expect(c.notice, hatOverHairText);
      expect(c.error, isNull);
      expect(c.state.avatarEquipment['hat'], isNot('beanie'));
      expect(await c.equipAvatar('ballcap'), isTrue);
      // The other way round: the hat worn keeps the high ponytail off.
      expect(await c.equipAvatar('curly'), isTrue);
      expect(await c.equipAvatar('beanie'), isTrue);
      expect(await c.equipAvatar('ponytail'), isFalse);
      expect(c.notice, hairUnderHatText);
      expect(c.state.avatarEquipment['hair'], 'curly');
      expect(c.state.avatarEquipment['hat'], 'beanie');
    });

    test('저장에 함께 쓸 수 없는 조합이 있으면 모자를 벗고 읽는다', () async {
      final c = await owner(['ponytail', 'santa']);
      final saved = jsonDecode(jsonEncode(c.state.toJson())) as Map<String, dynamic>;
      saved['avatarEquipment'] = <String, dynamic>{...?saved['avatarEquipment'] as Map?, 'hair': 'ponytail', 'hat': 'santa'};
      final restored = WorkshopState.fromJson(saved, config);
      expect(restored.avatarEquipment['hair'], 'ponytail');
      expect(restored.avatarEquipment['hat'], 'nohat');
      expect(restored.purchases.owned['cosmetic:santa'], 1); // still owned
    });

    testWidgets('꾸미기: 함께 쓸 수 없는 것을 고르면 안내하고 입어 보는 것은 그대로', (tester) async {
      final game = await mountGame(tester, const Size(390, 844));
      final worn = <CosmeticSlot, String>{for (final s in CosmeticSlot.values) s: defaultCosmetics[s]!}
        ..[CosmeticSlot.hair] = 'ponytail';
      final applied = <String>[];
      final access = CosmeticMenuAccess(
          equipped: (s) => worn[s]!,
          owned: (d) => true,
          unlocked: (d) => true,
          canApply: (d) => true,
          price: (_) => '',
          action: (_) => '',
          apply: (d) async {
            // As the controller: never the high ponytail under a crown hat.
            final hair = d.slot == CosmeticSlot.hair ? d.id : worn[CosmeticSlot.hair]!;
            final hat = d.slot == CosmeticSlot.hat ? d.id : worn[CosmeticSlot.hat]!;
            if (hairHatClash(hair, hat)) return false;
            applied.add(d.id);
            worn[d.slot] = d.id;
            return true;
          },
          listed: (d) => d.slot.category == CosmeticCategory.avatar && d.id != 'lowponytail');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WardrobePanel(controller: game, access: access))));
      await _tap(tester, 'cosmetic-slot-hat');
      await _tap(tester, 'preview-beanie');
      expect(CenterToast.current, hatOverHairText);
      expect(find.text('입어 보는 중'), findsNothing);
      // A cap is fine.
      await _tap(tester, 'preview-ballcap');
      expect(find.text('입어 보는 중'), findsOneWidget);
      await _tap(tester, 'preview-ballcap'); // back to what is worn
      // Another hair first, then the beanie: both go on ('모두 적용'),
      // the hair before the hat.
      await _tap(tester, 'cosmetic-slot-hair');
      await _tap(tester, 'preview-curly');
      await _tap(tester, 'cosmetic-slot-hat');
      await _tap(tester, 'preview-beanie');
      // Now the high ponytail cannot be picked back under the beanie.
      await _tap(tester, 'cosmetic-slot-hair');
      await _tap(tester, 'preview-ponytail');
      expect(CenterToast.current, hairUnderHatText);
      await _tap(tester, 'wardrobe-apply-all');
      expect(applied, ['curly', 'beanie']);
      expect(worn[CosmeticSlot.hair], 'curly');
      expect(worn[CosmeticSlot.hat], 'beanie');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('모두 적용: 모자를 먼저 벗어야 묶은 머리를 할 수 있으면 모자부터', (tester) async {
      final game = await mountGame(tester, const Size(390, 844));
      final worn = <CosmeticSlot, String>{for (final s in CosmeticSlot.values) s: defaultCosmetics[s]!}
        ..[CosmeticSlot.hat] = 'santa';
      final applied = <String>[];
      final access = CosmeticMenuAccess(
          equipped: (s) => worn[s]!,
          owned: (d) => true,
          unlocked: (d) => true,
          canApply: (d) => true,
          price: (_) => '',
          action: (_) => '',
          apply: (d) async {
            final hair = d.slot == CosmeticSlot.hair ? d.id : worn[CosmeticSlot.hair]!;
            final hat = d.slot == CosmeticSlot.hat ? d.id : worn[CosmeticSlot.hat]!;
            if (hairHatClash(hair, hat)) return false;
            applied.add(d.id);
            worn[d.slot] = d.id;
            return true;
          },
          listed: (d) => d.slot.category == CosmeticCategory.avatar && d.id != 'lowponytail');
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: WardrobePanel(controller: game, access: access))));
      await _tap(tester, 'cosmetic-slot-hair');
      await _tap(tester, 'preview-ponytail');
      expect(CenterToast.current, hairUnderHatText);
      await _tap(tester, 'cosmetic-slot-hat');
      await _tap(tester, 'preview-ballcap');
      await _tap(tester, 'cosmetic-slot-hair');
      await _tap(tester, 'preview-ponytail');
      expect(find.text('입어 보는 중'), findsOneWidget);
      await _tap(tester, 'wardrobe-apply-all');
      expect(applied, ['ballcap', 'ponytail']);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('낮게 묶은 머리 (DEC-TBD-hAV3-4)', () {
    test('남녀 모두 머리 칸에 있고 가격·해금은 묶은 머리와 같다(임시값)', () {
      final d = cosmeticDefinitions.singleWhere((d) => d.id == 'lowponytail');
      final pony = cosmeticDefinitions.singleWhere((d) => d.id == 'ponytail');
      expect(d.name, '낮게 묶은 머리');
      expect(d.slot, CosmeticSlot.hair);
      expect((d.cost, d.unlockLevel), (pony.cost, pony.unlockLevel));
      for (final file in ['config/development_balance.json', 'firebase/functions/src/generated/development_balance.json']) {
        final data = jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
        final row = data['avatar_catalog']['lowponytail'] as Map;
        final ponyRow = data['avatar_catalog']['ponytail'] as Map;
        expect(row['label'], '낮게 묶은 머리', reason: file);
        expect(row['slot'], 'hair');
        expect(row['free'], isFalse);
        expect(row['unlock_level'], ponyRow['unlock_level']);
        expect(data['cosmetic_purchase']['lowponytail'], data['cosmetic_purchase']['ponytail'], reason: file);
      }
      final catalog = jsonDecode(File('firebase/functions/src/catalog.json').readAsStringSync());
      expect(catalog['spend']['cosmetic']['lowponytail'], catalog['spend']['cosmetic']['ponytail']);
    });

    test('그림이 오기 전에는 상점·꾸미기에서 숨기고 v2 필수 그림에서도 뺀다', () {
      for (final c in ['girl', 'boy']) {
        expect(avatarItemWithdrawn(c, 'lowponytail'), isTrue, reason: c);
        expect(PixelSprites.avatarArtReady(c, CosmeticSlot.hair, 'lowponytail'), isFalse, reason: c);
        expect(avatarV2Required().any((f) => f.contains('lowponytail')), isFalse);
      }
      // So v2 stays on while it waits.
      expect(avatarV2ReadyFor(avatarV2Files), avatarV2Ready);
    });
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// One receipt per purchase (as test/workshop_wardrobe_test.dart).
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
