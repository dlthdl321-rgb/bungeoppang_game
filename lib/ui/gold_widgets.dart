import 'package:flutter/material.dart';
import '../billing_service.dart';
import '../game_controller.dart';
import '../online_backend.dart';
import '../premium_config.dart';
import '../support_config.dart';
import 'cozy_style.dart';
import 'support_panels.dart' show confirmAction;

/// Asks, spends gold on [itemId] through the server and reports the result.
Future<void> buyWithGold(BuildContext context, GameController c,
    PremiumKind kind, String itemId, String title, String effect) async {
  final price = c.goldPrice(kind, itemId);
  if (price == null) return;
  final gold = c.state.premium.gold;
  if (!await confirmAction(
      context,
      title,
      '$goldName $price개\n보유 $gold → ${gold - price}개\n$effect',
      '구매')) {
    return;
  }
  final error = await c.spendGold(kind, itemId);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? '$title 완료')));
  }
}

/// A small '황금 N' button for anything also sold for gold.
class GoldPriceButton extends StatelessWidget {
  final GameController controller;
  final PremiumKind kind;
  final String itemId, title, effect;
  const GoldPriceButton(
      {super.key,
      required this.controller,
      required this.kind,
      required this.itemId,
      required this.title,
      required this.effect});

  @override
  Widget build(BuildContext context) {
    final price = controller.goldPrice(kind, itemId);
    if (price == null) return const SizedBox.shrink();
    return OutlinedButton(
        key: Key('gold-${kind.name}-$itemId'),
        style: OutlinedButton.styleFrom(
            foregroundColor: Cozy.wood,
            side: const BorderSide(color: Cozy.orangeDeep)),
        onPressed: controller.busy || !controller.online.configured
            ? null
            : () => buyWithGold(context, controller, kind, itemId, title, effect),
        child: FittedBox(child: Text('황금 $price')));
  }
}

/// The shop's 충전 tab: balance, the packs with Google Play prices, the
/// 10-minute boost for gold and the legally required purchase notes.
class GoldChargeTab extends StatefulWidget {
  final GameController controller;
  const GoldChargeTab({super.key, required this.controller});
  @override
  State<GoldChargeTab> createState() => _GoldChargeTabState();
}

class _GoldChargeTabState extends State<GoldChargeTab> {
  late final Future<List<StoreProduct>> _packs =
      widget.controller.goldPacks();

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final boost = boostOf(BoostKind.bought);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CozyPanel(
          padding: const EdgeInsets.all(10),
          child: Text('보유 $goldName ${c.state.premium.gold}개',
              key: const Key('gold-balance'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      if (c.premiumNotice case final notice?)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(notice, key: const Key('gold-notice'))),
      if (!c.online.configured)
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('결제를 준비 중이에요', key: Key('gold-offline'))),
      const SizedBox(height: 8),
      FutureBuilder<List<StoreProduct>>(
          future: _packs,
          builder: (context, snap) {
            final packs = {for (final p in snap.data ?? const []) p.id: p};
            return Column(children: [
              for (final p in goldProducts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: CozyPanel(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Expanded(
                          child: Text('$goldName ${p.gold}개',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w900))),
                      FilledButton(
                          key: Key('gold-pack-${p.id}'),
                          style: FilledButton.styleFrom(
                              backgroundColor: Cozy.orange,
                              foregroundColor: Cozy.ink),
                          onPressed: packs[p.id] == null
                              ? null
                              : () async {
                                  final error = await c.buyGoldPack(p.id);
                                  if (error != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error)));
                                  }
                                },
                          child: Text(packs[p.id]?.price ?? '준비 중')),
                    ]),
                  ),
                ),
            ]);
          }),
      const SizedBox(height: 4),
      CozyPanel(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
              child: Text(
                  '${boost.name} · 생산 ${boost.multiplierPermille ~/ 1000}배 ${boost.durationSeconds ~/ 60}분',
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          GoldPriceButton(
              controller: c,
              kind: PremiumKind.boost,
              itemId: BoostKind.bought.name,
              title: boost.name,
              effect:
                  '${boost.durationSeconds ~/ 60}분 동안 클릭·자동 생산 ${boost.multiplierPermille ~/ 1000}배'),
        ]),
      ),
      const SizedBox(height: 10),
      const Text(
          '· 결제는 Google Play로 처리돼요. 구매 후 사용하지 않은 $goldName은 '
          '구매일로부터 7일 안에 청약철회를 요청할 수 있어요.\n'
          '· 미성년자는 법정대리인의 동의 없이 결제하면 취소될 수 있어요.\n'
          '· $goldName은 이 계정(Google Play 게임즈)에 보관되고, 다시 설치해도 꾸미기와 '
          '스킬 해금은 돌아와요. 이미 쓴 부스트는 돌아오지 않아요.',
          key: Key('gold-terms'),
          style: TextStyle(color: Cozy.inkSoft, fontSize: 11)),
    ]);
  }
}
