import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, Firestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";
import { signedIn } from "./auth";
import { catalog } from "./catalog";
import * as friends from "./friends";
import * as invites from "./invites";
import { KakaoAccounts, KakaoError, authKakao as checkKakao, kakaoRestApi } from "./kakao";
import * as ranking from "./ranking";
import { AlreadyExists, Doc, Store, Tx } from "./store";
import { PlayPurchases, WalletError, redeemPurchase, spendGold, syncWallet } from "./wallet";

// Callable endpoints for the app. authKakao turns a Kakao login into a
// Firebase account; every other call needs that account (auth.ts). The app
// never reads or writes Firestore itself.

initializeApp();
const db = getFirestore();

function firestoreStore(fs: Firestore): Store {
  return {
    run: (fn) =>
      fs.runTransaction(async (t) => {
        const tx: Tx = {
          get: async (path) => (await t.get(fs.doc(path))).data() as Doc | undefined,
          create: (path, data) => void t.create(fs.doc(path), data),
          set: (path, data) => void t.set(fs.doc(path), data),
        };
        return fn(tx);
      }),
    list: async (collection) =>
      (await fs.collection(collection).orderBy("__name__").get()).docs.map((d) => ({
        id: d.id,
        data: d.data(),
      })),
  };
}

const store = firestoreStore(db);

// The function's service account needs "View financial data" and "Manage
// orders" in Play Console (see docs/stage15_release_online.md).
const publisher = google.androidpublisher({
  version: "v3",
  auth: new google.auth.GoogleAuth({ scopes: ["https://www.googleapis.com/auth/androidpublisher"] }),
});

const play: PlayPurchases = {
  async get(productId, token) {
    const { data } = await publisher.purchases.products.get({
      packageName: catalog.packageName, productId, token,
    });
    return {
      purchaseState: data.purchaseState ?? 1,
      consumptionState: data.consumptionState ?? 0,
      orderId: data.orderId ?? "",
    };
  },
  async consume(productId, token) {
    await publisher.purchases.products.consume({ packageName: catalog.packageName, productId, token });
  },
};

// Custom tokens need the function's service account to hold "Service
// Account Token Creator" (docs/stage16_kakao_login_ranking.md).
const auth = getAuth();
const kakaoAccounts: KakaoAccounts = {
  createCustomToken: (uid, claims) => auth.createCustomToken(uid, claims),
  async setDisplayName(uid, name) {
    try {
      await auth.updateUser(uid, { displayName: name });
    } catch (e) {
      if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
      await auth.createUser({ uid, ...(name ? { displayName: name } : {}) });
    }
  },
};

const rankingQueries: ranking.RankingQueries = {
  async top(board, limit) {
    const snap = await db.collection(`rankings/${board}/entries`)
      .orderBy("score", "desc").orderBy("updatedAt", "asc").limit(limit).get();
    return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  },
  async countAbove(board, score) {
    const snap = await db.collection(`rankings/${board}/entries`).where("score", ">", score).count().get();
    return snap.data().count;
  },
};

/** Maps domain errors to callable errors the app can tell apart. */
async function handle<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    if (e instanceof WalletError || e instanceof invites.InviteError || e instanceof friends.FriendError) {
      const code = e.code === "insufficient" || e.code === "pending" || e.code === "not-purchased"
        ? "failed-precondition"
        : e.code === "already-owned" || e.code === "already-accepted" || e.code === "token-owned-by-other" ||
            e.code === "already-visited"
          ? "already-exists"
          : e.code === "unknown-product" || e.code === "not-found"
            ? "not-found"
            : e.code === "limit"
              ? "resource-exhausted"
              : "invalid-argument";
      throw new HttpsError(code, e.message, { reason: e.code });
    }
    if (e instanceof ranking.RankingError) {
      const code = e.code === "too-soon" ? "resource-exhausted" : "invalid-argument";
      throw new HttpsError(code, e.message, { reason: e.code });
    }
    if (e instanceof KakaoError) {
      const code = e.code === "expired"
        ? "unauthenticated"
        : e.code === "wrong-app"
          ? "permission-denied"
          : e.code === "unavailable"
            ? "unavailable"
            : e.code === "misconfigured"
              ? "failed-precondition"
              : "invalid-argument";
      throw new HttpsError(code, e.message, { reason: e.code });
    }
    if (e instanceof AlreadyExists) throw new HttpsError("aborted", "please retry");
    throw e;
  }
}

const options = { region: "asia-northeast3", enforceAppCheck: false };

// Set in functions/.env (not committed): KAKAO_APP_ID=<카카오 앱 ID>.
export const authKakao = onCall(options, (req) =>
  handle(() => checkKakao(kakaoRestApi, kakaoAccounts, process.env.KAKAO_APP_ID, req.data ?? {})));

export const walletSync = onCall(options, (req) =>
  handle(() => syncWallet(store, signedIn(req))));

export const walletRedeem = onCall(options, (req) =>
  handle(() => redeemPurchase(store, play, catalog, signedIn(req), req.data ?? {}, Date.now())));

export const walletSpend = onCall(options, (req) =>
  handle(() => spendGold(store, catalog, signedIn(req), req.data ?? {}, Date.now())));

export const inviteRegister = onCall(options, (req) =>
  handle(() => invites.register(store, signedIn(req), Date.now())));

export const inviteCreateTicket = onCall(options, (req) =>
  handle(() => invites.createTicket(store, catalog.packageName, signedIn(req), req.data ?? {}, Date.now())));

export const inviteAccept = onCall(options, (req) =>
  handle(() => invites.accept(store, signedIn(req), req.data ?? {}, Date.now())));

export const inviteLevelOne = onCall(options, (req) =>
  handle(() => invites.reachedLevelOne(store, signedIn(req), Date.now())));

export const inviteFetchEvents = onCall(options, (req) =>
  handle(async () => ({ events: await invites.fetchEvents(store, signedIn(req), req.data ?? {}) })));

export const profileSet = onCall(options, (req) =>
  handle(() => friends.setProfile(store, signedIn(req), req.data ?? {})));

export const friendAdd = onCall(options, (req) =>
  handle(() => friends.addFriend(store, signedIn(req), req.data ?? {}, Date.now())));

export const friendList = onCall(options, (req) =>
  handle(async () => ({ friends: await friends.listFriends(store, signedIn(req), Date.now()) })));

export const friendVisit = onCall(options, (req) =>
  handle(() => friends.visitFriend(store, signedIn(req), req.data ?? {}, Date.now())));

export const visitsFetch = onCall(options, (req) =>
  handle(async () => ({ visits: await friends.fetchVisits(store, signedIn(req), req.data ?? {}, Date.now()) })));

export const rankingSubmit = onCall(options, (req) =>
  handle(() => ranking.submit(store, signedIn(req), req.data ?? {}, Date.now())));

export const rankingTop = onCall(options, (req) =>
  handle(() => ranking.top(store, rankingQueries, signedIn(req), req.data ?? {})));
