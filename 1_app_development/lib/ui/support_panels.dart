import 'package:flutter/material.dart';
import '../game_controller.dart';
import '../support_config.dart';

String rewardLabel(RewardDefinition r) => '코인 ${r.coins}개';
String remainingLabel(int ms) {
  final seconds = (ms + 999) ~/ 1000;
  return '${seconds ~/ 60}분 ${(seconds % 60).toString().padLeft(2, '0')}초';
}

Widget saveError(GameController c) => c.error == null
    ? const SizedBox.shrink()
    : Text(c.error!, style: const TextStyle(color: Colors.red));

Future<bool> confirmAction(BuildContext context, String title, String details,
        String label) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                scrollable: true,
                title: Text(title),
                content: Text(details),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소')),
                  FilledButton(
                      key: const Key('confirm-support'),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(label)),
                ])) ??
    false;
