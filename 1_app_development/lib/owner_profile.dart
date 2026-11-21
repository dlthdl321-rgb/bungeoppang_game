import 'online_backend.dart';

// 26번 2-1단계: what the first-run screens collect, kept on this device
// (OwnerProfileRepository) and, for a signed-in player, on the server's
// account profile (functions/src/account.ts).
//
// The order on a new install: required consent + login (Kakao or Google) →
// owner name → 여자/남자 사장님 → optional gender and age band → the first-run
// guide (workshop_tutorial.dart). The character choice itself lives in the
// workshop save (avatarEquipment.character); this profile only remembers
// that the question was answered.

/// The terms and privacy notice the required consent refers to. Bump it when
/// either changes so every player agrees again (server: account.ts).
/// 2026-11-19: '(필수) 만 14세 이상입니다' joins the required consent
/// (만 14세 미만은 가입 불가, DEC-125), so everyone confirms it once.
/// 2026-11-21 (4차 병합 3 사용자 결정): the privacy notice lists the new
/// usage event `ingredient_out` (재료 타이쿤), so everyone agrees again.
const requiredConsentVersion = '2026-11-21';

/// Gender the player may tell (optional; not the character choice).
enum PlayerGender {
  female('female', '여성'),
  male('male', '남성'),
  none('none', '선택 안 함');

  final String id, label;
  const PlayerGender(this.id, this.label);
  static PlayerGender? byId(Object? id) =>
      values.where((v) => v.id == id).firstOrNull;
}

/// Age band the player may tell (optional). There is no 만 14세 미만 band:
/// players under 14 cannot sign up (DEC-125). A save from before
/// that still holding 'under14' is dropped on reading ([OptionalInfo.fromJson]).
enum AgeBand {
  teen('14_19', '14~19세'),
  twenties('20s', '20대'),
  thirties('30s', '30대'),
  forties('40s', '40대'),
  fiftyPlus('50plus', '50대 이상'),
  none('none', '선택 안 함');

  final String id, label;
  const AgeBand(this.id, this.label);
  static AgeBand? byId(Object? id) => values.where((v) => v.id == id).firstOrNull;
}

/// The owner name rules from config/owner_name_rules.json: 2~8 letters of
/// Hangul syllables, Latin letters or digits, none of the banned words.
/// Names may repeat between players.
class OwnerNameRules {
  final int minLength, maxLength;
  final List<String> bannedWords;
  const OwnerNameRules(
      {this.minLength = 2, this.maxLength = 8, this.bannedWords = const []});

  factory OwnerNameRules.fromJson(Map<String, dynamic> json) {
    final min = json['min_length'], max = json['max_length'], words = json['banned_words'];
    if (min is! int || max is! int || min < 1 || max < min || words is! List ||
        words.any((w) => w is! String || w.isEmpty)) {
      throw const FormatException('사장님 이름 규칙 형식 오류');
    }
    return OwnerNameRules(
        minLength: min,
        maxLength: max,
        bannedWords: [for (final w in words) (w as String).toLowerCase()]);
  }

  // 완성형 한글(U+AC00~U+D7A3)·영문·숫자. 글자를 escape로 적어 font_coverage_test가
  // 범위 끝 글자를 화면 문구로 세지 않게 한다.
  static final _allowed = RegExp(r'^[\uAC00-\uD7A3A-Za-z0-9]+$');
  static final _notAllowed = RegExp(r'[^\uAC00-\uD7A3A-Za-z0-9]');

  /// Why [raw] cannot be the owner name, or null when it can.
  String? problem(String raw) {
    final name = raw.trim();
    final length = name.runes.length;
    if (length < minLength || length > maxLength) {
      return '이름은 $minLength~$maxLength자로 정해 주세요';
    }
    if (!_allowed.hasMatch(name)) return '한글·영문·숫자만 쓸 수 있어요';
    final lower = name.toLowerCase();
    if (bannedWords.any(lower.contains)) return '다른 이름을 써 주세요';
    return null;
  }

