import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/game_controller.dart';
import 'package:todays_bungeoppang/online_backend.dart';
import 'package:todays_bungeoppang/owner_account.dart';
import 'package:todays_bungeoppang/owner_profile.dart';
import 'package:todays_bungeoppang/owner_repository.dart';
import 'package:todays_bungeoppang/local_test_purchases.dart';
import 'package:todays_bungeoppang/online_texts.dart';
import 'package:todays_bungeoppang/owner_texts.dart';
import 'package:todays_bungeoppang/ui/first_run.dart';
import 'package:todays_bungeoppang/ui/game_app.dart';
import 'package:todays_bungeoppang/ui/workshop_page.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'online_backend_test.dart' show backend;
import 'step02_controller_test.dart' show MemoryRepository;
import 'widget_test.dart' show mountGame;

// 26번 2-1단계: first-run login (Kakao or Google, required), owner name,
// 여자/남자 사장님, optional gender and age band, and the account settings
// (rename, optional info, logout, account deletion).

final rules = OwnerNameRules.fromJson(
    jsonDecode(File('config/owner_name_rules.json').readAsStringSync()) as Map<String, dynamic>);

class Analytics implements OwnerAnalytics {
  final calls = <(String?, String?)>[];
  /// Every consent state OwnerAccount reported (DEC-126).
  final consents = <bool>[];
  @override
  void setUserProperties({String? gender, String? ageBand}) => calls.add((gender, ageBand));
  @override
  void setConsented(bool consented) => consents.add(consented);
}

class FirstRun {
  final GameController game;
  final WorkshopController shop;
  final OwnerAccount owner;
  final OnlineBackend online;
  final MemoryOwnerProfileRepository profiles;
  final Analytics analytics;
  FirstRun(this.game, this.shop, this.owner, this.online, this.profiles, this.analytics);
  FakeOnlineBackend get fake => online as FakeOnlineBackend;
}

/// Is there internet in the fake world?
bool internet = true;

Future<FirstRun> mountFirstRun(WidgetTester tester,
    {OnlineBackend? online,
    OwnerProfile? profile,
    Future<void> Function(WorkshopController shop)? before,
    Size size = const Size(390, 844),
    bool startOnline = true}) async {
  internet = startOnline;
  final net = online ?? backend();
  final game = await mountGame(tester, size, reduced: true, online: net);
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);
  final shop = WorkshopController(config, MemoryRepository(), now: () => DateTime.utc(2026, 11, 18), monotonicMs: () => 0);
  await shop.initialize();
  if (before != null) await before(shop);
  final profiles = MemoryOwnerProfileRepository(profile);
  final analytics = Analytics();
  final owner = OwnerAccount(
      repository: profiles,
      online: net,
      rules: rules,
      game: game,
      workshop: shop,
      hasInternet: () async => internet,
      analytics: analytics,
      now: () => DateTime.utc(2026, 11, 18, 9));
  await owner.load();
  internet = true;
  await tester.pumpWidget(GameApp(controller: game, workshop: shop, owner: owner));
  await tester.pump();
  return FirstRun(game, shop, owner, net, profiles, analytics);
}

Future<void> tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> agreeAndLogin(WidgetTester tester, LoginProvider provider) async {
  await tap(tester, const Key('consent-all'));
  await tap(tester, Key('login-${provider.name}'));
}

Future<void> enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('owner-name-field')), name);
  await tap(tester, const Key('first-run-name-next'));
}

bool gameShown() => find.byType(WorkshopPage).evaluate().isNotEmpty;

