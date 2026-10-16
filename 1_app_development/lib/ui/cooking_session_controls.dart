import 'package:flutter/material.dart';
import '../cooking_input.dart';
import '../cooking_session.dart';

/// Shared touch controls. Host owns recipe permissions, atomic saving, timer
/// pause, sound sources and inventory. Not a second game/economy controller.
class CookingSessionControls extends StatelessWidget {
  final CookingSession session;
  final bool blocked;
  final void Function(CookingSession) onCommand;
  final int cookingElapsedMs;
  const CookingSessionControls({super.key, required this.session,
      required this.blocked, required this.onCommand, required this.cookingElapsedMs});
  @override
  Widget build(BuildContext context) {
    final token = session.token;
    Widget button(String label, CookingSession Function() next) => FilledButton(
        onPressed: blocked ? null : () => onCommand(next()), child: Text(label));
    final Widget control;
    switch (session.phase) {
      case CookingPhase.firstBatter:
      case CookingPhase.secondBatter:
        control = BatterHoldButton(stageToken: token, blocked: blocked,
            label: session.phase == CookingPhase.firstBatter ? '첫 반죽 붓기' : '둘째 반죽 붓기',
            onFinished: (duration) => onCommand(session.pour(token, duration)));
      case CookingPhase.filling:
        control = Wrap(spacing: 12, children: [
          button('왼쪽으로 속 넣기', () => session.fill(token, CookingDirection.left)),
          button('오른쪽으로 속 넣기', () => session.fill(token, CookingDirection.right)),
        ]);
      case CookingPhase.closing:
        control = button('뚜껑 닫기', () => session.close(token));
      case CookingPhase.flipping:
        control = button('뒤집기', () => session.flip(token));
      case CookingPhase.cooking:
        control = button('꺼내기', () => session.takeOut(token, cookingElapsedMs));
      case CookingPhase.result:
        control = const Text('제작 결과를 확인해 주세요.');
      case CookingPhase.canceled:
        control = const Text('제작을 취소했어요.');
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [control,
      if (!session.finished) TextButton(onPressed: blocked ? null :
          () => onCommand(session.cancel()), child: const Text('제작 취소')),
    ]);
  }
}

class BatterHoldButton extends StatefulWidget {
  final int stageToken;
  final bool blocked;
  final String label;
  final void Function(int durationMs) onFinished;
  const BatterHoldButton({super.key, required this.stageToken, required this.blocked,
      required this.label, required this.onFinished});
  @override
  State<BatterHoldButton> createState() => _BatterHoldButtonState();
}
class _BatterHoldButtonState extends State<BatterHoldButton> with WidgetsBindingObserver {
  final _clock = Stopwatch()..start();
  late BatterHoldInput _input;
  @override
  void initState() {
    super.initState();
    _input = BatterHoldInput(widget.stageToken);
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void didUpdateWidget(covariant BatterHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stageToken != widget.stageToken || widget.blocked) {
      _input.cancel(); _input = BatterHoldInput(widget.stageToken);
    }
  }
  void _cancel() { _input.cancel(); if (mounted) setState(() {}); }
  void _begin(int pointer) {
    if (widget.blocked || _input.active) return;
    setState(() => _input.begin(token: widget.stageToken,
        pointer: pointer, monotonicMs: _clock.elapsedMilliseconds));
  }
  void _finish(int pointer) {
    if (widget.blocked) { _cancel(); return; }
    final duration = _input.finish(token: widget.stageToken,
        pointer: pointer, monotonicMs: _clock.elapsedMilliseconds);
    if (duration == null) return;
    setState(() {});
    widget.onFinished(duration);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); _input.cancel(); _clock.stop(); super.dispose();
  }
  @override
  Widget build(BuildContext context) => Semantics(
    button: true, enabled: !widget.blocked, label: widget.label,
    value: _input.active ? '붓는 중' : '멈춤',
    hint: '길게 누르거나, 화면 읽기 기능으로 두 번 활성화해 시작하고 멈출 수 있어요.',
    onTap: widget.blocked ? null : () => _input.active ? _finish(-1) : _begin(-1),
    child: Listener(onPointerDown: (event) => _begin(event.pointer),
      onPointerUp: (event) => _finish(event.pointer), onPointerCancel: (_) => _cancel(),
      child: ExcludeSemantics(child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: widget.blocked ? Colors.grey.shade300 :
            Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Text('${widget.label}\n${_input.active ? '붓는 중 — 놓으면 멈춰요' : '길게 눌러 주세요'}'),
      )),
    ),
  );
}
