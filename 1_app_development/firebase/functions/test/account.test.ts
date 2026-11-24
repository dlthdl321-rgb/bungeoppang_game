import assert from "node:assert/strict";
import { test } from "node:test";
import {
  AccountError, AccountEraser, cleanOwnerName, deleteAccount, rememberEmail, requiredConsentVersion,
  setAccountProfile,
} from "../src/account";
import * as friends from "../src/friends";
import * as invites from "../src/invites";
import * as ranking from "../src/ranking";
import { MemoryStore } from "../src/store";

// 26번 2-1단계: account profile (owner name, consents, optional info) and
// in-app account deletion, for Kakao and Google accounts alike.

const start = Date.UTC(2026, 10, 18, 3);
const googleUid = "Gq3x9ZpLr0aB1cD2eF3gH4iJ5kL6";
const code = (e: unknown) => (e as AccountError).code;
const google = { uid: googleUid, provider: "google" as const, email: "owner@example.com" };
const kakao = { uid: "kakao:42", provider: "kakao" as const };

/** Deletes like Firestore's recursiveDelete, and records the Auth deletions. */
function memoryEraser(store: MemoryStore) {
  const authDeleted: string[] = [];
  const eraser: AccountEraser = {
    async deleteTree(path) {
      for (const key of [...store.docs.keys()]) {
        if (key === path || key.startsWith(`${path}/`)) store.docs.delete(key);
      }
    },
    async deletePrefixed(collection, prefix) {
      for (const key of [...store.docs.keys()]) {
        if (key.startsWith(`${collection}/${prefix}`)) store.docs.delete(key);
      }
    },
    async deleteAuthUser(uid) {
      authDeleted.push(uid);
    },
  };
  return { eraser, authDeleted };
}

test("owner name: 2~8 Hangul syllables, Latin letters or digits", () => {
  assert.equal(cleanOwnerName(" 붕어빵장인 "), "붕어빵장인");
  assert.equal(cleanOwnerName("Bun8"), "Bun8");
  assert.equal(cleanOwnerName("가나다라마바사아"), "가나다라마바사아");
  for (const bad of ["가", "가나다라마바사아자", "붕어 빵", "ㄱㄴ", "bun!", "", 7, null]) {
    assert.throws(() => cleanOwnerName(bad), (e) => code(e) === "invalid-argument", String(bad));
  }
});

test("accountProfileSet: name and required consent; Google email from the token", async () => {
  const store = new MemoryStore();
  await setAccountProfile(store, google, { name: "구글사장", consentVersion: requiredConsentVersion, over14Confirmed: true }, start);
  assert.deepEqual(store.docs.get(`accountProfiles/${googleUid}`), {
    provider: "google",
    name: "구글사장",
    email: "owner@example.com",
    requiredConsent: { version: requiredConsentVersion, atMs: start, over14: true },
    updatedAtMs: start,
  });
  // A later rename keeps the first consent time.
  await setAccountProfile(store, google, { name: "새이름", consentVersion: requiredConsentVersion, over14Confirmed: true }, start + 1000);
  const doc = store.docs.get(`accountProfiles/${googleUid}`)!;
  assert.equal(doc.name, "새이름");
  assert.deepEqual(doc.requiredConsent, { version: requiredConsentVersion, atMs: start, over14: true });
});

test("accountProfileSet: Kakao keeps the email authKakao remembered", async () => {
  const store = new MemoryStore();
  await rememberEmail(store, "kakao:42", "k@example.com");
  await setAccountProfile(store, kakao, { name: "카카오", consentVersion: requiredConsentVersion, over14Confirmed: true }, start);
  assert.equal(store.docs.get("accountProfiles/kakao:42")!.email, "k@example.com");
  await rememberEmail(store, "kakao:42", null);
  assert.equal(store.docs.get("accountProfiles/kakao:42")!.email, undefined);
  assert.equal(store.docs.get("accountProfiles/kakao:42")!.name, "카카오");
  // Nothing to forget for an account that never had a profile.
  await rememberEmail(store, "kakao:7", null);
  assert.equal(store.docs.has("accountProfiles/kakao:7"), false);
});

test("accountProfileSet: optional gender and age band only with their own consent, cleared by omission", async () => {
  const store = new MemoryStore();
  const path = `accountProfiles/${googleUid}`;
  await setAccountProfile(store, google, {
    name: "구글사장", consentVersion: requiredConsentVersion, over14Confirmed: true, optional: { gender: "female", ageBand: "20s" },
  }, start);
  let doc = store.docs.get(path)!;
  assert.deepEqual([doc.gender, doc.ageBand, doc.optionalConsent], ["female", "20s", { atMs: start }]);
  await setAccountProfile(store, google, { name: "구글사장", consentVersion: requiredConsentVersion, over14Confirmed: true }, start + 5);
  doc = store.docs.get(path)!;
  assert.deepEqual([doc.gender, doc.ageBand, doc.optionalConsent], [undefined, undefined, undefined]);
  await assert.rejects(setAccountProfile(store, google, {
    name: "구글사장", consentVersion: requiredConsentVersion, over14Confirmed: true, optional: { gender: "other", ageBand: "20s" },
  }, start), (e) => code(e) === "invalid-argument");
});

