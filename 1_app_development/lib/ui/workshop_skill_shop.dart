import 'package:flutter/material.dart';
import '../balance.dart';
import '../development_balance.dart';
import '../development_rules.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../models.dart';
import '../workshop_controller.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';

/// The Workshop skill window (26번 4-3단계, F12~F19): a list of skills to
/// level up, not things to buy. Two tabs (클릭 생산·자동 생산) share one
/// layout; a small wheel beside them picks how many levels one '+' adds
/// (×1·×10·×100, [skillLevelUpSteps]). Each row: picture, name,
/// 'Lv.12/1000 · +60/클릭' (one level's effect), the price of the chosen
/// step and a round '+' that is lit only when the level-up can go through.
/// A dark '+' still answers with the reason. Of the locked skills only the
/// next one shows, as a silhouette under the padlock with its condition.
class WorkshopSkillShop extends StatefulWidget {
  final WorkshopController controller;
  final GameController account;
  const WorkshopSkillShop({super.key, required this.controller, required this.account});
  @override
  State<WorkshopSkillShop> createState() => _WorkshopSkillShopState();
}

class _WorkshopSkillShopState extends State<WorkshopSkillShop> {
  UpgradeKind _kind = UpgradeKind.tap;
  int _step = skillLevelUpSteps.first;

  /// Leading tiers whose tap and auto skills cost no gold (DEC-041: 4).
  static int _freeTiers(WorkshopController c) {
    var tier = 0;
    while (tier < 16 &&
        DevelopmentBalance.integer(c.config.skill('tap_${tier + 1}'), 'gold') == 0 &&
        DevelopmentBalance.integer(c.config.skill('auto_${tier + 1}'), 'gold') == 0) {
      tier++;
    }
    return tier;
  }

