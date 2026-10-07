import { initializeApp } from "firebase-admin/app";
import { getFirestore, Firestore } from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { google } from "googleapis";
import { catalog } from "./catalog";
import * as friends from "./friends";
import * as invites from "./invites";
import { AlreadyExists, Doc, Store, Tx } from "./store";
import { PlayPurchases, WalletError, redeemPurchase, spendGold, syncWallet } from "./wallet";

// Callable endpoints for the app. Every call needs a Firebase account signed
// in with Google Play Games; the app never reads or writes Firestore itself.

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

function signedIn(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in with Google Play Games first");
  if (req.auth?.token.firebase?.sign_in_provider !== "playgames.google.com") {
    throw new HttpsError("permission-denied", "a Play Games account is required");
  }
  return uid;
}

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
    if (e instanceof AlreadyExists) throw new HttpsError("aborted", "please retry");
    throw e;
  }
}

const options = { region: "asia-northeast3", enforceAppCheck: false };

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
