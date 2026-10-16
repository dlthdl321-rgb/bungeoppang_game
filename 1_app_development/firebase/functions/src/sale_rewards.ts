import { createHash, createHmac } from "node:crypto";
import { Store } from "./store";

export interface VerifiedSaleRewardEvidence {
  account: string; saleId: string; progress: string; revision: string; fingerprint: string;
  status: "verified" | "pending" | "unverifiable"; stars: number;
}
export interface SaleRewardVerifier {
  verify(account: string, saleId: string): Promise<VerifiedSaleRewardEvidence>;
}
/** Approved DEC-022 follow-up: first finalized SERVER review's KST day;
 * capped rewards never carry over. Read the trusted clock after verification
 * on each transaction attempt, rather than before a long verification wait. */
export function saleRewardKstDay(serverNowMs: number): string {
  natural(serverNowMs);
  const date = new Date(serverNowMs + 540 * 60000);
  if (!Number.isFinite(date.getTime())) throw new SaleRewardError("판매 보상 서버 시각 오류");
  return date.toISOString().slice(0,10);
}
export interface SaleRewardResult extends Record<string, unknown> {
  account: string; evidence: string; kind: "sale"; revision: string; fingerprint: string;
  outcome: "eligible" | "noWin" | "unverifiable";
  reason: "won" | "drawLost" | "dailyCap" | "invalidEvidence";
  progress: string; policyRevision: string; day: string; gold: number; draw: number | null;
}
export class SaleRewardError extends Error {}
function natural(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new SaleRewardError("판매 보상 설정/기록 오류");
  return value;
}
function policy(config: unknown) {
  const root = config as { metadata: { revision: string }; rare_gold_sale: {
    probability_basis_points_by_stars: number[]; gold_per_award: number;
    daily_gold_cap: number; one_draw_per_sale: number; maximum_gold_per_sale: number } };
  const row = root.rare_gold_sale;
  if (typeof root.metadata.revision !== "string" || !root.metadata.revision || row.one_draw_per_sale !== 1 ||
      !Array.isArray(row.probability_basis_points_by_stars) || row.probability_basis_points_by_stars.length !== 5 ||
      row.probability_basis_points_by_stars.some((v,i,a) => natural(v) > 10000 || (i > 0 && v < a[i-1])) ||
      natural(row.gold_per_award) === 0 || row.gold_per_award > natural(row.maximum_gold_per_sale)) {
    throw new SaleRewardError("판매 보상 정책 오류");
  }
  return { revision: root.metadata.revision, odds: [...row.probability_basis_points_by_stars],
    gold: row.gold_per_award, cap: natural(row.daily_gold_cap) };
}
/** Rejection sampling avoids modulo bias. Key is server-only and must survive
 * retries; it is never sourced from clients/config JSON or returned in receipts. */
function draw(key: Uint8Array, account: string, saleId: string): number {
  if (key.byteLength < 32) throw new SaleRewardError("서버 추첨 키 설정 필요");
  const range = Math.floor(0x100000000 / 10000) * 10000;
  for (let counter = 0; counter < 128; counter++) {
    const digest = createHmac("sha256",key).update(JSON.stringify(["sale",account,saleId,counter])).digest();
    for (let offset = 0; offset < digest.length; offset += 4) {
      const value = digest.readUInt32BE(offset);
      if (value < range) return value % 10000;
    }
  }
  throw new SaleRewardError("추첨 범위 생성 실패");
}
function paths(account: string, saleId: string) {
  if (!account || account.includes("/") || account.length > 128 || !/^[A-Za-z0-9_-]{8,64}$/.test(saleId)) {
    throw new SaleRewardError("판매 계정/식별자 오류");
  }
  const base = `users/${account}`;
  const digest = createHash("sha256").update(JSON.stringify(["sale",saleId])).digest("hex");
  return { base, result: `${base}/saleRewardResults/${saleId}`, ledger: `${base}/ledger/earned_${digest}` };
}
function decode(row: Record<string,unknown>, account: string, saleId: string): SaleRewardResult {
  if (row.account !== account || row.evidence !== saleId || row.kind !== "sale" ||
      !["eligible","noWin","unverifiable"].includes(String(row.outcome)) ||
      typeof row.fingerprint !== "string" || !row.fingerprint || typeof row.revision !== "string" || !row.revision ||
      typeof row.progress !== "string" || !row.progress || typeof row.policyRevision !== "string" || !row.policyRevision ||
      typeof row.day !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(row.day) ||
      !Number.isFinite(Date.parse(`${row.day}T00:00:00Z`)) ||
      new Date(`${row.day}T00:00:00Z`).toISOString().slice(0,10) !== row.day || typeof row.reason !== "string" ||
      !["won","drawLost","dailyCap","invalidEvidence"].includes(row.reason) ||
      (row.outcome === "eligible") !== (natural(row.gold) > 0) ||
      (row.draw !== null && natural(row.draw) >= 10000) ||
      (row.outcome === "eligible" && (row.reason !== "won" || row.draw === null)) ||
      (row.outcome === "noWin" && (!["drawLost","dailyCap"].includes(row.reason) || row.draw === null)) ||
      (row.outcome === "unverifiable" && (row.reason !== "invalidEvidence" || row.draw !== null))) throw new SaleRewardError("판매 보상 결과 손상");
  return row as SaleRewardResult;
}
/** Internal only. First accepted result, daily usage, existing wallet and credit
 * ledger commit together. Offline evidence is NOT accepted without verifier.
 * A noWin/unverifiable result is durable and cannot be rerolled tomorrow. */
