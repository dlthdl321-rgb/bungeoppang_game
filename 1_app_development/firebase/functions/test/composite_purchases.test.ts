import assert from "node:assert/strict";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { withPaidTap1 } from "./paid_skill_fixture";
const realConfig = JSON.parse(readFileSync(resolve(__dirname, "../../../../config/development_balance.json"), "utf8"));
// 결제 흐름 검사용: tap_1만 황금 1(실제 설정은 DEC-041로 0).
const config = withPaidTap1(realConfig);
import { claimDevelopmentProgress } from "../src/active_progress";
import { PurchaseContext, PurchaseEvidenceVerifier, purchaseFingerprint,
  reserveCompositePurchase, finishCompositePurchase, queryCompositePurchase } from "../src/composite_purchases";
import { CompositeIntent, validateDevelopmentCompositeQuote } from "../src/development_contracts";
import { MemoryStore } from "../src/store";

const ctx: PurchaseContext = { account: "a", progress: "progress_0001", epoch: 1 };
function intent(id = "transaction_0001"): CompositeIntent {
  return { account: "a", transaction: id, revision: config.metadata.revision,
    skill: "tap_1", owned: 0, quantity: 1, buns: "20", gold: "1" };
}
const verifier: PurchaseEvidenceVerifier = { verify: async (context, value, phase) => ({
  account: context.account, progress: context.progress, transaction: value.transaction,
  fingerprint: purchaseFingerprint(value), phase, snapshotDigest: `protected-${phase}`,
  availableBuns: "100", lifetimeBuns: "100" }) };
async function setup() {
  const store = new MemoryStore(); store.docs.set("users/a", { gold: 5, nickname: "유지" });
  await claimDevelopmentProgress(store, ctx.account, ctx.progress); return store;
}
test("예약 재시도는 황금1회 홀드, 확정 재시도는 소유1회 반영", async () => {
  const store = await setup(), value = intent();
  const reserved = await reserveCompositePurchase(store, config, verifier, ctx, value);
  assert.equal(reserved.status, "reserved");
  assert.deepEqual(await reserveCompositePurchase(store, config, verifier, ctx, value), reserved);
  assert.equal(store.docs.get("users/a")!.gold, 4);
  const committed = await finishCompositePurchase(store, verifier, ctx, value, "commit");
  assert.equal(committed.status, "committed");
  assert.deepEqual(await finishCompositePurchase(store, verifier, ctx, value, "commit"), committed);
  assert.deepEqual(await finishCompositePurchase(store, verifier, ctx, value, "cancel"), committed);
  assert.equal(store.docs.get("users/a/compositeSkills/tap_1")!.owned, 1);
  assert.equal(store.docs.get("users/a")!.nickname, "유지");
});
test("취소 재시도와 뒤늦은 확정은 홀드1회만 복원하고 상품을 지급하지 않는다", async () => {
  const store = await setup(), value = intent();
  await reserveCompositePurchase(store, config, verifier, ctx, value);
  const canceled = await finishCompositePurchase(store, verifier, ctx, value, "cancel");
  assert.deepEqual(await finishCompositePurchase(store, verifier, ctx, value, "cancel"), canceled);
  assert.deepEqual(await finishCompositePurchase(store, verifier, ctx, value, "commit"), canceled);
  assert.equal(store.docs.get("users/a")!.gold, 5);
  assert.equal(store.docs.has("users/a/compositeSkills/tap_1"), false);
});
test("활성 진행/차감 검증이 없으면 지갑을 변경하지 않는다", async () => {
  const store = await setup(), value = intent();
  await assert.rejects(reserveCompositePurchase(store, config, verifier, { ...ctx, epoch: 2 }, value));
  const broken: PurchaseEvidenceVerifier = { verify: async (c,v,p) => ({ ...await verifier.verify(c,v,p), fingerprint:"forged" }) };
  await assert.rejects(reserveCompositePurchase(store, config, broken, ctx, value));
  assert.equal(store.docs.get("users/a")!.gold, 5);
  await reserveCompositePurchase(store, config, verifier, ctx, value);
  await assert.rejects(finishCompositePurchase(store, broken, ctx, value, "commit"));
  assert.equal((await queryCompositePurchase(store,ctx,value.transaction)).status, "reserved");
});
test("미정산 동시 거래·변조 견적·잔액 부족은 추가 홀드하지 않는다", async () => {
  const store = await setup();
  await assert.rejects(reserveCompositePurchase(store, config, verifier, ctx, { ...intent(), buns:"1" }));
  await reserveCompositePurchase(store, config, verifier, ctx, intent());
  await assert.rejects(reserveCompositePurchase(store, config, verifier, ctx, intent("transaction_0002")));
  assert.equal(store.docs.get("users/a")!.gold, 4);
  await finishCompositePurchase(store, verifier, ctx, intent(), "cancel");
  store.docs.set("users/a", { gold:0 });
  await assert.rejects(reserveCompositePurchase(store, config, verifier, ctx, intent("transaction_0002")));
});
test("알 수 없는 거래 조회는 환불/취소를 만들지 않고 동일 ID를 돌려준다", async () => {
  const store = await setup();
  assert.deepEqual(await queryCompositePurchase(store, ctx, intent().transaction),
    { account:"a", transaction:intent().transaction, status:"unknown" });
  assert.equal(store.docs.get("users/a")!.gold, 5);
});

// 26번 3단계(DEC-041): 실제 설정은 1~4단계 스킬이 황금 0, 5단계부터 그대로 유료.
test("실제 설정: 1~4단계 스킬은 몇 번째든 황금 0, 5단계는 기존 황금 가격", () => {
  const base = { account: "a", transaction: "transaction_0009", revision: realConfig.metadata.revision };
  const free = { ...base, skill: "tap_1", owned: 10, quantity: 1, buns: "403", gold: "0" };
  assert.deepEqual(validateDevelopmentCompositeQuote(realConfig, free, "a", 10), free);
  assert.throws(() => validateDevelopmentCompositeQuote(realConfig, { ...free, gold: "1" }, "a", 10));
  const bundle = { ...base, skill: "tap_1", owned: 0, quantity: 12, buns: "2042", gold: "0" };
  assert.deepEqual(validateDevelopmentCompositeQuote(realConfig, bundle, "a", 0), bundle);
  for (const id of ["tap_1", "tap_2", "tap_3", "tap_4", "auto_1", "auto_2", "auto_3", "auto_4"]) {
    assert.equal(realConfig.skill_purchase.entries[id].gold, 0, id);
  }
  const paid = { ...base, skill: "tap_5", owned: 9, quantity: 2, buns: "1400013", gold: "5" };
  assert.deepEqual(validateDevelopmentCompositeQuote(realConfig, paid, "a", 9), paid);
  assert.throws(() => validateDevelopmentCompositeQuote(realConfig, { ...paid, gold: "0" }, "a", 9));
});
test("실제 설정: 황금 0 스킬은 지갑을 건드리지 않고 예약·확정된다", async () => {
  const store = await setup();
  const value = { ...intent("transaction_0010"), gold: "0" };
  const reserved = await reserveCompositePurchase(store, realConfig, verifier, ctx, value);
  assert.equal(reserved.status, "reserved");
  assert.equal(store.docs.get("users/a")!.gold, 5);
  assert.equal((await finishCompositePurchase(store, verifier, ctx, value, "commit")).status, "committed");
  assert.equal(store.docs.get("users/a")!.gold, 5);
  assert.equal(store.docs.get("users/a/compositeSkills/tap_1")!.owned, 1);
});
