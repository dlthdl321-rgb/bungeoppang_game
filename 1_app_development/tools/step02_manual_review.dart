// Debug-only entry point for physical touch/tilt and lifecycle observation.
// It runs the actual app and never seeds or edits gameplay state.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:todays_bungeoppang/main.dart' as app;
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

Future<void> main() async {
  if (!kDebugMode || !const bool.fromEnvironment('PRODUCTION_AUDIT')) {
    throw StateError(
        'Use a debug PRODUCTION_AUDIT build with the isolated app ID.');
  }
  await app.main();
  await WidgetsBinding.instance.endOfFrame;
  WorkshopController? controller;
  void findController(Element element) {
    final widget = element.widget;
    if (widget is GameApp) controller = widget.workshop;
    element.visitChildren(findController);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(findController);
  final workshop = controller;
  if (workshop == null) {
    debugPrint('STEP02_REVIEW_STARTUP_FAILED');
    return;
  }
  _ReviewObserver(workshop).start();
}

class _ReviewObserver with WidgetsBindingObserver {
  final WorkshopController controller;
  String? previous;
  _ReviewObserver(this.controller);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(record);
    record();
    // No account, economic, inventory, authentication or stable-ID data logged.
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (controller.disposed) {
        timer.cancel();
        WidgetsBinding.instance.removeObserver(this);
        controller.removeListener(record);
        return;
      }
      if (controller.state.session != null ||
          controller.state.grid.cells.any((cell) => cell.cooking)) {
        debugPrint('STEP02_REVIEW_CLOCK ${_snapshot()}');
      }
    });
    debugPrint('STEP02_REVIEW_READY');
  }

  String _snapshot() {
    final state = controller.state;
    final session = state.session;
    return 'phase=${session?.phase.name} token=${session?.token} '
        'phaseMs=${state.phaseMs} first=${session?.firstBatterMs} '
        'second=${session?.secondBatterMs} paused=${controller.gameplayPaused} '
        'cells=${state.grid.cells.map((cell) => '${cell.cooking}:${cell.cycle}:${cell.elapsedMs}').join(',')}';
  }

  void record() {
    final state = controller.state;
    final session = state.session;
    final key = '${session?.phase.name}:${session?.token}:'
        '${state.grid.cells.map((cell) => '${cell.cooking}:${cell.cycle}').join(',')}:'
        '${controller.gameplayPaused}';
    if (key != previous) {
      previous = key;
      debugPrint('STEP02_REVIEW_STATE ${_snapshot()}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('STEP02_REVIEW_LIFECYCLE ${state.name} ${_snapshot()}');
  }
}
