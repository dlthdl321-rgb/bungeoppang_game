import 'package:flutter/material.dart';
import '../billing_service.dart';
import '../game_controller.dart';
import '../online_texts.dart';
import '../premium_config.dart';
import '../usage_stats.dart';
import '../economy.dart' show exactNumber;
import 'center_toast.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// The shop's 충전 tab: balance, the packs with Google Play prices, the
/// and the legally required purchase notes.
class GoldChargeTab extends StatefulWidget {
  final GameController controller;

  /// A build without the online settings (4차 피드백 IC10 후속): a free
  /// '시험용 황금 +10' button, clearly test-only, instead of the login note.
  final bool localTestGold;
  const GoldChargeTab({super.key, required this.controller, this.localTestGold = false});
  @override
  State<GoldChargeTab> createState() => _GoldChargeTabState();
}

class _GoldChargeTabState extends State<GoldChargeTab> {
  late final Future<List<StoreProduct>> _packs =
      widget.controller.goldPacks();

  @override
  void initState() {
    super.initState();
    // 사용 통계(26번 5단계): the charge tab was opened, once a day.
    widget.controller.usage.record(UsageEvent.payView);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // 26번 3차 피드백 H31: a gold balance card, then one clean card per
    // pack (its picture, the amount large, the Play price as a honey pill)
    // instead of beige boxes with '황금붕어빵력 N개' and a pale button.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CozyPanel(
          tone: CozyTone.reward,
          radius: 16,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            const PixelIcon('gold_bun', size: 34),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('보유 $goldName',
                    style: TextStyle(fontSize: 14, color: Cozy.inkSoft))),
            Text('${c.state.premium.gold}개',
                key: const Key('gold-balance'),
                style: const TextStyle(
                    fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 24, color: Cozy.ink)),
          ])),
      if (c.premiumNotice case final notice?)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CozyNotice(notice, key: const Key('gold-notice'), tone: CozyTone.success)),
      if (widget.localTestGold)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CozyPanel(
                key: const Key('gold-test'),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text(OnlineTexts.testGoldNote,
                      style: TextStyle(fontSize: 12, color: Cozy.brick, height: 1.35)),
                  const SizedBox(height: 6),
                  CozyPrimaryButton(
                      key: const Key('gold-test-add'),
                      minHeight: 38,
                      fontSize: 15,
                      label: OnlineTexts.testGoldButton,
                      onPressed: () async {
                        final ok = await c.setLocalTestGold(c.state.premium.gold + 10);
                        if (ok && context.mounted) showCenterToast(context, OnlineTexts.testGoldDone);
                      }),
                ])))
      else if (!c.online.signedIn)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: CozyNotice('로그인하면 충전할 수 있어요', key: Key('gold-offline'))),
      const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text('$goldName 쓰는 곳: 꾸미기(옷·모자·머리·도구)와 높은 단계 스킬. '
                '낮은 단계 스킬은 붕어빵력만으로 레벨업해요.',
                key: Key('gold-uses'),
                style: TextStyle(color: Cozy.inkSoft, fontSize: 12, height: 1.35))),
      const SizedBox(height: 10),
      FutureBuilder<List<StoreProduct>>(
          future: _packs,
          builder: (context, snap) {
            final packs = {for (final p in snap.data ?? const []) p.id: p};
            final loading = snap.connectionState != ConnectionState.done;
            return Column(children: [
              for (final (tier, p) in goldProducts.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GoldPackCard(
                    tier: tier + 1,
                    gold: p.gold,
                    button: CozyPrimaryButton(
                        key: Key('gold-pack-${p.id}'),
                        minHeight: 40,
                        fontSize: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        onPressed: packs[p.id] == null
                            ? null
                            : () async {
                                final error = await c.buyGoldPack(p.id);
                                if (error != null && context.mounted) {
                                  showCenterToast(context, error);
                                }
                              },
                        label: packs[p.id]?.price ?? (loading ? '불러오는 중' : '구매할 수 없음')),
                  ),
                ),
            ]);
          }),
      const SizedBox(height: 8),
      Text(
          '· 결제는 Google Play로 처리돼요. 구매 후 사용하지 않은 $goldName은 '
          '구매일로부터 7일 안에 청약철회를 요청할 수 있어요.\n'
          '· 미성년자는 법정대리인의 동의 없이 결제하면 취소될 수 있어요.\n'
          '· $goldName 잔액은 로그인한 카카오 계정에 보관돼요.',
          key: const Key('gold-terms'),
          style: const TextStyle(color: Cozy.caption, fontSize: 11, height: 1.4)),
    ]);
  }
}

/// One gold pack in the charge tab (H31): its picture on a gold tile, the
/// amount large and [button] (the Play price) at the right.
class GoldPackCard extends StatelessWidget {
  /// 1 (smallest) to 5: which picture.
  final int tier;
  final int gold;
  final Widget button;
  const GoldPackCard({super.key, required this.tier, required this.gold, required this.button});

  @override
  Widget build(BuildContext context) => CozyPanel(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: CozyTone.reward.fill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CozyTone.reward.edge)),
            child: GoldPackArt(tier: tier),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text(goldName, style: TextStyle(fontSize: 12, color: Cozy.inkSoft)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: exactNumber(BigInt.from(gold)),
                    style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 24, color: Cozy.ink)),
                const TextSpan(text: ' 개', style: TextStyle(fontSize: 14, color: Cozy.inkSoft)),
              ])),
            ),
          ])),
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 96, maxWidth: 132), child: button),
        ]),
      );
}

/// A gold pack's picture: `ui/gold_pack_<tier>.png` once drawn (25번
/// 40번), until then a heap of the gold bungeoppang icon that grows with
/// the pack (1 to 5).
class GoldPackArt extends StatelessWidget {
  final int tier;
  const GoldPackArt({super.key, required this.tier});

  static const _spots = [
    [Offset(0, 0)],
    [Offset(-8, 4), Offset(8, -4)],
    [Offset(-10, 6), Offset(10, 6), Offset(0, -6)],
    [Offset(-11, 8), Offset(11, 8), Offset(-6, -6), Offset(8, -7)],
    [Offset(-12, 10), Offset(0, 11), Offset(12, 10), Offset(-6, -4), Offset(7, -5)],
  ];

  @override
  Widget build(BuildContext context) {
    final art = PixelSprites.byPath('ui/gold_pack_$tier.png');
    if (art != null) return Center(child: PixelImage(art, size: 54));
    final at = _spots[(tier - 1).clamp(0, _spots.length - 1)];
    final size = tier == 1 ? 40.0 : tier <= 3 ? 32.0 : 28.0;
    return Stack(alignment: Alignment.center, children: [
      for (final o in at) Transform.translate(offset: o, child: PixelIcon('gold_bun', size: size)),
      if (tier >= 4)
        const Positioned(right: 3, top: 3, child: Icon(Icons.auto_awesome, size: 14, color: Color(0xffe6a800))),
    ]);
  }
}
