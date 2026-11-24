import 'package:flutter/material.dart';
import '../game_controller.dart';

/// The account save's last error under a window (32번: the old clicker's
/// coin-reward helpers are gone).
Widget saveError(GameController c) => c.error == null
    ? const SizedBox.shrink()
    : Text(c.error!, style: const TextStyle(color: Colors.red));