void main() {
  group('사장님 이름 규칙', () {
    test('한글·영문·숫자 2~8자, 겹쳐도 되고 비속어는 막는다', () {
      for (final ok in ['붕어', '붕어빵장인', 'Bun8', '가나다라마바사아', 'ABcd1234']) {
        expect(rules.problem(ok), isNull, reason: ok);
      }
      expect(rules.problem('붕'), '이름은 2~8자로 정해 주세요');
      expect(rules.problem('가나다라마바사아자'), '이름은 2~8자로 정해 주세요');
      expect(rules.problem('붕어 빵'), '한글·영문·숫자만 쓸 수 있어요');
      expect(rules.problem('ㄱㄴㄷ'), '한글·영문·숫자만 쓸 수 있어요');
      expect(rules.problem('빵!'), '한글·영문·숫자만 쓸 수 있어요');
      expect(rules.problem('씨발사장'), '다른 이름을 써 주세요');
      expect(rules.problem('FUCKer'), '다른 이름을 써 주세요');
      expect(rules.problem('운영자'), '다른 이름을 써 주세요');
    });

    test('로그인 닉네임에서 쓸 수 있는 글자만 남겨 기본값으로 쓴다', () {
      expect(rules.suggestion('붕어빵 사장님!!'), '붕어빵사장님');
      expect(rules.suggestion('Very Long Nickname'), 'VeryLong');
      expect(rules.suggestion('🐟'), '');
      expect(rules.suggestion(null), '');
      expect(rules.suggestion('시발'), '');
    });

    test('설정 파일 형식이 틀리면 읽지 않는다', () {
      expect(() => OwnerNameRules.fromJson({'min_length': 2, 'max_length': 1, 'banned_words': []}),
          throwsFormatException);
      expect(() => OwnerNameRules.fromJson({'min_length': 2, 'max_length': 8, 'banned_words': ['']}),
          throwsFormatException);
    });
  });

  group('사장님 정보 저장 형식 (schema 1)', () {
    test('저장했다가 그대로 읽고, 틀린 값은 거절한다', () {
      final p = OwnerProfile()
        ..account = 'kakao:1001'
        ..provider = LoginProvider.kakao
        ..consentVersion = requiredConsentVersion
        ..consentAtMs = 5
        ..name = '붕어빵'
        ..characterChosen = true
        ..optionalAsked = true
        ..optional = const OptionalInfo(gender: PlayerGender.female, ageBand: AgeBand.twenties, agreedAtMs: 7);
      final back = OwnerProfile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), p.toJson());
      Map<String, dynamic> broken(void Function(Map<String, dynamic>) edit) {
        final m = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
        edit(m);
        return m;
      }
      expect(() => OwnerProfile.fromJson(broken((m) => m['schema'] = 2)), throwsFormatException);
      expect(() => OwnerProfile.fromJson(broken((m) => m['provider'] = 'apple')), throwsFormatException);
      expect(() => OwnerProfile.fromJson(broken((m) => m['account'] = null)), throwsFormatException);
      expect(() => OwnerProfile.fromJson(broken((m) => (m['optional'] as Map)['ageBand'] = 'under14')),
          throwsFormatException, reason: '보호자 체크도 없는 만 14세 미만은 옛 저장에도 없던 값');
      expect(() => OwnerProfile.fromJson(broken((m) => (m['optional'] as Map)['ageBand'] = 'kid')), throwsFormatException);
    });

    test('옛 저장의 만 14세 미만 선택 정보(보호자 체크)는 읽을 때 버리고 서버에서도 지우게 한다', () {
      final old = {
        'schema': 1, 'account': 'kakao:1001', 'provider': 'kakao', 'consentVersion': '2026-11-18',
        'consentAtMs': 5, 'name': '붕어빵', 'characterChosen': true, 'optionalAsked': true,
        'optional': {'gender': 'none', 'ageBand': 'under14', 'guardianConsent': true, 'agreedAtMs': 7},
        'serverSynced': true,
      };
      final p = OwnerProfile.fromJson(old);
      expect(p.optional, isNull);
      expect(p.optionalAsked, isTrue);
      expect(p.serverSynced, isFalse, reason: '다음 동기화에 서버 연령대도 지움');
      // An older adult answer with the old guardianConsent: false still reads.
      final adult = OwnerProfile.fromJson({...old, 'optional': {'gender': 'male', 'ageBand': '30s', 'guardianConsent': false, 'agreedAtMs': 7}});
      expect(adult.optional!.ageBand, AgeBand.thirties);
      expect(adult.serverSynced, isTrue);
      expect(adult.optional!.toJson().containsKey('guardianConsent'), isFalse);
    });

    test('필수 동의 판은 만 14세 이상 확인이 들어간 2026-11-19, 연령대에 만 14세 미만이 없다', () {
      expect(requiredConsentVersion, '2026-11-19');
      expect(AgeBand.values.map((a) => a.id), isNot(contains('under14')));
      expect(AgeBand.values.map((a) => a.label).where((l) => l.contains('미만')), isEmpty);
      final json = const AccountProfileUpdate(name: '붕어빵', consentVersion: requiredConsentVersion, over14Confirmed: true,
          gender: 'female', ageBand: '20s').toJson();
      expect(json, {
        'name': '붕어빵', 'consentVersion': requiredConsentVersion, 'over14Confirmed': true,
        'optional': {'gender': 'female', 'ageBand': '20s'},
      });
    });

    test('읽을 수 없는 기록은 새 설치처럼 다시 묻는다', () async {
      final repo = MemoryOwnerProfileRepository()..stored = {'schema': 1, 'name': 3};
      expect(await repo.load(), isNull);
    });
  });

  group('첫 실행', () {
    testWidgets('로그인 전에는 게임 화면으로 들어가지 못하고, 필수 동의 전에는 로그인 버튼이 꺼져 있다', (tester) async {
      final r = await mountFirstRun(tester);
      expect(gameShown(), isFalse);
      expect(find.byKey(const Key('login-kakao')), findsOneWidget);
      expect(find.byKey(const Key('login-google')), findsOneWidget);
      expect(find.text(OwnerTexts.oneWayNotice), findsOneWidget);
      await tap(tester, const Key('login-kakao'));
      expect(r.fake.signIns, 0, reason: '동의 전에는 누를 수 없음');
      // One required item is not enough.
      await tap(tester, const Key('consent-terms'));
      await tap(tester, const Key('login-kakao'));
      expect(r.fake.signIns, 0);
      await tap(tester, const Key('consent-privacy'));
      // 약관·개인정보만으로는 안 됨: 만 14세 이상 확인이 필요(DEC-125).
      expect(find.text(OwnerTexts.agreeAge), findsOneWidget);
      expect(find.byKey(const Key('first-run-child-notice')), findsOneWidget);
      expect(find.text(OwnerTexts.childNotice), findsOneWidget);
      await tap(tester, const Key('login-kakao'));
      await tap(tester, const Key('login-google'));
      expect(r.fake.signIns, 0, reason: '만 14세 이상 체크 없이는 로그인 불가');
      expect(r.owner.step, OwnerStep.login);
      expect(r.analytics.consents.contains(true), isFalse, reason: '동의 전에는 사용 통계를 모으지 않음');
      await tap(tester, const Key('consent-age'));
      expect(find.byKey(const Key('first-run-child-notice')), findsNothing);
      await tap(tester, const Key('login-kakao'));
      expect(r.fake.signIns, 1);
      expect(r.analytics.consents.last, isTrue, reason: '필수 동의를 마친 뒤 사용 통계 시작');
      expect(r.owner.step, OwnerStep.name);
      expect(gameShown(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('카카오: 로그인 → 이름 → 캐릭터 → 선택 정보 건너뛰기 → 첫 실행 안내', (tester) async {
      final r = await mountFirstRun(tester);
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(r.owner.profile.account, 'kakao:1001');
      expect(r.owner.profile.consentVersion, requiredConsentVersion);
      // The Kakao nickname fills the name box.
      expect(find.widgetWithText(TextField, '테스터'), findsOneWidget);
      await enterName(tester, '붕');
      expect(find.text('이름은 2~8자로 정해 주세요'), findsOneWidget);
      expect(r.owner.step, OwnerStep.name);
      await enterName(tester, '붕어빵장인');
      expect(r.owner.step, OwnerStep.character);
      expect(r.game.ownerName, '붕어빵장인');
      await tap(tester, const Key('character-boy'));
      await tap(tester, const Key('first-run-character-start'));
      expect(r.shop.state.avatarEquipment['character'], 'boy');
      expect(r.owner.step, OwnerStep.optional);
      await tap(tester, const Key('optional-skip'));
      expect(r.owner.step, OwnerStep.done);
      expect(gameShown(), isTrue);
      // 26번 3차 H6: the welcome story (with the owner name), then the guide.
      expect(find.byWidgetPredicate((w) => w is Text && w.data?.replaceAll('⁠', '') == '어서 오세요, 붕어빵장인 사장님! 환영합니다.'),
          findsOneWidget, reason: '이야기형 안내로 이어짐');
      await tap(tester, const Key('story-skip'));
      expect(find.byKey(const Key('tutorial-card')), findsOneWidget, reason: '2단계 첫 실행 안내로 이어짐');
      // The server profile has the name and the consent, nothing optional.
      final sent = r.fake.accountProfiles['kakao:1001']!;
      expect([sent.name, sent.consentVersion, sent.over14Confirmed, sent.hasOptional],
          ['붕어빵장인', requiredConsentVersion, true, false]);
      expect(r.profiles.stored!['serverSynced'], isTrue);
      // The online sync shows the owner name to friends and rankings.
      await r.game.syncOnline();
      expect(r.fake.name, '붕어빵장인');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('구글로도 같은 흐름으로 시작하고, 구글 계정 id로 저장된다', (tester) async {
      final r = await mountFirstRun(tester);
      await agreeAndLogin(tester, LoginProvider.google);
      expect(r.fake.loginProvider, LoginProvider.google);
      expect(r.owner.profile.account, 'GoogleUid1001');
      expect(r.owner.profile.provider, LoginProvider.google);
      expect(r.game.preferredLogin, LoginProvider.google);
      await enterName(tester, 'Bun8');
      await tap(tester, const Key('first-run-character-start'));
      expect(r.shop.state.avatarEquipment['character'] ?? 'girl', 'girl', reason: '기본은 여자 사장님');
      await tap(tester, const Key('optional-skip'));
      expect(gameShown(), isTrue);
      expect(r.fake.accountProfiles['GoogleUid1001']!.name, 'Bun8');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('구글 클라이언트 ID가 없는 빌드는 카카오 버튼만 보인다', (tester) async {
      final net = backend()..loginProviders = {LoginProvider.kakao};
      await mountFirstRun(tester, online: net);
      expect(find.byKey(const Key('login-kakao')), findsOneWidget);
      expect(find.byKey(const Key('login-google')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('인터넷이 없으면 연결 안내, 다시 시도하면 로그인 화면', (tester) async {
      final r = await mountFirstRun(tester);
      internet = false;
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(r.fake.signIns, 0);
      expect(find.byKey(const Key('first-run-offline')), findsOneWidget);
      expect(find.text(OwnerTexts.offlineTitle), findsOneWidget);
      await tap(tester, const Key('first-run-retry'));
      expect(find.byKey(const Key('first-run-offline')), findsOneWidget, reason: '아직 연결 없음');
      internet = true;
      await tap(tester, const Key('first-run-retry'));
      expect(find.byKey(const Key('login-kakao')), findsOneWidget);
      // A sign-in that fails for the connection also lands on that screen.
      r.fake.offline = true;
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(find.byKey(const Key('first-run-offline')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('시험용 빌드에서 만든 저장은 온라인 로그인에 묶지 않는다', (tester) async {
      final r = await mountFirstRun(tester, before: (shop) async {
        await shop.command(() {
          shop.state.lifetime = BigInt.from(100);
          shop.state.buns = BigInt.from(100);
        });
        final local = LocalTestPurchaseGateway(gold: () => 0, setGold: (_) async => true);
        expect(await shop.purchaseSkill(local, 'tap_1'), isTrue, reason: shop.notice);
      });
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(find.text(OnlineTexts.localTestSave), findsOneWidget);
      expect(r.fake.signedIn, isFalse);
      expect(gameShown(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('로그인을 취소하면 말없이, 실패하면 다시 해 달라고 한다', (tester) async {
      final r = await mountFirstRun(tester);
      r.fake.signInResult = SignInResult.canceled;
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(find.byKey(const Key('first-run-message')), findsNothing);
      r.fake.signInResult = SignInResult.failed;
      await tap(tester, const Key('login-kakao'));
      expect(find.text(OwnerTexts.loginFailed), findsOneWidget);
      expect(gameShown(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('로그인 없이 하던 기존 저장: 로그인 뒤 진행이 그대로이고 캐릭터는 기존 선택이 기본값', (tester) async {
      late Map<String, dynamic> before;
      final r = await mountFirstRun(tester, before: (shop) async {
        expect(await shop.command(() => shop.state.tutorial = 'done'), isTrue);
        for (var i = 0; i < 25; i++) {
          shop.tap();
        }
        // A save from before 3차 피드백 H11 that wore the boy owns him.
        expect(await shop.chooseStarterCharacter('boy'), isTrue);
        expect(shop.state.taps, 25);
        before = shop.state.toJson();
      });
      expect(gameShown(), isFalse, reason: '업데이트 뒤 첫 실행도 로그인 필요');
      await agreeAndLogin(tester, LoginProvider.kakao);
      await enterName(tester, '오래된가게');
      // The picker starts on what the shop already wears.
      final boy = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byKey(const Key('character-boy')), matching: find.byType(AnimatedContainer)));
      expect((boy.decoration as BoxDecoration).border!.top.width, 2, reason: '고른 카드는 주황 2px 테두리(26번 3차)');
      await tap(tester, const Key('first-run-character-start'));
      await tap(tester, const Key('optional-skip'));
      expect(gameShown(), isTrue);
      final after = r.shop.state.toJson();
      for (final key in ['buns', 'taps', 'tutorial', 'avatarEquipment', 'level', 'lifetime']) {
        expect(after[key], before[key], reason: key);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('기기의 가게가 다른 계정에 연결돼 있으면 로그인을 되돌리고 안내한다', (tester) async {
      final r = await mountFirstRun(tester, before: (shop) => shop.command(() => shop.state.rewardAccount = 'kakao:77'));
      await agreeAndLogin(tester, LoginProvider.google);
      expect(r.fake.signedIn, isFalse);
      expect(find.text(OwnerTexts.otherAccount(LoginProvider.kakao)), findsOneWidget);
      expect(r.owner.step, OwnerStep.login);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('전체 동의는 만 14세 이상까지 함께 체크하고, 하나를 풀면 로그인 버튼이 꺼진다', (tester) async {
      final r = await mountFirstRun(tester);
      await tap(tester, const Key('consent-all'));
      expect(tester.widget<Checkbox>(find.descendant(of: find.byKey(const Key('consent-age')), matching: find.byType(Checkbox))).value,
          isTrue);
      await tap(tester, const Key('consent-age'));
      await tap(tester, const Key('login-kakao'));
      expect(r.fake.signIns, 0);
      expect(find.text(OwnerTexts.needAgreement), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('예전 동의(만 14세 이상 확인 전)로 가입한 사용자는 업데이트 뒤 다시 동의해야 게임에 들어간다', (tester) async {
      final net = backend()..signedIn = true..loginProvider = LoginProvider.kakao;
      final r = await mountFirstRun(tester,
          online: net,
          profile: OwnerProfile()
            ..account = 'kakao:1001'
            ..provider = LoginProvider.kakao
            ..consentVersion = '2026-11-18'
            ..consentAtMs = 1
            ..name = '붕어빵'
            ..characterChosen = true
            ..optionalAsked = true
            ..serverSynced = true,
          before: (shop) => shop.command(() => shop.state.tutorial = 'done'));
      expect(r.owner.step, OwnerStep.login);
      expect(gameShown(), isFalse);
      expect(r.analytics.consents, [false], reason: '재동의 전에는 사용 통계를 멈춤');
      await tap(tester, const Key('consent-terms'));
      await tap(tester, const Key('consent-privacy'));
      await tap(tester, const Key('first-run-continue'));
      expect(r.owner.step, OwnerStep.login, reason: '만 14세 이상 체크 없이는 계속할 수 없음');
      await tap(tester, const Key('consent-age'));
      await tap(tester, const Key('first-run-continue'));
      expect(r.owner.step, OwnerStep.done);
      expect(gameShown(), isTrue);
      expect(r.owner.profile.consentVersion, requiredConsentVersion);
      expect(r.analytics.consents.last, isTrue);
      await tester.pump();
      final sent = r.fake.accountProfiles['kakao:1001']!;
      expect([sent.consentVersion, sent.over14Confirmed], [requiredConsentVersion, true]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('이미 로그인해 있던 사용자는 동의만 받고 이름·캐릭터로 간다', (tester) async {
      final net = backend()..signedIn = true..loginProvider = LoginProvider.kakao;
      final r = await mountFirstRun(tester, online: net);
      expect(find.byKey(const Key('login-kakao')), findsNothing);
      await tap(tester, const Key('consent-all'));
      await tap(tester, const Key('first-run-continue'));
      expect(r.fake.signIns, 0);
      expect(r.owner.step, OwnerStep.name);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('온라인 설정이 없는 빌드는 로그인·선택 정보 없이 이름과 캐릭터만', (tester) async {
      final r = await mountFirstRun(tester, online: const NoOnlineBackend());
      expect(r.owner.step, OwnerStep.name);
      await enterName(tester, '개발가게');
      await tap(tester, const Key('character-girl'));
      await tap(tester, const Key('first-run-character-start'));
      expect(r.owner.step, OwnerStep.done);
      expect(gameShown(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('선택 정보 (성별·연령대)', () {
    Future<FirstRun> toOptional(WidgetTester tester) async {
      final r = await mountFirstRun(tester);
      await agreeAndLogin(tester, LoginProvider.kakao);
      await enterName(tester, '붕어빵');
      await tap(tester, const Key('first-run-character-start'));
      expect(r.owner.step, OwnerStep.optional);
      return r;
    }

    testWidgets('선택 동의에 체크해야 저장되고, 서버와 분석 연결 지점에 넘어간다', (tester) async {
      final r = await toOptional(tester);
      await tap(tester, const Key('gender-female'));
      await tap(tester, const Key('age-twenties'));
      await tap(tester, const Key('optional-save'));
      expect(r.owner.step, OwnerStep.optional, reason: '동의 전에는 저장 버튼이 꺼져 있음');
      await tap(tester, const Key('consent-optional'));
      await tap(tester, const Key('optional-save'));
      expect(gameShown(), isTrue);
      final info = r.owner.profile.optional!;
      expect([info.gender, info.ageBand], [PlayerGender.female, AgeBand.twenties]);
      final sent = r.fake.accountProfiles['kakao:1001']!;
      expect([sent.gender, sent.ageBand], ['female', '20s']);
      expect(r.analytics.calls.last, ('female', '20s'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('연령대에 만 14세 미만 항목과 보호자 체크가 없다', (tester) async {
      await toOptional(tester);
      expect(find.byKey(const Key('age-under14')), findsNothing);
      expect(find.byKey(const Key('consent-guardian')), findsNothing);
      expect(find.textContaining('만 14세 미만'), findsNothing);
      expect(find.byKey(const Key('age-teen')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('설정의 계정', () {
    Future<FirstRun> started(WidgetTester tester, {OwnerProfile? profile, bool startOnline = true}) async {
      final net = backend()..signedIn = true..loginProvider = LoginProvider.kakao;
      final r = await mountFirstRun(tester,
          online: net,
          startOnline: startOnline,
          profile: profile ??
              (OwnerProfile()
                ..account = 'kakao:1001'
                ..provider = LoginProvider.kakao
                ..consentVersion = requiredConsentVersion
                ..name = '붕어빵'
                ..characterChosen = true
                ..optionalAsked = true
                ..optional = const OptionalInfo(gender: PlayerGender.male, ageBand: AgeBand.thirties, agreedAtMs: 1)
                ..serverSynced = true),
          before: (shop) => shop.command(() => shop.state.tutorial = 'done'));
      expect(gameShown(), isTrue);
      return r;
    }

    // 4차 피드백 IC10: the game is online-only. No network in tests: the
    // connection is the injected [internet].
    testWidgets('플레이 중 연결이 끊기면 모든 창 위에 알림이 덮이고 가게가 멈춘다, 다시 시도로 이어 한다', (tester) async {
      final r = await started(tester);
      expect(find.byKey(const Key('connection-lost')), findsNothing);
      // A window is open when the connection goes.
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      internet = false;
      await tester.pump(connectionCheckInterval);
      await tester.pump();
      expect(find.byKey(const Key('connection-lost')), findsOneWidget);
      expect(find.text(OnlineTexts.lostTitle), findsOneWidget);
      expect(r.owner.connectionLost, isTrue);
      expect(r.shop.foreground, isFalse, reason: '알림 동안 가게는 멈춤');
      // The notice takes the touches: the menu under it cannot be used.
      expect(find.byKey(const Key('menu-menubar')).hitTestable(), findsNothing);
      await tap(tester, const Key('connection-retry'));
      expect(find.byKey(const Key('connection-lost')), findsOneWidget, reason: '아직 연결 없음');
      internet = true;
      await tap(tester, const Key('connection-retry'));
      await tester.pump();
      expect(find.byKey(const Key('connection-lost')), findsNothing);
      expect(r.shop.foreground, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('연결 없이 시작하면 처음부터 알림', (tester) async {
      final r = await started(tester, startOnline: false);
      expect(find.byKey(const Key('connection-lost')), findsOneWidget);
      expect(r.shop.foreground, isFalse);
      internet = true;
      await tap(tester, const Key('connection-retry'));
      await tester.pump();
      expect(find.byKey(const Key('connection-lost')), findsNothing);
      expect(r.shop.foreground, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('설정'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('메뉴 창 위에 이름이 보이고, 설정에서 이름을 바꾼다', (tester) async {
      final r = await started(tester);
      await tester.tap(find.byKey(const Key('menu-menubar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(OwnerTexts.shopOf('붕어빵')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('menu-owner-name')))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      await openSettings(tester);
      expect(find.text('${OwnerTexts.ownerName}: 붕어빵'), findsOneWidget);
      expect(find.text(OwnerTexts.loggedInWith(LoginProvider.kakao)), findsOneWidget);
      await tap(tester, const Key('settings-rename'));
      await tester.enterText(find.descendant(of: find.byKey(const Key('rename-dialog')), matching: find.byType(TextField)), '병신');
      await tap(tester, const Key('rename-save'));
      // The problem shows in small red under the box (26번 3차 H4).
      expect(find.descendant(of: find.byKey(const Key('rename-dialog')), matching: find.text('다른 이름을 써 주세요')),
          findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const Key('rename-dialog')), matching: find.byType(TextField)), '새가게');
      await tap(tester, const Key('rename-save'));
      expect(r.owner.profile.name, '새가게');
      expect(r.fake.accountProfiles['kakao:1001']!.name, '새가게');
      expect(find.text('${OwnerTexts.ownerName}: 새가게'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('성별·연령대만 따로 지운다', (tester) async {
      final r = await started(tester);
      await openSettings(tester);
      expect(find.text('${OwnerTexts.optionalInfo}: 남성 · 30대'), findsOneWidget);
      await tap(tester, const Key('settings-optional-clear'));
      expect(r.owner.profile.optional, isNull);
      expect(r.owner.profile.name, '붕어빵', reason: '이름은 그대로');
      expect(r.fake.accountProfiles['kakao:1001']!.hasOptional, isFalse);
      expect(r.analytics.calls.last, (null, null));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('로그아웃하면 로그인 화면, 같은 계정으로 다시 들어오면 바로 게임', (tester) async {
      final r = await started(tester);
      await openSettings(tester);
      await tap(tester, const Key('settings-logout'));
      await tap(tester, const Key('logout-confirm'));
      expect(r.fake.signedIn, isFalse);
      expect(gameShown(), isFalse);
      expect(find.byKey(const Key('login-kakao')), findsOneWidget);
      await agreeAndLogin(tester, LoginProvider.kakao);
      expect(r.owner.step, OwnerStep.done);
      expect(gameShown(), isTrue);
      expect(r.owner.profile.name, '붕어빵');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('계정 삭제: 확인 체크 뒤 서버 계정을 지우고 첫 실행으로 돌아간다', (tester) async {
      final r = await started(tester);
      var wiped = 0;
      r.owner.onDeleted = () async => wiped++;
      await openSettings(tester);
      await tap(tester, const Key('settings-delete-account'));
      expect(find.text(OwnerTexts.deleteTitle), findsOneWidget);
      await tap(tester, const Key('delete-confirm'));
      expect(r.fake.deletedAccounts, isEmpty, reason: '확인 체크 전에는 지우지 않음');
      await tap(tester, const Key('delete-check'));
      await tap(tester, const Key('delete-confirm'));
      expect(r.fake.deletedAccounts, ['kakao:1001']);
      expect(r.fake.accountProfiles, isEmpty);
      expect(r.fake.signedIn, isFalse);
      expect(r.profiles.stored, isNull, reason: '기기의 사장님 정보도 지움');
      expect(wiped, 1, reason: '기기 저장 삭제 후 다시 시작(main)');
      expect(gameShown(), isFalse);
      expect(find.byKey(const Key('login-kakao')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('인터넷이 없으면 계정을 지우지 않고 알려 준다', (tester) async {
      final r = await started(tester);
      await openSettings(tester);
      internet = false;
      await tap(tester, const Key('settings-delete-account'));
      await tap(tester, const Key('delete-check'));
      await tap(tester, const Key('delete-confirm'));
      expect(r.fake.deletedAccounts, isEmpty);
      expect(find.text(OwnerTexts.deleteOffline), findsOneWidget);
      expect(gameShown(), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('다른 작업 중이면 계정도 기기 저장도 지우지 않는다', (tester) async {
      final r = await started(tester);
      var wiped = 0;
      r.owner.onDeleted = () async => wiped++;
      r.owner.busy = true;
      expect(await r.owner.deleteAccount(), OwnerTexts.deleteFailed);
      expect(r.fake.deletedAccounts, isEmpty);
      expect(wiped, 0);
      expect(r.profiles.stored, isNotNull);
      r.owner.busy = false;
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('앱 안 약관·개인정보처리방침은 문서 폴더 원본과 같다', () {
    const docs = '../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/'
        '2.1.3_legacy_code_policies_and_online_setup';
    for (final name in ['privacy_policy.md', 'terms_of_service.md']) {
      expect(File('assets/legal/$name').readAsStringSync(), File('$docs/$name').readAsStringSync(), reason: name);
    }
  });

  test('약관·방침 미리보기는 표·목록·제목을 읽을 수 있는 줄로 바꾼다', () {
    final lines = markdownLines('# 제목\n\n| a | b |\n| --- | --- |\n| **c** | [d](https://x) |\n- 하나\n본문 `코드`');
    final texts = [for (final w in lines) ((w as Padding).child as Text).data];
    expect(texts, ['제목', 'a · b', 'c · d (https://x)', '• 하나', '본문 코드']);
  });
}
