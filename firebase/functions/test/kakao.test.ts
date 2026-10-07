import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import { AuthedRequest, signedIn } from "../src/auth";
import { KakaoAccounts, KakaoApi, KakaoError, authKakao } from "../src/kakao";

const appId = "123456";
const code = (e: unknown) => (e as KakaoError).code;

/** Kakao with one valid token per member; other tokens are expired. */
function fakeKakao(tokens: Record<string, { id: string; appId: string; nickname?: string }>): KakaoApi {
  const find = (t: string) => {
    const user = tokens[t];
    if (!user) throw new KakaoError("expired", "token expired");
    return user;
  };
  return {
    tokenInfo: async (t) => ({ id: find(t).id, appId: find(t).appId }),
    me: async (t) => ({ id: find(t).id, nickname: find(t).nickname }),
  };
}

function fakeAccounts() {
  const names = new Map<string, string | null>();
  const issued: Array<{ uid: string; claims: Record<string, unknown> }> = [];
  const accounts: KakaoAccounts = {
    createCustomToken: async (uid, claims) => {
      issued.push({ uid, claims });
      return `custom-${uid}`;
    },
    setDisplayName: async (uid, name) => void names.set(uid, name),
  };
  return { accounts, names, issued };
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

test("signedIn: only Firebase accounts made from a Kakao custom token may call", () => {
  assert.equal(signedIn(request("kakao:42", "custom", "kakao")), "kakao:42");
  const denied = (req: AuthedRequest, status: string) =>
    assert.throws(() => signedIn(req), (e) => e instanceof HttpsError && e.code === status);
  denied(request(undefined, "custom", "kakao"), "unauthenticated");
  denied(request("anon", "anonymous"), "permission-denied");
  denied(request("g", "google.com", "kakao"), "permission-denied");
  denied(request("c", "custom"), "permission-denied");
  denied(request("c", "custom", "other"), "permission-denied");
});
