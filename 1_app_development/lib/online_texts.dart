/// What the player reads about the connection (4차 피드백 IC10).
///
/// The game is online-only: a build made with the online settings
/// (`--dart-define-from-file=dart_defines/online.json`) plays only while the
/// phone is connected. A build made without them can never reach the server,
/// so it says that instead of blaming the internet.
abstract final class OnlineTexts {
  // A build without the online settings (no Firebase keys).
  static const notSetUp = '온라인 설정 없이 만든 빌드라 서버에 연결할 수 없어요';
  static const rankingNotSetUp = '온라인 설정 없이 만든 빌드라 랭킹을 볼 수 없어요';
  static const skillNotSetUp = '온라인 설정 없이 만든 빌드라 레벨업할 수 없어요.\n온라인 빌드로 설치해 주세요.';
  static const cosmeticNotSetUp = '온라인 설정 없이 만든 빌드라 꾸미기를 살 수 없어요.\n온라인 빌드로 설치해 주세요.';
  /// The small band a debug build without the settings shows at the top:
  /// it plays without a server, its progress kept on this device only.
  static const devBuild = '시험용 빌드: 서버 없이 이 기기에만 저장돼요';
  /// The charge tab of such a build: free test gold, never real money.
  static const testGoldButton = '시험용 황금 +10 받기';
  static const testGoldNote = '시험용 빌드 전용이에요. 실제 결제가 아니고 이 기기에만 저장돼요.';
  static const testGoldDone = '시험용 황금 10개를 받았어요';
  /// An online build opening a save made in a test build.
  static const localTestSave = '시험용 빌드에서 만든 저장이라 온라인에서 이어 할 수 없어요. 앱을 지우고 다시 설치해 주세요.';
  /// A release build without the settings shows only this screen.
  static const releaseNotSetUpTitle = '온라인 설정이 없는 빌드예요';
  static const releaseNotSetUpBody = '오늘의 붕어빵은 인터넷에 연결해서만 할 수 있어요.\n'
      '이 설치 파일은 온라인 설정 없이 만들어져\n서버에 연결할 수 없어요.\n'
      '온라인 빌드로 다시 설치해 주세요.';

  // An online build that lost the connection while playing (or started
  // without one): everything stops under this notice until it comes back.
  static const lostTitle = '인터넷에 연결해 주세요';
  static const lostBody = '오늘의 붕어빵은 인터넷에 연결된 동안에만 할 수 있어요.\n'
      '와이파이나 모바일 데이터를 확인하고\n다시 시도해 주세요.';
  static const checking = '연결 확인 중…';
  static const retry = '다시 시도';

  // Purchases in an online build before the login.
  static const cosmeticSignIn = '로그인 후 꾸미기를 살 수 있어요.';
}
