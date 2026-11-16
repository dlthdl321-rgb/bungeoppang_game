import 'package:flutter/material.dart';
import '../cooking_session.dart';
import '../development_balance.dart';
import 'piping_bag_control.dart';

/// Shared touch controls. Host owns recipe permissions, atomic saving, timer
/// pause, sound sources and inventory. Not a second game/economy controller.
/// The piping steps use the same painting control as the home mold.
class CookingSessionControls extends StatelessWidget {
  final CookingSession session;
  final DevelopmentBalance config;
  final bool blocked;
  final void Function(CookingSession) onCommand;
  final int cookingElapsedMs;
  const CookingSessionControls(
      {super.key,
      required this.session,
      required this.config,
      required this.blocked,
      required this.onCommand,
      required this.cookingElapsedMs});
  @override
  Widget build(BuildContext context) {
    final token = session.token;
    Widget button(String label, CookingSession Function() next) => FilledButton(
        onPressed: blocked ? null : () => onCommand(next()),
        child: Text(label));
    final Widget control;
    switch (session.phase) {
      case CookingPhase.firstBatter:
      case CookingPhase.secondBatter:
      case CookingPhase.filling:
        final filling = session.phase == CookingPhase.filling;
        control = SizedBox(
            width: 260,
            height: 180,
            child: MoldPaintControl(
                stageToken: token,
                blocked: blocked,
                filling: filling,
                flavor: session.flavor,
                config: config,
                onFinished: (paint, _) => onCommand(filling
                    ? session.squeezeFilling(token, paint)
                    : session.pour(token, paint))));
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      control,
      if (!session.finished)
        TextButton(
            onPressed: blocked ? null : () => onCommand(session.cancel()),
            child: const Text('제작 취소')),
    ]);
  }
}
