import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../development_balance.dart';
import '../workshop_controller.dart';
import 'center_toast.dart';
import 'cozy_style.dart';
import 'piping_bag_control.dart' show fillingPasteColor;
import 'pixel_sprites.dart';

/// The flavor of the special bungeoppang (26번 3차 피드백 H26): chosen when
/// baking starts, not a small drop-down under the HUD. The round button at
/// the HUD's top-left (where the menu button was, H28) shows the flavor in
/// the mold — its filling as a round swatch with the name under it — and
/// opens [showFlavorPicker] before opening (practice). While a practice
/// bake is on before opening it shows that bake's flavor and cannot change.
/// 4차 병합 3 사용자 결정: in business it shows the flavor production uses
/// (taps, auto, a '특제 <맛>' for the mold and the six cells) and can change
/// it any time, even with an order's bake in the mold (which keeps its own
/// flavor and the portion it took).
class WorkshopFlavorButton extends StatelessWidget {
  final WorkshopController controller;
  const WorkshopFlavorButton({super.key, required this.controller});

  /// The round button's side (the settings button's size).
  static const size = 48.0;

  @override
  Widget build(BuildContext context) {
    final c = controller, s = c.state, session = s.session;
    final open = s.business.open;
    // Before opening with a practice bake in the mold: that bake's flavor.
    final baking = session != null && !open;
    final flavor = baking ? session.flavor : s.selectedFlavor;
    // 재료 타이쿤 B: '특제 팥' while the 특제 choice is on (not for a practice bake).
    final premium = !baking && s.selectedPremium;
    final label = premium ? '특제 ${c.flavorLabel(flavor)}' : c.flavorLabel(flavor);
    final enabled = !baking && !c.inputBusy && !c.gameplayPaused && c.error == null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: baking ? '만드는 맛 $label' : '맛 고르기, 지금 $label',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('flavor-button'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (enabled) {
            showFlavorPicker(context, c);
          } else if (baking) {
            showCenterToast(context, '만드는 중에는 맛을 바꿀 수 없어요.');
          }
        },
        // Exactly the settings button's square, so the HUD row keeps its
        // height: the name tag overlaps the swatch's lower rim.
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
            FlavorSwatch(flavor: flavor, size: size - 6, premium: premium),
            Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                      color: Cozy.cream,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))]),
                  child: Text(label,
                      key: const Key('flavor-label'),
                      maxLines: 1,
                      style: const TextStyle(
                          fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 12, color: Cozy.ink, height: 1.2)),
                )),
          ]),
        ),
      ),
    );
  }
}

/// A flavor's filling (mold/paint_<flavor>.png, or its flat colour) in a
/// round frame.
class FlavorSwatch extends StatelessWidget {
  final String flavor;
  final double size;
  final bool dim;
  /// 특제 (재료 타이쿤 B): a gold rim and a small gold star (code-drawn
  /// until the art of order 62 comes).
  final bool premium;
  const FlavorSwatch({super.key, required this.flavor, this.size = 48, this.dim = false, this.premium = false});
  static const gold = Color(0xFFE0A526);
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Cozy.cream,
              border: Border.all(color: premium ? gold : Cozy.cream, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))]),
          child: ClipOval(
            child: Opacity(
              opacity: dim ? .35 : 1,
              child: CustomPaint(painter: _PastePainter(flavor)),
            ),
          ),
        ),
        if (premium)
          Positioned(
              right: -size * .06,
              top: -size * .06,
              child: Icon(Icons.star_rounded, key: const Key('flavor-premium-star'), size: size * .38, color: gold,
                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1))])),
      ]);
}

class _PastePainter extends CustomPainter {
  final String flavor;
  _PastePainter(this.flavor);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = fillingPasteColor(flavor));
    final texture = PixelSprites.fillingTexture(flavor);
    if (texture != null) {
      // About a fifth of the tile across the swatch: a few beans or swirls.
      final k = size.width / (texture.width * .45);
      canvas.save();
      canvas.scale(k);
      canvas.drawImageRect(texture, Rect.fromLTWH(0, 0, texture.width * .45, texture.height * .45),
          Rect.fromLTWH(0, 0, texture.width * .45, texture.height * .45),
          Paint()..filterQuality = ui.FilterQuality.medium);
      canvas.restore();
    }
    // A soft top light, so it reads as a round button.
    canvas.drawCircle(Offset(size.width * .35, size.height * .3), size.width * .32,
        Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .35), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset(size.width * .35, size.height * .3), radius: size.width * .32)));
  }

  @override
  bool shouldRepaint(_PastePainter old) => old.flavor != flavor;
}

