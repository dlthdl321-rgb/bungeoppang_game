import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// Sharing opens the OS picker; it is never evidence of delivery or a reward.
class InviteSharingService {
  const InviteSharingService();
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
  Future<void> share(String text, Rect origin) async {
    await SharePlus.instance.share(ShareParams(
        text: text, subject: '오늘의 붕어빵 모의 초대', sharePositionOrigin: origin));
  }
}
