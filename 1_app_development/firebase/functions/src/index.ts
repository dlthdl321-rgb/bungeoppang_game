import { createPlayPurchases } from "./play_purchases";
import { lazyFirestoreStore } from "./firestore_store";
import { ProtectedPurchasePipeline, TrustedSnapshotKey } from "./protected_purchase_pipeline";
import { AdMobSsvVerifier, AdMobKeyUnavailable } from "./admob_ssv";
import { acceptWorkshopSsv } from "./workshop_ads";
import { workshopFailure } from "./workshop_errors";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import developmentBalance from "./generated/development_balance.json";
import { WorkshopService } from "./workshop_service";
import { signedIn } from "./auth";
import { catalog } from "./catalog";
import * as friends from "./friends";
import * as invites from "./invites";
import { KakaoAccounts, KakaoError, authKakao as checkKakao, kakaoRestApi } from "./kakao";
import * as ranking from "./ranking";
import { AlreadyExists } from "./store";
import { WalletError, redeemPurchase, spendGold, syncWallet } from "./wallet";

// Callable endpoints for the app. authKakao turns a Kakao login into a
// Firebase account; every other call needs that account (auth.ts). The app
// never reads or writes Firestore itself.

initializeApp();
const db = () => getFirestore();

const store = lazyFirestoreStore(db);

const play = createPlayPurchases();

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
    const snap = await db().collection(`rankings/${board}/entries`)
      .orderBy("score", "desc").orderBy("updatedAt", "asc").limit(limit).get();
    return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  },
  async countAbove(board, score) {
    const snap = await db().collection(`rankings/${board}/entries`).where("score", ">", score).count().get();
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


// Prepared source only. Default OFF; never enable without the server evidence
// validation pipeline, secret binding and integration/security review.
function workshopService(): WorkshopService {
  if (process.env.WORKSHOP_ONLINE_ENABLED !== "true") {
    throw new HttpsError("failed-precondition", "신규 게임 온라인 검증 연결을 준비 중입니다.");
  }
  const encoded = process.env.WORKSHOP_SALE_DRAW_KEY_BASE64 ?? "";
  const key = Buffer.from(encoded,"base64");
  if (key.length < 32 || key.toString("base64") !== encoded) {
    throw new HttpsError("failed-precondition", "판매 보상 서버 설정 확인이 필요합니다.");
  }
  return new WorkshopService(store,developmentBalance,Date.now,key);
}
async function workshopCall(req: Parameters<typeof signedIn>[0], work: (service: WorkshopService, uid: string) => Promise<unknown>) {
  const uid = signedIn(req);
  try { return await work(workshopService(),uid); }
  catch (error) {
    if (error instanceof HttpsError) throw error;
    // Domain errors never disclose documents, tokens or provider data.
    const failure=workshopFailure(error);
    throw new HttpsError(failure.code, "진행·거래·검증 상태를 다시 확인해 주세요.", {reason:failure.reason,retryable:failure.retryable});
  }
}
export const workshopProgressClaim = onCall(options,req => workshopCall(req,(s,uid) => s.claim(uid,req.data)));
export const workshopPurchaseReserve = onCall(options,req => workshopCall(req,(s,uid) => s.purchase(uid,"reserve",req.data)));
export const workshopPurchaseQuery = onCall(options,req => workshopCall(req,(s,uid) => s.purchase(uid,"query",req.data)));
export const workshopPurchaseCommit = onCall(options,req => workshopCall(req,(s,uid) => s.purchase(uid,"commit",req.data)));
export const workshopPurchaseCancel = onCall(options,req => workshopCall(req,(s,uid) => s.purchase(uid,"cancel",req.data)));
export const workshopRewardSubmit = onCall(options,req => workshopCall(req,(s,uid) => s.reward(uid,req.data,true)));
export const workshopRewardQuery = onCall(options,req => workshopCall(req,(s,uid) => s.reward(uid,req.data,false)));
export const workshopAdStart = onCall(options,req => workshopCall(req,(s,uid) => {
  if(process.env.WORKSHOP_AD_SSV_ENABLED!=="true" || !(process.env.WORKSHOP_ADMOB_AD_UNITS??"").split(",").some(x=>x.trim())) {
    throw new HttpsError("failed-precondition","\uad11\uace0 \uac80\uc99d \uc124\uc815 \ud655\uc778\uc774 \ud544\uc694\ud569\ub2c8\ub2e4.",{reason:"ads-disabled",retryable:false});
  }
  return s.adStart(uid,req.data);
}));
export const workshopAdQuery = onCall(options,req => workshopCall(req,(s,uid) => s.adQuery(uid,req.data)));

export const workshopProgressTransfer = onCall(options,req => workshopCall(req,(s,uid) => s.transfer(uid,req.data)));

// Separate opt-in gate. App callbacks and callable JSON never approve ads.
const admobVerifier = new AdMobSsvVerifier();
export const workshopAdSsv = onRequest({region:"asia-northeast3"},async(req,res)=>{
  if(process.env.WORKSHOP_ONLINE_ENABLED!=="true" || process.env.WORKSHOP_AD_SSV_ENABLED!=="true") {
    res.status(503).send("disabled");return;
  }
  if(req.method!=="GET") {res.status(405).send("method not allowed");return;}
  const units=new Set((process.env.WORKSHOP_ADMOB_AD_UNITS??"").split(",").map(x=>x.trim()).filter(Boolean));
  if(!units.size) {res.status(503).send("configuration required");return;}
  const index=req.originalUrl.indexOf("?");
  try {
    if(index<0) throw new Error("missing query");
    await acceptWorkshopSsv(store,admobVerifier,req.originalUrl.slice(index+1),units,Date.now);
    res.status(200).send("ok");
  } catch(error) {
    // Never echo signed query, token, provider response or account in HTTP/logs.
    const failure=workshopFailure(error);
    res.status(error instanceof AdMobKeyUnavailable || failure.retryable ? 503:400).send("verification incomplete");
  }
});

// Clients may relay signed server attestations, but cannot sign/approve saves.
export const workshopProtectedSnapshotIngest = onCall(options,req=>workshopCall(req,async(_service,uid)=>{
  if(process.env.WORKSHOP_PROTECTION_ENABLED!=="true") {
    throw new HttpsError("failed-precondition","\ubcf4\ud638 \uac80\uc99d \uc5f0\uacb0\uc744 \uc900\ube44 \uc911\uc785\ub2c8\ub2e4.",{reason:"validator-disabled",retryable:false});
  }
  let keys:Record<string,TrustedSnapshotKey>;
  try {
    keys=JSON.parse(process.env.WORKSHOP_SNAPSHOT_VALIDATOR_KEYS_JSON??"");
    if(!keys || Array.isArray(keys) || typeof keys!=="object") throw new Error();
    return await new ProtectedPurchasePipeline(store,developmentBalance,keys,Date.now).ingest(uid,req.data);
  } catch(error) {
    if(error instanceof SyntaxError || error instanceof TypeError) {
      throw new HttpsError("failed-precondition","\ubcf4\ud638 \uac80\uc99d \uc124\uc815 \ud655\uc778\uc774 \ud544\uc694\ud569\ub2c8\ub2e4.",{reason:"validator-misconfigured",retryable:false});
    }
    throw error;
  }
}));
