import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import { AuthedRequest, signedIn, signedInAccount } from "../src/auth";
import { KakaoAccounts, KakaoApi, KakaoError, authKakao, cleanEmail } from "../src/kakao";

const appId = "123456";
const code = (e: unknown) => (e as KakaoError).code;

/** Kakao with one valid token per member; other tokens are expired. */
function fakeKakao(tokens: Record<string, { id: string; appId: string; nickname?: string; email?: string }>): KakaoApi {
  const find = (t: string) => {
    const user = tokens[t];
    if (!user) throw new KakaoError("expired", "token expired");
    return user;
  };
  return {
    tokenInfo: async (t) => ({ id: find(t).id, appId: find(t).appId }),
    me: async (t) => ({ id: find(t).id, nickname: find(t).nickname, email: find(t).email }),
  };
}

function fakeAccounts() {
  const names = new Map<string, string | null>();
  const emails = new Map<string, string | null>();
  const issued: Array<{ uid: string; claims: Record<string, unknown> }> = [];
  const accounts: KakaoAccounts = {
    createCustomToken: async (uid, claims) => {
      issued.push({ uid, claims });
      return `custom-${uid}`;
    },
    setDisplayName: async (uid, name) => void names.set(uid, name),
    saveEmail: async (uid, email) => void emails.set(uid, email),
  };
  return { accounts, names, emails, issued };
}

test("authKakao: a token from our app becomes a custom token for kakao:<회원번호>", async () => {
  const kakao = fakeKakao({ good: { id: "42", appId, nickname: " 붕어빵장인 " } });
  const { accounts, names, issued } = fakeAccounts();
  const result = await authKakao(kakao, accounts, appId, { accessToken: "good" });
  assert.deepEqual(result, { token: "custom-kakao:42", displayName: "붕어빵장인" });
  assert.deepEqual(issued, [{ uid: "kakao:42", claims: { provider: "kakao" } }]);
  assert.equal(names.get("kakao:42"), "붕어빵장인");
});

test("authKakao: no nickname shared leaves the display name empty", async () => {
  const kakao = fakeKakao({ quiet: { id: "7", appId } });
  const { accounts, names } = fakeAccounts();
  assert.equal((await authKakao(kakao, accounts, appId, { accessToken: "quiet" })).displayName, null);
  assert.equal(names.get("kakao:7"), null);
});

test("authKakao: a token issued to another Kakao app is refused", async () => {
  const kakao = fakeKakao({ other: { id: "42", appId: "999999" } });
  const { accounts, issued } = fakeAccounts();
  await assert.rejects(authKakao(kakao, accounts, appId, { accessToken: "other" }),
    (e) => code(e) === "wrong-app");
  assert.equal(issued.length, 0);
});

test("authKakao: an expired token, a missing token or a missing app ID is refused", async () => {
  const kakao = fakeKakao({});
  const { accounts, issued } = fakeAccounts();
  await assert.rejects(authKakao(kakao, accounts, appId, { accessToken: "old" }),
    (e) => code(e) === "expired");
  await assert.rejects(authKakao(kakao, accounts, appId, {}), (e) => code(e) === "invalid-argument");
  await assert.rejects(authKakao(kakao, accounts, undefined, { accessToken: "old" }),
    (e) => code(e) === "misconfigured");
  assert.equal(issued.length, 0);
});

const request = (uid: string | undefined, provider: string, claim?: string): AuthedRequest => ({
  auth: uid === undefined
    ? undefined
    : { uid, token: { firebase: { sign_in_provider: provider }, ...(claim ? { provider: claim } : {}) } },
});

test("signedIn: Kakao custom-token accounts and Google accounts may call (26번 2-1단계)", () => {
  assert.equal(signedIn(request("kakao:42", "custom", "kakao")), "kakao:42");
  // Google: Firebase makes the uid; documents are keyed by it like Kakao's.
  assert.equal(signedIn(request("Gq3x9ZpLr0aB1cD2eF3gH4iJ5kL6", "google.com")), "Gq3x9ZpLr0aB1cD2eF3gH4iJ5kL6");
  const denied = (req: AuthedRequest, status: string) =>
    assert.throws(() => signedIn(req), (e) => e instanceof HttpsError && e.code === status);
  denied(request(undefined, "custom", "kakao"), "unauthenticated");
  denied(request(undefined, "google.com"), "unauthenticated");
  denied(request("anon", "anonymous"), "permission-denied");
  denied(request("p", "password"), "permission-denied");
  denied(request("a", "apple.com"), "permission-denied");
  denied(request("c", "custom"), "permission-denied");
  denied(request("c", "custom", "other"), "permission-denied");
});

test("signedInAccount: the provider and only a verified Google email", () => {
  assert.deepEqual(signedInAccount(request("kakao:42", "custom", "kakao")), { uid: "kakao:42", provider: "kakao" });
  const google = (email: unknown, verified: unknown): AuthedRequest => ({
    auth: { uid: "g1", token: { firebase: { sign_in_provider: "google.com" }, email, email_verified: verified } },
  });
  assert.deepEqual(signedInAccount(google("me@example.com", true)), { uid: "g1", provider: "google", email: "me@example.com" });
  assert.deepEqual(signedInAccount(google("me@example.com", false)), { uid: "g1", provider: "google" });
  assert.deepEqual(signedInAccount(google(undefined, true)), { uid: "g1", provider: "google" });
});

test("authKakao: a shared, verified email is kept; none shared forgets it", async () => {
  const kakao = fakeKakao({ mail: { id: "5", appId, email: "owner@example.com" }, quiet: { id: "6", appId } });
  const { accounts, emails } = fakeAccounts();
  await authKakao(kakao, accounts, appId, { accessToken: "mail" });
  await authKakao(kakao, accounts, appId, { accessToken: "quiet" });
  assert.equal(emails.get("kakao:5"), "owner@example.com");
  assert.equal(emails.get("kakao:6"), null);
  assert.equal(cleanEmail(" a@b.co "), "a@b.co");
  assert.equal(cleanEmail("not an email"), null);
  assert.equal(cleanEmail(42), null);
});
