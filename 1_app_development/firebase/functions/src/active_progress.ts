import { Store, Tx } from "./store";

export class ActiveProgressError extends Error {}
interface ActiveProgress { progressId: string; epoch: number }
export interface VerifiedProgressTransfer {
  account: string; from: string; to: string; sourceEpoch: number;
  snapshotDigest: string; protectionDigest: string; pendingResolved: true;
}
function identifier(value: string): string {
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(value)) throw new ActiveProgressError("진행 식별자 오류");
  return value;
}
function path(uid: string): string {
  if (!uid || uid.length > 128) throw new ActiveProgressError("계정 식별자 오류");
  return `users/${encodeURIComponent(uid)}/developmentProgress/active`;
}
function decode(value: Record<string, unknown>): ActiveProgress {
  if (typeof value.progressId !== "string" || typeof value.epoch !== "number" ||
      !Number.isSafeInteger(value.epoch) || value.epoch <= 0) throw new ActiveProgressError("활성 진행 기록 손상");
  return { progressId: identifier(value.progressId), epoch: value.epoch };
}
/** Internal server function: authenticated account context required. Does not
 * lock ordinary offline play or overwrite any local wallet/save. */
export async function claimDevelopmentProgress(store: Store, uid: string, progressId: string): Promise<ActiveProgress> {
  identifier(progressId);
  return store.run(async (tx) => {
    const activePath = path(uid), old = await tx.get(activePath);
    if (old) {
      const active = decode(old);
      if (active.progressId !== progressId) throw new ActiveProgressError("진행 이전 확인 필요");
      return active;
    }
    const active = { progressId, epoch: 1 };
    tx.create(activePath, active);
    return active;
  });
}
/** Call inside the SAME transaction as reserving/committing a composite
 * purchase. A prior standalone check is vulnerable to transfer races. */
export async function requireDevelopmentProgress(tx: Tx, uid: string,
    progressId: string, epoch: number): Promise<ActiveProgress> {
  const value = await tx.get(path(uid));
  if (!value) throw new ActiveProgressError("활성 진행 등록 필요");
  const active = decode(value);
  if (active.progressId !== progressId || active.epoch !== epoch) throw new ActiveProgressError("비활성 진행의 구매 차단");
  return active;
}
/** Proof is an internal VERIFIED attestation, never a client request body.
 * Actual snapshot transfer/receipt reconciliation/cryptographic verifier must
 * precede this function. Missing evidence cannot cause a free restore. */
export async function transferDevelopmentProgress(store: Store, uid: string, transferId: string,
    proof: VerifiedProgressTransfer): Promise<ActiveProgress> {
  identifier(transferId);
  const clean = { ...proof };
  identifier(clean.from); identifier(clean.to);
  if (clean.account !== uid || clean.from === clean.to || clean.pendingResolved !== true ||
      !Number.isSafeInteger(clean.sourceEpoch) || clean.sourceEpoch <= 0 ||
      clean.sourceEpoch >= Number.MAX_SAFE_INTEGER || !clean.snapshotDigest || !clean.protectionDigest) {
    throw new ActiveProgressError("진행 이전 증거 부족");
  }
  const activePath = path(uid), transferPath = `users/${encodeURIComponent(uid)}/developmentTransfers/${transferId}`;
  return store.run(async (tx) => {
    const previous = await tx.get(transferPath), stored = await tx.get(activePath);
    if (!stored) throw new ActiveProgressError("이전 원본 진행 없음");
    const active = decode(stored);
    if (previous) {
      for (const key of Object.keys(clean) as Array<keyof VerifiedProgressTransfer>) {
        if (previous[key] !== clean[key]) throw new ActiveProgressError("이전 요청 재사용 충돌");
      }
      // Return the original result even if the account later transfers again.
      // This result does NOT re-activate the old target; purchase rechecks epoch.
      return { progressId: clean.to, epoch: clean.sourceEpoch + 1 };
    }
    // Recheck unsettled payment lock in this SAME transaction; an older
    // transfer attestation must not race a newly reserved purchase.
    const purchase=await tx.get(`users/${uid}/compositeState/pending`);
    if (purchase?.transaction) throw new ActiveProgressError("미정산 구매 복구 후 진행을 이전해야 합니다.");
    if (active.progressId !== clean.from || active.epoch !== clean.sourceEpoch) {
      throw new ActiveProgressError("활성 진행 변경, 이전 근거 재대조 필요");
    }
    const next = { progressId: clean.to, epoch: clean.sourceEpoch + 1 };
    tx.create(transferPath, clean);
    tx.set(activePath, next);
    return next;
  });
}
