import { createHash, randomBytes } from "node:crypto";
import { befriend, readProfile, writeVisit } from "./friends";
import { Store } from "./store";

// Invitations, matching the app's InvitationRepository port
// (lib/invite_repository.dart) and event reducer (lib/invite_rules.dart):
// clicked -> classifiedNew -> reachedLevelOne for a new player, or
// clicked -> existingParticipated for someone who already played.
//
// Identity is the Firebase account (signed in with Play Games). Players are
// shown to each other only as an opaque playerId, never the account id.

export class InviteError extends Error {
  constructor(
    readonly code: "invalid-argument" | "not-found" | "already-accepted" | "self-invite",
    message: string,
  ) {
    super(message);
  }
}

export type InviteEventKind =
  | "clicked"
  | "classifiedNew"
  | "reachedLevelOne"
  | "existingParticipated";

export interface InviteEvent {
  eventId: string;
  ticketId: string;
  visitId: string;
  playerId: string;
  kind: InviteEventKind;
  atMs: number;
}

/** A player counts as new when their account is younger than this. */
export const newPlayerWindowMs = 24 * 60 * 60 * 1000;

const idPattern = /^[A-Za-z0-9_-]{1,128}$/;
const codePattern = /^BB[A-Z2-7]{8}$/;

export const publicPlayerId = (uid: string) =>
  `p${createHash("sha256").update(`player:${uid}`).digest("hex").slice(0, 24)}`;

const randomCode = () => {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  return `BB${[...randomBytes(8)].map((b) => alphabet[b % 32]).join("")}`;
};

/** Records when an account was first seen; used to tell new from existing. */
export async function touchUser(store: Store, uid: string, now: number): Promise<void> {
  await store.run(async (tx) => {
    const user = await tx.get(`users/${uid}`);
    if (!user) tx.set(`users/${uid}`, { gold: 0, createdAtMs: now });
    else if (user.createdAtMs === undefined) tx.set(`users/${uid}`, { ...user, createdAtMs: now });
  });
}

export async function register(store: Store, uid: string, now: number) {
  await touchUser(store, uid, now);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    const profile = await store.run(async (tx) => {
      const existing = await tx.get(`inviteProfiles/${uid}`);
      if (existing) return existing;
      if (await tx.get(`inviteCodes/${code}`)) return undefined;
      tx.create(`inviteCodes/${code}`, { uid });
      const created = { code, createdAtMs: now };
      tx.create(`inviteProfiles/${uid}`, created);
      tx.set(`players/${publicPlayerId(uid)}`, { uid });
      return created;
    });
    if (profile) return { playerId: publicPlayerId(uid), referralCode: String(profile.code) };
  }
  throw new Error("could not allocate an invite code");
}

/** The Play Store link carries the code to the new install (Install Referrer). */
export function storeUrl(packageName: string, code: string, ticketId: string) {
  const referrer = encodeURIComponent(`invite=${code}&ticket=${ticketId}`);
  return `https://play.google.com/store/apps/details?id=${packageName}&referrer=${referrer}`;
}

export async function createTicket(
  store: Store, packageName: string, uid: string, input: { missionToken?: unknown }, now: number,
) {
  const { missionToken } = input;
  if (typeof missionToken !== "string" || !idPattern.test(missionToken)) {
    throw new InviteError("invalid-argument", "missionToken is required");
  }
  const profile = await register(store, uid, now);
  const id = `t${randomBytes(12).toString("hex")}`;
  await store.run(async (tx) => {
    const p = (await tx.get(`inviteProfiles/${uid}`))!;
    tx.create(`inviteTickets/${id}`, { uid, missionToken, createdAtMs: now });
    tx.set(`inviteProfiles/${uid}`, { ...p, latestTicket: id });
  });
  return { id, missionToken, url: storeUrl(packageName, profile.referralCode, id), createdAtMs: now };
}

/**
 * Called by the invited player's app once, with the code from the install
 * referrer or typed in by hand. Each account can accept one invitation.
 */
