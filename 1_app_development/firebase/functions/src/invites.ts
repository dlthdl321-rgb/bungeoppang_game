import { createHash, randomBytes } from "node:crypto";
import { readDevelopmentProgress } from "./active_progress";
import { befriend, readProfile, writeVisit } from "./friends";
import { plausibilityCheckpointPath } from "./plausibility_validator";
import { Doc, Store, Tx } from "./store";

// Invitations, matching the app's InvitationRepository port
// (lib/invite_repository.dart) and event reducer (lib/invite_rules.dart):
// clicked -> classifiedNew -> reachedLevelOne for a new player, or
// clicked -> existingParticipated for someone who already played.
//
// Identity is the Firebase account (signed in with Kakao). Players are
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

/**
 * 29번 친구 초대 보상 (DEC-151, `invite_rewards` in the shared balance):
 * the invited new player gets [inviteeGold] on accepting; the inviter gets
 * [inviterGold] when that player's workshop reaches [targetLevel], at most
 * [dailyLimit] friends a KST day and [lifetimeLimit] in all. Only the
 * server wallet moves; the app re-reads it.
 */
export interface InviteRewards {
  inviterGold: number; inviteeGold: number; targetLevel: number; dailyLimit: number; lifetimeLimit: number;
}

export function inviteRewards(config: unknown): InviteRewards {
  const section = (config as Record<string, unknown> | undefined)?.invite_rewards as Record<string, unknown> | undefined;
  const value = (key: string, min: number) => {
    const v = section?.[key];
    if (typeof v !== "number" || !Number.isSafeInteger(v) || v < min) throw new Error(`invite_rewards.${key} 설정 오류`);
    return v;
  };
  return {
    inviterGold: value("inviter_gold", 1), inviteeGold: value("invitee_gold", 0), targetLevel: value("target_level", 2),
    dailyLimit: value("inviter_daily_limit", 1), lifetimeLimit: value("inviter_lifetime_limit", 1),
  };
}

const kstDay = (ms: number) => new Date(ms + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);

/** Adds [gold] to [uid]'s server wallet with a ledger row (read [user] first). */
function creditGold(tx: Tx, uid: string, user: Doc | undefined, ledgerId: string, gold: number, now: number, detail: Doc) {
  const balance = user?.gold ?? 0;
  if (typeof balance !== "number" || !Number.isSafeInteger(balance) || balance < 0) throw new Error("서버 황금 지갑 손상");
  tx.set(`users/${uid}`, { ...user, gold: balance + gold });
  tx.create(`users/${uid}/ledger/${ledgerId}`, { type: "inviteGold", gold, delta: gold, atMs: now, ...detail });
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
  rewards?: InviteRewards,
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
    let inviterProfile: Doc | undefined;
    if (!usedTicket) {
      inviterProfile = await tx.get(`inviteProfiles/${inviterUid}`);
      usedTicket = inviterProfile?.latestTicket ? String(inviterProfile.latestTicket) : undefined;
      ticket = usedTicket ? await tx.get(`inviteTickets/${usedTicket}`) : undefined;
    }
    // 29번: the new home shares only the ID (the code). An inviter who never
    // made a link gets one ticket for typed codes, made here once.
    let madeTicket = false;
    if (!usedTicket || !ticket) {
      if (!inviterProfile) throw new InviteError("not-found", "the inviter has no open invitation");
      usedTicket = `t${createHash("sha256").update(`code:${inviterUid}`).digest("hex").slice(0, 24)}`;
      ticket = { uid: inviterUid, missionToken: "code", createdAtMs: now - 1 };
      madeTicket = true;
    }
    const invitee = await tx.get(`users/${inviteeUid}`);
    const isNew = now - Number(invitee?.createdAtMs ?? now) < newPlayerWindowMs;
    const playerId = publicPlayerId(inviteeUid);
    const visitId = `v${playerId.slice(1, 17)}`;
    // Events must come after the ticket and in causal order.
    const at = Math.max(now, Number(ticket.createdAtMs) + 1);
    const welcome = isNew && rewards && rewards.inviteeGold > 0 ? `invite_accept_${visitId}` : undefined;
    if (welcome && await tx.get(`users/${inviteeUid}/ledger/${welcome}`)) {
      throw new InviteError("already-accepted", "this account already accepted an invitation");
    }
    const event = (kind: InviteEventKind, offset: number): InviteEvent => ({
      eventId: `${visitId}_${kind}`, ticketId: usedTicket!, visitId, playerId, kind, atMs: at + offset,
    });
    const events = isNew
      ? [event("clicked", 0), event("classifiedNew", 1)]
      : [event("clicked", 0), event("existingParticipated", 1)];
    if (madeTicket) {
      tx.create(`inviteTickets/${usedTicket}`, ticket!);
      tx.set(`inviteProfiles/${inviterUid}`, { ...inviterProfile, latestTicket: usedTicket });
    }
    tx.create(`inviteAccepts/${inviteeUid}`, {
      inviterUid, ticketId: usedTicket, visitId, isNew, atMs: at,
    });
    befriend(tx, inviterUid, inviteeUid, now);
    for (const e of events) tx.create(`inviteEvents/${inviterUid}/events/${e.eventId}`, { ...e });
    if (welcome) creditGold(tx, inviteeUid, invitee, welcome, rewards!.inviteeGold, at, { reason: "invited", inviterUid });
    return rewards ? { isNew, gold: welcome ? rewards.inviteeGold : 0 } : { isNew };
  });
}

