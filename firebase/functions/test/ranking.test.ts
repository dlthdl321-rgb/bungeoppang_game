import assert from "node:assert/strict";
import { test } from "node:test";
import * as friends from "../src/friends";
import { publicPlayerId } from "../src/invites";
import * as ranking from "../src/ranking";
import { MemoryStore } from "../src/store";

const minute = 60 * 1000;
const hour = 60 * minute;
const start = Date.UTC(2026, 9, 7, 3);
const code = (e: unknown) => (e as ranking.RankingError).code;

async function player(store: MemoryStore, uid: string, name: string) {
  await friends.setProfile(store, uid, { name, look: { hair: "long" } });
}

const entry = (store: MemoryStore, board: string, uid: string) =>
  store.docs.get(`rankings/${board}/entries/${uid}`);

test("rankingSubmit keeps each board's best score and refreshes the name", async () => {
  const store = new MemoryStore();
  await player(store, "kakao:1", "앨리스");
  await ranking.submit(store, "kakao:1", { bestAutoRate: "500", lifetime: "9000", bestCombo: 12 }, start);
  await player(store, "kakao:1", "앨리스2");
  const r = await ranking.submit(store, "kakao:1",
    { bestAutoRate: "400", lifetime: "12000", bestCombo: 12 }, start + 10 * minute);
  assert.deepEqual(r.best, { bestAutoRate: "500", lifetime: "12000", bestCombo: "12" });
  const auto = entry(store, "bestAutoRate", "kakao:1")!;
  assert.deepEqual([auto.score, auto.scoreText, auto.name, auto.updatedAt], [500, "500", "앨리스2", start]);
  assert.deepEqual(entry(store, "lifetime", "kakao:1")!.look, { hair: "long" });
  assert.equal(entry(store, "lifetime", "kakao:1")!.updatedAt, start + 10 * minute);
});

test("rankingSubmit keeps 64-bit scores exactly and refuses larger ones", async () => {
  const store = new MemoryStore();
  const max = ranking.rankingScoreMax.toString();
  await ranking.submit(store, "kakao:1", { lifetime: max }, start);
  assert.equal(entry(store, "lifetime", "kakao:1")!.scoreText, "9223372036854775807");
  await assert.rejects(ranking.submit(store, "kakao:2", { lifetime: "9223372036854775808" }, start),
    (e) => code(e) === "invalid-argument");
  await assert.rejects(ranking.submit(store, "kakao:2", { lifetime: -1 }, start),
    (e) => code(e) === "invalid-argument");
  await assert.rejects(ranking.submit(store, "kakao:2", {}, start), (e) => code(e) === "invalid-argument");
});

test("rankingSubmit refuses calls closer together than the minimum gap", async () => {
  const store = new MemoryStore();
  await ranking.submit(store, "kakao:1", { bestCombo: 5 }, start);
  await assert.rejects(ranking.submit(store, "kakao:1", { bestCombo: 6 }, start + ranking.rankingSubmitMinGapMs - 1),
    (e) => code(e) === "too-soon");
  // Another player is not held back.
  await ranking.submit(store, "kakao:2", { bestCombo: 6 }, start + 1);
  await ranking.submit(store, "kakao:1", { bestCombo: 7 }, start + ranking.rankingSubmitMinGapMs);
  assert.equal(entry(store, "bestCombo", "kakao:1")!.scoreText, "7");
});

test("rankingSubmit refuses an implausible jump but allows growth over time", async () => {
  const store = new MemoryStore();
  await ranking.submit(store, "kakao:1", { lifetime: "2000000000" }, start);
  // Five minutes later: 1,000 times more is not believable.
  await assert.rejects(ranking.submit(store, "kakao:1", { lifetime: "2000000000000" }, start + 5 * minute),
    (e) => code(e) === "implausible");
  assert.equal(entry(store, "lifetime", "kakao:1")!.scoreText, "2000000000"); // nothing written
  // Ten times at once is fine, and a day later anything up to the cap is.
  await ranking.submit(store, "kakao:1", { lifetime: "20000000000" }, start + 6 * minute);
  await ranking.submit(store, "kakao:1", { lifetime: ranking.rankingScoreMax.toString() }, start + 30 * hour);
  // Small scores always pass.
  await ranking.submit(store, "kakao:2", { bestCombo: 900 }, start);
  await ranking.submit(store, "kakao:2", { bestCombo: 1000 }, start + 2 * minute);
  assert.equal(ranking.plausible("bestCombo", 1000n, 10000n, 0), true);
  assert.equal(ranking.plausible("bestCombo", 1000n, 10001n, 0), false);
});

test("rankingTop lists the best first, shares ranks on ties and shows my rank", async () => {
  const store = new MemoryStore();
  const queries = ranking.memoryRankingQueries(store);
  const scores: Array<[string, number, number]> = [
    ["kakao:a", 300, 0], ["kakao:b", 500, 1], ["kakao:c", 300, 2], ["kakao:d", 100, 3],
  ];
  for (const [uid, score, at] of scores) {
    await player(store, uid, uid.slice(-1).toUpperCase());
    await ranking.submit(store, uid, { bestCombo: score }, start + at * minute);
  }
  const board = await ranking.top(store, queries, "kakao:c", { board: "bestCombo" });
  assert.deepEqual(board.entries.map((e) => [e.rank, e.name, e.score, e.me]), [
    [1, "B", "500", false], [2, "A", "300", false], [2, "C", "300", true], [4, "D", "100", false],
  ]);
  assert.equal(board.entries[0].playerId, publicPlayerId("kakao:b"));
  assert.deepEqual(board.entries[0].look, { hair: "long" });
  assert.deepEqual(board.me, { rank: 2, score: "300" });
  // The uid (with the Kakao member number) never leaves the server.
  assert.ok(!JSON.stringify(board).includes("kakao:"));
  assert.equal((await ranking.top(store, queries, "kakao:none", { board: "lifetime" })).me, null);
  await assert.rejects(ranking.top(store, queries, "kakao:c", { board: "nope" }),
    (e) => code(e) === "invalid-argument");
});

test("rankingTop returns at most the top count", async () => {
  const store = new MemoryStore();
  for (let i = 0; i < ranking.rankingTopCount + 5; i++) {
    await ranking.submit(store, `kakao:${i}`, { bestCombo: i + 1 }, start);
  }
  const board = await ranking.top(store, ranking.memoryRankingQueries(store), "kakao:0", { board: "bestCombo" });
  assert.equal(board.entries.length, ranking.rankingTopCount);
  assert.equal(board.entries[0].score, String(ranking.rankingTopCount + 5));
  assert.deepEqual(board.me, { rank: ranking.rankingTopCount + 5, score: "1" });
});
