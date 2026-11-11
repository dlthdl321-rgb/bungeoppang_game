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
      CookingPhase.firstBatter => const WorkshopTutorialStep(2, '큰 틀을 길게 누르고 있으면 반죽이 부어져요. 알맞을 때 손을 떼요.', 'workshop-mold', below: _stage),
      CookingPhase.filling => const WorkshopTutorialStep(3, '짤주머니를 눌러 속을 짜 넣어요.', 'workshop-mold', below: _stage),
      CookingPhase.secondBatter => const WorkshopTutorialStep(4, '반죽을 한 번 더 부어 속을 덮어요.', 'workshop-mold', below: _stage),
      CookingPhase.closing => const WorkshopTutorialStep(4, '뚜껑을 닫아요.', 'workshop-mold', below: _stage),
      CookingPhase.flipping => const WorkshopTutorialStep(5, '틀을 뒤집어 반대쪽도 구워요.', 'workshop-mold', below: _stage),
      CookingPhase.cooking => const WorkshopTutorialStep(6, '노릇하게 익었다 싶을 때 꺼내요.', 'workshop-mold', below: _stage),
      CookingPhase.result => session.practice
          ? const WorkshopTutorialStep(6, "완성! '보관'을 눌러 판매할 재고로 넣어요.", 'mold-store', below: _stage)
          : const WorkshopTutorialStep(6, "완성! '결과 닫기'를 누르면 재고에 들어가요.", 'mold-store', below: _stage),
      CookingPhase.canceled => null,
    };
  }
  if (s.tutorial == 'cook') {
    return const WorkshopTutorialStep(1, '큰 틀을 눌러 붕어빵 굽기 연습을 시작해요.', 'workshop-mold', below: _stage);
  }
  if (!s.business.open) {
    return const WorkshopTutorialStep(7, "'영업 시작'을 눌러 가게 문을 열어요.", 'business-open');
  }
  if (s.customers.isEmpty) {
    return const WorkshopTutorialStep(7, '첫 손님을 기다려요. 손님은 왼쪽 줄에 서요.', 'sale-counter');
  }
  return ready > 0
      ? const WorkshopTutorialStep(7, '구운 붕어빵을 손님에게 판매해요.', 'sale-button')
      : const WorkshopTutorialStep(7, '모자란 맛은 주문 제작으로 바로 구워요.', 'order-produce');
}
