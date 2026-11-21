import 'package:flutter/material.dart';
import '../balance.dart';
import '../development_balance.dart';
import '../development_rules.dart';
import '../economy.dart';
import '../game_controller.dart';
import '../models.dart';
import '../online_texts.dart';
import '../workshop_controller.dart';
import 'center_toast.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'lock_overlay.dart';
import 'pixel_sprites.dart';

/// The Workshop skill window (26번 4-3단계, F12~F19): a list of skills to
/// level up, not things to buy. Two tabs (클릭 생산·자동 생산) share one
/// layout. Each row: picture, name, 'Lv.12/1000 · +60/클릭' (one level's
/// effect), the price of the chosen step, the skill's own small wheel that
/// picks how many levels one press adds (×1·×10·×100, [skillLevelUpSteps];
/// 시안 확인 2차: one wheel per skill, remembered in
/// [WorkshopController.skillSteps] while the app runs) and a 'LEVEL UP'
/// button that is lit only when the level-up can go through. A dark button
/// still answers with the reason. Of the locked skills only the next one
/// shows, as a silhouette under the padlock with its condition.
class WorkshopSkillShop extends StatefulWidget {
  final WorkshopController controller;
  final GameController account;
  const WorkshopSkillShop({super.key, required this.controller, required this.account});
  @override
  State<WorkshopSkillShop> createState() => _WorkshopSkillShopState();
}

class _WorkshopSkillShopState extends State<WorkshopSkillShop> {
  UpgradeKind _kind = UpgradeKind.tap;

  /// The height of every skill row, wheel or not (4차 피드백 ID1).
  static const rowHeight = 80.0;

  int _step(String id) => widget.controller.skillSteps[id] ?? skillLevelUpSteps.first;

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
    showCenterToast(context, message);
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
            if (kind != UpgradeKind.values.first) const SizedBox(width: 6),
            Expanded(child: _KindTab(kind: kind, selected: kind == _kind, onTap: () => setState(() => _kind = kind))),
          ],
        ]),
      ),
      Expanded(
        child: ListView(key: ValueKey('skills-${_kind.name}'), padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), children: [
          // 4차 피드백 IC10: a build without the online settings says so
          // (it is not the phone's connection).
          if (c.purchaseGateway == null)
            CozyPanel(
                key: const Key('skill-setup-note'),
                child: const Text(OnlineTexts.skillNotSetUp, textAlign: TextAlign.center)),
          // Before the login (a test build's local purchases need none).
          if (c.purchaseGateway != null && c.purchaseGateway!.authenticatedAccount.isEmpty)
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
                    onPressed: c.purchaseGateway == null || c.purchaseBusy || c.inputBusy
                        ? null
                        : () => c.recoverPurchase(c.purchaseGateway!, journal.transactionId),
                    child: const Text('복구')),
                TextButton(
                    onPressed: c.purchaseGateway == null || c.purchaseBusy || c.inputBusy
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
    if (c.purchaseGateway == null) return OnlineTexts.skillNotSetUp;
    if (c.purchaseGateway!.authenticatedAccount.isEmpty) return '카카오 로그인 후 레벨업할 수 있어요.';
    if (c.error != null) return c.error;
    if (c.inputBusy || c.purchaseBusy) return '잠시 뒤에 다시 눌러 주세요.';
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
    final step = _step(id);
    final quantity = skillLevelUpQuantity(step, owned: owned, cap: cap);
    final quote = maxed ? null : quoteCompositeSkill(c.config, id, owned: owned, quantity: quantity);
    final buns = c.state.purchases.available(c.state.buns), gold = BigInt.from(account.state.premium.gold);
    final reason = maxed ? null : _blocked(unlocked: unlocked, id: id, quote: quote, buns: buns, gold: gold);
    final picture = PixelImage(PixelSprites.skill(id), size: 40);
    final unit = _kind == UpgradeKind.tap ? '클릭' : '초';
    // Every row the same height (4차 피드백 ID1): locked and MAX rows have
    // no wheel, so the row is at least [rowHeight], and the lit row's
    // thicker edge comes out of its padding instead of adding to it.
    final edge = reason == null && !maxed ? 2.0 : 1.0;
    return Container(
      key: Key('skill-$id'),
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(minHeight: rowHeight),
      padding: EdgeInsets.fromLTRB(10 - edge, 8 - edge, 8 - edge, 8 - edge),
      decoration: BoxDecoration(
        color: unlocked ? Cozy.cream : Cozy.creamDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: edge > 1 ? Cozy.honeyDeep : Cozy.tan, width: edge),
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
              // Two short lines so the per-skill wheel leaves them room
              // (시안 확인 2차): the level, then one level's effect.
              // 4차 g13: a wide ×100 price at 360 used to break 'Lv.880/1000'
              // into 'Lv.880/100' + '0' and push '+1/클릭' out; the two
              // lines shrink together instead.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Lv.$owned/$cap\n+${compactNumber(DevelopmentBalance.decimal(rule, 'effect'))}/$unit',
                    key: Key('level-$id'),
                    maxLines: 2,
                    softWrap: false,
                    style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w700)),
              )
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
            decoration: BoxDecoration(color: Cozy.honey, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.honeyDeep)),
            child: const Text('MAX', style: TextStyle(fontWeight: FontWeight.w900, color: Cozy.ink)),
          )
        else ...[
          if (unlocked && quote != null)
            // 4차 g7: level prices grow 1.35× now, so ×100 can cost '2602.29조';
            // a long price shrinks to fit instead of pushing the row over
            // (360 wide at text scale 1.5).
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(key: Key('cost-$id'), crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  CurrencyAmount(Currency.buns, quote.buns, missing: quote.buns > buns),
                  // DEC-041: tiers 1~4 ask no gold, so no '황금 0'.
                  if (quote.gold > BigInt.zero) CurrencyAmount(Currency.gold, quote.gold, missing: quote.gold > gold),
                ]),
              ),
            ),
          const SizedBox(width: 6),
          if (unlocked) ...[
            SkillStepWheel(
                key: Key('skill-step-$id'),
                skillId: id,
                value: step,
                onChanged: (next) => setState(() => c.skillSteps[id] = next)),
            const SizedBox(width: 4),
          ],
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

