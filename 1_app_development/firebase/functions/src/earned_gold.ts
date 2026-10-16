import { createHash } from "node:crypto";
import { Store } from "./store";

export interface VerifiedEarnedGold {
  account: string; claimId: string; kind: "mission" | "sale" | "rewardedAd";
  revision: string; fingerprint: string; gold: number;
}
/** Trusted server adapter only: must verify mission progress, fixed sale draw
 * or AdMob SSV and return a stable result. Never echo a client claim's amount. */
export interface EarnedGoldVerifier {
  verify(account: string, claimId: string): Promise<VerifiedEarnedGold>;
}
export class EarnedGoldError extends Error {}
function check(value: VerifiedEarnedGold, account: string, claimId: string): void {
  if (!account || account.includes("/") || value.account !== account || value.claimId !== claimId || !claimId ||
      !["mission", "sale", "rewardedAd"].includes(value.kind) || !value.revision || !value.fingerprint ||
      !Number.isSafeInteger(value.gold) || value.gold <= 0) throw new EarnedGoldError("황금 지급 검증 결과 오류");
}
/** Atomically credit the EXISTING server wallet and immutable earned ledger.
 * No callable/HTTP handler is wired. No local state can grant server gold. */
export async function creditVerifiedEarnedGold(store: Store, verifier: EarnedGoldVerifier,
    account: string, claimId: string, serverNowMs: number): Promise<{ gold: number; added: number }> {
  if (!Number.isSafeInteger(serverNowMs) || serverNowMs < 0) throw new EarnedGoldError("서버 지급 시각 오류");
  const verified = { ...await verifier.verify(account, claimId) };
  check(verified, account, claimId);
  const key = createHash("sha256").update(JSON.stringify([verified.kind, claimId])).digest("hex");
  const userPath = `users/${account}`;
  const ledgerPath = `${userPath}/ledger/earned_${key}`;
  return store.run(async (tx) => {
    const user = await tx.get(userPath), existing = await tx.get(ledgerPath);
    const balance = user?.gold ?? 0;
    if (typeof balance !== "number" || !Number.isSafeInteger(balance) || balance < 0) {
      throw new EarnedGoldError("서버 황금 지갑 손상");
    }
    if (existing) {
      for (const field of ["account", "claimId", "kind", "revision", "fingerprint", "gold"] as const) {
        if (existing[field] !== verified[field]) throw new EarnedGoldError("황금 지급 ID 재사용 충돌");
      }
      return { gold: balance, added: 0 };
    }
    const gold = balance + verified.gold;
    if (!Number.isSafeInteger(gold)) throw new EarnedGoldError("황금 지갑 범위 초과");
    tx.set(userPath, { ...user, gold });
    tx.create(ledgerPath, { ...verified, type: "earnedGold", delta: verified.gold, atMs: serverNowMs });
    return { gold, added: verified.gold };
  });
}
