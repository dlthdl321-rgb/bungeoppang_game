import 'package:flutter/material.dart';
import '../economy.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

/// One number of '생산 기록' (3차 피드백 H44·H45): an icon, the number big
/// and what it is small.
class RecordTile {
  final String id, icon, label, value;
  /// Icon art drawn with wide margins shows bigger.
  final double iconSize;
  const RecordTile(this.id, this.icon, this.label, this.value, {this.iconSize = 32});
}

/// '생산 기록' (was '통계'): the device's numbers as icon + number tiles,
/// two across, so they read at a glance (H45).
class WorkshopRecordsView extends StatelessWidget {
  final List<RecordTile> tiles;
  const WorkshopRecordsView({super.key, required this.tiles});

  /// The usual tiles from the Workshop's state.
  static List<RecordTile> of({required int level, required BigInt buns, required BigInt lifetime, required int taps,
      required int sales, required BigInt tapRate, required BigInt autoRate, required int mastered, required int businessDays}) => [
        RecordTile('level', 'star', '레벨', 'Lv.$level'),
        RecordTile('buns', 'bun', '붕어빵력', compactNumber(buns), iconSize: 44),
        RecordTile('lifetime', 'records', '누적 생산', compactNumber(lifetime)),
        RecordTile('taps', 'tab_tap', '누적 탭', compactNumber(BigInt.from(taps))),
        RecordTile('sales', 'coin', '판매 횟수', '$sales번', iconSize: 44),
        RecordTile('tap-rate', 'skill', '클릭당 생산', compactNumber(tapRate), iconSize: 48),
        RecordTile('auto-rate', 'time_clock', '초당 생산', compactNumber(autoRate)),
        RecordTile('mastered', 'title', '숙련한 맛', '$mastered가지'),
        RecordTile('days', 'prestige', '영업한 날', '$businessDays일'),
      ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 10.0, pad = 14.0;
        final width = (box.maxWidth - pad * 2 - gap) / 2;
        return SingleChildScrollView(
          key: const Key('records-scroll'),
          padding: const EdgeInsets.fromLTRB(pad, 6, pad, pad),
          child: Wrap(spacing: gap, runSpacing: gap, children: [
            for (final t in tiles) SizedBox(width: width, child: _Tile(t)),
          ]),
        );
      });
}

class _Tile extends StatelessWidget {
  final RecordTile tile;
  const _Tile(this.tile);
  @override
  Widget build(BuildContext context) => Container(
        key: Key('record-${tile.id}'),
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xfffffaf0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Cozy.tan),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xfffff0d6), borderRadius: BorderRadius.circular(12)),
            child: OverflowBox(maxWidth: 60, maxHeight: 60, child: PixelIcon(tile.icon, size: tile.iconSize)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(tile.value, key: Key('record-${tile.id}-value'), maxLines: 1,
                    style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 22, color: Cozy.ink))),
            Text(tile.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Cozy.inkSoft, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}
