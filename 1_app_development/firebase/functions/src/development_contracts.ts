import { createHash } from "node:crypto";
import { Store } from "./store";

// Dormant development module: no callable export, SDK, wallet mutation or
// deployment wiring. Caller must supply authenticated uid and server clock.
type Row = Record<string, unknown>;
export class DevelopmentContractError extends Error {}
function fail(message: string): never { throw new DevelopmentContractError(message); }
function object(value: unknown): Row {
  if (!value || typeof value !== "object" || Array.isArray(value)) return fail("객체 형식 오류");
  return value as Row;
}
function text(value: unknown): string {
  if (typeof value !== "string" || !value.length) return fail("식별자 누락");
  return value;
}
function natural(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) return fail("정수 범위 오류");
  return value;
}
function decimal(value: unknown): string {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) return fail("재화 문자열 오류");
  return value;
}
function id(value: string): string {
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(value)) return fail("거래 식별자 오류");
  return value;
}
function user(value: string): string {
  if (!value || value.length > 128) return fail("계정 식별자 오류");
  return encodeURIComponent(value);
}

export interface CompositeIntent {
  account: string; transaction: string; revision: string; skill: string;
  owned: number; quantity: number; buns: string; gold: string;
}
/** Shape validation only. Server-authoritative catalog/ownership/balance
 * checks must occur before reserving or charging anything. */
export function parseCompositeIntent(value: unknown, authenticatedUid: string): CompositeIntent {
  const row = object(value);
  const result = {
    account: text(row.account), transaction: id(text(row.transaction)),
    revision: text(row.revision), skill: text(row.skill),
    owned: natural(row.owned), quantity: natural(row.quantity),
    buns: decimal(row.buns), gold: decimal(row.gold),
  };
  if (result.account !== authenticatedUid || !authenticatedUid ||
      result.quantity === 0 || BigInt(result.buns) === 0n || BigInt(result.gold) === 0n) {
    return fail("계정 또는 유상 견적 불일치");
  }
  return result;
}
export function assertSameCompositeIntent(expected: CompositeIntent, actual: CompositeIntent): void {
  for (const key of Object.keys(expected) as Array<keyof CompositeIntent>) {
    if (expected[key] !== actual[key]) fail("같은 거래 ID의 견적 변경");
  }
}

export interface DevelopmentAdPolicy { revision: string; gold: number; limit: 2; offsetMinutes: 540 }
/** Read trusted server-side copy of the single provisional config. Never accept
 * this config from a request body. No final release balance is implied. */
export function developmentAdPolicy(config: unknown): DevelopmentAdPolicy {
  const root = object(config), fixed = object(root.fixed_requirements);
  const ads = object(root.rewarded_ads), metadata = object(root.metadata);
  if (fixed.rewarded_ads_per_account_day !== 2 || fixed.ad_timezone_offset_minutes !== 540) {
    return fail("확정 광고 한도/날짜 변경");
  }
  const gold = natural(ads.gold_per_verified_view);
  if (!gold) return fail("광고 임시 보상 누락");
  return { revision: text(metadata.revision), gold, limit: 2, offsetMinutes: 540 };
}
function day(nowMs: number): string {
  natural(nowMs);
  const date = new Date(nowMs + 540 * 60000);
  if (!Number.isFinite(date.getTime())) return fail("서버 날짜 범위 오류");
  return date.toISOString().slice(0, 10);
}
export interface AdAttempt extends Row {
  account: string; attempt: string; revision: string; day: string;
  providerProofKey?: string;
  startedAtMs: number; gold: number; status: "reserved" | "verifying" | "verified" | "rejectedFinal";
}
function attempt(value: unknown): AdAttempt {
  const row = object(value);
  text(row.account); id(text(row.attempt)); text(row.revision);
  const start = natural(row.startedAtMs);
  if (row.day !== day(start) || natural(row.gold) === 0 ||
      !["reserved", "verifying", "verified", "rejectedFinal"].includes(text(row.status))) {
    return fail("광고 저장 기록 손상");
  }
  if (row.status === "verified") {
    if (!/^[a-f0-9]{64}$/.test(text(row.providerProofKey))) return fail("광고 검증 키 손상");
  } else if (row.providerProofKey !== undefined) return fail("광고 상태/증거 불일치");
  return structuredClone(row) as AdAttempt;
}
function occupancy(value: unknown): string[] {
  if (value === undefined) return [];
  const slots = object(value).slots;
  if (!Array.isArray(slots) || slots.length > 2 || new Set(slots).size !== slots.length) {
    return fail("광고 일일 원장 손상");
  }
  return slots.map((value) => id(text(value)));
}
const attemptPath = (uid: string, attemptId: string) =>
  `users/${user(uid)}/developmentAdAttempts/${id(attemptId)}`;
