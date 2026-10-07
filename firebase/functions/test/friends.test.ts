import assert from "node:assert/strict";
import { test } from "node:test";
import * as friends from "../src/friends";
import * as invites from "../src/invites";
import { MemoryStore } from "../src/store";

const hour = 60 * 60 * 1000;
const code = (e: unknown) => (e as friends.FriendError).code;
// 2026-10-06 10:00 KST
const morning = Date.UTC(2026, 9, 6, 1);

async function player(store: MemoryStore, uid: string, name: string) {
  const p = await invites.register(store, uid, morning);
  await friends.setProfile(store, uid, { name, look: { hair: "long", hat: "beanie" } });
  return p;
}

test("adding by ID makes both players friends", async () => {
  const store = new MemoryStore();
  await player(store, "alice", "앨리스");
  const bob = await player(store, "bob", "밥");
  assert.deepEqual(await friends.addFriend(store, "alice", { code: bob.referralCode }, morning),
    { playerId: bob.playerId, name: "밥" });
  assert.deepEqual((await friends.listFriends(store, "bob", morning)).map((f) => f.name), ["앨리스"]);
  await assert.rejects(friends.addFriend(store, "bob", { code: bob.referralCode }, morning),
    (e) => code(e) === "self");
  await assert.rejects(friends.addFriend(store, "bob", { code: "BBAAAAAAAA" }, morning),
    (e) => code(e) === "not-found");
});

test("a friend can visit once per Korean day; the host gets the visitor's look", async () => {
  const store = new MemoryStore();
  await player(store, "alice", "앨리스");
  const bob = await player(store, "bob", "밥");
  await friends.addFriend(store, "alice", { code: bob.referralCode }, morning);
  await friends.visitFriend(store, "alice", { playerId: bob.playerId }, morning);
  assert.equal((await friends.listFriends(store, "alice", morning))[0].visitedToday, true);
  await assert.rejects(friends.visitFriend(store, "alice", { playerId: bob.playerId }, morning + hour),
    (e) => code(e) === "already-visited");
  const inbox = await friends.fetchVisits(store, "bob", {}, morning + hour);
  assert.equal(inbox.length, 1);
  assert.deepEqual([inbox[0].kind, inbox[0].name, inbox[0].look.hat], ["visit", "앨리스", "beanie"]);
  assert.deepEqual(await friends.fetchVisits(store, "bob", { applied: [inbox[0].id] }, morning + hour), []);
  // Next day (after midnight KST) the same friend can visit again.
  await friends.visitFriend(store, "alice", { playerId: bob.playerId }, morning + 15 * hour);
  assert.equal((await friends.fetchVisits(store, "bob", {}, morning + 15 * hour)).length, 2);
});

test("only friends can visit, and old visits expire", async () => {
  const store = new MemoryStore();
  await player(store, "alice", "앨리스");
  const carol = await player(store, "carol", "캐롤");
  await assert.rejects(friends.visitFriend(store, "alice", { playerId: carol.playerId }, morning),
    (e) => code(e) === "not-found");
  await friends.addFriend(store, "carol", { code: (await invites.register(store, "alice", morning)).referralCode }, morning);
  await friends.visitFriend(store, "alice", { playerId: carol.playerId }, morning);
  assert.equal((await friends.fetchVisits(store, "carol", {}, morning + friends.visitTtlMs)).length, 0);
});

test("the invited player's Lv.1 brings the inviter as a guest, once, and makes them friends", async () => {
  const store = new MemoryStore();
  const alice = await player(store, "alice", "앨리스");
  await invites.createTicket(store, "com.example", "alice", { missionToken: "m1" }, morning);
  await invites.accept(store, "bob", { code: alice.referralCode }, morning + 1000);
  assert.deepEqual((await friends.listFriends(store, "bob", morning)).map((f) => f.name), ["앨리스"]);
  await invites.reachedLevelOne(store, "bob", morning + 2000);
  await invites.reachedLevelOne(store, "bob", morning + 3000);
  const inbox = await friends.fetchVisits(store, "bob", {}, morning + 4000);
  assert.deepEqual(inbox.map((v) => [v.kind, v.name]), [["invite", "앨리스"]]);
});

test("looks and names are checked", async () => {
  const store = new MemoryStore();
  await assert.rejects(friends.setProfile(store, "a", { look: { "Bad Key": "x" } }),
    (e) => code(e) === "invalid-argument");
  await assert.rejects(friends.setProfile(store, "a", { look: "nope" }), (e) => code(e) === "invalid-argument");
  assert.equal(friends.cleanName("   "), "친구");
  assert.equal(friends.cleanName("a".repeat(30)).length, 16);
});
