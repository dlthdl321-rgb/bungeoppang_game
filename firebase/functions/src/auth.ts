import { HttpsError } from "firebase-functions/v2/https";

// Who may call the app's functions: a Firebase account signed in with the
// custom token from authKakao (kakao.ts). Kept apart from index.ts so tests
// can check it without starting the Admin SDK.

/** The parts of a CallableRequest that sign-in checks look at. */
export interface AuthedRequest {
  auth?: {
    uid: string;
    token: { firebase?: { sign_in_provider?: string }; [claim: string]: unknown };
  };
}

export function signedIn(req: AuthedRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "sign in with a Kakao account first");
  const token = req.auth?.token;
  if (token?.firebase?.sign_in_provider !== "custom" || token.provider !== "kakao") {
    throw new HttpsError("permission-denied", "a Kakao account is required");
  }
  return uid;
}