export async function accept(
  store: Store, inviteeUid: string, input: { code?: unknown; ticketId?: unknown }, now: number,
) {
  const { code, ticketId } = input;
  if (typeof code !== "string" || !codePattern.test(code) ||
      (ticketId !== undefined && (typeof ticketId !== "string" || !idPattern.test(ticketId)))) {
    throw new InviteError("invalid-argument", "a valid invite code is required");
  }
  await touchUser(store, inviteeUid, now);
  return store.run(async (tx) => {
    const owner = await tx.get(`inviteCodes/${code}`);
    if (!owner) throw new InviteError("not-found", "unknown invite code");
    const inviterUid = String(owner.uid);
    if (inviterUid === inviteeUid) throw new InviteError("self-invite", "cannot invite yourself");
    if (await tx.get(`inviteAccepts/${inviteeUid}`)) {
      throw new InviteError("already-accepted", "this account already accepted an invitation");
    }
    let ticket = typeof ticketId === "string" ? await tx.get(`inviteTickets/${ticketId}`) : undefined;
    let usedTicket = ticket && ticket.uid === inviterUid ? (ticketId as string) : undefined;
    if (!usedTicket) {
      const profile = await tx.get(`inviteProfiles/${inviterUid}`);
      usedTicket = profile?.latestTicket ? String(profile.latestTicket) : undefined;
      ticket = usedTicket ? await tx.get(`inviteTickets/${usedTicket}`) : undefined;
    }
    if (!usedTicket || !ticket) throw new InviteError("not-found", "the inviter has no open invitation");
    const invitee = await tx.get(`users/${inviteeUid}`);
    const isNew = now - Number(invitee?.createdAtMs ?? now) < newPlayerWindowMs;
    const playerId = publicPlayerId(inviteeUid);
    const visitId = `v${playerId.slice(1, 17)}`;
    // Events must come after the ticket and in causal order.
    const at = Math.max(now, Number(ticket.createdAtMs) + 1);
    const event = (kind: InviteEventKind, offset: number): InviteEvent => ({
      eventId: `${visitId}_${kind}`, ticketId: usedTicket!, visitId, playerId, kind, atMs: at + offset,
    });
    const events = isNew
      ? [event("clicked", 0), event("classifiedNew", 1)]
      : [event("clicked", 0), event("existingParticipated", 1)];
    tx.create(`inviteAccepts/${inviteeUid}`, {
      inviterUid, ticketId: usedTicket, visitId, isNew, atMs: at,
    });
    befriend(tx, inviterUid, inviteeUid, now);
    for (const e of events) tx.create(`inviteEvents/${inviterUid}/events/${e.eventId}`, { ...e });
    return { isNew };
  });
}

/**
 * The invited player reached Lv.1's goal: the inviter gets the invitation
 * event (coins) and visits the invited player's stall as a guest (a 10-minute
 * boost there), once.
 */
export async function reachedLevelOne(store: Store, inviteeUid: string, now: number) {
  return store.run(async (tx) => {
    const a = await tx.get(`inviteAccepts/${inviteeUid}`);
    if (!a || !a.isNew || a.levelOneAtMs !== undefined) return { recorded: false };
    const inviter = await readProfile(tx, String(a.inviterUid));
    const playerId = publicPlayerId(inviteeUid);
    const e: InviteEvent = {
      eventId: `${a.visitId}_reachedLevelOne`, ticketId: String(a.ticketId), visitId: String(a.visitId),
      playerId, kind: "reachedLevelOne", atMs: Math.max(now, Number(a.atMs) + 2),
    };
    tx.set(`inviteAccepts/${inviteeUid}`, { ...a, levelOneAtMs: e.atMs });
    tx.create(`inviteEvents/${a.inviterUid}/events/${e.eventId}`, { ...e });
    writeVisit(tx, inviter, String(a.inviterUid), inviteeUid, "invite", `invite_${a.visitId}`, e.atMs);
    return { recorded: true };
  });
}

/** Events the inviter's app has not committed yet, oldest first. */
export async function fetchEvents(store: Store, uid: string, input: { committed?: unknown }) {
  const committed = new Set(
    Array.isArray(input.committed) ? input.committed.filter((x) => typeof x === "string") : [],
  );
  return (await store.list(`inviteEvents/${uid}/events`))
    .map((e) => e.data as unknown as InviteEvent)
    .filter((e) => !committed.has(e.eventId))
    .sort((a, b) => a.atMs - b.atMs || (a.eventId < b.eventId ? -1 : 1));
}
