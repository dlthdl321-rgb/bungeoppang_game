import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../pantry_rules.dart';
import '../workshop_controller.dart';
import '../workshop_pantry_prep.dart';
import 'cozy_style.dart';
import 'currency_amount.dart';
import 'pixel_sprites.dart' show PixelSprites;
import 'prep_art.dart';
import 'prep_minigames.dart';

/// '재료 준비' 창 (재료 타이쿤 D, 설계안 7장; 영업 준비 중에만 열림 —
/// WorkshopPage `_open('pantry')`): tabs for the batter and every owned
/// recipe's filling; for the picked one the stock bar (tubs / limit and
/// when the oldest tub goes off), the ingredients needed against those
/// owned (red when short), 1·3·5 tubs, 특제 when its special ingredient is
/// owned, '모자란 재료 한 번에 사기' and '만들기' → the mini-game
/// ([PrepGameScreen]) over everything → result → back here.
class PantryWindow extends StatefulWidget {
  final WorkshopController controller;
  final bool reduceMotion, vibration;
  const PantryWindow({super.key, required this.controller, this.reduceMotion = false, this.vibration = false});

  @override
  State<PantryWindow> createState() => PantryWindowState();
}

class PantryWindowState extends State<PantryWindow> {
  /// `makeBlocker`'s words for missing basic ingredients (the buy button
  /// and its line say it instead).
  static const _shortText = '재료가 모자라요.';
  String _kind = 'batter';
  int _tubs = 1;
  bool _premium = false;