/// The 'LEVEL UP' word button (시안 확인 2차, 25번 33번: `ui/levelup.png`
/// lit / `ui/levelup_off.png` dark, [width] x [height] at the row's height;
/// the art is 3:2). Always pressable: a dark button explains itself through
/// [onPressed]. The step shows on the wheel beside it.
class LevelUpButton extends StatelessWidget {
  final bool enabled;
  final int quantity;
  final VoidCallback onPressed;
  const LevelUpButton({super.key, required this.enabled, required this.quantity, required this.onPressed});

  static const width = 54.0, height = 36.0;

  @override
  Widget build(BuildContext context) {
    final art = PixelSprites.screenArt(enabled ? 'levelup' : 'levelup_off');
    return Semantics(
      button: true,
      enabled: enabled,
      label: quantity > 1 ? '레벨업 $quantity' : '레벨업',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: width,
          height: height + 8,
          child: Center(
            child: art != null
                ? PixelArt(art, width: width, height: height)
                : Container(
                    width: width,
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: enabled ? Cozy.honey : const Color(0xffb7aca5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: enabled ? Cozy.wood : const Color(0xff6f6560), width: 2)),
                    child: const Text('LEVEL\nUP',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w900, color: Cozy.ink)),
                  ),
          ),
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
              // H41: hairlines, no dark outline on the picked tab.
              border: Border.all(color: selected ? Cozy.honeyDeep : Cozy.line),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PixelIcon(kind == UpgradeKind.tap ? 'tab_tap' : 'tab_auto', size: 34),
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

/// A skill's small vertical wheel that picks its level-up step (S43-Q8,
/// one per skill since 시안 확인 2차): a little drum that scrolls. The
/// honey band stays in the middle and the chosen '×10' sits in it with its
/// neighbours above and below; the steps follow the finger while it drags
/// and snap to the nearest step when it lets go (a quick flick moves one
/// step), and a tap on a neighbour picks it. 4차 피드백 g13 brought the
/// scroll back after ID1 had turned it into three fixed cells with a moving
/// band ("전처럼 스크롤 하듯이"); the box keeps one size for every step, so
/// at ×1 or ×100 one end of the drum is simply empty. Keys
/// `step-<skill>-<step>`.
class SkillStepWheel extends StatefulWidget {
  final String skillId;
  final int value;
  final ValueChanged<int> onChanged;
  const SkillStepWheel({super.key, required this.skillId, required this.value, required this.onChanged});

