import 'dart:async';
import 'package:flutter/material.dart';
import 'cozy_style.dart';

/// The app's one short notice (26번 3차 피드백 H23): a translucent dark
/// window in the middle of the screen that fades in, stays a moment and
/// fades out, instead of a snack bar rising from the bottom. Touches pass
/// through it. A new notice replaces the one showing.
///
/// Every short message in the app goes through [showCenterToast] (a lock's
/// reason, a failed purchase, '로그인 후 …'), so they all look the same.
class CenterToast {
  CenterToast._();

  /// How long a notice stays (fading in and out included).
  static const duration = Duration(milliseconds: 2200);
  static const fadeMs = 180;

  /// Widest the window grows; it is never wider than the screen less 48.
  static const maxWidth = 300.0;

  /// The window's colour: dark wood at 82%, so the stall shows through.
  static const background = Color(0xd12a1810);

  static OverlayEntry? _entry;

  /// The message showing now, for tests.
  static String? get current => _current;
  static String? _current;

  /// Removes the notice showing, if any.
  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
    _current = null;
  }
}

/// Shows [message] in the middle of the screen for [duration].
void showCenterToast(BuildContext context, String message, {Duration duration = CenterToast.duration}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  // 5차 피드백 7: the same notice already up stays as it is (tapping again
  // used to make it fade out and in, a blink).
  if (CenterToast._current == message && CenterToast._entry != null && CenterToast._entry!.mounted) return;
  CenterToast.hide();
  late final OverlayEntry entry;
  entry = OverlayEntry(
      builder: (_) => _ToastView(
          message: message,
          duration: duration,
          onDone: () {
            if (CenterToast._entry == entry) CenterToast.hide();
          },
          onGone: () {
            // The screen went away with the notice on it (a test's end).
            if (CenterToast._entry == entry && !entry.mounted) {
              CenterToast._entry = null;
              CenterToast._current = null;
            }
          }));
  CenterToast._entry = entry;
  CenterToast._current = message;
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDone, onGone;
  const _ToastView({required this.message, required this.duration, required this.onDone, required this.onGone});
  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  bool _shown = false;
  Timer? _in, _out, _done;

  @override
  void initState() {
    super.initState();
    _in = Timer(Duration.zero, () {
      if (mounted) setState(() => _shown = true);
    });
    final fade = const Duration(milliseconds: CenterToast.fadeMs);
    _out = Timer(widget.duration - fade, () {
      if (mounted) setState(() => _shown = false);
    });
    _done = Timer(widget.duration, widget.onDone);
  }

  @override
  void dispose() {
    _in?.cancel();
    _out?.cancel();
    _done?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onGone());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: widget.message,
              excludeSemantics: true,
              child: AnimatedOpacity(
                opacity: _shown || still ? 1 : 0,
                duration: still ? Duration.zero : const Duration(milliseconds: CenterToast.fadeMs),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    key: const Key('center-toast'),
                    constraints: BoxConstraints(
                        maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(120.0, CenterToast.maxWidth)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                        color: CenterToast.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Cozy.cream.withValues(alpha: .18)),
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))]),
                    child: Text(widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Cozy.cream, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
