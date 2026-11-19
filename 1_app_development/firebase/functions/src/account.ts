import { LoginProvider, SignedInAccount } from "./auth";
import { publicPlayerId } from "./invites";
import { rankingBoards } from "./ranking";
import { Doc, Store } from "./store";

// 26번 2-1단계: the account profile and account deletion.
//
// accountProfiles/{uid} is server-only (firestore.rules denies the app) and
// holds what the first-run screens collect: the owner name (사장님 이름), the
// login email (Kakao account_email or the Google account's verified address),
// the required consent version with the player's own 만 14세 이상 confirmation
// (players under 14 are not accepted, DEC-125) and, only with the
// separate optional consent, the player's gender and age band. The email is never shown to other players
// and never sent to analytics. Purpose: player statistics and notices about
// the account; no marketing.
//
// accountDelete (Google Play: accounts made in the app can be deleted in the
// app) removes everything keyed by the uid, then the Firebase Auth user.
// Payment records (purchases/{token hash}) stay for the period the law
// requires (privacy_policy.md 6절).

export class AccountError extends Error {
  constructor(
    readonly code: "invalid-argument" | "consent-required" | "age-required",
    message: string,
  ) {
    super(message);
  }
}

/** Mirrors lib/owner_profile.dart (ownerNameMin/Max, allowed letters). */
export const ownerNameMin = 2;
export const ownerNameMax = 8;
const ownerNamePattern = /^[가-힣A-Za-z0-9]+$/;
export const genders = ["female", "male", "none"] as const;
export const ageBands = ["14_19", "20s", "30s", "40s", "50plus", "none"] as const;
/**
 * The terms and privacy notice the required consent refers to
 * (lib/owner_profile.dart). 2026-11-19: adds the 만 14세 이상 confirmation.
 */
export const requiredConsentVersion = "2026-11-19";

export const accountProfilePath = (uid: string) => `accountProfiles/${uid}`;

/** A valid owner name or an error: 2~8 Hangul syllables, Latin letters or digits. */
export function cleanOwnerName(raw: unknown): string {
  const name = typeof raw === "string" ? raw.trim() : "";
  const length = [...name].length;
  if (length < ownerNameMin || length > ownerNameMax || !ownerNamePattern.test(name)) {
    throw new AccountError("invalid-argument", "name must be 2-8 Hangul, Latin letters or digits");
  }
  return name;
}

interface OptionalInfo {
  gender: (typeof genders)[number];
  ageBand: (typeof ageBands)[number];
}

function optionalInfo(raw: unknown): OptionalInfo | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw !== "object" || Array.isArray(raw)) throw new AccountError("invalid-argument", "bad optional info");
  const { gender, ageBand } = raw as Record<string, unknown>;
  // No 만 14세 미만 band: players under 14 cannot sign up (DEC-125).
  if (!genders.includes(gender as never) || !ageBands.includes(ageBand as never)) {
    throw new AccountError("invalid-argument", "bad gender or age band");
  }
  return { gender: gender as OptionalInfo["gender"], ageBand: ageBand as OptionalInfo["ageBand"] };
}

/**
 * Saves the owner name, the required consent and (only when [input.optional]
 * is given) the optional gender and age band. Sending no optional info clears
 * what was stored, so withdrawing the optional consent is the same call.
 */