/// The flavors to choose from: every flavor of `active_recipes`, owned ones
/// first; ones not owned yet show what opens them (their recipe mission).
List<(String, String?)> flavorChoices(WorkshopController c) {
  final catalog = c.config.section('active_recipes');
  final tiers = c.config.rows('additional_recipe_acquisition_tiers');
  final owned = [for (final f in catalog.keys) if (c.state.recipes.contains(f)) (f, null)];
  final locked = <(String, String?)>[];
  for (final f in catalog.keys) {
    if (c.state.recipes.contains(f)) continue;
    final tier = DevelopmentBalance.integer(catalog[f] as Map<String, dynamic>, 'acquisition_tier');
    final rule = tiers.where((r) => r['tier'] == tier).firstOrNull;
    locked.add((f, rule == null ? '레시피 미션' : 'Lv.${rule['unlock_level']} 레시피 미션'));
  }
  return [...owned, ...locked];
}

/// The picker's tiles (재료 타이쿤 B): (flavor, 특제, lock). '특제 <맛>'
/// follows its flavor while that 특제 filling is in stock
/// ([WorkshopController.premiumFlavors]).
List<(String, bool, String?)> premiumChoices(WorkshopController c) {
  final premium = c.premiumFlavors;
  return [
    for (final (flavor, lock) in flavorChoices(c)) ...[
      (flavor, false, lock),
      if (lock == null && premium.contains(flavor)) (flavor, true, null),
    ],
  ];
}

/// Asks which flavor to bake (26번 3차 피드백 H26) and selects it. Returns
/// the chosen flavor, or null when the window is closed without one.
Future<String?> showFlavorPicker(BuildContext context, WorkshopController c, {String title = '어떤 붕어빵을 만들까요?'}) async {
  final chosen = await showDialog<(String, bool)>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => Dialog(
            key: const Key('flavor-picker'),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                  color: Cozy.cream,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 19, color: Cozy.ink)),
                const SizedBox(height: 14),
                Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 12, children: [
                  for (final (flavor, premium, lock) in premiumChoices(c))
                    Semantics(
                      button: true,
                      enabled: lock == null,
                      label: lock == null
                          ? '${premium ? '특제 ' : ''}${c.flavorLabel(flavor)} 붕어빵'
                          : '${c.flavorLabel(flavor)}, 잠김, $lock',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: Key(premium ? 'flavor-pick-premium-$flavor' : 'flavor-pick-$flavor'),
                        behavior: HitTestBehavior.opaque,
                        onTap: lock == null
                            ? () => Navigator.pop(ctx, (flavor, premium))
                            : () => showCenterToast(ctx, '${c.flavorLabel(flavor)}: $lock에서 받아요'),
                        child: SizedBox(
                          width: 76,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: flavor == c.state.selectedFlavor && premium == c.state.selectedPremium &&
                                                lock == null
                                            ? Cozy.honeyDeep
                                            : Colors.transparent,
                                        width: 3)),
                                child: FlavorSwatch(flavor: flavor, size: 56, dim: lock != null, premium: premium),
                              ),
                              if (lock != null)
                                const Positioned(right: 2, top: 2, child: Icon(Icons.lock, size: 18, color: Cozy.woodDark)),
                            ]),
                            const SizedBox(height: 4),
                            Text(premium ? '특제 ${c.flavorLabel(flavor)}' : c.flavorLabel(flavor),
                                style: TextStyle(
                                    fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16,
                                    color: lock == null ? Cozy.ink : Cozy.inkSoft)),
                            if (lock != null)
                              Text(lock, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, color: Cozy.inkSoft, height: 1.2)),
                          ]),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                TextButton(
                    key: const Key('flavor-picker-close'),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('닫기', style: TextStyle(color: Cozy.inkSoft))),
              ]),
            ),
          ));
  if (chosen == null) return null;
  final (flavor, premium) = chosen;
  if ((flavor != c.state.selectedFlavor || premium != c.state.selectedPremium) &&
      !await c.selectFlavor(flavor, premium: premium)) {
    return null;
  }
  return flavor;
}