  void _say(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, account = widget.account;
    final cap = DevelopmentBalance.integer(c.config.section('skill_purchase'), 'max_owned_per_skill');
    final skills = upgrades.where((u) => u.kind == _kind).toList();
    final rows = <Widget>[];
    var nextLockedShown = false;
    for (final skill in skills) {
      final owned = c.state.purchases.owned[skill.id] ?? 0;
      final unlocked = owned > 0 ||
          c.state.lifetime >= DevelopmentBalance.decimal(c.config.skill(skill.id), 'unlock_total');
      if (!unlocked) {
        // S43-Q3: only the very next locked skill shows; the rest stay hidden.
        if (nextLockedShown) continue;
        nextLockedShown = true;
      }
      rows.add(_row(skill, owned: owned, cap: cap, unlocked: unlocked));
    }
    final free = _freeTiers(c);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(children: [
          for (final kind in UpgradeKind.values) ...[
            Expanded(child: _KindTab(kind: kind, selected: kind == _kind, onTap: () => setState(() => _kind = kind))),
            const SizedBox(width: 6),
          ],
          SkillStepWheel(value: _step, onChanged: (step) => setState(() => _step = step)),
        ]),
      ),
      Expanded(
        child: ListView(key: ValueKey('skills-${_kind.name}'), padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), children: [
          if (c.purchaseGateway != null && !account.online.signedIn)
            CozyPanel(
                key: const Key('skill-sign-in'),
                child: Column(children: [
                  const Text('카카오 로그인 후 레벨업할 수 있어요.', textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  FilledButton(
                      key: const Key('skill-sign-in-button'),
                      onPressed: account.signingIn
                          ? null
                          : () async {
                              final message = await account.signInOnline();
                              if (message != null && context.mounted) _say(message);
                            },
                      child: const Text('카카오 로그인')),
                ])),
          if (free > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  free >= 16
                      ? '모든 스킬은 붕어빵력만으로 레벨업해요.'
                      : '1~$free단계 스킬은 붕어빵력만으로 레벨업해요. 황금붕어빵력은 ${free + 1}단계부터 필요해요.',
                  key: const Key('skill-gold-note'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Cozy.inkSoft, fontSize: 12)),
            ),
          for (final journal in c.state.purchases.journals.values.where((j) => !j.settled))
            CozyPanel(
                child: Column(children: [
              Text(_pendingLabel(journal.quote.skillId)),
              Wrap(children: [
                TextButton(
                    onPressed: c.purchaseGateway == null || c.purchaseBusy || c.busy
                        ? null
                        : () => c.recoverPurchase(c.purchaseGateway!, journal.transactionId),
                    child: const Text('복구')),
                TextButton(
                    onPressed: c.purchaseGateway == null || c.purchaseBusy || c.busy
                        ? null
                        : () => c.recoverPurchase(c.purchaseGateway!, journal.transactionId, cancel: true),
                    child: const Text('취소 확인')),
              ])
            ])),
          ...rows,
        ]),
      ),
    ]);
  }

  static String _pendingLabel(String id) {
    if (id.startsWith('cosmetic:')) return '구매 확인 대기: ${id.substring(9)}';
    final skill = upgrades.where((u) => u.id == id);
    return '레벨업 확인 대기: ${skill.isEmpty ? id : skill.first.name}';
  }

  /// Why the '+' of [id] cannot level up now, or null when it can.
  String? _blocked({required bool unlocked, required String id, required CompositeQuote? quote,
      required BigInt buns, required BigInt gold}) {
    final c = widget.controller;
    if (!unlocked) return '${unlockGoalText(c.config, id)} 만들면 열려요.';
    if (c.purchaseGateway == null) return '인터넷에 연결하면 레벨업할 수 있어요.';
    if (c.purchaseGateway!.authenticatedAccount.isEmpty) return '카카오 로그인 후 레벨업할 수 있어요.';
    if (c.error != null) return c.error;
    if (c.busy || c.purchaseBusy) return '잠시 뒤에 다시 눌러 주세요.';
    if (quote == null) return null;
    final lackBuns = quote.buns - buns, lackGold = quote.gold - gold;
    if (lackBuns > BigInt.zero && lackGold > BigInt.zero) {
      return '붕어빵력이 ${compactNumber(lackBuns)}, 황금붕어빵력이 ${compactNumber(lackGold)} 모자라요.';
    }
    if (lackBuns > BigInt.zero) return '붕어빵력이 ${compactNumber(lackBuns)} 모자라요.';
    if (lackGold > BigInt.zero) return '황금붕어빵력이 ${compactNumber(lackGold)} 모자라요.';
    return null;
  }

  Widget _row(UpgradeDefinition skill, {required int owned, required int cap, required bool unlocked}) {
    final c = widget.controller, account = widget.account, id = skill.id;
    final rule = c.config.skill(id);
    final maxed = owned >= cap;
    final quantity = skillLevelUpQuantity(_step, owned: owned, cap: cap);
    final quote = maxed ? null : quoteCompositeSkill(c.config, id, owned: owned, quantity: quantity);
    final buns = c.state.purchases.available(c.state.buns), gold = BigInt.from(account.state.premium.gold);
    final reason = maxed ? null : _blocked(unlocked: unlocked, id: id, quote: quote, buns: buns, gold: gold);
    final picture = PixelImage(PixelSprites.skill(id), size: 40);
    final unit = _kind == UpgradeKind.tap ? '클릭' : '초';
    return Container(
      key: Key('skill-$id'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: unlocked ? Cozy.cream : Cozy.creamDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reason == null && !maxed ? Cozy.honeyDeep : Cozy.tan, width: reason == null && !maxed ? 2 : 1),
      ),
      child: Row(children: [
        SizedBox.square(
          dimension: 40,
          child: unlocked
              ? picture
              : LockedOverlay(
                  key: Key('skill-lock-$id'),
                  style: LockStyle.hidden,
                  caption: '${unlockGoalText(c.config, id)} 만들면 해금',
                  showCaption: false,
                  maxLock: 30,
                  child: picture),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(skill.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Cozy.ink)),
            if (unlocked)
              Text('Lv.$owned/$cap · +${compactNumber(DevelopmentBalance.decimal(rule, 'effect'))}/$unit',
                  key: Key('level-$id'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w700))
            else
              Text('${unlockGoalText(c.config, id)} 만들면 해금',
                  key: Key('unlock-$id'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Cozy.brick, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (maxed)
          Container(
            key: Key('max-$id'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Cozy.honey, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.wood)),
            child: const Text('MAX', style: TextStyle(fontWeight: FontWeight.w900, color: Cozy.ink)),
          )
        else ...[
          if (unlocked && quote != null)
            Column(key: Key('cost-$id'), crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              CurrencyAmount(Currency.buns, quote.buns, missing: quote.buns > buns),
              // DEC-041: tiers 1~4 ask no gold, so no '황금 0'.
              if (quote.gold > BigInt.zero) CurrencyAmount(Currency.gold, quote.gold, missing: quote.gold > gold),
            ]),
          const SizedBox(width: 6),
          LevelUpButton(
            key: Key('buy-$id'),
            enabled: reason == null,
            quantity: quantity,
            onPressed: () async {
              if (reason != null) return _say(reason);
              await c.purchaseSkill(c.purchaseGateway!, id, quantity: quantity);
              await account.refreshWorkshopWallet();
            },
          ),
        ],
      ]),
    );
  }
}

