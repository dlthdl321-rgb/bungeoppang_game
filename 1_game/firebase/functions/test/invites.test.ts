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
