import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { creditVerifiedEarnedGold } from "../src/earned_gold";
import { MemoryStore } from "../src/store";
import { reviewAndCreditSale, querySaleReward, SaleRewardVerifier,
  saleRewardKstDay, VerifiedSaleRewardEvidence } from "../src/sale_rewards";

const config = { metadata:{ revision:"test-balance" },rare_gold_sale:{
  probability_basis_points_by_stars:[10000,10000,10000,10000,10000],
  gold_per_award:1,daily_gold_cap:1,one_draw_per_sale:1,maximum_gold_per_sale:1 } };
const key = new Uint8Array(32).fill(7);
const verifier: SaleRewardVerifier = { verify:async (account,saleId) => ({ account,saleId,progress:"progress_0001",
  revision:"sale-revision",fingerprint:`evidence-${saleId}`,status:"verified",stars:3 }) };
const at = Date.UTC(2026,9,16);
test("판매 결과·일일 누적·기존 황금 지갑은 한 번만 반영하고 재시도는 원래 결과다", async () => {
  const store = new MemoryStore(); store.docs.set("users/a",{ gold:4,nickname:"유지" });
  const result = await reviewAndCreditSale(store,verifier,config,key,"a","sale_0001",() => at);
  assert.equal(result.outcome,"eligible");
  const failed: SaleRewardVerifier = { verify:async () => { throw new Error("must not reverify a final result"); } };
  assert.deepEqual(await reviewAndCreditSale(store,failed,{},new Uint8Array(),"a","sale_0001",() => at+86400000),result);
  assert.equal(store.docs.get("users/a")!.gold,5);
  assert.equal(store.docs.get("users/a")!.nickname,"유지");
});
test("일일 상한 초과와 미당첨 결과는 다음 날 재시도해도 다시 추첨하지 않는다", async () => {
  const store = new MemoryStore();
  await reviewAndCreditSale(store,verifier,config,key,"a","sale_0001",() => at);
  const capped = await reviewAndCreditSale(store,verifier,config,key,"a","sale_0002",() => at);
  assert.equal(capped.outcome,"noWin");
  assert.equal((await querySaleReward(store,"a","sale_0002"))!.reason,"dailyCap");
  assert.deepEqual(await reviewAndCreditSale(store,verifier,config,key,"a","sale_0002",() => at+86400000),capped);
  const losing = { ...config,rare_gold_sale:{ ...config.rare_gold_sale,probability_basis_points_by_stars:[0,0,0,0,0] } };
  const lost = await reviewAndCreditSale(store,verifier,losing,key,"a","sale_0003",() => at+86400000);
  assert.equal(lost.outcome,"noWin");
  assert.equal(store.docs.get("users/a")!.gold,1);
});
test("검증 대기는 추첨·결과 확정·지급을 만들지 않고 검증 불가는 영구 무지급이다", async () => {
  const store = new MemoryStore();
  let status: VerifiedSaleRewardEvidence["status"] = "pending";
  const waiting: SaleRewardVerifier = { verify:async (a,s) => ({ ...await verifier.verify(a,s),status }) };
  assert.deepEqual(await reviewAndCreditSale(store,waiting,config,key,"a","sale_0001",() => at),{ outcome:"pending" });
  assert.equal(await querySaleReward(store,"a","sale_0001"),null);
  status = "unverifiable";
  const rejected = await reviewAndCreditSale(store,waiting,config,key,"a","sale_0001",() => at);
  assert.equal(rejected.outcome,"unverifiable");
  assert.equal(store.docs.has("users/a"),false);
  status = "verified";
  assert.deepEqual(await reviewAndCreditSale(store,waiting,config,key,"a","sale_0001",() => at+86400000),rejected);
});
test("다른 계정 증거·추첨 키 누락·지급 원장만 남은 손상은 지급하지 않는다", async () => {
  const store = new MemoryStore();
  const other: SaleRewardVerifier = { verify:async (a,s) => ({ ...await verifier.verify(a,s),account:"other" }) };
  await assert.rejects(reviewAndCreditSale(store,other,config,key,"a","sale_0001",() => at));
  await assert.rejects(reviewAndCreditSale(store,verifier,config,new Uint8Array(1),"a","sale_0001",() => at));
  assert.equal(store.docs.size,0);
  const digest = createHash("sha256").update(JSON.stringify(["sale","sale_0001"])).digest("hex");
  store.docs.set(`users/a/ledger/earned_${digest}`,{ gold:1 });
  await assert.rejects(reviewAndCreditSale(store,verifier,config,key,"a","sale_0001",() => at));
  assert.equal(store.docs.has("users/a"),false);
  assert.equal(await querySaleReward(store,"a","sale_0001"),null);
});

test("최초 심사일은 검증 대기 후 KST 자정 경계이며 판매일·광고 시작일과 별개다", async () => {
  assert.equal(saleRewardKstDay(Date.UTC(2026,9,16,14,59,59)),"2026-10-16");
  assert.equal(saleRewardKstDay(Date.UTC(2026,9,16,15)),"2026-10-17");
  const store = new MemoryStore(); let now = Date.UTC(2026,9,16,14,59,59);
  const delayed: SaleRewardVerifier = { verify:async (a,s) => {
    now = Date.UTC(2026,9,16,15); return verifier.verify(a,s);
  } };
  await reviewAndCreditSale(store,delayed,config,key,"a","sale_0001",() => now);
  assert.equal((await querySaleReward(store,"a","sale_0001"))!.day,"2026-10-17");
});

test("일반 검증 지급 코어와 판매 지급 코어는 동일 earned ID를 공유해 중복 지급하지 않는다", async () => {
  const store = new MemoryStore();
  await reviewAndCreditSale(store,verifier,config,key,"a","sale_0001",() => at);
  const receipt = (await querySaleReward(store,"a","sale_0001"))!;
  const repeated = await creditVerifiedEarnedGold(store,{ verify:async () => ({ account:"a",claimId:"sale_0001",kind:"sale",
    revision:receipt.revision,fingerprint:receipt.fingerprint,gold:receipt.gold }) },"a","sale_0001",at);
  assert.equal(repeated.added,0); assert.equal(repeated.gold,1);
});
