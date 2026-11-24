import assert from "node:assert/strict";
import { test } from "node:test";
import * as invites from "../src/invites";
import { MemoryStore } from "../src/store";

const day = 24 * 60 * 60 * 1000;
const code = (e: unknown) => (e as invites.InviteError).code;

async function inviter(store: MemoryStore) {
  const profile = await invites.register(store, "alice", 1000);
  const ticket = await invites.createTicket(store, "com.example", "alice", { missionToken: "mission-1" }, 1000);
  return { profile, ticket };
}

test("a new player goes clicked -> classifiedNew -> reachedLevelOne, once", async () => {
  const store = new MemoryStore();
  const { profile, ticket } = await inviter(store);
  assert.match(profile.referralCode, /^BB[A-Z2-7]{8}$/);
  assert.ok(ticket.url.startsWith("https://play.google.com/store/apps/details?id=com.example&referrer="));
  assert.deepEqual(await invites.accept(store, "bob", { code: profile.referralCode, ticketId: ticket.id }, 2000),
    { isNew: true });
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 3000), { recorded: true });
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 4000), { recorded: false });
  const events = await invites.fetchEvents(store, "alice", {});
  assert.deepEqual(events.map((e) => e.kind), ["clicked", "classifiedNew", "reachedLevelOne"]);
  assert.ok(events.every((e) => e.ticketId === ticket.id && e.playerId === events[0].playerId));
  assert.ok(!events[0].playerId.includes("bob"));
  assert.ok(events[0].atMs < events[1].atMs && events[1].atMs < events[2].atMs);
  const left = await invites.fetchEvents(store, "alice", { committed: [events[0].eventId, events[1].eventId] });
  assert.deepEqual(left.map((e) => e.kind), ["reachedLevelOne"]);
});

test("an existing player participates; a code typed by hand uses the latest ticket", async () => {
  const store = new MemoryStore();
  const { profile, ticket } = await inviter(store);
  await invites.touchUser(store, "carol", 0);
  assert.deepEqual(await invites.accept(store, "carol", { code: profile.referralCode }, 2 * day),
    { isNew: false });
  assert.deepEqual(await invites.reachedLevelOne(store, "carol", 3 * day), { recorded: false });
  const events = await invites.fetchEvents(store, "alice", {});
  assert.deepEqual(events.map((e) => [e.kind, e.ticketId]),
    [["clicked", ticket.id], ["existingParticipated", ticket.id]]);
});

test("one accept per account, no self-invites, unknown codes rejected", async () => {
  const store = new MemoryStore();
  const { profile } = await inviter(store);
  await assert.rejects(invites.accept(store, "alice", { code: profile.referralCode }, 2000),
    (e) => code(e) === "self-invite");
  await invites.accept(store, "bob", { code: profile.referralCode }, 2000);
  await assert.rejects(invites.accept(store, "bob", { code: profile.referralCode }, 3000),
    (e) => code(e) === "already-accepted");
  await assert.rejects(invites.accept(store, "dan", { code: "BBAAAAAAAA" }, 3000),
    (e) => code(e) === "not-found");
  await assert.rejects(invites.accept(store, "dan", { code: "nope" }, 3000),
    (e) => code(e) === "invalid-argument");
});

test("registering twice keeps the same code", async () => {
  const store = new MemoryStore();
  const a = await invites.register(store, "alice", 1);
  const b = await invites.register(store, "alice", 2);
  assert.deepEqual(a, b);
});

// 29번 친구 초대 보상 (DEC-151).
const rewards: invites.InviteRewards = { inviterGold: 5, inviteeGold: 3, targetLevel: 5, dailyLimit: 3, lifetimeLimit: 20 };

/** The server's own record of [uid]'s progress at [level] (what plausibility checks keep). */
async function progressAt(store: MemoryStore, uid: string, level: number) {
  await store.run(async (tx) => {
    tx.set(`users/${encodeURIComponent(uid)}/developmentProgress/active`, { progressId: `progress-${uid}`, epoch: 1 });
    tx.set(`users/${uid}/workshopPlausibility/progress-${uid}`, { level });
  });
}
const goldOf = async (store: MemoryStore, uid: string) => store.run(async (tx) => Number((await tx.get(`users/${uid}`))?.gold ?? 0));

