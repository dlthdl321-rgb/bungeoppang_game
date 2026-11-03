import { Doc, Store, Tx } from "./store";
import { requireDevelopmentProgress } from "./active_progress";
import { parseCompositeIntent } from "./development_contracts";
import { PurchaseContext, purchaseFingerprint } from "./composite_purchases";
import { evidencePath } from "./workshop_evidence";

/** final=true: the claim itself is invalid and gets a durable unverifiable
 * result. final=false: retry later (e.g. snapshot outran the server bound). */
export class PlausibilityError extends Error {
  constructor(message: string, readonly final = false) { super(message); }
}
export interface ProgressSnapshot { buns: bigint; lifetime: bigint; level: number; taps: number; sales: number }
interface Checkpoint extends ProgressSnapshot { atMs: number; saleEvidence: number }
interface Rates { tap: bigint; auto: bigint; skills: number }
type Row = Record<string, unknown>;

function fail(message: string, final = false): never { throw new PlausibilityError(message, final); }
function object(value: unknown): Row {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail("검증 요청 형식 오류", true);
  return value as Row;
}
function natural(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) fail("검증 정수 오류", true);
  return value as number;
}
function decimal(value: unknown): bigint {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]{0,4095})$/.test(value)) fail("검증 붕어빵력 형식 오류", true);
  return BigInt(value as string);
}
export function parseSnapshot(value: unknown): ProgressSnapshot {
  const row = object(value);
  const snapshot = { buns: decimal(row.buns), lifetime: decimal(row.lifetimeBuns), level: natural(row.level),
    taps: natural(row.taps), sales: natural(row.sales) };
  if (snapshot.buns > snapshot.lifetime || snapshot.level < 1 || snapshot.level > 50) fail("진행 스냅샷 범위 오류", true);
  return snapshot;
}
function kstDay(ms: number): string { return new Date(ms + 540 * 60000).toISOString().slice(0, 10); }
function kstWeek(ms: number): string {
  const date = new Date(ms + 540 * 60000), weekday = (date.getUTCDay() + 6) % 7;
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() - weekday)).toISOString().slice(0, 10);
}

/** Server-side plausibility validation (2026-11-03 user decision for the
 * closed test). The server cannot replay local cooking, so it bounds each
 * reported snapshot by server time and the server-owned skill rates, keeps a
 * per-progress checkpoint, and only then writes trustedServerValidation
 * evidence. Gold itself only ever moves in the server wallet. */
