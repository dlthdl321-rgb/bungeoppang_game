import assert from "node:assert/strict";
import { test } from "node:test";
import { MemoryStore } from "../src/store";
import { claimDevelopmentProgress, requireDevelopmentProgress, transferDevelopmentProgress,
  VerifiedProgressTransfer } from "../src/active_progress";

test("계정당 한 진행만 활성화하고 같은 등록은 멱등이다", async () => {
  const store = new MemoryStore();
  const first = await claimDevelopmentProgress(store, "a", "progress_a");
  assert.deepEqual(await claimDevelopmentProgress(store, "a", "progress_a"), first);
  await assert.rejects(claimDevelopmentProgress(store, "a", "progress_b"));
  await claimDevelopmentProgress(store, "b", "progress_b");
});
test("이전 후 구형 epoch는 구매 권한을 얻지 못한다", async () => {
  const store = new MemoryStore();
  await claimDevelopmentProgress(store, "a", "progress_a");
  const proof: VerifiedProgressTransfer = { account: "a", from: "progress_a", to: "progress_b",
    sourceEpoch: 1, snapshotDigest: "snapshot", protectionDigest: "journal", pendingResolved: true };
  const next = await transferDevelopmentProgress(store, "a", "transfer_1", proof);
  assert.equal(next.epoch, 2);
  assert.deepEqual(await transferDevelopmentProgress(store, "a", "transfer_1", proof), next);
  await assert.rejects(store.run((tx) => requireDevelopmentProgress(tx, "a", "progress_a", 1)));
  assert.deepEqual(await store.run((tx) => requireDevelopmentProgress(tx, "a", "progress_b", 2)), next);
});
test("증거 없는 이전·같은 요청의 다른 원본은 거부한다", async () => {
  const store = new MemoryStore();
  await claimDevelopmentProgress(store, "a", "progress_a");
  const proof: VerifiedProgressTransfer = { account: "a", from: "progress_a", to: "progress_b",
    sourceEpoch: 1, snapshotDigest: "snapshot", protectionDigest: "journal", pendingResolved: true };
  await assert.rejects(transferDevelopmentProgress(store, "a", "transfer_1", { ...proof, protectionDigest: "" }));
  await transferDevelopmentProgress(store, "a", "transfer_1", proof);
  await assert.rejects(transferDevelopmentProgress(store, "a", "transfer_1", { ...proof, snapshotDigest: "changed" }));
});
