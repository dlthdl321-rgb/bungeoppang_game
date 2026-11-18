import { HttpsError } from "firebase-functions/v2/https";

// Who may call the app's functions: a Firebase account signed in either with
// the custom token from authKakao (kakao.ts, uid "kakao:<회원번호>") or with
// Google through Firebase Auth's Google provider (26번 2-1단계, uid made by
// Firebase). Every document key is the uid itself, so the two kinds of
// account never share wallets, purchases or rankings. Kept apart from
// index.ts so tests can check it without starting the Admin SDK.

/** The parts of a CallableRequest that sign-in checks look at. */
export interface AuthedRequest {
  auth?: {
    uid: string;
    token: {
      firebase?: { sign_in_provider?: string };
      email?: unknown;
      email_verified?: unknown;
      [claim: string]: unknown;
    };
  };
}

export type LoginProvider = "kakao" | "google";

export interface SignedInAccount {
  uid: string;
  provider: LoginProvider;
  /** The Google account's verified email (Kakao's comes through authKakao). */
  email?: string;
}

export function signedInAccount(req: AuthedRequest): SignedInAccount {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in with Kakao or Google first");
  const token = req.auth?.token;
  const provider = token?.firebase?.sign_in_provider;
  if (provider === "custom" && token?.provider === "kakao") return { uid, provider: "kakao" };
  if (provider === "google.com") {
    const email = token?.email_verified === true && typeof token.email === "string" ? token.email : undefined;
    return { uid, provider: "google", ...(email ? { email } : {}) };
  }
  throw new HttpsError("permission-denied", "a Kakao or Google account is required");
}

export function signedIn(req: AuthedRequest): string {
  return signedInAccount(req).uid;
}
