import 'cooking_session.dart';
import 'workshop_controller.dart';

/// One step of the first-run guide (첫 실행 안내): what to do next and the
/// widget key the overlay points at. Derived from the saved state each frame,
/// so only the `cook`/`sell` stage itself is persisted.
class WorkshopTutorialStep {
  final int number;
  final String text, target;
  /// When set, the card sits below this widget instead of beside [target]:
  /// mold steps keep it under the whole stage, clear of the mold's buttons.
  final String? below;
  const WorkshopTutorialStep(this.number, this.text, this.target, {this.below});
}

const _stage = 'workshop-center-stage';

const workshopTutorialSteps = 7;

/// The step for [s], or null when the guide is finished or skipped.
/// [ready] is how many stock items the sale button would hand over now.
WorkshopTutorialStep? workshopTutorialStep(WorkshopState s, {required int ready}) {
  if (!s.tutorialActive || s.customerScene != null) return null;
  final session = s.session;
  if (session != null) {
    return switch (session.phase) {
      CookingPhase.firstBatter => const WorkshopTutorialStep(2, '틀 위를 문질러 반죽을 칠하듯 부어요. 붕어빵 모양을 고르게 덮고 손을 떼요.', 'workshop-mold', below: _stage),
      CookingPhase.filling => const WorkshopTutorialStep(3, '틀 위를 문질러 속을 짜 넣어요.', 'workshop-mold', below: _stage),
      CookingPhase.secondBatter => const WorkshopTutorialStep(4, '반죽을 한 번 더 문질러 속을 덮어요.', 'workshop-mold', below: _stage),
      CookingPhase.closing => const WorkshopTutorialStep(4, '뚜껑을 닫아요.', 'workshop-mold', below: _stage),
      CookingPhase.flipping => const WorkshopTutorialStep(5, '틀 둘레에 손가락으로 원을 그리면 틀이 돌아가며 뒤집혀요.', 'workshop-mold', below: _stage),
      CookingPhase.cooking => const WorkshopTutorialStep(6, '노릇하게 익었다 싶을 때 꺼내요.', 'workshop-mold', below: _stage),
      CookingPhase.result => session.practice
          ? const WorkshopTutorialStep(6, "완성! '보관'을 눌러 판매할 재고로 넣어요.", 'mold-store', below: _stage)
          : const WorkshopTutorialStep(6, "완성! '결과 닫기'를 누르면 재고에 들어가요.", 'mold-store', below: _stage),
      CookingPhase.canceled => null,
    };
  }
  if (s.tutorial == 'cook') {
    if (!s.business.open) {
      return const WorkshopTutorialStep(1, '스페셜 붕어빵 틀을 눌러 굽기 연습을 시작해요.', 'workshop-mold', below: _stage);
    }
    // Opened before the first bake: practice is closed in business
    // (DEC-035), so the first bungeoppang is an order (DEC-037).
    if (s.customers.isEmpty) {
      return const WorkshopTutorialStep(1, '영업 중에는 손님 주문을 받아 구워요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.', 'workshop-clicker');
    }
    return ready > 0
        ? const WorkshopTutorialStep(1, '구운 붕어빵을 손님에게 판매해요.', 'sale-button')
        : const WorkshopTutorialStep(1, '손님을 눌러 주문 제작으로 바로 구워요.', 'customer-0');
  }
  if (!s.business.open) {
    return const WorkshopTutorialStep(7, "'영업 시작'을 눌러 가게 문을 열어요.", 'business-open');
  }
  if (s.customers.isEmpty) {
    return const WorkshopTutorialStep(7, '첫 손님을 기다려요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.', 'workshop-clicker');
  }
  return ready > 0
      ? const WorkshopTutorialStep(7, '구운 붕어빵을 손님에게 판매해요.', 'sale-button')
      : const WorkshopTutorialStep(7, '모자란 맛은 손님을 눌러 주문 제작으로 바로 구워요.', 'customer-0');
}

/// 26번 3차 H6: a short story told before a guide stage, line by line in
/// the middle of the home (환영 → 무엇을 하는 가게인지 → 연습 권유), so the
/// first run reads like an opening instead of bare instructions. Not saved:
/// a chapter shows once per app run while its stage waits for the player.
enum WorkshopStoryChapter {
  /// Before the practice bake (stage `cook`, closed, nothing on the mold).
  welcome,
  /// After the practice is kept (stage `sell`, still closed).
  open,
}

/// The chapter for [s] now, or null: only while the guide waits on the
/// closed stall with nothing being baked or talked through.
WorkshopStoryChapter? workshopStoryChapter(WorkshopState s) {
  if (!s.tutorialActive || s.customerScene != null || s.session != null || s.business.open) return null;
  return s.tutorial == 'cook' ? WorkshopStoryChapter.welcome : WorkshopStoryChapter.open;
}

/// The lines of [chapter]; [owner] is the owner name, if any.
List<String> workshopStoryLines(WorkshopStoryChapter chapter, String? owner) {
  final name = owner == null || owner.trim().isEmpty ? '사장님' : '${owner.trim()} 사장님';
  return switch (chapter) {
    WorkshopStoryChapter.welcome => [
        '어서 오세요, $name! 환영합니다.',
        '우리는 오늘부터 이 작은 노점에서 따끈한 붕어빵을 팔 거예요.',
        '손님을 맞기 전에, 먼저 붕어빵 굽기 연습을 해 볼까요?',
      ],
    WorkshopStoryChapter.open => [
        '잘 구웠어요! 이 정도면 손님에게 내놓아도 되겠어요.',
        '이제 가게 문을 열고 첫 손님에게 붕어빵을 팔아 볼까요?',
      ],
  };
}

/// The last line's button.
String workshopStoryAction(WorkshopStoryChapter chapter) => switch (chapter) {
      WorkshopStoryChapter.welcome => '연습해 볼게요',
      WorkshopStoryChapter.open => '좋아요',
    };