/// '누적 1만 개' for the skill's unlock goal ([compactNumber], so
/// 2×10^15 reads '누적 2000조 개' instead of sixteen digits).
String unlockGoalText(DevelopmentBalance config, String id) {
  final goal = compactNumber(DevelopmentBalance.decimal(config.skill(id), 'unlock_total'));
  final digitEnd = RegExp(r'\d$').hasMatch(goal);
  return '누적 $goal${digitEnd ? '' : ' '}개';
}

/// The round '+' (25번 19번 `ui/levelup_plus.png` / `levelup_plus_off.png`).
/// Always pressable: a dark '+' explains itself through [onPressed].
/// [quantity] over one shows as a small '×10' tag.
class LevelUpButton extends StatelessWidget {
  final bool enabled;
  final int quantity;
  final VoidCallback onPressed;
  const LevelUpButton({super.key, required this.enabled, required this.quantity, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final art = PixelSprites.screenArt(enabled ? 'levelup_plus' : 'levelup_plus_off');
    return Semantics(
      button: true,
      enabled: enabled,
      label: quantity > 1 ? '레벨업 $quantity' : '레벨업',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (art != null)
              PixelArt(art, width: 40, height: 40)
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? Cozy.honey : const Color(0xffb7aca5),
                    border: Border.all(color: enabled ? Cozy.wood : const Color(0xff6f6560), width: 2)),
                child: const Icon(Icons.add, color: Cozy.cream, size: 26),
              ),
            if (quantity > 1)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                      color: Cozy.cream, borderRadius: BorderRadius.circular(6), border: Border.all(color: Cozy.wood)),
                  child: Text('×$quantity',
                      style: const TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w900, color: Cozy.ink)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A tab of the skill window: icon and name, the chosen one filled honey.
/// No check mark (a ChoiceChip's check covered the icon, F19).
class _KindTab extends StatelessWidget {
  final UpgradeKind kind;
  final bool selected;
  final VoidCallback onTap;
  const _KindTab({required this.kind, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: Key('kind-${kind.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: selected ? Cozy.honey : Cozy.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Cozy.wood : Cozy.tan, width: selected ? 2 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PixelIcon(kind == UpgradeKind.tap ? 'tab_tap' : 'tab_auto', size: 28),
              const SizedBox(width: 2),
              Flexible(
                child: Text(kind == UpgradeKind.tap ? '클릭 생산' : '자동 생산',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: selected ? Cozy.ink : Cozy.inkSoft)),
              ),
            ]),
          ),
        ),
      );
}

/// The small vertical wheel that picks the level-up step (S43-Q8): the
/// chosen '×10' sits in the middle band with its neighbours above and
/// below; a swipe up or down moves one step, a tap on a neighbour picks it.
class SkillStepWheel extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const SkillStepWheel({super.key, required this.value, required this.onChanged});

  static const rowHeight = 16.0, width = 52.0;

  void _move(int by) {
    final i = skillLevelUpSteps.indexOf(value) + by;
    if (i >= 0 && i < skillLevelUpSteps.length) onChanged(skillLevelUpSteps[i]);
  }

  @override
  Widget build(BuildContext context) {
    final index = skillLevelUpSteps.indexOf(value);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      key: const Key('skill-step'),
      label: '한 번에 올릴 레벨',
      value: '×$value',
      increasedValue: index + 1 < skillLevelUpSteps.length ? '×${skillLevelUpSteps[index + 1]}' : null,
      decreasedValue: index > 0 ? '×${skillLevelUpSteps[index - 1]}' : null,
      onIncrease: index + 1 < skillLevelUpSteps.length ? () => _move(1) : null,
      onDecrease: index > 0 ? () => _move(-1) : null,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -50) _move(1);
          if (v > 50) _move(-1);
        },
        child: Container(
          width: width,
          height: rowHeight * 3 + 4,
          decoration: BoxDecoration(
              color: Cozy.cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.wood, width: 2)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(children: [
              Positioned(
                  left: 0,
                  right: 0,
                  top: rowHeight,
                  height: rowHeight,
                  child: Container(color: Cozy.honey)),
              AnimatedPositioned(
                duration: still ? Duration.zero : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: rowHeight * (1 - index),
                child: Column(children: [
                  for (final step in skillLevelUpSteps)
                    GestureDetector(
                      key: Key('step-$step'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(step),
                      child: SizedBox(
                        height: rowHeight,
                        child: Center(
                          child: Text('×$step',
                              style: TextStyle(
                                  fontSize: step == value ? 13 : 10.5,
                                  height: 1,
                                  fontWeight: step == value ? FontWeight.w900 : FontWeight.w700,
                                  color: step == value ? Cozy.ink : Cozy.inkSoft)),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
