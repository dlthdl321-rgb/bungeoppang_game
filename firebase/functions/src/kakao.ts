// Kakao login. The app logs in with the Kakao SDK and sends its access token
// here; the server asks Kakao whose token it is and which app issued it, then
// hands back a Firebase custom token for the uid "kakao:<회원번호>". Only the
// member number and the nickname (if the player agreed to share it) are used.

export class KakaoError extends Error {
  constructor(
    readonly code: "invalid-argument" | "expired" | "wrong-app" | "unavailable" | "misconfigured",
    message: string,
  ) {
    super(message);
  }
}

/** The two Kakao REST calls the server needs; tests pass a fake. */
export interface KakaoApi {
  /** GET /v1/user/access_token_info: the member and the app the token belongs to. */
  tokenInfo(accessToken: string): Promise<{ id: string; appId: string }>;
  /** GET /v2/user/me: the member number and the nickname if agreed to. */
  me(accessToken: string): Promise<{ id: string; nickname?: string }>;
}

/** Firebase Auth operations, injected so tests need no Admin SDK. */
export interface KakaoAccounts {
  createCustomToken(uid: string, claims: Record<string, unknown>): Promise<string>;
  /** Creates the Auth user if needed; null removes the display name. */
  setDisplayName(uid: string, name: string | null): Promise<void>;
}

const idPattern = /^[0-9]{1,20}$/;

async function kakaoGet(path: string, accessToken: string): Promise<Record<string, unknown>> {
  let res: Response;
  try {
    res = await fetch(`https://kapi.kakao.com${path}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch {
    throw new KakaoError("unavailable", "Kakao is unreachable");
  }
  // 401 (code -401): the token does not exist or has expired.
  if (res.status === 401) throw new KakaoError("expired", "the Kakao token is invalid or expired");
  if (res.status === 400) throw new KakaoError("invalid-argument", "Kakao rejected the token");
  if (!res.ok) throw new KakaoError("unavailable", `Kakao answered ${res.status}`);
  return (await res.json()) as Record<string, unknown>;
}

export const kakaoRestApi: KakaoApi = {
  async tokenInfo(accessToken) {
    const info = await kakaoGet("/v1/user/access_token_info", accessToken);
    return { id: String(info.id ?? ""), appId: String(info.app_id ?? "") };
  },
  async me(accessToken) {
    const user = await kakaoGet("/v2/user/me", accessToken);
    const account = user.kakao_account as { profile?: { nickname?: unknown } } | undefined;
    const properties = user.properties as { nickname?: unknown } | undefined;
    const nickname = account?.profile?.nickname ?? properties?.nickname;
    return {
      id: String(user.id ?? ""),
      nickname: typeof nickname === "string" ? nickname : undefined,
    };
  },
};

/** Display name for Firebase Auth; null when the player shared none. */
export function kakaoDisplayName(nickname: string | undefined): string | null {
  const name = nickname?.trim().slice(0, 16) ?? "";
  return name.length > 0 ? name : null;
}

/**
 * Checks a Kakao access token and returns a Firebase custom token.
 * [appId] is our Kakao app ID (env KAKAO_APP_ID); tokens issued to any other
 * app are refused, so a token from another service cannot sign in here.
 */
export async function authKakao(
  kakao: KakaoApi, accounts: KakaoAccounts, appId: string | undefined,
  input: { accessToken?: unknown },
) {
  if (!appId || !idPattern.test(appId)) throw new KakaoError("misconfigured", "KAKAO_APP_ID is not set");
  const { accessToken } = input;
  if (typeof accessToken !== "string" || accessToken.length === 0 || accessToken.length > 512) {
    throw new KakaoError("invalid-argument", "accessToken is required");
  }
  const info = await kakao.tokenInfo(accessToken);
  if (info.appId !== appId) throw new KakaoError("wrong-app", "the token was issued to another app");
  const user = await kakao.me(accessToken);
  if (!idPattern.test(user.id) || user.id !== info.id) {
    throw new KakaoError("invalid-argument", "Kakao returned an unexpected member");
  }
  const uid = `kakao:${user.id}`;
  const displayName = kakaoDisplayName(user.nickname);
  await accounts.setDisplayName(uid, displayName);
  const token = await accounts.createCustomToken(uid, { provider: "kakao" });
  return { token, displayName };
}
