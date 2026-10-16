import { publicPlayerId } from "./invites";
import { Store, Tx } from "./store";

// Friends and visits. Players add each other by ID (the invite code shown as
// "내 아이디"); friendship is mutual. Once per friend per day (Korea time) a
// player can visit a friend's stall: the visit waits in the friend's inbox
// and becomes a 5-minute boost with the visitor's avatar when the friend's
// app fetches it. The invitation guest (the inviter visiting the invited
// player who reached Lv.1) arrives through the same inbox.

export class FriendError extends Error {
  constructor(
    readonly code: "invalid-argument" | "not-found" | "self" | "limit" | "already-visited",
    message: string,
  ) {
    super(message);
  }
}

export type VisitKind = "visit" | "invite";

export interface Visit {
  id: string;
  kind: VisitKind;
  fromPlayerId: string;
  name: string;
  look: Record<string, string>;
  atMs: number;
}

export const friendLimit = 100;
/** Visits older than this are never delivered. */
export const visitTtlMs = 7 * 24 * 60 * 60 * 1000;
const kstOffsetMs = 9 * 60 * 60 * 1000;

const codePattern = /^BB[A-Z2-7]{8}$/;
const slotPattern = /^[a-z]{1,16}$/;
const itemPattern = /^[a-z0-9_]{1,32}$/;
const playerPattern = /^p[0-9a-f]{24}$/;

export const kstDay = (ms: number) => new Date(ms + kstOffsetMs).toISOString().slice(0, 10);

/** Avatar look as sent by the app: slot name -> item id, at most 16 slots. */
export function cleanLook(raw: unknown): Record<string, string> {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new FriendError("invalid-argument", "look must be an object");
  }
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length > 16 ||
      entries.some(([k, v]) => !slotPattern.test(k) || typeof v !== "string" || !itemPattern.test(v))) {
    throw new FriendError("invalid-argument", "bad look");
  }
  return Object.fromEntries(entries) as Record<string, string>;
}

export function cleanName(raw: unknown): string {
  if (typeof raw !== "string") return "친구";
  const name = raw.trim().slice(0, 16);
  return name.length > 0 ? name : "친구";
}

async function profileOf(tx: Tx, uid: string) {
  return (await tx.get(`inviteProfiles/${uid}`)) ?? {};
}

/** The app tells the server how its vendor looks and is called. */
export async function setProfile(store: Store, uid: string, input: { look?: unknown; name?: unknown }) {
  const look = cleanLook(input.look);
  const name = cleanName(input.name);
  await store.run(async (tx) => {
    const p = await profileOf(tx, uid);
    tx.set(`inviteProfiles/${uid}`, { ...p, look, name });
    tx.set(`players/${publicPlayerId(uid)}`, { uid });
  });
}

/** Makes [a] and [b] friends both ways (no-op if they already are). */
export function befriend(tx: Tx, a: string, b: string, now: number) {
  tx.set(`friends/${a}/list/${b}`, { sinceMs: now });
  tx.set(`friends/${b}/list/${a}`, { sinceMs: now });
}

export async function addFriend(store: Store, uid: string, input: { code?: unknown }, now: number) {
  const { code } = input;
  if (typeof code !== "string" || !codePattern.test(code)) {
    throw new FriendError("invalid-argument", "a valid ID is required");
  }
  const mine = (await store.list(`friends/${uid}/list`)).length;
  return store.run(async (tx) => {
    const owner = await tx.get(`inviteCodes/${code}`);
    if (!owner) throw new FriendError("not-found", "unknown ID");
    const other = String(owner.uid);
    if (other === uid) throw new FriendError("self", "cannot add yourself");
    const already = await tx.get(`friends/${uid}/list/${other}`);
    if (!already && mine >= friendLimit) throw new FriendError("limit", "too many friends");
    const theirs = await profileOf(tx, other);
    befriend(tx, uid, other, now);
    return { playerId: publicPlayerId(other), name: cleanName(theirs.name) };
  });
}

export async function listFriends(store: Store, uid: string, now: number) {
  const day = kstDay(now);
  const friends = await store.list(`friends/${uid}/list`);
  const out = [];
  for (const f of friends) {
    const row = await store.run(async (tx) => {
      const p = await profileOf(tx, f.id);
      const sent = await tx.get(`visitsSent/${uid}_${f.id}_${day}`);
      return {
        playerId: publicPlayerId(f.id),
        name: cleanName(p.name),
        look: (p.look as Record<string, string> | undefined) ?? {},
        visitedToday: sent !== undefined,
      };
    });
    out.push(row);
  }
  return out.sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

/**
 * Writes a visit from the sender (whose profile [sender] the caller has
 * already read; Firestore allows no reads after the first write) into
 * [hostUid]'s inbox.
 */
export function writeVisit(
  tx: Tx, sender: Record<string, unknown>, fromUid: string, hostUid: string,
  kind: VisitKind, id: string, now: number,
) {
  const visit: Visit = {
    id, kind, fromPlayerId: publicPlayerId(fromUid), name: cleanName(sender.name),
    look: (sender.look as Record<string, string> | undefined) ?? {}, atMs: now,
  };
  tx.create(`visits/${hostUid}/inbox/${id}`, { ...visit });
}

export const readProfile = profileOf;

/** Visits [playerId]'s stall; once per friend per Korean day. */
export async function visitFriend(store: Store, uid: string, input: { playerId?: unknown }, now: number) {
  const { playerId } = input;
  if (typeof playerId !== "string" || !playerPattern.test(playerId)) {
    throw new FriendError("invalid-argument", "playerId is required");
  }
  const day = kstDay(now);
  return store.run(async (tx) => {
    const target = await tx.get(`players/${playerId}`);
    const host = target ? String(target.uid) : undefined;
    if (!host || !(await tx.get(`friends/${uid}/list/${host}`))) {
      throw new FriendError("not-found", "not a friend");
    }
    const sentPath = `visitsSent/${uid}_${host}_${day}`;
    if (await tx.get(sentPath)) throw new FriendError("already-visited", "already visited today");
    const sender = await profileOf(tx, uid);
    const id = `visit_${publicPlayerId(uid).slice(1, 13)}_${day}`;
    tx.create(sentPath, { atMs: now });
    writeVisit(tx, sender, uid, host, "visit", id, now);
    return { visited: true };
  });
}

/** Visits waiting for [uid] that the app has not applied yet, oldest first. */
export async function fetchVisits(store: Store, uid: string, input: { applied?: unknown }, now: number) {
  const applied = new Set(
    Array.isArray(input.applied) ? input.applied.filter((x) => typeof x === "string") : [],
  );
  return (await store.list(`visits/${uid}/inbox`))
    .map((v) => v.data as unknown as Visit)
    .filter((v) => !applied.has(v.id) && now - v.atMs < visitTtlMs)
    .sort((a, b) => a.atMs - b.atMs || (a.id < b.id ? -1 : 1));
}
