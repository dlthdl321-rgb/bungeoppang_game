import 'package:flutter/material.dart';
import '../customer_notifier.dart';
import 'cozy_style.dart';

/// Shown under the guest-notice switches in the settings while a switch is
/// on but the phone does not allow the app's notices (the first-run prompt
/// was answered '나중에' or the permission was refused, DEC-105). The
/// switch stays on; this row says why nothing comes and asks again only when
/// the player taps it. Looks again when the app comes back to the front (the
/// player may have allowed it in the phone settings) and when [revision]
/// changes (a switch just got the permission).
class NoticePermissionHint extends StatefulWidget {
  final CustomerNotifier notifier;
  final int revision;
  /// The request was refused (Android stops showing its window after two
  /// refusals): the caller shows how to allow it in the phone settings.
  final VoidCallback denied;
  const NoticePermissionHint({super.key, required this.notifier, required this.revision, required this.denied});

  static const text = '알림 권한이 필요해요';
  static const detail = '휴대폰이 이 앱의 알림을 막고 있어 켜 둔 알림이 오지 않아요.';
  static const action = '권한 허용하기';

  @override
  State<NoticePermissionHint> createState() => _NoticePermissionHintState();
}

class _NoticePermissionHintState extends State<NoticePermissionHint> with WidgetsBindingObserver {
  bool? _allowed;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void didUpdateWidget(NoticePermissionHint old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision || old.notifier != widget.notifier) _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    final allowed = await widget.notifier.hasPermission();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() => _asking = true);
    try {
      final granted = await widget.notifier.requestPermission();
      if (!mounted) return;
      setState(() => _allowed = granted);
      if (!granted) widget.denied();
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed != false) return const SizedBox.shrink();
    return Padding(
      key: const Key('settings-notice-permission'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(color: Cozy.cream, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Cozy.woodLight, width: 1.5)),
        child: Row(children: [
          const Icon(Icons.notifications_off_outlined, color: Cozy.inkSoft),
          const SizedBox(width: 8),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(NoticePermissionHint.text, style: TextStyle(fontWeight: FontWeight.w700)),
            Text(NoticePermissionHint.detail, style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
          ])),
          const SizedBox(width: 4),
          TextButton(key: const Key('settings-notice-permission-ask'), onPressed: _asking ? null : _ask,
              child: const Text(NoticePermissionHint.action)),
        ]),
      ),
    );
  }
}
