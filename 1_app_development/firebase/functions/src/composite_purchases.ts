import { createHash } from "node:crypto";
import { requireDevelopmentProgress } from "./active_progress";
import { CompositeIntent, parseCompositeIntent, assertSameCompositeIntent,
  validateDevelopmentCompositeQuote } from "./development_contracts";
import { Store, Tx } from "./store";

export class CompositePurchaseError extends Error {}
export interface PurchaseContext { account: string; progress: string; epoch: number }
export interface VerifiedPurchaseEvidence {
  account: string; progress: string; transaction: string; fingerprint: string;
  phase: "reservation" | "debit"; snapshotDigest: string; level?: number;
  availableBuns: string; lifetimeBuns: string;
}
/** Must verify protected progress/journal evidence. Never echo request JSON or
 * treat an App Check token / client debited=true as verified wallet evidence. */
export interface PurchaseEvidenceVerifier {
  verify(context: PurchaseContext, intent: CompositeIntent,
    phase: "reservation" | "debit"): Promise<VerifiedPurchaseEvidence>;
}
interface PurchaseRecord extends CompositeIntent {
  [key: string]: unknown;
  progress: string; epoch: number; status: "reserved" | "committed" | "canceled";
  receiptId: string; grantId: string; reservedDigest: string; debitDigest: string;
}
export function purchaseFingerprint(intent: CompositeIntent): string {
  return createHash("sha256").update(JSON.stringify([intent.account, intent.transaction,
    intent.revision, intent.skill, intent.owned, intent.quantity, intent.buns, intent.gold])).digest("hex");
}
function user(context: PurchaseContext): string {
  if (!context.account || context.account.includes("/") || context.account.length > 128 ||
      !Number.isSafeInteger(context.epoch) || context.epoch <= 0) throw new CompositePurchaseError("구매 계정/진행 오류");
  return `users/${context.account}`;
}
function transactionPath(context: PurchaseContext, id: string): string {
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) throw new CompositePurchaseError("거래 ID 오류");
  return `${user(context)}/compositePurchases/${id}`;
}
function natural(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new CompositePurchaseError("황금/보유 기록 오류");
  return value;
}
function decimal(value: unknown): bigint {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw new CompositePurchaseError("붕어빵력 증거 오류");
  return BigInt(value);
}
function checkProof(proof: VerifiedPurchaseEvidence, ctx: PurchaseContext, intent: CompositeIntent,
    phase: "reservation" | "debit"): void {
  if (proof.account !== ctx.account || proof.progress !== ctx.progress || proof.transaction !== intent.transaction ||
      proof.fingerprint !== purchaseFingerprint(intent) || proof.phase !== phase || !proof.snapshotDigest) {
    throw new CompositePurchaseError("구매 진행/차감 증거 불일치");
  }
  decimal(proof.availableBuns); decimal(proof.lifetimeBuns);
  if (phase === "reservation" && decimal(proof.availableBuns) < BigInt(intent.buns)) throw new CompositePurchaseError("일반 재화 부족");
}
function decode(value: Record<string, unknown>, ctx: PurchaseContext, id: string): PurchaseRecord {
  parseCompositeIntent(value, ctx.account);
  if (value.transaction !== id || value.progress !== ctx.progress || value.epoch !== ctx.epoch ||
      !["reserved", "committed", "canceled"].includes(String(value.status)) ||
      typeof value.receiptId !== "string" || typeof value.grantId !== "string" ||
      typeof value.reservedDigest !== "string" || !value.reservedDigest || typeof value.debitDigest !== "string" ||
      (value.status === "reserved" && (value.receiptId !== "" || value.grantId !== "")) ||
      (value.status !== "reserved" && !value.receiptId) ||
      (value.status === "committed" && (!value.grantId || !value.debitDigest)) ||
      (value.status === "canceled" && value.grantId !== "")) throw new CompositePurchaseError("구매 원장 손상/다른 진행");
  return value as PurchaseRecord;
}
function receipt(record: PurchaseRecord): Record<string, unknown> {
  const { account, transaction, revision, skill, owned, quantity, buns, gold, status, receiptId, grantId } = record;
  return { account, transaction, revision, skill, owned, quantity, buns, gold, status, receiptId, grantId };
}
async function active(tx: Tx, context: PurchaseContext): Promise<void> {
  await requireDevelopmentProgress(tx, context.account, context.progress, context.epoch);
}
/** Reservation holds gold by debiting the server available wallet once. It is
 * NOT a grant; canceled reservations restore that exact hold once. No TTL or
 * automatic ambiguous-result refund policy is invented. All APIs are internal. */
