import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import { MemoryStore } from "../src/store";
import {
  DevelopmentAdPolicy, assertSameCompositeIntent, developmentAdPolicy,
  queryDevelopmentAd, queryDevelopmentRewardDecision,
  parseCompositeIntent, validateDevelopmentCompositeQuote, recordDevelopmentAdVerification,
  recordDevelopmentRewardDecision, reserveDevelopmentAd,
} from "../src/development_contracts";

const policy: DevelopmentAdPolicy = { revision: "draft", gold: 1, limit: 2, offsetMinutes: 540 };
const now = Date.UTC(2026, 9, 16, 14, 59);
const proof = (attempt: string, transaction = "provider-transaction-1") => ({
  provider: "test-verifier", transaction, account: "a", attempt, revision: "draft",
});

test("실제 공통 JSON의 광고 정책을 읽고 확정 한도 변경을 거부한다", () => {
  const config = JSON.parse(readFileSync(resolve(__dirname, "../../../../config/development_balance.json"), "utf8"));
  assert.equal(developmentAdPolicy(config).gold, config.rewarded_ads.gold_per_verified_view);
  config.fixed_requirements.rewarded_ads_per_account_day = 3;
  assert.throws(() => developmentAdPolicy(config));
});

test("두 비용 견적은 계정·정수·10진 문자열을 검사한다", () => {
  const value = { account: "a", transaction: "purchase_1", revision: "draft", skill: "tap_1",
    owned: 0, quantity: 1, buns: "15", gold: "1" };
  const parsed = parseCompositeIntent(value, "a");
  assert.throws(() => parseCompositeIntent(value, "b"));
  assert.throws(() => parseCompositeIntent({ ...value, quantity: 1.5 }, "a"));
  assert.throws(() => parseCompositeIntent({ ...value, gold: "01" }, "a"));
  assert.throws(() => parseCompositeIntent({ ...value, buns: "0" }, "a"));
  assert.throws(() => assertSameCompositeIntent(parsed, { ...parsed, owned: 1 }));
});

test("한 계정2회 예약, 다른 기기는 같은 한도, 자정 재시도는 원래 날짜", async () => {
  const store = new MemoryStore();
  const first = await reserveDevelopmentAd(store, "a", "attempt_1", now, policy);
  await reserveDevelopmentAd(store, "a", "attempt_2", now, policy);
  await assert.rejects(reserveDevelopmentAd(store, "a", "attempt_3", now, policy));
  const nextDay = Date.UTC(2026, 9, 16, 15);
  const retry = await reserveDevelopmentAd(store, "a", "attempt_1", nextDay, { ...policy, gold: 7 });
  assert.deepEqual(retry, first);
  assert.equal(retry.day, "2026-10-16");
  assert.equal(retry.gold, 1);
  assert.deepEqual(await queryDevelopmentAd(store, "a", "attempt_1"), first);
  assert.equal(await queryDevelopmentAd(store, "b", "missing_1"), undefined);
  const fresh = await reserveDevelopmentAd(store, "a", "attempt_3", nextDay, policy);
  assert.equal(fresh.day, "2026-10-17");
  await reserveDevelopmentAd(store, "b", "attempt_1", now, policy);
});

test("검증 대기는 슬롯을 유지하고 최종 거절 뒤 늦은 성공은 차단한다", async () => {
  const store = new MemoryStore();
  await reserveDevelopmentAd(store, "a", "attempt_1", now, policy);
  await reserveDevelopmentAd(store, "a", "attempt_2", now, policy);
  await recordDevelopmentAdVerification(store, "a", "attempt_1", "pending");
  await assert.rejects(reserveDevelopmentAd(store, "a", "attempt_3", now, policy));
  await recordDevelopmentAdVerification(store, "a", "attempt_1", "rejectedFinal");
  await recordDevelopmentAdVerification(store, "a", "attempt_1", "rejectedFinal");
  await reserveDevelopmentAd(store, "a", "attempt_3", now, policy);
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible", proof("attempt_1")));
});

test("검증 성공 중복은 같은 결과, 취소 역행이나 지갑 선지급은 없다", async () => {
  const store = new MemoryStore();
  await reserveDevelopmentAd(store, "a", "attempt_1", now, policy);
  const first = await recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible", proof("attempt_1"));
  assert.deepEqual(await recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible", proof("attempt_1")), first);
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_1", "rejectedFinal"));
  assert.equal(store.docs.has("users/a"), false);
});

test("미당첨도 최종 저장하고 같은 판매를 다시 당첨으로 바꾸지 않는다", async () => {
  const store = new MemoryStore();
  const result = { account: "a", evidence: "sale_001", kind: "sale" as const,
    revision: "draft", fingerprint: "stable-evidence", outcome: "noWin" as const };
  await recordDevelopmentRewardDecision(store, result);
  assert.deepEqual(await queryDevelopmentRewardDecision(store, "a", "sale", "sale_001", "draft", "stable-evidence"), result);
  await assert.rejects(queryDevelopmentRewardDecision(store, "a", "sale", "sale_001", "draft", "changed"));
  assert.deepEqual(await recordDevelopmentRewardDecision(store, result), result);
  await assert.rejects(recordDevelopmentRewardDecision(store, { ...result, outcome: "eligible" }));
  await assert.rejects(recordDevelopmentRewardDecision(store, { ...result, fingerprint: "other" }));
  await assert.rejects(recordDevelopmentRewardDecision(store, { ...result, kind: "rewardedAd" }));
  assert.equal(store.docs.has("users/a"), false);
});

test("손상된 한도 원장은 기본값으로 덮지 않는다", async () => {
  const store = new MemoryStore();
  store.docs.set("users/a/developmentAdDays/2026-10-16", { slots: ["attempt_1", "attempt_1"] });
  await assert.rejects(reserveDevelopmentAd(store, "a", "attempt_2", now, policy));
  assert.equal(store.docs.has("users/a/developmentAdAttempts/attempt_2"), false);
});

test("서버 가격은 개별 올림하고 요청의 회차/버전/두 비용을 신뢰하지 않는다", () => {
  const config = { metadata: { revision: "draft" }, skill_purchase: {
    max_owned_per_skill: 1000, gold_step_purchase_count: 10, gold_step_amount: 1,
    entries: { tap_1: { buns: "15", gold: 1, ratio_numerator: 115, ratio_denominator: 100 } } } };
  const value = { account: "a", transaction: "purchase_1", revision: "draft", skill: "tap_1",
    owned: 0, quantity: 2, buns: "33", gold: "2" };
  assert.deepEqual(validateDevelopmentCompositeQuote(config, value, "a", 0), value);
  for (const change of [{ buns: "32" }, { gold: "1" }, { revision: "old" }]) {
    assert.throws(() => validateDevelopmentCompositeQuote(config, { ...value, ...change }, "a", 0));
  }
  assert.throws(() => validateDevelopmentCompositeQuote(config, value, "a", 1));
  assert.throws(() => validateDevelopmentCompositeQuote(config, value, "a", 1000));
});

test("같은 업체 거래를 다른 시도에 재사용하거나 증거 없이 성공시키지 않는다", async () => {
  const store = new MemoryStore();
  await reserveDevelopmentAd(store, "a", "attempt_1", now, policy);
  await reserveDevelopmentAd(store, "a", "attempt_2", now, policy);
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible"));
  await recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible", proof("attempt_1"));
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_2", "eligible", proof("attempt_2")));
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_1", "eligible", proof("attempt_1", "changed-proof")));
  await assert.rejects(recordDevelopmentAdVerification(store, "a", "attempt_2", "eligible", { ...proof("attempt_2"), account: "b" }));
});