  static const rowHeight = 14.0, width = 40.0;

  /// How far past the first or last step a drag may pull, in rows.
  static const overscroll = 0.35;

  @override
  State<SkillStepWheel> createState() => _SkillStepWheelState();
}

class _SkillStepWheelState extends State<SkillStepWheel> {
  /// The finger's pull in pixels while dragging (down is positive), 0 at rest.
  double _drag = 0;
  bool _dragging = false;

  int get _index => skillLevelUpSteps.indexOf(widget.value);

  /// The step position under the band, in rows: [_index] at rest.
  double get _position {
    final last = skillLevelUpSteps.length - 1.0;
    return (_index - _drag / SkillStepWheel.rowHeight)
        .clamp(-SkillStepWheel.overscroll, last + SkillStepWheel.overscroll)
        .toDouble();
  }

  int get _centered => _position.round().clamp(0, skillLevelUpSteps.length - 1);

  void _pick(int i) {
    if (i >= 0 && i < skillLevelUpSteps.length && i != _index) widget.onChanged(skillLevelUpSteps[i]);
  }

  void _end(DragEndDetails d) {
    var target = _centered;
    // A flick that did not cross half a row still moves one step its way.
    final v = d.primaryVelocity ?? 0;
    if (target == _index && v.abs() > 50) target = _index + (v < 0 ? 1 : -1);
    setState(() {
      _dragging = false;
      _drag = 0;
    });
    _pick(target.clamp(0, skillLevelUpSteps.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final index = _index, h = SkillStepWheel.rowHeight, centered = _centered;
    final still = _dragging || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return Semantics(
      label: '한 번에 올릴 레벨',
      value: '×${widget.value}',
      increasedValue: index + 1 < skillLevelUpSteps.length ? '×${skillLevelUpSteps[index + 1]}' : null,
      decreasedValue: index > 0 ? '×${skillLevelUpSteps[index - 1]}' : null,
      onIncrease: index + 1 < skillLevelUpSteps.length ? () => _pick(index + 1) : null,
      onDecrease: index > 0 ? () => _pick(index - 1) : null,
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (d) => setState(() => _drag += d.primaryDelta ?? 0),
        onVerticalDragEnd: _end,
        onVerticalDragCancel: () => setState(() {
          _dragging = false;
          _drag = 0;
        }),
        child: Container(
          width: SkillStepWheel.width,
          height: h * 3 + 4,
          decoration: BoxDecoration(
              color: Cozy.cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: Cozy.woodLight, width: 1.5)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(children: [
              Positioned(left: 0, right: 0, top: h, height: h, child: Container(color: Cozy.honey)),
              AnimatedPositioned(
                duration: still ? Duration.zero : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: h * (1 - _position),
                child: Column(children: [
                  for (final (i, step) in skillLevelUpSteps.indexed)
                    GestureDetector(
                      key: Key('step-${widget.skillId}-$step'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pick(i),
                      child: SizedBox(
                        height: h,
                        child: Center(
                          child: Text('×$step',
                              style: TextStyle(
                                  fontSize: i == centered ? 12 : 9.5,
                                  height: 1,
                                  fontWeight: i == centered ? FontWeight.w900 : FontWeight.w700,
                                  color: i == centered ? Cozy.ink : Cozy.inkSoft)),
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
