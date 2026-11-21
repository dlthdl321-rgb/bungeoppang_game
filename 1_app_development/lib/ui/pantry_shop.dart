import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../pantry_rules.dart';
import '../workshop_controller.dart';
import 'center_toast.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';
import 'workshop_skill_shop.dart' show SkillStepWheel;

/// The shop's '재료' tab (재료 타이쿤 C, between 꾸미기 and 충전).
///
/// 기본 재료: one row per basic ingredient the shop lists now
/// ([WorkshopController.shopBasicIngredients]: 코코아 가루 only after the
/// 초코 recipe) with its picture (25번 62번), name, '보유 12/99개', what the
/// wheel's step buys (count and 붕어빵력, red when short), the skill window's
/// small wheel (`ingredients.buy_steps`: ×1 · ×10 · 최대) and '사기'. Bought
/// on this device: the 붕어빵력 leaves in the same save.
///
/// 특별한 재료: the same rows priced in 황금붕어빵력 (one pack = `pack_count`
/// for `pack_gold`), bought through the server like a cosmetic
/// (`ingredient:<id>`). Locked rows under the padlock until
/// `premium.unlock_level`; a special ingredient whose 반죽·속 needs a recipe
/// not owned yet (바닐라 빈 → 슈크림, 고급 초콜릿 → 초코) is not listed.
///
/// Like the skill rows, a dark '사기' still answers with the reason.
class PantryShop extends StatefulWidget {
  final WorkshopController controller;
  final GameController account;
  const PantryShop({super.key, required this.controller, required this.account});

  /// Every row's height (the wheel's box plus padding), like the skill rows.
  static const rowHeight = 64.0;

  /// '최대' for the step that is the biggest one ([WorkshopController.pantryMaxStep]).
  static String stepLabel(int step, int limit) => WorkshopController.pantryMaxStep(step, limit) ? '최대' : '×$step';

  @override
  State<PantryShop> createState() => _PantryShopState();
}

class _PantryShopState extends State<PantryShop> {
  /// Each row's wheel step while the window is open.
  final _steps = <String, int>{};

  WorkshopController get c => widget.controller;
  int get _gold => widget.account.state.premium.gold;

  int _step(String id, PantryConfig p) => _steps[id] ?? p.buySteps.first;

