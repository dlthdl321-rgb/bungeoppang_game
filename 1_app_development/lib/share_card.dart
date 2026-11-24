import 'development_balance.dart';
import 'invite_sharing.dart';

/// 공유 카드(26번 8단계, DEC-048, S8-Q1): the four moments a player can
/// show off. Sharing gives nothing in the game (MASTER 1장).
enum ShareMoment {
  /// A perfect bake's result ('완벽해요!').
  perfect('perfect', '완벽!'),
  /// The end of a regular's story scene.
  story('story', '이야기'),
  /// A flavor whose five doneness entries are all found in 도감.
  collection('collection', '도감 완성'),
  /// '가게 사진 찍기' in the menu.
  shop('shop', '우리 가게');

  /// The Analytics `moment` value and the file name part.
  final String id;
  /// The badge on the card.
  final String badge;
  const ShareMoment(this.id, this.badge);
}

/// What one card shows. On purpose there is no owner name, account, level,
/// currency, date or device detail: only game pictures and game words.
class ShareCardData {
  final ShareMoment moment;

  /// The big line under the picture: '팥 붕어빵' (always ends in 붕어빵 or
  /// 도감 for perfect and collection cards), the story's name, '우리 가게'.
  final String title;

  /// A guest's short name and their one line, or null.
  final String? speaker, line;

  /// The guest picture standing beside the bungeoppang
  /// (`assets/images/customer/<id>_happy.png`), or null.
  final String? guestArt;

  /// The bungeoppang's doneness picture (0..4) and whether it shines; null
  /// draws no bungeoppang (the shop photo shows the stall itself).
  final int? variant;
  final bool shine;

  /// What the stall wears in the picture (background, decoration, lamp and
  /// the vendor's clothes), by [CosmeticSlot] name.
  final Map<String, String> equipped;

  const ShareCardData(
      {required this.moment,
      required this.title,
      this.speaker,
      this.line,
      this.guestArt,
      this.variant,
      this.shine = false,
      this.equipped = const {}});

  /// Every word printed on the card (tests check none is personal).
  List<String> get words => [moment.badge, title, if (speaker != null) speaker!, if (line != null) line!];
}

/// The card's fixed texts from the `share` settings.
class ShareCardTexts {
  final String storeLine, storeUrl;
  final int width, height;
  const ShareCardTexts(
      {required this.storeLine,
      required this.storeUrl,
      this.width = 1080,
      this.height = 1350});

  factory ShareCardTexts.of(DevelopmentBalance config) {
    final share = config.section('share');
    final live = share['store_line_mode'] == 'live';
    return ShareCardTexts(
        storeLine: (live ? share['store_line_live'] : share['store_line_soon']) as String,
        storeUrl: share['store_url'] as String,
        width: DevelopmentBalance.integer(share, 'card_width'),
        height: DevelopmentBalance.integer(share, 'card_height'));
  }

  /// The words sent with the picture: one line about the moment, the store
  /// line and the store address.
  String message(ShareCardData data) {
    final about = switch (data.moment) {
      ShareMoment.perfect => '완벽한 ${data.title}을 구웠어요!',
      ShareMoment.story => '단골손님의 이야기를 들었어요. "${data.title}"',
      ShareMoment.collection => '${data.title}을 다 채웠어요!',
      ShareMoment.shop => '우리 붕어빵 가게에 놀러 오세요!',
    };
    return '$about\n$storeLine\n$storeUrl';
  }

  String fileName(ShareCardData data) => 'todays_bungeoppang_${data.moment.id}.png';
}

/// Where share cards go. Tests swap in a fake; the app uses the share window.
class ShareCards {
  static CardSharer sharer = const SharePlusCardSharer();

  /// The message when the share window did not open (state unchanged).
  static const failedText = '공유 창을 열지 못했어요. 잠시 뒤 다시 해 주세요.';
}