  WorkshopController get c => widget.controller;
  PantryConfig get pc => c.pantryConfig;
  PantryState get pantry => c.state.pantry;
  int get _nowMs => c.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _tubs = pc.batchTubs.first;
    PrepArt.loaded.addListener(_artIn);
    PrepArt.load();
  }

  void _artIn() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PrepArt.loaded.removeListener(_artIn);
    super.dispose();
  }

  List<PreparedKind> get _kinds =>
      [for (final k in pc.prepared.values) if (pantry.preparedVisible(pc, k.id, c.state.recipes)) k];

  /// The tab's short name: the first word ('초코 크림' → '초코').
  static String tabLabel(PreparedKind k) => k.label.split(' ').first;

  bool get _premiumOffered {
    final k = pc.kind(_kind);
    return pantry.premiumVisible(pc, c.state.level) && (pantry.premium[k.premiumIngredient] ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    final kinds = _kinds;
    if (!kinds.any((k) => k.id == _kind)) _kind = kinds.first.id;
    final kind = pc.kind(_kind);
    final premium = _premium && _premiumOffered;
    final nowMs = _nowMs;
    final level = c.state.level;
    final shortfall = pantry.shortfall(pc, kind.id, _tubs);
    final cost = c.prepShortfallCost(kind.id, _tubs);
    final blocker = pantry.makeBlocker(pc, kind.id, _tubs, level, nowMs, c.state.recipes, premium: premium);
    final busy = c.inputBusy;
    return SingleChildScrollView(
      key: const Key('pantry-window'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CozyTabBar<String>(
          key: const Key('pantry-tabs'),
          tabs: [for (final k in kinds) CozyTab(k.id, tabLabel(k), key: Key('pantry-tab-${k.id}'))],
          selected: _kind,
          onSelected: (v) => setState(() {
            _kind = v;
            _premium = false;
          }),
        ),
        const SizedBox(height: 10),
        _stock(kind, level, nowMs),
        const SizedBox(height: 10),
        _section('통 수'),
        CozyTabBar<int>(
          key: const Key('pantry-tubs'),
          height: 38,
          tabs: [for (final n in pc.batchTubs) CozyTab(n, '$n통', key: Key('pantry-tubs-$n'))],
          selected: _tubs,
          onSelected: (v) => setState(() => _tubs = v),
        ),
        const SizedBox(height: 10),
        _section('$_tubs통에 드는 재료'),
        _ingredients(kind, premium),
        if (_premiumOffered) ...[
          const SizedBox(height: 8),
          CozySettingRow(
            key: const Key('pantry-premium'),
            icon: _icon(PrepArt.ingredientIcon[kind.premiumIngredient], 28, pc.premium[kind.premiumIngredient]!.label),
            label: '${kind.premiumLabel}${_toward(kind.premiumLabel)} 만들기',
            subtitle: '${pc.premium[kind.premiumIngredient]!.label} 1통에 1개, 붕어빵력 +${pc.premiumBonusPermille ~/ 10}%',
            value: _premium,
            onChanged: (v) => setState(() => _premium = v),
          ),
        ],
        const SizedBox(height: 8),
        if (blocker != null && (shortfall.isEmpty || blocker != _shortText))
          CozyNotice(blocker, key: const Key('pantry-blocker'), tone: CozyTone.warning)
        else if (shortfall.isNotEmpty)
          CozyNotice(cost > c.state.buns ? '재료가 모자라요. 붕어빵력도 모자라서 지금은 살 수 없어요.' : '재료가 모자라요. 모자란 재료를 한 번에 살 수 있어요.',
              key: const Key('pantry-short'), tone: cost > c.state.buns ? CozyTone.warning : CozyTone.info),
        const SizedBox(height: 10),
        if (shortfall.isNotEmpty) ...[
          CozyButton(
            key: const Key('pantry-buy-short'),
            minHeight: 44,
            fontSize: 16,
            onPressed: busy || cost > c.state.buns ? null : () => c.buyPrepShortfall(kind.id, _tubs),
            label: '모자란 재료 한 번에 사기',
            icon: CurrencyAmount(Currency.buns, cost, size: 22, fontSize: 14, missing: cost > c.state.buns),
          ),
          const SizedBox(height: 8),
        ],
        CozyPrimaryButton(
          key: const Key('pantry-make'),
          minHeight: 48,
          onPressed: busy || blocker != null ? null : () => _make(kind, _tubs, premium),
          label: '만들기',
        ),
        const SizedBox(height: 6),
        Text('${PrepGameScreen.title(kind.minigame)} 미니게임을 하면 만들어요.\n잘하면 1통에 덤 ${pc.bonusPerTub}인분, 못해도 통은 그대로 만들어져요.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
      ]),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(text, style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 17, color: Cozy.ink)),
      );

  /// A 62번 icon, or a stand-in: a coloured round with the label's first letter.
  Widget _icon(String? name, double size, String label) {
    final image = name == null ? null : PrepArt.icon(name);
    if (image != null) return SizedBox.square(dimension: size, child: CustomPaint(painter: _IconPainter(image)));
    return Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: Cozy.peach, shape: BoxShape.circle, border: Border.all(color: Cozy.peachEdge)),
      child: Text(label.characters.first, style: TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: size * .45, color: Cozy.ink)),
    );
  }

  Widget _stock(PreparedKind kind, int level, int nowMs) {
    final have = pantry.usable(pc, kind.id, nowMs);
    final limit = pc.stockLimitPortions(level);
    final share = limit == 0 ? 0.0 : (have / limit).clamp(0.0, 1.0);
    final colour = have == 0 ? Cozy.brick : pantry.lowStock(pc, kind.id, level, nowMs) ? Cozy.orangeDeep : CozyTone.success.text;
    final premium = pantry.portions(kind.id, premium: true, nowMs: nowMs, config: pc);
    return CozyPanel(
      key: const Key('pantry-stock'),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
      child: Row(children: [
        _icon('tub_${kind.id}', 56, kind.label),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(kind.label, style: const TextStyle(fontFamily: 'Jua', fontFamilyFallback: Cozy.fontFallback, fontSize: 20))),
            Text('${amountText(pc, have)} / ${pc.stockLimitTubs(level)}통', key: const Key('pantry-stock-count'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: have == 0 ? Cozy.brick : Cozy.ink)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(height: 10, child: LinearProgressIndicator(
                key: const Key('pantry-stock-bar'), value: share, color: colour, backgroundColor: Cozy.creamDeep)),
          ),
          const SizedBox(height: 5),
          Text(_expiryLine(kind, nowMs), key: const Key('pantry-expiry'),
              style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)),
          if (premium > 0) Text('그중 ${kind.premiumLabel} ${amountText(pc, premium)}',
              style: TextStyle(fontSize: 12, color: CozyTone.reward.text)),
        ])),
      ]),
    );
  }

  /// When the oldest usable tub of [kind] goes off ('가장 오래된 통은
  /// 23시간 10분 뒤 버려요'); with only the starting stock, which never goes
  /// off ([PantryLot.keeps], 사용자 결정), '처음 받은 통은 상하지 않아요.';
  /// or that none is made.
  String _expiryLine(PreparedKind kind, int nowMs) {
    var keeps = false;
    for (final lot in pantry.lots) {
      if (lot.kind != kind.id || lot.portions <= 0 || lot.expired(pc, nowMs)) continue;
      if (lot.keeps) { keeps = true; continue; }
      final left = lot.madeAtMs + pc.expiryMs - nowMs;
      return '가장 오래된 통은 ${durationText(left)} 뒤 버려요.';
    }
    if (keeps) return '처음 받은 통은 상하지 않아요.';
    return '만든 ${kind.label}${_jong(kind.label) ? '이' : '가'} 없어요.';
  }

  /// '으로' after a closing consonant other than ㄹ, else '로'.
  static String _toward(String w) {
    final code = w.runes.last;
    final j = code >= 0xac00 && code <= 0xd7a3 ? (code - 0xac00) % 28 : 0;
    return j == 0 || j == 8 ? '로' : '으로';
  }

  static bool _jong(String w) {
    final code = w.runes.last;
    return code >= 0xac00 && code <= 0xd7a3 && (code - 0xac00) % 28 != 0;
  }

  /// '4통 10인분', '3통', '40인분', '0통' (tubs and the rest, so the count
  /// reads against the limit in tubs).
  static String amountText(PantryConfig c, int portions) {
    final tubs = portions ~/ c.portionsPerTub, rest = portions % c.portionsPerTub;
    if (rest == 0) return '$tubs통';
    return tubs == 0 ? '$rest인분' : '$tubs통 $rest인분';
  }

  /// '23시간 10분', '45분', '1분' (rounded up to the minute).
  static String durationText(int ms) {
    final minutes = (ms / 60000).ceil().clamp(1, 1 << 30);
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '$m분';
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }

  Widget _ingredients(PreparedKind kind, bool premium) {
    final rows = <(String, String, int, int)>[
      for (final e in kind.recipe.entries)
        (e.key, pc.basic[e.key]!.label, e.value * _tubs, pantry.basic[e.key] ?? 0),
      if (premium) (kind.premiumIngredient, pc.premium[kind.premiumIngredient]!.label, _tubs, pantry.premium[kind.premiumIngredient] ?? 0),
    ];
    return LayoutBuilder(builder: (context, box) {
      const gap = 6.0;
      final perRow = box.maxWidth >= 340 ? 3 : 2;
      final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (id, label, need, have) in rows)
          SizedBox(width: w, child: _ingredient(id, label, need, have)),
      ]);
    });
  }

  Widget _ingredient(String id, String label, int need, int have) {
    final short = have < need;
    return Semantics(
      label: '$label 필요 $need개, 가진 것 $have개${short ? ', 모자라요' : ''}',
      excludeSemantics: true,
      child: Container(
        key: Key('pantry-need-$id'),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: short ? CozyTone.warning.fill : Cozy.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: short ? CozyTone.warning.edge : Cozy.line),
        ),
        child: Row(children: [
          _icon(PrepArt.ingredientIcon[id], 32, label),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Cozy.ink)),
            Text.rich(TextSpan(children: [
              TextSpan(text: '$have', style: TextStyle(fontWeight: FontWeight.w800, color: short ? CurrencyAmount.missingColor : Cozy.ink)),
              TextSpan(text: ' / $need', style: const TextStyle(color: Cozy.inkSoft)),
            ]), key: Key('pantry-have-$id'), style: const TextStyle(fontSize: 13)),
          ])),
        ]),
      ),
    );
  }

  Future<void> _make(PreparedKind kind, int tubs, bool premium) async {
    final made = await Navigator.of(context, rootNavigator: true).push<bool>(PageRouteBuilder<bool>(
      opaque: true,
      transitionDuration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      reverseTransitionDuration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
      pageBuilder: (_, __, ___) => PrepGameScreen(
        config: c.config,
        kind: kind,
        tubs: tubs,
        premium: premium,
        reduceMotion: widget.reduceMotion,
        vibration: widget.vibration,
        onFinish: (success) async {
          final result = await c.makePrepared(kind.id, tubs, premium: premium, success: success);
          if (result == null) return PrepFinish(false, c.notice ?? c.error ?? '만들지 못했어요.');
          return PrepFinish(true, makeText(pc, result, success: success));
        },
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
    if (made == true && mounted) setState(() => _premium = false);
  }

  /// The result line: '반죽 3통을 만들었어요. 덤 30인분도 더 들어갔어요.'
  static String makeText(PantryConfig c, PantryMakeResult r, {required bool success}) {
    final kind = c.kind(r.kind);
    final name = r.premium ? kind.premiumLabel : kind.label;
    final made = '$name ${r.tubs}통을 만들었어요.';
    if (!success) return made;
    final wanted = r.tubs * c.bonusPerTub;
    if (r.bonus >= wanted) return '$made 덤 ${r.bonus}인분도 더 들어갔어요.';
    if (r.bonus == 0) return '$made 보관 한도가 차서 덤은 넣지 못했어요.';
    return '$made 보관 한도가 차서 덤은 ${r.bonus}인분만 넣었어요.';
  }
}

class _IconPainter extends CustomPainter {
  final ui.Image image;
  _IconPainter(this.image);
  @override
  void paint(Canvas canvas, Size size) => PixelSprites.draw(canvas, image, Offset.zero & size);
  @override
  bool shouldRepaint(covariant _IconPainter old) => old.image != image;
}