/**
 * The invited player reached the goal: the inviter gets the invitation event
 * (kind `reachedLevelOne`, kept for older apps) and visits the invited
 * player's stall as a guest, once.
 *
 * With [rewards] (29번): the goal is `target_level` of the NEW game, read
 * from the server's own checkpoint of the invited player's active progress
 * (never from the request), and the inviter gets `inviter_gold` within the
 * limits. Over the day's limit nothing is recorded yet (`retry`: the invited
 * app asks again on a later day); over the lifetime limit the event is
 * recorded without gold.
 */
export async function reachedLevelOne(store: Store, inviteeUid: string, now: number, rewards?: InviteRewards) {
  return store.run(async (tx) => {
    const a = await tx.get(`inviteAccepts/${inviteeUid}`);
    if (!a || !a.isNew || a.levelOneAtMs !== undefined) return { recorded: false };
    if (rewards) {
      const progress = await readDevelopmentProgress(tx, inviteeUid);
      const checkpoint = progress ? await tx.get(plausibilityCheckpointPath(inviteeUid, progress.progressId)) : undefined;
      if (!checkpoint || typeof checkpoint.level !== "number" || checkpoint.level < rewards.targetLevel) {
        return { recorded: false, retry: true };
      }
    }
    const inviterUid = String(a.inviterUid);
    const inviter = await readProfile(tx, inviterUid);
    let gold = 0;
    let counted: Doc | undefined;
    let inviterUser: Doc | undefined;
    if (rewards) {
      const summary = await tx.get(`users/${inviterUid}/inviteRewards/summary`);
      inviterUser = await tx.get(`users/${inviterUid}`);
      const today = kstDay(now), total = Number(summary?.total ?? 0);
      const todayCount = summary?.day === today ? Number(summary?.dayCount ?? 0) : 0;
      if (todayCount >= rewards.dailyLimit) return { recorded: false, retry: true };
      if (total < rewards.lifetimeLimit) {
        gold = rewards.inviterGold;
        counted = { total: total + 1, day: today, dayCount: todayCount + 1 };
      }
    }
    const playerId = publicPlayerId(inviteeUid);
    const e: InviteEvent = {
      eventId: `${a.visitId}_reachedLevelOne`, ticketId: String(a.ticketId), visitId: String(a.visitId),
      playerId, kind: "reachedLevelOne", atMs: Math.max(now, Number(a.atMs) + 2),
    };
    tx.set(`inviteAccepts/${inviteeUid}`, { ...a, levelOneAtMs: e.atMs, ...(rewards ? { inviterGold: gold } : {}) });
    tx.create(`inviteEvents/${a.inviterUid}/events/${e.eventId}`, { ...e });
    writeVisit(tx, inviter, inviterUid, inviteeUid, "invite", `invite_${a.visitId}`, e.atMs);
    if (counted) {
      tx.set(`users/${inviterUid}/inviteRewards/summary`, counted);
      creditGold(tx, inviterUid, inviterUser, `invite_${a.visitId}`, gold, e.atMs, { reason: "friendReachedLevel", playerId });
    }
    return rewards ? { recorded: true, gold } : { recorded: true };
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
