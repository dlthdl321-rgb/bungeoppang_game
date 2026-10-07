import assert from "node:assert/strict";
import { test } from "node:test";
import { Catalog } from "../src/catalog";
import { MemoryStore } from "../src/store";
import { PlayPurchases, WalletError, redeemPurchase, spendGold, syncWallet } from "../src/wallet";

const catalog: Catalog = {
  version: "test",
  packageName: "com.example",
  products: [{ id: "gold_60", gold: 60 }],
  spend: { cosmetic: { beanie: 15 }, skill: { tap_4: 40 }, boost: { bought: 20 } },
};

function fakePlay(state = 0) {
  const consumed: string[] = [];
  const play: PlayPurchases = {
    get: async () => ({ purchaseState: state, consumptionState: consumed.length ? 1 : 0, orderId: "GPA.1" }),
    consume: async (_p, token) => void consumed.push(token),
  };
  return { play, consumed };
}

const code = (e: unknown) => (e as WalletError).code;

test("a verified purchase adds gold once and is consumed", async () => {
  const store = new MemoryStore();
  const { play, consumed } = fakePlay();
  const first = await redeemPurchase(store, play, catalog, "u1", { productId: "gold_60", purchaseToken: "tok" }, 1);
  assert.deepEqual(first, { gold: 60, added: 60 });
  const again = await redeemPurchase(store, play, catalog, "u1", { productId: "gold_60", purchaseToken: "tok" }, 2);
  assert.deepEqual(again, { gold: 60, added: 0 });
  assert.deepEqual(consumed, ["tok"]);
});

test("another account cannot reuse a purchase token", async () => {
  const store = new MemoryStore();
  const { play } = fakePlay();
  await redeemPurchase(store, play, catalog, "u1", { productId: "gold_60", purchaseToken: "tok" }, 1);
  await assert.rejects(
    redeemPurchase(store, play, catalog, "u2", { productId: "gold_60", purchaseToken: "tok" }, 2),
    (e) => code(e) === "token-owned-by-other");
  assert.equal((await syncWallet(store, "u2")).gold, 0);
});

test("pending, canceled and unknown purchases add nothing", async () => {
  const store = new MemoryStore();
  await assert.rejects(redeemPurchase(store, fakePlay(2).play, catalog, "u1",
    { productId: "gold_60", purchaseToken: "a" }, 1), (e) => code(e) === "pending");
  await assert.rejects(redeemPurchase(store, fakePlay(1).play, catalog, "u1",
    { productId: "gold_60", purchaseToken: "b" }, 1), (e) => code(e) === "not-purchased");
  await assert.rejects(redeemPurchase(store, fakePlay().play, catalog, "u1",
    { productId: "gold_9999", purchaseToken: "c" }, 1), (e) => code(e) === "unknown-product");
  assert.equal((await syncWallet(store, "u1")).gold, 0);
});

test("spending checks the balance, never charges a request twice, and keeps unlocks", async () => {
  const store = new MemoryStore();
  await assert.rejects(spendGold(store, catalog, "u1",
    { requestId: "req-00001", kind: "skill", itemId: "tap_4" }, 1), (e) => code(e) === "insufficient");
  await redeemPurchase(store, fakePlay().play, catalog, "u1", { productId: "gold_60", purchaseToken: "t" }, 1);
  const bought = await spendGold(store, catalog, "u1",
    { requestId: "req-00002", kind: "skill", itemId: "tap_4" }, 2);
  assert.equal(bought.gold, 20);
  const retry = await spendGold(store, catalog, "u1",
    { requestId: "req-00002", kind: "skill", itemId: "tap_4" }, 3);
  assert.equal(retry.gold, 20);
  assert.equal(retry.grant.id, bought.grant.id);
  await assert.rejects(spendGold(store, catalog, "u1",
    { requestId: "req-00003", kind: "skill", itemId: "tap_4" }, 4), (e) => code(e) === "already-owned");
  await spendGold(store, catalog, "u1", { requestId: "req-00004", kind: "boost", itemId: "bought" }, 5);
  const wallet = await syncWallet(store, "u1");
  assert.equal(wallet.gold, 0);
  assert.deepEqual(wallet.grants.map((g) => [g.kind, g.itemId, g.consumable]),
    [["skill", "tap_4", false], ["boost", "bought", true]]);
});

test("bad input and unknown items are rejected", async () => {
  const store = new MemoryStore();
  for (const input of [
    {}, { requestId: "short", kind: "boost", itemId: "bought" },
    { requestId: "req-00001", kind: "coins", itemId: "fairy" },
  ]) {
    await assert.rejects(spendGold(store, catalog, "u1", input, 1), (e) => code(e) === "invalid-argument");
  }
  await assert.rejects(spendGold(store, catalog, "u1",
    { requestId: "req-00001", kind: "cosmetic", itemId: "crown" }, 1), (e) => code(e) === "unknown-product");
});
