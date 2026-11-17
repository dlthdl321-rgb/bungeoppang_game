// Options shared by every callable the app uses.
//
// App Check (23번 7단계): callables reject requests without a valid App Check
// token (Play Integrity on Play builds, a registered debug token on debug
// builds). APP_CHECK_ENFORCED=false in functions/.env turns enforcement off for
// a short troubleshooting window only; anything else, including no value,
// keeps it on so a forgotten setting fails closed. The value is read when the
// Firebase CLI loads the functions at deploy time, so changing it needs a
// redeploy.

export const functionsRegion = "asia-northeast3";

export interface CallableOptions {
  region: string;
  enforceAppCheck: boolean;
}

export function callableOptions(env: Record<string, string | undefined> = process.env): CallableOptions {
  return { region: functionsRegion, enforceAppCheck: env.APP_CHECK_ENFORCED !== "false" };
}