  /// A starting name from the login nickname: only allowed letters, cut to
  /// the maximum; empty when nothing usable is left.
  String suggestion(String? nickname) {
    final kept = (nickname ?? '').replaceAll(_notAllowed, '');
    final cut = String.fromCharCodes(kept.runes.take(maxLength));
    return problem(cut) == null ? cut : '';
  }
}

/// The optional answers, stored only with their own consent.
class OptionalInfo {
  final PlayerGender gender;
  final AgeBand ageBand;
  final int agreedAtMs;
  const OptionalInfo({required this.gender, required this.ageBand, required this.agreedAtMs});

  Map<String, Object?> toJson() => {
        'gender': gender.id,
        'ageBand': ageBand.id,
        'agreedAtMs': agreedAtMs,
      };

  /// The saved answers, or null for a save from before DEC-125 that
  /// chose 'under14' (with the old guardian tick): those are forgotten, here
  /// and, through the next profile push, on the server.
  static OptionalInfo? fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('선택 정보 형식 오류');
    final gender = PlayerGender.byId(raw['gender']), at = raw['agreedAtMs'];
    final ageId = raw['ageBand'], age = AgeBand.byId(ageId);
    final guardian = raw['guardianConsent'];
    if (gender == null || at is! int || (guardian != null && guardian is! bool)) {
      throw const FormatException('선택 정보 형식 오류');
    }
    if (ageId == 'under14' && guardian == true) return null;
    if (age == null) throw const FormatException('선택 정보 형식 오류');
    return OptionalInfo(gender: gender, ageBand: age, agreedAtMs: at);
  }
}

/// The first-run answers on this device. Saved as JSON (`schema` 1) in its
/// own small database, apart from the game saves, so the account and
/// workshop save formats do not change.
class OwnerProfile {
  static const schema = 1;

  /// The account this device's shop belongs to (`kakao:<번호>` or Google's
  /// uid) and how it logs in. Null before the first login.
  String? account;
  LoginProvider? provider;
  String? consentVersion;
  int? consentAtMs;
  String? name;
  bool characterChosen = false;
  bool optionalAsked = false;
  OptionalInfo? optional;
  /// The server profile has the latest name and optional info.
  bool serverSynced = false;

  OwnerProfile();

  Map<String, Object?> toJson() => {
        'schema': schema,
        'account': account,
        'provider': provider?.name,
        'consentVersion': consentVersion,
        'consentAtMs': consentAtMs,
        'name': name,
        'characterChosen': characterChosen,
        'optionalAsked': optionalAsked,
        'optional': optional?.toJson(),
        'serverSynced': serverSynced,
      };

  static OwnerProfile fromJson(Map<String, dynamic> json) {
    T? nullable<T>(String key) {
      final value = json[key];
      if (value != null && value is! T) throw FormatException('사장님 정보 형식 오류: $key');
      return value as T?;
    }
    bool flag(String key) {
      final value = json[key];
      if (value is! bool) throw FormatException('사장님 정보 형식 오류: $key');
      return value;
    }
    if (json['schema'] != schema) throw const FormatException('사장님 정보 버전 오류');
    final providerName = nullable<String>('provider');
    final provider = providerName == null
        ? null
        : LoginProvider.values.where((p) => p.name == providerName).firstOrNull;
    if (providerName != null && provider == null) {
      throw const FormatException('사장님 정보 형식 오류: provider');
    }
    final account = nullable<String>('account');
    if ((account == null) != (provider == null) || account == '') {
      throw const FormatException('사장님 정보 형식 오류: account');
    }
    final rawOptional = json['optional'];
    final optional = rawOptional == null ? null : OptionalInfo.fromJson(rawOptional);
    // A dropped old under-14 answer still has to be cleared on the server.
    final dropped = rawOptional != null && optional == null;
    return OwnerProfile()
      ..account = account
      ..provider = provider
      ..consentVersion = nullable<String>('consentVersion')
      ..consentAtMs = nullable<int>('consentAtMs')
      ..name = nullable<String>('name')
      ..characterChosen = flag('characterChosen')
      ..optionalAsked = flag('optionalAsked')
      ..optional = optional
      ..serverSynced = flag('serverSynced') && !dropped;
  }
}