export async function reserveCompositePurchase(store: Store, config: unknown,
    verifier: PurchaseEvidenceVerifier, context: PurchaseContext, input: unknown): Promise<Record<string, unknown>> {
  context = { ...context };
  const intent = parseCompositeIntent(input, context.account), base = user(context);
  if (!/^(?:(tap|auto)_([1-9]|1[0-6])|cosmetic:[A-Za-z0-9_]+)$/.test(intent.skill)) throw new CompositePurchaseError("스킬 식별자 오류");
  const prior = await store.run(async tx => {
    await active(tx, context);
    const row = await tx.get(transactionPath(context, intent.transaction));
    if (!row) return undefined;
    const old = decode(row, context, intent.transaction);
    assertSameCompositeIntent(intent, old);
    return receipt(old);
  });
  if (prior) return prior;
  const proof = { ...await verifier.verify(context, intent, "reservation") };
  checkProof(proof, context, intent, "reservation");
  return store.run(async (tx) => {
    await active(tx, context);
    const path = transactionPath(context, intent.transaction), existing = await tx.get(path);
    if (existing) {
      const old = decode(existing, context, intent.transaction);
      assertSameCompositeIntent(intent, old);
      return receipt(old);
    }
    const lockPath = `${base}/compositeState/pending`, ownedPath = `${base}/compositeSkills/${intent.skill}`;
    const lock = await tx.get(lockPath), ownership = await tx.get(ownedPath), wallet = await tx.get(base);
    if (lock?.transaction) throw new CompositePurchaseError("미정산 거래를 먼저 복구해야 합니다.");
    const owned = natural(ownership?.owned ?? 0);
    validateDevelopmentCompositeQuote(config, intent, context.account, owned);
    const root=config as { skill_purchase:{ entries:Record<string,{unlock_total:string}> };avatar_catalog:Record<string,{unlock_total:string;unlock_level:number}> };
    const entry=intent.skill.startsWith("cosmetic:") ? root.avatar_catalog[intent.skill.slice(9)] : root.skill_purchase.entries[intent.skill];
    if (intent.skill.startsWith("cosmetic:")) {
      const cosmetic=root.avatar_catalog[intent.skill.slice(9)];
      if (!Number.isSafeInteger(proof.level) || proof.level!<cosmetic.unlock_level) throw new CompositePurchaseError("꾸미기 레벨 해금 전");
    }
    if (decimal(proof.lifetimeBuns) < decimal(entry.unlock_total)) throw new CompositePurchaseError("스킬 해금 전");
    const gold = natural(wallet?.gold ?? 0), cost = BigInt(intent.gold);
    if (cost > BigInt(gold)) throw new CompositePurchaseError("황금붕어빵력 부족");
    const next: PurchaseRecord = { ...intent, progress: context.progress, epoch: context.epoch,
      status: "reserved", receiptId: "", grantId: "", reservedDigest: proof.snapshotDigest, debitDigest: "" };
    tx.set(base, { ...wallet, gold: gold - Number(cost) });
    tx.create(path, next); tx.set(lockPath, { transaction: intent.transaction });
    return receipt(next);
  });
}
export async function finishCompositePurchase(store: Store, verifier: PurchaseEvidenceVerifier,
    context: PurchaseContext, input: unknown, action: "commit" | "cancel"): Promise<Record<string, unknown>> {
  if (action !== "commit" && action !== "cancel") throw new CompositePurchaseError("구매 명령 오류");
  context = { ...context };
  const intent = parseCompositeIntent(input, context.account), base = user(context);
  if (!/^(?:(tap|auto)_([1-9]|1[0-6])|cosmetic:[A-Za-z0-9_]+)$/.test(intent.skill)) throw new CompositePurchaseError("스킬 식별자 오류");
  const terminal = await store.run(async tx => {
    await active(tx, context);
    const row = await tx.get(transactionPath(context, intent.transaction));
    if (!row) return { account: context.account, transaction: intent.transaction, status: "unknown" };
    const old = decode(row, context, intent.transaction);
    assertSameCompositeIntent(intent, old);
    return old.status === "reserved" ? undefined : receipt(old);
  });
  if (terminal) return terminal;
  const proof = action === "commit" ? { ...await verifier.verify(context, intent, "debit") } : undefined;
  if (proof) checkProof(proof, context, intent, "debit");
  return store.run(async (tx) => {
    await active(tx, context);
    const path = transactionPath(context, intent.transaction), value = await tx.get(path);
    if (!value) return { account: context.account, transaction: intent.transaction, status: "unknown" };
    const old = decode(value, context, intent.transaction); assertSameCompositeIntent(intent, old);
    if (old.status !== "reserved") return receipt(old); // Terminal result wins over late cancel/commit.
    const lockPath = `${base}/compositeState/pending`, ownedPath = `${base}/compositeSkills/${intent.skill}`;
    const lock = await tx.get(lockPath), ownership = await tx.get(ownedPath), wallet = await tx.get(base);
    if (lock?.transaction !== intent.transaction || natural(ownership?.owned ?? 0) !== intent.owned) {
      throw new CompositePurchaseError("구매 잠금/보유 회차 재대조 필요");
    }
    const balance = natural(wallet?.gold ?? 0);
    const status = action === "commit" ? "committed" : "canceled";
    const digest = purchaseFingerprint(intent);
    const next: PurchaseRecord = { ...old, status, receiptId: `${status}_${digest}`,
      grantId: action === "commit" ? `skill_${digest}` : "", debitDigest: proof?.snapshotDigest ?? "" };
    if (action === "cancel") {
      const refunded = BigInt(balance) + BigInt(intent.gold);
      if (refunded > BigInt(Number.MAX_SAFE_INTEGER)) throw new CompositePurchaseError("황금 복원 범위 초과");
      tx.set(base, { ...wallet, gold: Number(refunded) });
    } else {
      const owned = intent.owned + intent.quantity;
      if (!Number.isSafeInteger(owned)) throw new CompositePurchaseError("보유 회차 범위 초과");
      tx.set(ownedPath, { ...ownership, owned });
    }
    tx.set(path, next); tx.set(lockPath, { transaction: null });
    return receipt(next);
  });
}
export async function queryCompositePurchase(store: Store, context: PurchaseContext,
    transaction: string): Promise<Record<string, unknown>> {
  return store.run(async (tx) => {
    const value = await tx.get(transactionPath(context, transaction));
    return value ? receipt(decode(value, context, transaction)) :
      { account: context.account, transaction, status: "unknown" };
  });
}