const dayPath = (uid: string, key: string) => `users/${user(uid)}/developmentAdDays/${key}`;

/** Atomically reserve across devices. Retrying an existing ID, even after
 * midnight, returns its original day/reward. No expiry-based auto-release. */
export async function reserveDevelopmentAd(store: Store, uid: string, attemptId: string,
    serverNowMs: number, policy: DevelopmentAdPolicy): Promise<AdAttempt> {
  policy = { ...policy };
  const key = day(serverNowMs), path = attemptPath(uid, attemptId);
  if (policy.limit !== 2 || policy.offsetMinutes !== 540 || !policy.revision ||
      !Number.isSafeInteger(policy.gold) || policy.gold <= 0) return fail("광고 정책 오류");
  return store.run(async (tx) => {
    const old = await tx.get(path);
    if (old) {
      const existing = attempt(old);
      if (existing.account !== uid || existing.attempt !== attemptId) return fail("광고 키 불일치");
      return existing;
    }
    const dailyPath = dayPath(uid, key), slots = occupancy(await tx.get(dailyPath));
    if (slots.length >= policy.limit || slots.includes(attemptId)) return fail("광고 일일 한도 도달 또는 원장 충돌");
    const created: AdAttempt = { account: uid, attempt: attemptId,
      revision: policy.revision, day: key, startedAtMs: serverNowMs,
      gold: policy.gold, status: "reserved" };
    tx.set(dailyPath, { slots: [...slots, attemptId] });
    tx.create(path, created);
    return structuredClone(created);
  });
}

export interface VerifiedDevelopmentAdProof {
  provider: string; transaction: string; account: string; attempt: string; revision: string;
}
function proofKey(proof: VerifiedDevelopmentAdProof): string {
  text(proof.provider); text(proof.transaction);
  return createHash("sha256").update(JSON.stringify([proof.provider, proof.transaction])).digest("hex");
}

/** Only an authenticated provider verifier may call this internal function.
 * verified means proof accepted, NOT wallet granted. rejectedFinal requires
 * permanent rejection of all late callbacks. No HTTP/SDK callback is trusted. */
export async function recordDevelopmentAdVerification(store: Store, uid: string, attemptId: string,
    verdict: "pending" | "eligible" | "rejectedFinal",
    proof?: VerifiedDevelopmentAdProof): Promise<AdAttempt> {
  proof = proof === undefined ? undefined : { ...proof };
  if (!["pending", "eligible", "rejectedFinal"].includes(verdict)) return fail("검증 결과 오류");
  const path = attemptPath(uid, attemptId);
  return store.run(async (tx) => {
    const record = attempt(await tx.get(path));
    if (record.account !== uid || record.attempt !== attemptId) return fail("광고 키 불일치");
    let verifiedKey: string | undefined;
    if (verdict === "eligible") {
      if (!proof || proof.account !== uid || proof.attempt !== attemptId ||
          proof.revision !== record.revision) return fail("광고 검증 증거 귀속 불일치");
      verifiedKey = proofKey(proof);
    } else if (proof !== undefined) return fail("비성공 상태의 광고 검증 증거 오류");
    const next = verdict === "pending" ? "verifying" : verdict === "eligible" ? "verified" : "rejectedFinal";
    if (record.status === "verified" || record.status === "rejectedFinal") {
      if (record.status !== next || record.providerProofKey !== verifiedKey) return fail("최종 광고 결과 충돌");
      return record;
    }
    const dailyPath = dayPath(uid, record.day), slots = occupancy(await tx.get(dailyPath));
    if (!slots.includes(attemptId)) return fail("광고 예약 근거 없음");
    const proofPath = verifiedKey ? `developmentAdProviderProofs/${verifiedKey}` : undefined;
    if (proofPath && await tx.get(proofPath)) return fail("이미 사용된 광고 업체 거래");
    const updated = { ...record, status: next } as AdAttempt;
    if (verifiedKey) updated.providerProofKey = verifiedKey;
    if (proofPath) tx.create(proofPath, { account: uid, attempt: attemptId,
      revision: record.revision, provider: proof!.provider, transaction: proof!.transaction });
    if (next === "rejectedFinal") tx.set(dailyPath, { slots: slots.filter((v) => v !== attemptId) });
    tx.set(path, updated);
    return structuredClone(updated);
  });
}

export interface RewardDecision extends Row {
  account: string; evidence: string; kind: "sale" | "rewardedAd";
  revision: string; fingerprint: string;
  outcome: "unverifiable" | "noWin" | "eligible";
}
/** Immutable server review result, including non-winning sales. Verifier owns
 * authenticity/random draw; wallet/grant atomic integration is still absent. */
