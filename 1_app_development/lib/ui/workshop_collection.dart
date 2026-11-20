import 'package:flutter/material.dart';
import '../cooking_result_rules.dart';
import 'cozy_style.dart';
import 'share_card_view.dart' show ShareFishPainter;

/// One flavor's page of 도감 (3차 피드백 H32, 4차 피드백 g6).
class CollectionFlavor {
  final String id, label;
  /// Whether the player has the recipe; others show how to get it.
  final bool owned;
  /// Doneness indexes found (0~4, [provisionalDonenessLabels]): baked at
  /// least once, and 팥 미디엄 known from the start.
  final Set<int> found;
  /// Special-mold bakes of each doneness, and how many complete a cell.
  final List<int> counts, required;
  /// The title the collected flavor gives ('팥 장인'), or null.
  final String? title;
  /// Mastered under the old rule (an older save): the griddle stays open.
  final bool legacyMastered;
  /// How a recipe not owned yet is found ('레시피 미션 · Lv.8').
  final String? howToGet;
  const CollectionFlavor({required this.id, required this.label, required this.owned, required this.found,
      this.counts = const [0, 0, 0, 0, 0], this.required = const [1, 1, 1, 1, 1], this.title,
      this.legacyMastered = false, this.howToGet});
  bool cellComplete(int i) => counts[i] >= required[i];
  int get completedCells => [for (var i = 0; i < required.length; i++) if (cellComplete(i)) i].length;
  /// All five cells complete: the six-cell griddle bakes this flavor.
  bool get complete => owned && completedCells >= provisionalDonenessLabels.length;
}

/// 붕어빵 도감: per flavor, the five donenesses as pictures (found in
/// colour, not yet as a '?' shadow), each with its bakes counted to the
/// number that completes it (gold frame), and '완성 n/5'. Before it opens
/// ([lockText]) the same pages show dimmed under the note, so the player
/// sees what is coming. [titles] (collected flavors) head the page.
class WorkshopCollectionView extends StatelessWidget {
  final List<CollectionFlavor> flavors;
  final String? lockText;
  final List<String> titles;
  final void Function(String flavor)? onShare;
  /// More below the pages (customer records, stories).
  final List<Widget> extra;
  const WorkshopCollectionView({super.key, required this.flavors, this.lockText, this.titles = const [],
      this.onShare, this.extra = const []});

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
      ] else ...[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            titles.isEmpty ? '익힘마다 정해진 횟수를 구우면 칸이 완성돼요.' : '칭호 · ${titles.join(' · ')}',
            key: const Key('collection-titles'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: titles.isEmpty ? Cozy.inkSoft : const Color(0xffa86a00))),
        ),
        pages,
      ],
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
            Text('완성 ${f.completedCells}/$total', key: Key('collection-${f.id}-count'),
                style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14,
                    color: f.complete ? const Color(0xffa86a00) : Cozy.inkSoft))
          else
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 16, color: Cozy.inkSoft),
              SizedBox(width: 2),
              Text('아직 없는 맛', style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 14, color: Cozy.inkSoft)),
            ]),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _Doneness(index: i, found: f.owned && f.found.contains(i),
                count: f.owned ? f.counts[i] : 0, required: f.required[i], complete: f.owned && f.cellComplete(i),
                key: Key('collection-${f.id}-$i'))),
          ],
        ]),
        const SizedBox(height: 8),
        if (!f.owned)
          Text(f.howToGet ?? '레시피를 얻으면 열려요.', style: const TextStyle(fontSize: 13, color: Cozy.inkSoft))
        else if (f.complete)
          Text('도감 완성 · 「${f.title ?? f.label}」 · 숙련된 붕어빵 틀 열림',
              key: Key('collection-${f.id}-done'),
              style: const TextStyle(fontSize: 13, color: Color(0xff3f9b5a), fontWeight: FontWeight.w700))
        else if (f.legacyMastered)
          const Text('숙련 완료 · 숙련된 붕어빵 틀에서 구울 수 있어요',
              style: TextStyle(fontSize: 13, color: Color(0xff3f9b5a), fontWeight: FontWeight.w700))
        else
          Text('다섯 칸을 완성하면 숙련된 붕어빵 틀이 열려요.', key: Key('collection-${f.id}-goal'),
              style: const TextStyle(fontSize: 13, color: Cozy.inkSoft)),
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
  final int index, count, required;
  final bool found, complete;
  const _Doneness({super.key, required this.index, required this.found, required this.count,
      required this.required, required this.complete});
  @override
  Widget build(BuildContext context) {
    Widget fish = CustomPaint(painter: ShareFishPainter(variant: index));
    if (!found) {
      fish = ColorFiltered(colorFilter: const ColorFilter.mode(Color(0x33a07850), BlendMode.srcIn), child: fish);
    }
    final shown = count > required ? required : count;
    return Column(children: [
      AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: complete ? const Color(0xfffff6dc) : found ? Colors.white : const Color(0xfff6ead8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: complete ? Cozy.honeyDeep : found ? Cozy.tan : const Color(0xffeedcc4),
                width: complete ? 2 : 1),
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
      FittedBox(fit: BoxFit.scaleDown, child: Text(complete ? '완성' : '$shown/$required', maxLines: 1,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: complete ? const Color(0xffa86a00) : found ? Cozy.inkSoft : const Color(0xffc8ac90)))),
    ]);
  }
}