export async function setAccountProfile(
  store: Store, who: SignedInAccount,
  input: { name?: unknown; consentVersion?: unknown; over14Confirmed?: unknown; optional?: unknown }, now: number,
) {
  if (input.consentVersion !== requiredConsentVersion) {
    throw new AccountError("consent-required", "the current terms have to be agreed to");
  }
  // 만 14세 미만은 가입 불가(개인정보 보호법 22조의2를 피하는 A안): the player
  // ticked '(필수) 만 14세 이상입니다'; kept with the consent as its record.
  if (input.over14Confirmed !== true) {
    throw new AccountError("age-required", "only players aged 14 or over can sign up");
  }
  const name = cleanOwnerName(input.name);
  const optional = optionalInfo(input.optional);
  await store.run(async (tx) => {
    const old = (await tx.get(accountProfilePath(who.uid))) ?? {};
    const oldConsent = old.requiredConsent as { version?: unknown; atMs?: unknown } | undefined;
    const consentAtMs =
      oldConsent?.version === requiredConsentVersion && typeof oldConsent.atMs === "number" ? oldConsent.atMs : now;
    const oldOptional = old.optionalConsent as { atMs?: unknown } | undefined;
    const email = who.email ?? (typeof old.email === "string" ? old.email : undefined);
    const doc: Doc = {
      provider: who.provider satisfies LoginProvider,
      name,
      ...(email ? { email } : {}),
      // over14: the player confirmed 만 14세 이상 together with this consent.
      requiredConsent: { version: requiredConsentVersion, atMs: consentAtMs, over14: true },
      updatedAtMs: now,
    };
    if (optional) {
      doc.optionalConsent = { atMs: typeof oldOptional?.atMs === "number" ? oldOptional.atMs : now };
      doc.gender = optional.gender;
      doc.ageBand = optional.ageBand;
    }
    tx.set(accountProfilePath(who.uid), doc);
  });
  return { saved: true };
}

/** authKakao's email: kept (or forgotten) without touching the rest. */
export async function rememberEmail(store: Store, uid: string, email: string | null) {
  await store.run(async (tx) => {
    const old = await tx.get(accountProfilePath(uid));
    if (!old && email === null) return;
    const next: Doc = { ...(old ?? {}) };
    if (email === null) delete next.email;
    else next.email = email;
    tx.set(accountProfilePath(uid), next);
  });
}

/** Deletions Firestore and Firebase Auth do outside a transaction. */
export interface AccountEraser {
  /** A document and every subcollection under it (Firestore recursiveDelete). */
  deleteTree(path: string): Promise<void>;
  /** Documents of [collection] whose id starts with [prefix]. */
  deletePrefixed(collection: string, prefix: string): Promise<void>;
  /** The Firebase Auth user; no error when it is already gone. */
  deleteAuthUser(uid: string): Promise<void>;
}

/** Every path keyed by [uid] that accountDelete removes (after the friend links). */
export function accountPaths(uid: string): string[] {
  const encoded = encodeURIComponent(uid);
  return [
    `friends/${uid}`,
    `visits/${uid}`,
    `inviteEvents/${uid}`,
    `inviteAccepts/${uid}`,
    `inviteProfiles/${uid}`,
    `players/${publicPlayerId(uid)}`,
    `rankingSubmits/${uid}`,
    ...rankingBoards.map((board) => `rankings/${board}/entries/${uid}`),
    accountProfilePath(uid),
    `users/${uid}`,
    // development_contracts.ts keys reward decisions by the encoded uid.
    ...(encoded === uid ? [] : [`users/${encoded}`]),
  ];
}

/**
 * Deletes the signed-in account: my side of every friendship, my ID code,
 * my latest invite link, visits, invitations, rankings, the profile, the
 * wallet (gold, ledger, items) and workshop records, then the login itself.
 * Safe to retry: every step skips what is already gone.
 */
export async function deleteAccount(store: Store, eraser: AccountEraser, uid: string) {
  const profile = await store.run((tx) => tx.get(`inviteProfiles/${uid}`));
  const friends = await store.list(`friends/${uid}/list`);
  for (const friend of friends) {
    await eraser.deleteTree(`friends/${friend.id}/list/${uid}`);
    // Daily visit marks (friends.ts visitsSent/{from}_{to}_{day}), both ways.
    await eraser.deletePrefixed("visitsSent", `${uid}_${friend.id}_`);
    await eraser.deletePrefixed("visitsSent", `${friend.id}_${uid}_`);
  }
  if (typeof profile?.code === "string") {
    const owner = await store.run((tx) => tx.get(`inviteCodes/${profile.code}`));
    if (owner?.uid === uid) await eraser.deleteTree(`inviteCodes/${profile.code}`);
  }
  if (typeof profile?.latestTicket === "string") await eraser.deleteTree(`inviteTickets/${profile.latestTicket}`);
  for (const path of accountPaths(uid)) await eraser.deleteTree(path);
  await eraser.deleteAuthUser(uid);
  return { deleted: true };
}