export class PlausibilityValidator {
  private readonly limits;
  constructor(private readonly store: Store, private readonly config: unknown, private readonly clock: () => number) {
    const root = object(config), v = object(root.server_validation), sale = object(root.ordinary_sale);
    const levels = root.level_progression as Row[];
    const base = (sale.base_buns_by_difficulty as string[]).map(decimal).reduce((a, b) => a > b ? a : b);
    const quantity = levels.reduce((m, r) => Math.max(m, natural(r.order_flavor_limit) * natural(r.order_quantity_limit)), 1);
    const preferred = Object.values(object(root.customer_order_preferences)).reduce((m: number, r) => Math.max(m, natural(object(r).quantity)), 1);
    this.limits = {
      tapsPerSecond: BigInt(natural(v.max_taps_per_second)), slackBuns: decimal(v.slack_buns),
      slackTaps: natural(v.slack_taps), slackSales: natural(v.slack_sales),
      firstLifetime: decimal(v.first_checkpoint_max_lifetime), firstTaps: natural(v.first_checkpoint_max_taps),
      firstSales: natural(v.first_checkpoint_max_sales), graceDays: natural(v.mission_claim_grace_days),
      arrivalMs: natural(sale.customer_arrival_interval_ms), saleBuns: base * BigInt(Math.max(quantity, preferred)),
      levels, revision: String(object(root.metadata).revision),
    };
  }
  private skill(id: string): Row { return object(object(object(this.config).skill_purchase).entries)[id] as Row; }
  /** Read outside the transaction: ownership only grows, and a stale read can
   * only make the bound tighter, never looser. */
  private async rates(account: string): Promise<Rates> {
    let tap = 1n, auto = 0n, skills = 0;
    for (const { id, data } of await this.store.list(`users/${account}/compositeSkills`)) {
      const row = this.skill(id), owned = natural(data.owned ?? 0);
      if (!row) continue;
      skills += owned;
      if (id.startsWith("tap_")) tap += decimal(row.effect) * BigInt(owned);
      else auto += decimal(row.effect) * BigInt(owned);
    }
    return { tap, auto, skills };
  }
  private checkpointPath(account: string, progress: string) { return `users/${account}/workshopPlausibility/${progress}`; }
  private decodeCheckpoint(row: Doc | undefined): Checkpoint | undefined {
    if (!row) return undefined;
    return { ...parseSnapshot(row), atMs: natural(row.atMs), saleEvidence: natural(row.saleEvidence) };
  }
  /** Throws (retryable) when the snapshot is not reachable from the previous
   * checkpoint. Returns the next checkpoint to store in the same transaction. */
  private advance(prev: Checkpoint | undefined, next: ProgressSnapshot, rates: Rates, now: number, saleEvidence = 0): Checkpoint {
    const l = this.limits, row = this.levels(next.level);
    if (next.lifetime < row.lifetime || next.taps < row.taps || next.sales < row.sales) fail("레벨 조건과 진행 기록 불일치", true);
    if (!prev) {
      if (next.lifetime > l.firstLifetime || next.taps > l.firstTaps || next.sales > l.firstSales) fail("첫 서버 확인의 진행량이 한도를 넘었습니다.");
      return { ...next, atMs: now, saleEvidence };
    }
    if (next.lifetime < prev.lifetime || next.taps < prev.taps || next.sales < prev.sales || next.level < prev.level) {
      fail("진행 기록이 이전 서버 확인보다 줄었습니다.", true);
    }
    const elapsedMs = Math.max(0, now - prev.atMs), seconds = BigInt(Math.ceil(elapsedMs / 1000));
    const taps = next.taps - prev.taps, sales = next.sales - prev.sales;
    if (BigInt(taps) > seconds * l.tapsPerSecond + BigInt(l.slackTaps)) fail("탭 증가가 서버 시간 한도를 넘었습니다.");
    if (sales > Math.floor(elapsedMs / l.arrivalMs) + l.slackSales) fail("판매 증가가 서버 시간 한도를 넘었습니다.");
    let rewards = 0n;
    for (let level = prev.level + 1; level <= next.level; level++) rewards += decimal(l.levels[level - 1].buns_reward);
    const bound = prev.lifetime + BigInt(taps) * rates.tap + seconds * rates.auto + BigInt(sales) * l.saleBuns + rewards + l.slackBuns;
    if (next.lifetime > bound) fail("붕어빵력 증가가 서버 시간 한도를 넘었습니다.");
    return { ...next, atMs: Math.max(now, prev.atMs), saleEvidence: prev.saleEvidence + saleEvidence };
  }
  private levels(level: number) {
    let taps = 0, sales = 0;
    for (let i = 1; i < level; i++) { taps += natural(this.limits.levels[i].additional_taps); sales += natural(this.limits.levels[i].additional_sales); }
    return { lifetime: decimal(this.limits.levels[level - 1].season_total_buns), taps, sales };
  }
  private stored(c: Checkpoint): Doc {
    return { buns: c.buns.toString(), lifetimeBuns: c.lifetime.toString(), level: c.level, taps: c.taps, sales: c.sales,
      atMs: c.atMs, saleEvidence: c.saleEvidence };
  }
  /** Shared transaction shape: all reads, validate, then all writes. */
  private async record(ctx: PurchaseContext, snapshotInput: unknown, evidence: { path: string; doc: Doc; same: (old: Doc) => boolean },
      extra?: (tx: Tx, snapshot: ProgressSnapshot, rates: Rates, now: number) => Promise<number | void>): Promise<void> {
    const snapshot = parseSnapshot(snapshotInput), rates = await this.rates(ctx.account);
    await this.store.run(async tx => {
      await requireDevelopmentProgress(tx, ctx.account, ctx.progress, ctx.epoch);
      const old = await tx.get(evidence.path);
      if (old) {
        if (!evidence.same(old)) fail("같은 ID의 검증 증거가 다릅니다.", true);
        return;
      }
      const path = this.checkpointPath(ctx.account, ctx.progress), prev = this.decodeCheckpoint(await tx.get(path));
      const now = this.clock();
      const sales = (await extra?.(tx, snapshot, rates, now)) ?? 0;
      const next = this.advance(prev, snapshot, rates, now, sales);
      if (next.saleEvidence > next.sales) fail("판매 검증 수가 판매 기록보다 많습니다.", true);
      tx.set(path, this.stored(next));
      tx.create(evidence.path, evidence.doc);
    });
  }
  private base(ctx: PurchaseContext) {
    return { source: "trustedServerValidation", verifierVersion: 1, validator: "plausibility-v1", account: ctx.account, progress: ctx.progress, epoch: ctx.epoch };
  }

