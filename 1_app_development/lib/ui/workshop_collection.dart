import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import 'cozy_style.dart';
import 'share_card_view.dart' show ShareFishPainter;

/// One flavor's page of 도감 (3차 피드백 H32).
class CollectionFlavor {
  final String id, label;
  /// Whether the player has the recipe; others show how to get it.
  final bool owned;
  /// Doneness indexes found (0~4, [provisionalDonenessLabels]).
  final Set<int> found;
  final int practices, practicesRequired, techniques, techniquesRequired;
  final bool mastered;
  /// How a recipe not owned yet is found ('레시피 미션 · Lv.8').
  final String? howToGet;
  const CollectionFlavor({required this.id, required this.label, required this.owned, required this.found,
      this.practices = 0, this.practicesRequired = 0, this.techniques = 0, this.techniquesRequired = 0,
      this.mastered = false, this.howToGet});
  bool get complete => found.length >= provisionalDonenessLabels.length;
}

/// 붕어빵 도감: per flavor, the five donenesses as pictures (found in
/// colour, not yet as a '?' shadow), the count and the mastery progress.
/// Before it opens ([lockText]) the same pages show dimmed under the note,
/// so the player sees what is coming.
class WorkshopCollectionView extends StatelessWidget {
  final List<CollectionFlavor> flavors;
  final String? lockText;
  final void Function(String flavor)? onShare;
  /// More below the pages (customer records, stories).
  final List<Widget> extra;
  const WorkshopCollectionView({super.key, required this.flavors, this.lockText, this.onShare, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    final pages = Column(children: [
      for (final f in flavors) Padding(padding: const EdgeInsets.only(bottom: 10), child: _FlavorCard(f, onShare: lockText == null ? onShare : null)),
    ]);
    return ListView(key: const Key('collection-scroll'), padding: const EdgeInsets.fromLTRB(14, 6, 14, 14), children: [
      if (lockText case final lock?) ...[
        Container(
          key: const Key('collection-locked'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xfffff3cf), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.lock_rounded, size: 20, color: Cozy.woodLight),
            const SizedBox(width: 8),
            Expanded(child: Text(lock, style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 16, color: Cozy.ink))),
          ]),
        ),
        const SizedBox(height: 10),
        Opacity(opacity: .55, child: IgnorePointer(child: pages)),
      ] else
        pages,
      ...extra,
    ]);
  }
}

class _FlavorCard extends StatelessWidget {
  final CollectionFlavor f;
  final void Function(String flavor)? onShare;
  const _FlavorCard(this.f, {this.onShare});

  @override
  Widget build(BuildContext context) {
    final total = provisionalDonenessLabels.length;
    return Container(
      key: Key('collection-${f.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f.complete ? Cozy.honeyDeep : Cozy.tan, width: f.complete ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${f.label} 붕어빵',
              style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 19, color: Cozy.ink))),
          if (f.owned)
            Text('${f.found.length}/$total 찾음', key: Key('collection-${f.id}-count'),
                style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: Cozy.inkSoft))
          else
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 16, color: Cozy.inkSoft),
              SizedBox(width: 2),
              Text('아직 없는 맛', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: Cozy.inkSoft)),
            ]),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _Doneness(index: i, found: f.owned && f.found.contains(i), key: Key('collection-${f.id}-$i'))),
          ],
        ]),
        const SizedBox(height: 8),
        if (!f.owned)
          Text(f.howToGet ?? '레시피를 얻으면 열려요.', style: const TextStyle(fontSize: 13, color: Cozy.inkSoft))
        else if (f.mastered)
          const Text('숙련 완료 · 숙련된 붕어빵을 만들 수 있어요', style: TextStyle(fontSize: 13, color: Color(0xff3f9b5a), fontWeight: FontWeight.w700))
        else
          Row(key: Key('mastery-${f.id}'), children: [
            Expanded(child: _Progress('연습', f.practices, f.practicesRequired)),
            const SizedBox(width: 12),
            Expanded(child: _Progress('손기술', f.techniques, f.techniquesRequired)),
          ]),
        if (f.complete && onShare != null) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: CozyButton(key: Key('collection-share-${f.id}'),
              minHeight: 34, fontSize: 14, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              icon: const Icon(Icons.ios_share_rounded, size: 16, color: Cozy.ink),
              label: '도감 완성 자랑하기', onPressed: () => onShare!(f.id))),
        ],
      ]),
    );
  }
}

class _Doneness extends StatelessWidget {
  final int index;
  final bool found;
  const _Doneness({super.key, required this.index, required this.found});
  @override
  Widget build(BuildContext context) {
    Widget fish = CustomPaint(painter: ShareFishPainter(variant: index));
    if (!found) {
      fish = ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x33a07850), BlendMode.srcIn), child: fish);
    }
    return Column(children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: found ? Colors.white : const Color(0xfff6ead8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: found ? Cozy.tan : const Color(0xffeedcc4)),
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(child: fish),
            if (!found)
              const Text('?', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 18, color: Color(0xffb89878))),
          ]),
        ),
      ),
      const SizedBox(height: 3),
      FittedBox(fit: BoxFit.scaleDown, child: Text(provisionalDonenessLabels[index], maxLines: 1,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: found ? Cozy.ink : const Color(0xffb89878)))),
    ]);
  }
}

class _Progress extends StatelessWidget {
  final String label;
  final int current, required;
  const _Progress(this.label, this.current, this.required);
  @override
  Widget build(BuildContext context) {
    final shown = current > required ? required : current;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label $shown/$required', style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: required <= 0 ? 1 : shown / required, minHeight: 6,
          backgroundColor: const Color(0xfff3e4cf), color: Cozy.tangerine)),
    ]);
  }
}