  void _say(String message) => showCenterToast(context, message);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([c, widget.account]),
      builder: (context, _) {
        final p = c.pantryConfig, pantry = c.state.pantry;
        final open = pantry.premiumVisible(p, c.state.level);
        final premium = [
          for (final e in p.premium.entries)
            if (pantry.preparedVisible(p, e.value.prepared, c.state.recipes)) e.key
        ];
        final pending = c.state.purchases.journals.values
            .where((j) => !j.settled && j.quote.skillId.startsWith('ingredient:'))
            .toList();
        // A dozen rows at most: one scrolling column (all rows built).
        return SingleChildScrollView(
            key: const Key('pantry-shop'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header('기본 재료', '붕어빵력으로 사요'),
          for (final id in c.shopBasicIngredients) _basicRow(id, p),
          const SizedBox(height: 8),
          _header('특별한 재료',
              open ? '황금붕어빵력 ${p.premiumPackGold}개에 ${p.premiumPackCount}개씩' : 'Lv.${p.premiumUnlockLevel}부터 살 수 있어요'),
          for (final j in pending) _pendingRow(j.transactionId, j.quote.skillId.substring(11), p),
          for (final id in premium) _premiumRow(id, p, open),
        ]));
      });

  Widget _header(String title, String note) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Cozy.ink)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cozy.inkSoft))),
        ]),
      );

  Widget _basicRow(String id, PantryConfig p) {
    final item = p.basic[id]!, have = c.state.pantry.basic[id] ?? 0;
    final step = _step(id, p), quantity = c.basicBuyQuantity(id, step);
    final cost = p.basicCost(id, quantity, c.pantryRate);
    final reason = c.basicBuyBlocker(id, quantity);
    return _row(
      key: Key('ingredient-$id'),
      icon: PixelIcon(PixelSprites.ingredientIcons[id] ?? 'bun', size: 40),
      name: item.label,
      detail: '보유 $have/${item.maxStock}개',
      price: _price(id, '$quantity개', CurrencyAmount(Currency.buns, cost, missing: c.state.purchases.available(c.state.buns) < cost)),
      wheel: _wheel(id, p, step, item.maxStock),
      button: _BuyButton(
          key: Key('buy-ingredient-$id'),
          enabled: reason == null,
          onPressed: () async {
            if (reason != null) return _say(reason);
            final ok = await c.buyIngredient(id, quantity);
            if (!mounted) return;
            _say(ok ? '${item.label} $quantity개를 샀어요.' : c.notice ?? c.error ?? '살 수 없어요.');
          }),
    );
  }

  Widget _premiumRow(String id, PantryConfig p, bool open) {
    final item = p.premium[id]!, have = c.state.pantry.premium[id] ?? 0;
    final picture = PixelIcon(PixelSprites.ingredientIcons[id] ?? 'gold_bun', size: 40);
    final use = '${p.kind(item.prepared).premiumLabel} 재료';
    if (!open) {
      return _row(
        key: Key('ingredient-$id'),
        locked: true,
        icon: LockedOverlay(
            key: Key('ingredient-lock-$id'),
            style: LockStyle.hidden,
            caption: 'Lv.${p.premiumUnlockLevel}부터 살 수 있어요',
            showCaption: false,
            maxLock: 30,
            child: picture),
        name: item.label,
        detail: use,
        price: Text('Lv.${p.premiumUnlockLevel} 해금',
            key: Key('ingredient-unlock-$id'),
            style: const TextStyle(fontSize: 12.5, color: Cozy.brick, fontWeight: FontWeight.w800)),
      );
    }
    final step = _step(id, p), packs = c.premiumBuyPacks(id, step, _gold);
    final gold = BigInt.from(packs * p.premiumPackGold);
    final reason = c.premiumBuyBlocker(id, packs, _gold);
    return _row(
      key: Key('ingredient-$id'),
      icon: picture,
      name: item.label,
      detail: '보유 $have/${item.maxStock}개\n$use',
      price: _price(id, '${packs * p.premiumPackCount}개', CurrencyAmount(Currency.gold, gold, missing: BigInt.from(_gold) < gold)),
      wheel: _wheel(id, p, step, item.maxStock ~/ p.premiumPackCount),
      button: _BuyButton(
          key: Key('buy-ingredient-$id'),
          enabled: reason == null,
          onPressed: () async {
            if (reason != null) return _say(reason);
            final before = c.state.pantry.premium[id] ?? 0;
            await c.buyPremiumIngredient(id, packs);
            await widget.account.refreshWorkshopWallet();
            if (!mounted) return;
            final got = (c.state.pantry.premium[id] ?? 0) - before;
            _say(got > 0 ? '${item.label} $got개를 샀어요.' : c.notice ?? c.error ?? '황금붕어빵력이 모자라요.');
          }),
    );
  }

  /// A special ingredient's purchase the server has not settled yet (the
  /// app closed in the middle): '다시 확인' finishes it with the same record.
  Widget _pendingRow(String transaction, String id, PantryConfig p) => Container(
        key: Key('ingredient-pending-$id'),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
            color: Cozy.peach, borderRadius: BorderRadius.circular(12), border: Border.all(color: Cozy.peachEdge)),
        child: Row(children: [
          Expanded(
              child: Text('${p.premium[id]?.label ?? id} 구매 확인이 남아 있어요',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Cozy.ink))),
          TextButton(
              onPressed: c.purchaseGateway == null || c.purchaseBusy
                  ? null
                  : () async {
                      await c.recoverPurchase(c.purchaseGateway!, transaction);
                      await widget.account.refreshWorkshopWallet();
                    },
              child: const Text('다시 확인')),
        ]),
      );

  Widget _wheel(String id, PantryConfig p, int step, int limit) => SkillStepWheel(
      key: Key('ingredient-step-$id'),
      skillId: id,
      value: step,
      steps: p.buySteps,
      labelOf: (s) => PantryShop.stepLabel(s, limit),
      semanticLabel: '한 번에 살 개수',
      onChanged: (next) => setState(() => _steps[id] = next));

  /// What one press buys: the count above its price.
  Widget _price(String id, String count, Widget amount) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 84),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Column(key: Key('ingredient-cost-$id'), crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(count, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Cozy.ink, height: 1.1)),
            amount,
          ]),
        ),
      );

  Widget _row({required Key key, bool locked = false, required Widget icon, required String name,
      required String detail, required Widget price, Widget? wheel, Widget? button}) {
    // A hairline edge on every row (no honey outline on a dozen rows at
    // once, 3차 피드백 원칙 4); whether it can be bought shows on '사기'.
    const edge = 1.0;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(minHeight: PantryShop.rowHeight),
      padding: const EdgeInsets.fromLTRB(10 - edge, 6 - edge, 8 - edge, 6 - edge),
      decoration: BoxDecoration(
        color: locked ? Cozy.creamDeep : Cozy.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cozy.tan, width: edge),
      ),
      child: Row(children: [
        SizedBox.square(dimension: 40, child: icon),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Cozy.ink)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(detail,
                  maxLines: 2,
                  softWrap: false,
                  style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        price,
        if (wheel != null) ...[const SizedBox(width: 6), wheel],
        if (button != null) ...[const SizedBox(width: 4), button],
      ]),
    );
  }
}

/// '사기': honey when the purchase can go through, pale otherwise. Always
/// pressable; a pale one answers with the reason.
class _BuyButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _BuyButton({super.key, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: '사기',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? Cozy.honey : Cozy.creamDeep,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: enabled ? Cozy.honeyDeep : Cozy.tan),
            ),
            child: Text('사기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: enabled ? Cozy.ink : Cozy.inkSoft)),
          ),
        ),
      );
}