  async purchase(ctx: PurchaseContext, input: unknown, phase: "reservation" | "debit", snapshotInput: unknown): Promise<void> {
    const intent = parseCompositeIntent(input, ctx.account), fingerprint = purchaseFingerprint(intent);
    const snapshot = parseSnapshot(snapshotInput);
    const path = evidencePath(ctx.account, phase, intent.transaction);
    const doc = { ...this.base(ctx), transaction: intent.transaction, phase, fingerprint, snapshotDigest: `plausibility:${phase}:${fingerprint}`,
      availableBuns: snapshot.buns.toString(), lifetimeBuns: snapshot.lifetime.toString(), level: snapshot.level };
    await this.record(ctx, snapshotInput, { path, doc, same: old => old.fingerprint === fingerprint }, async tx => {
      if (phase === "reservation") {
        if (snapshot.buns < BigInt(intent.buns)) fail("붕어빵력이 부족합니다.", true);
        return;
      }
      // Buns may only rise after the reservation by what lifetime also gained.
      const reserved = await tx.get(evidencePath(ctx.account, "reservation", intent.transaction));
      if (!reserved || reserved.fingerprint !== fingerprint) fail("예약 검증 없이 차감을 확인할 수 없습니다.", true);
      const before = decimal(reserved!.availableBuns), life = decimal(reserved!.lifetimeBuns);
      if (snapshot.lifetime < life || snapshot.buns + BigInt(intent.buns) > before + (snapshot.lifetime - life)) fail("구매 차감이 반영되지 않았습니다.", true);
    });
  }
  /** No grant is ever issued on cancel, and a terminal status wins, so a
   * cancellation fence is safe for any purchase that is not committed. */
  async cancellation(ctx: PurchaseContext, transaction: string, intentInput: unknown): Promise<Row | undefined> {
    const base = `users/${ctx.account}`;
    return this.store.run(async tx => {
      await requireDevelopmentProgress(tx, ctx.account, ctx.progress, ctx.epoch);
      const purchase = await tx.get(`${base}/compositePurchases/${transaction}`), pending = await tx.get(`${base}/compositeState/pending`);
      const path = evidencePath(ctx.account, "cancellation", transaction), old = await tx.get(path);
      if (purchase?.status === "committed" || purchase?.status === "canceled") return undefined;
      const intent = parseCompositeIntent(purchase ?? intentInput, ctx.account);
      if (intent.transaction !== transaction) fail("취소 대상 거래 불일치", true);
      const fingerprint = purchaseFingerprint(intent);
      if (!old) tx.create(path, { ...this.base(ctx), transaction, fingerprint, debitFenced: true, localDebitRestored: true });
      else if (old.fingerprint !== fingerprint) fail("취소 증거 불일치", true);
      if (purchase) return undefined;
      if (pending?.transaction === transaction) fail("보류 기록 없이 잠금만 남아 있습니다.");
      // Never reserved: an immutable no-charge tombstone, like the signed pipeline.
      const tombstone = { ...intent, progress: ctx.progress, epoch: ctx.epoch, status: "canceled",
        receiptId: `canceled_${fingerprint}`, grantId: "", reservedDigest: `plausibility:none:${fingerprint}`, debitDigest: "" };
      tx.create(`${base}/compositePurchases/${transaction}`, tombstone);
      return tombstone;
    });
  }
  async mission(ctx: PurchaseContext, claim: string, payloadInput: unknown, fingerprint: string, snapshotInput: unknown): Promise<void> {
    const payload = object(payloadInput), gold = this.missionGold(payload, parseSnapshot(snapshotInput));
    const doc = { ...this.base(ctx), claimId: claim, kind: "mission", revision: this.limits.revision, fingerprint, gold };
    await this.record(ctx, snapshotInput, { path: evidencePath(ctx.account, "mission", claim), doc, same: old => old.fingerprint === fingerprint },
      async (_tx, snapshot, rates, now) => this.missionPlausible(payload, snapshot, rates, now));
  }
  async sale(ctx: PurchaseContext, saleId: string, payloadInput: unknown, fingerprint: string, snapshotInput: unknown): Promise<void> {
    const payload = object(payloadInput);
    let status = "verified", stars = 1, revision = this.limits.revision;
    try {
      const evidence = object(payload.evidence), order = object(evidence.order);
      stars = natural(evidence.stars);
      if (order.id !== saleId || stars < 1 || stars > 5 || !Array.isArray(evidence.products) || !evidence.products.length ||
          typeof evidence.revision !== "string" || !evidence.revision || typeof payload.fingerprint !== "string") fail("판매 증거 형식 오류", true);
      revision = evidence.revision as string;
    } catch (error) {
      if (!(error instanceof PlausibilityError)) throw error;
      status = "unverifiable"; stars = 1;
    }
    const doc = { ...this.base(ctx), saleId, revision, fingerprint, status, stars };
    await this.record(ctx, snapshotInput, { path: evidencePath(ctx.account, "sale", saleId), doc, same: old => old.fingerprint === fingerprint },
      async () => 1);
  }
  private missionGold(payload: Row, snapshot: ProgressSnapshot): number {
    const root = object(this.config), rewards = object(root.mission_gold_rewards);
    if (payload.revision !== this.limits.revision) fail("미션 설정 버전이 바뀌었습니다.", true);
    if (payload.level !== undefined) {
      const level = natural(payload.level), row = level >= 2 && level <= 50 ? this.limits.levels[level - 1] : undefined;
      if (!row || level > snapshot.level || natural(row.gold_reward) <= 0 || payload.gold !== row.gold_reward) fail("승급 보상 근거 오류", true);
      return natural(row.gold_reward);
    }
    const scope = payload.scope, goal = payload.goal, targets = object(object(root.mission_targets)[String(scope)] ?? null);
    const all = scope === "daily" && goal === "all";
    if (typeof goal !== "string" || (!all && !targets[goal])) fail("미션 목표 오류", true);
    const expected = all ? targets : { [goal as string]: targets[goal as string] };
    const requirements = object(payload.requirements), progress = object(payload.progress);
    if (Object.keys(requirements).sort().join() !== Object.keys(expected).sort().join()) fail("미션 요구 조건 불일치", true);
    for (const [key, value] of Object.entries(expected)) {
      const want = object(value), got = object(requirements[key]);
      if (got.metric !== want.metric || got.target !== want.target || decimal(progress[String(want.metric)] ?? "0") < decimal(want.target)) {
        fail("미션 목표 미달성", true);
      }
    }
    const gold = natural(rewards[all ? "daily_all" : String(object(targets[goal as string]).reward_key)]);
    if (payload.gold !== gold || gold <= 0) fail("미션 보상량 불일치", true);
    return gold;
  }
  private missionPlausible(payload: Row, snapshot: ProgressSnapshot, rates: Rates, now: number): void {
    if (payload.level !== undefined) return;
    const period = payload.period, grace = this.limits.graceDays * 86400000;
    if (typeof period !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(period)) fail("미션 기간 형식 오류", true);
    const [latest, earliest] = payload.scope === "daily" ? [kstDay(now), kstDay(now - grace)] : [kstWeek(now), kstWeek(now - grace)];
    if (period > latest || period < earliest) fail("미션 신청 기간이 지났습니다.", true);
    const progress = object(payload.progress), value = (key: string) => decimal(progress[key] ?? "0");
    if (value("taps") > BigInt(snapshot.taps) || value("production") > snapshot.lifetime || value("purchases") > BigInt(rates.skills) ||
        value("auto") > rates.auto || value("days") > 7n || value("dailyAll") > 7n) fail("미션 진행량이 서버 확인 진행과 맞지 않습니다.", true);
  }
}
