import 'online_backend.dart';

/// Every sentence of the first-run screens and the account settings
/// (26번 2-1단계), kept in one place (DEC-014: shared wording, Korean first).
abstract final class OwnerTexts {
  static const appTitle = '오늘의 붕어빵';
  static const welcome = '따끈한 붕어빵 가게를 열어 볼까요?';

  // ① 약관·필수 동의 + 로그인
  static const agreeAll = '전체 동의';
  static const agreeTerms = '(필수) 이용약관 동의';
  static const agreePrivacy = '(필수) 개인정보 수집·이용 동의';
  /// 만 14세 미만은 가입 불가(DEC-125): part of the required consent.
  static const agreeAge = '(필수) 만 14세 이상입니다';
  static const view = '보기';
  static const privacySummaryTitle = '개인정보 수집·이용 (필수)';
  static const privacySummary =
      '수집 항목: 로그인 계정 ID(카카오 회원번호 또는 구글 계정 ID), 이메일(로그인할 때 제공에 동의한 경우), 사장님 이름\n'
      '목적: 로그인과 계정 관리, 친구·랭킹 이름 표시, 공지·계정 안내\n'
      '보관 기간: 계정을 삭제할 때까지(법령이 정한 결제 기록은 그 기간 동안)\n'
      '동의하지 않을 수 있지만, 동의하지 않으면 게임을 시작할 수 없어요.';
  static const loginKakao = '카카오로 시작하기';
  static const loginGoogle = 'Google로 시작하기';
  static const continueSignedIn = '동의하고 계속하기';
  static const oneWayNotice = '처음 고른 방법으로 계속 로그인해 주세요. 카카오와 구글 계정은 서로 이어지지 않아요.';
  static const childNotice = '만 14세 미만은 지금은 이용할 수 없어요.';
  static const needAgreement = '필수 항목에 모두 동의해 주세요';
  static const loginFailed = '로그인하지 못했어요. 잠시 후 다시 해 주세요';
  static String otherAccount(LoginProvider? provider) =>
      '이 기기의 가게는 다른 ${provider == null ? '' : '${provider.label} '}계정에 연결돼 있어요. 처음 로그인한 계정으로 다시 로그인해 주세요.';

  // 오프라인 첫 실행
  static const offlineTitle = '인터넷 연결이 필요해요';
  static const offlineBody = '처음 시작할 때 한 번 로그인해야 해요.\n인터넷에 연결한 뒤 다시 시도해 주세요.\n한 번 로그인하면 그다음부터는 인터넷 없이도 할 수 있어요.';
  static const retry = '다시 시도';

  // ② 사장님 이름
  static const nameTitle = '사장님 이름을 정해 주세요';
  static const nameHint = '예: 붕어빵장인';
  /// 26번 3차 H4: only this line; the 2~8자 rule shows in red under the box
  /// when a name breaks it (OwnerNameRules.problem).
  static const nameHelp = '설정에서 언제든 바꿀 수 있어요';
  static const next = '다음';

  // ③ 사장님 고르기
  static const characterTitle = '어떤 사장님으로 시작할까요?';
  static const characterHelp = '꾸미기에서 언제든 바꿀 수 있어요';
  static const girl = '여자 사장님';
  static const boy = '남자 사장님';
  static const startWith = '이 사장님으로 시작';

  // ④ 선택 정보
  static const optionalTitle = '조금 더 알려 주실래요? (선택)';
  static const optionalLead = '입력하지 않아도 게임은 똑같이 할 수 있어요.';
  static const genderLabel = '성별';
  static const ageLabel = '연령대';
  static const agreeOptional = '(선택) 개인정보 수집·이용 동의';
  static const optionalSummary =
      '수집 항목: 성별, 연령대\n'
      '목적: 이용자 분석, 공지·계정 안내 (광고·마케팅에는 쓰지 않아요)\n'
      '이용자 분석은 Google Analytics 사용 통계로 해요. 이름·이메일·계정과 연결하지 않고, Google(미국) 서버로 보내져 14개월 보관돼요\n'
      '보관 기간: 직접 지우거나 계정을 삭제할 때까지 (설정에서 바꾸거나 지울 수 있어요)\n'
      '동의하지 않아도 게임을 할 수 있어요.';
  static const skip = '건너뛰기';
  static const saveAndStart = '저장하고 시작';

  // 설정 > 계정
  static const accountSection = '계정';
  static const ownerName = '사장님 이름';
  static const rename = '이름 바꾸기';
  static const save = '저장';
  static const cancel = '취소';
  static String loggedInWith(LoginProvider? provider) =>
      provider == null ? '로그인 안 됨' : '${provider.label} 계정으로 로그인 중';
  static const optionalInfo = '성별·연령대 (선택)';
  static const optionalNone = '입력 안 함';
  static const change = '바꾸기';
  static const clearOptional = '지우기';
  static const optionalCleared = '성별·연령대를 지웠어요';
  static const terms = '이용약관';
  static const privacy = '개인정보처리방침';
  static const logout = '로그아웃';
  static const logoutConfirm = '로그아웃할까요? 이 기기의 진행은 그대로 남고, 다시 같은 계정으로 로그인하면 이어서 할 수 있어요.';
  static const deleteAccount = '계정 삭제';
  static const deleteTitle = '계정을 삭제할까요?';
  static const deleteBody =
      '서버에 있는 계정, 사장님 이름·이메일·성별·연령대, 남은 황금붕어빵력과 산 아이템, 친구·랭킹 기록과 이 기기의 게임 진행이 모두 지워져요. 되돌릴 수 없어요.\n'
      '(법령이 정한 결제 기록만 정해진 기간 동안 따로 보관해요.)';
  static const deleteCheck = '위 내용을 확인했어요';
  static const deleteConfirm = '삭제하기';
  static const deleteOffline = '계정 삭제는 인터넷에 연결된 상태에서만 할 수 있어요';
  static const deleteFailed = '계정을 삭제하지 못했어요. 잠시 후 다시 해 주세요';
  static String shopOf(String name) => '$name 사장님의 가게';
}
