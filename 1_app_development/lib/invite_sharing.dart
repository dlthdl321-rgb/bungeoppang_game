import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// Sharing opens the OS picker; it is never evidence of delivery or a reward.
class InviteSharingService {
  const InviteSharingService();
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
  Future<void> share(String text, Rect origin,
      {String subject = '오늘의 붕어빵'}) async {
    await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin));
  }
}

/// Hands a share card picture to the phone's share window (26번 8단계).
/// Only the share window: no photo-library save, so no storage permission.
/// Opening it gives nothing in the game (MASTER 1장 '공유에도 보상 없음').
abstract class CardSharer {
  /// Throws when the share window could not open.
  Future<void> sharePng(Uint8List png,
      {required String text, required String fileName, Rect? origin});
}

class SharePlusCardSharer implements CardSharer {
  const SharePlusCardSharer();
  @override
  Future<void> sharePng(Uint8List png,
      {required String text, required String fileName, Rect? origin}) async {
    final result = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        text: text,
        subject: '오늘의 붕어빵',
        sharePositionOrigin: origin));
    if (result.status == ShareResultStatus.unavailable) {
      throw StateError('share unavailable');
    }
  }
}