test("보상: 초대받은 새 플레이어는 수락 때 3, 초대한 사람은 친구가 Lv.5가 되면 5 (한 번만)", async () => {
  const store = new MemoryStore();
  const { profile } = await inviter(store);
  assert.deepEqual(await invites.accept(store, "bob", { code: profile.referralCode }, 2000, rewards), { isNew: true, gold: 3 });
  assert.equal(await goldOf(store, "bob"), 3);
  // Not yet Lv.5 on the server: nothing, ask again later.
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 3000, rewards), { recorded: false, retry: true });
  await progressAt(store, "bob", 4);
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 3000, rewards), { recorded: false, retry: true });
  await progressAt(store, "bob", 5);
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 4000, rewards), { recorded: true, gold: 5 });
  assert.deepEqual(await invites.reachedLevelOne(store, "bob", 5000, rewards), { recorded: false });
  assert.equal(await goldOf(store, "alice"), 5);
  const ledger = await store.list("users/alice/ledger");
  assert.deepEqual(ledger.map((e) => [e.data.type, e.data.gold]), [["inviteGold", 5]]);
});

test("보상: 기존 플레이어는 수락 보상이 없고, 하루 3명·평생 20명 한도", async () => {
  const store = new MemoryStore();
  const { profile } = await inviter(store);
  await invites.touchUser(store, "old", 0);
  assert.deepEqual(await invites.accept(store, "old", { code: profile.referralCode }, 2 * day, rewards), { isNew: false, gold: 0 });
  assert.equal(await goldOf(store, "old"), 0);
  const friends = ["f1", "f2", "f3", "f4"];
  for (const f of friends) {
    await invites.accept(store, f, { code: profile.referralCode }, 3 * day, rewards);
    await progressAt(store, f, 5);
  }
  for (const f of friends.slice(0, 3)) assert.deepEqual(await invites.reachedLevelOne(store, f, 3 * day + 10, rewards), { recorded: true, gold: 5 });
  // The fourth the same KST day waits for another day.
  assert.deepEqual(await invites.reachedLevelOne(store, "f4", 3 * day + 20, rewards), { recorded: false, retry: true });
  assert.deepEqual(await invites.reachedLevelOne(store, "f4", 4 * day + 20, rewards), { recorded: true, gold: 5 });
  assert.equal(await goldOf(store, "alice"), 20);
  // Past the lifetime limit: recorded, no gold.
  const tight = { ...rewards, lifetimeLimit: 4 };
  await invites.accept(store, "f5", { code: profile.referralCode }, 5 * day, rewards);
  await progressAt(store, "f5", 9);
  assert.deepEqual(await invites.reachedLevelOne(store, "f5", 5 * day + 10, tight), { recorded: true, gold: 0 });
  assert.equal(await goldOf(store, "alice"), 20);
});

test("보상 설정은 공통 밸런스에서 읽고, 빠지거나 틀리면 거부", () => {
  assert.throws(() => invites.inviteRewards({}));
  assert.throws(() => invites.inviteRewards({ invite_rewards: { ...rewards } }));
  assert.deepEqual(invites.inviteRewards({ invite_rewards: { inviter_gold: 5, invitee_gold: 3, target_level: 5,
    inviter_daily_limit: 3, inviter_lifetime_limit: 20 } }), rewards);
});

test("링크 없이 아이디만 알려 줘도 초대를 받을 수 있다 (초대권은 한 번 만들어 둠)", async () => {
  const store = new MemoryStore();
  const { referralCode } = await invites.register(store, "alice", 1000);
  assert.deepEqual(await invites.accept(store, "bob", { code: referralCode }, 2000, rewards), { isNew: true, gold: 3 });
  assert.deepEqual(await invites.accept(store, "carl", { code: referralCode }, 2500, rewards), { isNew: true, gold: 3 });
  const events = await invites.fetchEvents(store, "alice", {});
  assert.equal(new Set(events.map((e) => e.ticketId)).size, 1);
});
