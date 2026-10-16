import assert from "node:assert/strict";
import { test } from "node:test";
import { MemoryStore } from "../src/store";
import { creditVerifiedEarnedGold, EarnedGoldVerifier, VerifiedEarnedGold } from "../src/earned_gold";

test("검증된 미션 황금은 서버 지갑에1회만 반영하고 기존 필드는 보존한다", async () => {
  const store = new MemoryStore();
  store.docs.set("users/a", { gold: 7, nickname: "붕어" });
  const value: VerifiedEarnedGold = { account: "a", claimId: "daily:day:taps", kind: "mission",
    revision: "draft", fingerprint: "stable-evidence", gold: 1 };
  const verifier: EarnedGoldVerifier = { verify: async () => value };
  assert.deepEqual(await creditVerifiedEarnedGold(store, verifier, "a", value.claimId, 1), { gold: 8, added: 1 });
  assert.deepEqual(await creditVerifiedEarnedGold(store, verifier, "a", value.claimId, 2), { gold: 8, added: 0 });
  assert.equal(store.docs.get("users/a")!.nickname, "붕어");
  const changed = { verify: async () => ({ ...value, gold: 2 }) };
  await assert.rejects(creditVerifiedEarnedGold(store, changed, "a", value.claimId, 3));
});
test("다른 계정·손상 지갑·유효하지 않은 지급량은 황금을 생성하지 않는다", async () => {
  const store = new MemoryStore();
  const value: VerifiedEarnedGold = { account: "b", claimId: "sale:1", kind: "sale",
    revision: "draft", fingerprint: "evidence", gold: 1 };
  await assert.rejects(creditVerifiedEarnedGold(store, { verify: async () => value }, "a", "sale:1", 1));
  assert.equal(store.docs.has("users/a"), false);
  store.docs.set("users/b", { gold: -1 });
  await assert.rejects(creditVerifiedEarnedGold(store, { verify: async () => value }, "b", "sale:1", 1));
});