test("accountProfileSet: only players who confirmed 만 14세 이상; no under-14 band; the terms version must match", async () => {
  const store = new MemoryStore();
  const path = "accountProfiles/kakao:42";
  // Without the 만 14세 이상 tick nothing is saved.
  for (const over14Confirmed of [undefined, false, "true"]) {
    await assert.rejects(setAccountProfile(store, kakao, {
      name: "어린이", consentVersion: requiredConsentVersion, over14Confirmed,
    }, start), (e) => code(e) === "age-required", String(over14Confirmed));
  }
  assert.equal(store.docs.has(path), false);
  // The under-14 age band is gone, guardian consent or not.
  await assert.rejects(setAccountProfile(store, kakao, {
    name: "어린이", consentVersion: requiredConsentVersion, over14Confirmed: true,
    optional: { gender: "none", ageBand: "under14", guardianConsent: true },
  }, start), (e) => code(e) === "invalid-argument");
  // An older profile's guardian record does not survive the next save.
  store.docs.set(path, { name: "예전", ageBand: "under14", guardianConsentAtMs: 1, requiredConsent: { version: "2026-11-18", atMs: 1 } });
  await setAccountProfile(store, kakao, { name: "사장님", consentVersion: requiredConsentVersion, over14Confirmed: true }, start);
  const doc = store.docs.get(path)!;
  assert.deepEqual([doc.ageBand, doc.guardianConsentAtMs], [undefined, undefined]);
  assert.deepEqual(doc.requiredConsent, { version: requiredConsentVersion, atMs: start, over14: true }, "re-consent time");
  // The consent before the 만 14세 이상 question (2026-11-18) is not enough,
  // nor the one before `ingredient_out` joined the privacy notice (2026-11-19, 4차 병합 3).
  for (const consentVersion of ["2020-01-01", "2026-11-18", "2026-11-19"]) {
    await assert.rejects(setAccountProfile(store, kakao, { name: "어린이", consentVersion, over14Confirmed: true }, start),
      (e) => code(e) === "consent-required", consentVersion);
  }
  assert.equal(requiredConsentVersion, "2026-11-21");
});

test("Google uids work with friends, invites and rankings like Kakao uids", async () => {
  const store = new MemoryStore();
  const mine = await invites.register(store, googleUid, start);
  const theirs = await invites.register(store, "kakao:42", start);
  await friends.setProfile(store, googleUid, { name: "구글사장", look: { hair: "long" } });
  await ranking.submit(store, googleUid, { lifetime: "9000" }, start);
  assert.equal(store.docs.get(`rankings/lifetime/entries/${googleUid}`)!.name, "구글사장");
  await friends.addFriend(store, "kakao:42", { code: mine.referralCode }, start);
  assert.ok(store.docs.has(`friends/${googleUid}/list/kakao:42`));
  assert.notEqual(mine.playerId, theirs.playerId);
});

test("accountDelete removes everything keyed by the account, both friendship sides and the login", async () => {
  const store = new MemoryStore();
  const { eraser, authDeleted } = memoryEraser(store);
  const mine = await invites.register(store, googleUid, start);
  await friends.setProfile(store, googleUid, { name: "구글사장", look: { hair: "long" } });
  await setAccountProfile(store, google, {
    name: "구글사장", consentVersion: requiredConsentVersion, over14Confirmed: true, optional: { gender: "male", ageBand: "30s" },
  }, start);
  await ranking.submit(store, googleUid, { lifetime: "9000", bestCombo: 3 }, start);
  await invites.register(store, "kakao:42", start);
  await friends.setProfile(store, "kakao:42", { name: "친구", look: { hair: "short" } });
  await friends.addFriend(store, "kakao:42", { code: mine.referralCode }, start);
  await friends.visitFriend(store, "kakao:42", { playerId: mine.playerId }, start);
  store.docs.set(`users/${googleUid}/ledger/purchase_x`, { amount: 60 });
  store.docs.set(`users/${googleUid}/entitlements/cosmetic_hat`, { atMs: start });
  store.docs.set("purchases/tokenhash", { uid: googleUid, productId: "gold_60", orderId: "GPA.1" });

  assert.deepEqual(await deleteAccount(store, eraser, googleUid), { deleted: true });

  const left = [...store.docs.keys()];
  assert.deepEqual(left.filter((p) => p.includes(googleUid)), [], "nothing keyed by the uid");
  assert.equal(store.docs.has(`inviteCodes/${mine.referralCode}`), false);
  assert.equal(store.docs.has(`players/${mine.playerId}`), false);
  assert.equal(store.docs.has(`friends/kakao:42/list/${googleUid}`), false, "the friend's side too");
  // The other player keeps their own data; payment records stay for the law.
  assert.ok(store.docs.has("inviteProfiles/kakao:42"));
  assert.ok(store.docs.has("purchases/tokenhash"));
  assert.deepEqual(authDeleted, [googleUid]);
  // Retrying after a partial failure is harmless.
  assert.deepEqual(await deleteAccount(store, eraser, googleUid), { deleted: true });
});

test("accountDelete also clears the encoded users path of Kakao reward decisions", async () => {
  const store = new MemoryStore();
  const { eraser } = memoryEraser(store);
  store.docs.set("users/kakao%3A42/developmentRewardDecisions/sale_1", { ok: true });
  store.docs.set("users/kakao:42", { gold: 3 });
  store.docs.set("users/kakao:4200", { gold: 1 });
  await deleteAccount(store, eraser, "kakao:42");
  assert.deepEqual([...store.docs.keys()], ["users/kakao:4200"]);
});
