/** 26번 3단계(DEC-041): 실제 설정의 tap_1~4·auto_1~4는 황금 0이다.
 * 황금 홀드·환불·잔액 부족 흐름을 계속 검사하려고, 결제 흐름 테스트는
 * tap_1만 예전처럼 황금 1로 둔 사본을 쓴다. 실제 설정의 무료 구매는
 * development_contracts.test.ts·composite_purchases.test.ts가 따로 검사한다. */
export function withPaidTap1<T>(config: T): T {
  const copy = structuredClone(config) as unknown as { skill_purchase: { entries: { tap_1: { gold: number } } } };
  copy.skill_purchase.entries.tap_1.gold = 1;
  return copy as unknown as T;
}