export async function reviewAndCreditSale(store: Store, verifier: SaleRewardVerifier,
    config: unknown, key: Uint8Array,
    account: string, saleId: string, serverClock: () => number): Promise<SaleRewardResult | { outcome: "pending" }> {
  const path = paths(account,saleId);
  // Read first so a final result survives balance/key/verifier revisions.
  const prior = await querySaleReward(store,account,saleId);
  if (prior) return prior;
  const rules = policy(config), secret = Uint8Array.from(key);
  const evidence = { ...await verifier.verify(account,saleId) };
  if (evidence.account !== account || evidence.saleId !== saleId || !evidence.progress || !evidence.revision ||
      !evidence.fingerprint || !["verified","pending","unverifiable"].includes(evidence.status) ||
      natural(evidence.stars) < 1 || evidence.stars > 5) throw new SaleRewardError("판매 검증 증거 불일치");
  if (evidence.status === "pending") return { outcome:"pending" };
  const roll = evidence.status === "verified" ? draw(secret,account,saleId) : null;
  return store.run(async (tx) => {
    const stored = await tx.get(path.result);
    if (stored) {
      const old = decode(stored,account,saleId);
      if (old.fingerprint !== evidence.fingerprint || old.progress !== evidence.progress || old.revision !== evidence.revision) {
        throw new SaleRewardError("같은 판매의 증거 재사용 충돌");
      }
      return old;
    }
    const serverNowMs = serverClock();
    const day = saleRewardKstDay(serverNowMs);
    const dayPath = `${path.base}/saleRewardDays/${day}`;
    const usage = await tx.get(dayPath), wallet = await tx.get(path.base), ledger = await tx.get(path.ledger);
    if (ledger) throw new SaleRewardError("결과 없는 판매 지급 원장 재대조 필요");
    const used = natural(usage?.gold ?? 0), balance = natural(wallet?.gold ?? 0);
    const won = roll !== null && roll < rules.odds[evidence.stars-1];
    const gold = won && BigInt(used) + BigInt(rules.gold) <= BigInt(rules.cap) ? rules.gold : 0;
    if (BigInt(balance) + BigInt(gold) > BigInt(Number.MAX_SAFE_INTEGER)) throw new SaleRewardError("황금 지갑 범위 초과");
    const result: SaleRewardResult = { account,evidence:saleId,kind:"sale",revision:evidence.revision,
      fingerprint:evidence.fingerprint,progress:evidence.progress,policyRevision:rules.revision,day,gold,draw:roll,
      outcome:evidence.status === "unverifiable" ? "unverifiable" : gold > 0 ? "eligible" : "noWin",
      reason:evidence.status === "unverifiable" ? "invalidEvidence" : gold > 0 ? "won" : won ? "dailyCap" : "drawLost" };
    tx.create(path.result,result);
    if (gold > 0) {
      tx.set(path.base,{ ...wallet,gold:balance+gold });
      tx.set(dayPath,{ ...usage,gold:used+gold });
      tx.create(path.ledger,{ type:"saleGold",account,claimId:saleId,kind:"sale",saleId,gold,delta:gold,day,
        revision:evidence.revision,fingerprint:evidence.fingerprint,atMs:serverNowMs });
    }
    return result;
  });
}
export async function querySaleReward(store: Store, account: string, saleId: string): Promise<SaleRewardResult | null> {
  const path = paths(account,saleId);
  return store.run(async (tx) => {
    const value = await tx.get(path.result);
    if (!value) return null;
    const result = decode(value,account,saleId), ledger = await tx.get(path.ledger);
    if (result.outcome === "eligible") {
      if (!ledger || ledger.account !== account || ledger.claimId !== saleId || ledger.kind !== "sale" ||
          ledger.gold !== result.gold || ledger.revision !== result.revision || ledger.fingerprint !== result.fingerprint) {
        throw new SaleRewardError("판매 결과와 지급 원장 불일치");
      }
    } else if (ledger) throw new SaleRewardError("무지급 결과에 지급 원장이 존재함");
    return result;
  });
}