export async function recordDevelopmentRewardDecision(store: Store, value: RewardDecision): Promise<RewardDecision> {
  user(value.account); id(value.evidence); text(value.revision); text(value.fingerprint);
  if (!["sale", "rewardedAd"].includes(value.kind) ||
      !["unverifiable", "noWin", "eligible"].includes(value.outcome) ||
      (value.kind === "rewardedAd" && value.outcome === "noWin")) return fail("보상 심사 결과 오류");
  const clean: RewardDecision = { account: value.account, evidence: value.evidence,
    kind: value.kind, revision: value.revision, fingerprint: value.fingerprint, outcome: value.outcome };
  const path = `users/${user(clean.account)}/developmentRewardDecisions/${clean.kind}_${clean.evidence}`;
  return store.run(async (tx) => {
    const old = await tx.get(path);
    if (old) {
      for (const key of Object.keys(clean)) if (old[key] !== clean[key]) return fail("보상 심사 ID 재사용 충돌");
      return structuredClone(clean);
    }
    tx.create(path, clean);
    return structuredClone(clean);
  });
}

/** Recompute both costs from trusted server config and trusted ownership.
 * Does not establish whether local ownership is authoritative across devices;
 * do not pass a request's owned count as authoritativeOwned. */
export function validateDevelopmentCompositeQuote(config: unknown, input: unknown,
    authenticatedUid: string, authoritativeOwned: number): CompositeIntent {
  const requested = parseCompositeIntent(input, authenticatedUid);
  const root = object(config), metadata = object(root.metadata);
  const purchase = object(root.skill_purchase), entries = object(purchase.entries);
  if (!Object.prototype.hasOwnProperty.call(entries, requested.skill)) return fail("알 수 없는 스킬");
  const row = object(entries[requested.skill]);
  const owned = natural(authoritativeOwned), cap = natural(purchase.max_owned_per_skill);
  if (owned > cap || requested.quantity > cap - owned || requested.owned !== owned) {
    return fail("보유 회차 또는 구매 한도 불일치");
  }
  const num = natural(row.ratio_numerator), den = natural(row.ratio_denominator);
  const step = natural(purchase.gold_step_purchase_count), increment = natural(purchase.gold_step_amount);
  const initialGold = natural(row.gold), base = BigInt(decimal(row.buns));
  if (!den || num < den || !step || !initialGold || base === 0n) return fail("서버 가격 설정 오류");
  let numerator = base * BigInt(num) ** BigInt(owned);
  let denominator = BigInt(den) ** BigInt(owned);
  let buns = 0n, gold = 0n;
  for (let n = owned; n < owned + requested.quantity; n++) {
    buns += (numerator + denominator - 1n) / denominator;
    gold += BigInt(initialGold) + BigInt(Math.floor(n / step)) * BigInt(increment);
    numerator *= BigInt(num);
    denominator *= BigInt(den);
  }
  const expected = { ...requested, revision: text(metadata.revision), owned,
    buns: buns.toString(), gold: gold.toString() };
  assertSameCompositeIntent(expected, requested);
  return expected;
}


export async function queryDevelopmentAd(store: Store, uid: string,
    attemptId: string): Promise<AdAttempt | undefined> {
  return store.run(async (tx) => {
    const row = await tx.get(attemptPath(uid, attemptId));
    if (!row) return undefined;
    const result = attempt(row);
    if (result.account !== uid || result.attempt !== attemptId) return fail("광고 조회 키 불일치");
    return result;
  });
}

export async function queryDevelopmentRewardDecision(store: Store, uid: string,
    kind: "sale" | "rewardedAd", evidenceId: string, revision: string,
    fingerprint: string): Promise<RewardDecision | undefined> {
  user(uid); id(evidenceId); text(revision); text(fingerprint);
  if (!["sale", "rewardedAd"].includes(kind)) return fail("심사 종류 오류");
  return store.run(async (tx) => {
    const row = await tx.get(`users/${user(uid)}/developmentRewardDecisions/${kind}_${evidenceId}`);
    if (!row) return undefined;
    if (row.account !== uid || row.evidence !== evidenceId || row.kind !== kind ||
        row.revision !== revision || row.fingerprint !== fingerprint ||
        !["unverifiable", "noWin", "eligible"].includes(text(row.outcome)) ||
        (kind === "rewardedAd" && row.outcome === "noWin")) return fail("심사 조회 근거 불일치");
    return { account: uid, evidence: evidenceId, kind, revision, fingerprint,
      outcome: row.outcome as RewardDecision["outcome"] };
  });
}
