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
/** `pieces`: bungeoppang pieces handed over in finished sales (4차 피드백 g9).
 * Apps from before it leave it out; then sales stand in for it. */
export interface ProgressSnapshot { buns: bigint; lifetime: bigint; level: number; taps: number; sales: number; pieces?: number }
interface Checkpoint extends ProgressSnapshot { atMs: number; saleEvidence: number }
/** premium: special ingredients bought so far (재료 타이쿤 C, items, not packs). */
interface Rates { tap: bigint; auto: bigint; skills: number; premium: bigint }
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
    taps: natural(row.taps), sales: natural(row.sales), pieces: row.pieces === undefined ? undefined : natural(row.pieces) };
  if (snapshot.buns > snapshot.lifetime || snapshot.level < 1 || snapshot.level > 50 ||
      (snapshot.pieces !== undefined && snapshot.pieces < snapshot.sales)) fail("진행 스냅샷 범위 오류", true);
  return snapshot;
}
function kstDay(ms: number): string { return new Date(ms + 540 * 60000).toISOString().slice(0, 10); }
function kstWeek(ms: number): string {
  const date = new Date(ms + 540 * 60000), weekday = (date.getUTCDay() + 6) % 7;
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() - weekday)).toISOString().slice(0, 10);
}

/** Where the last server-checked progress of [progress] is kept. Its
 * `level` is a level the server accepted against server time (29번 친구
 * 초대 reads it for the invited player's goal). */
export function plausibilityCheckpointPath(account: string, progress: string): string {
  return `users/${account}/workshopPlausibility/${progress}`;
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
      // The most pieces one finished sale can hand over.
      salePieces: Math.max(quantity, preferred),
      levels, revision: String(object(root.metadata).revision),
      daily: PlausibilityValidator.dailyLimits(object(root.daily_return), root),
      collection: PlausibilityValidator.collectionLimits(root),
      premium: PlausibilityValidator.premiumLimits(root, base),
      friend: PlausibilityValidator.friendLimits(root),
    };
  }
  /** DEC-154 친구 가게 방문: each KST day at most `daily_limit` visits give
   * up to `invite_duration_ms` each of `multiplier_permille` production
   * (taps and auto). The extra that adds is allowed on top. A config without
   * `friend_visits` allows none. */
  private static friendLimits(root: Row) {
    if (root.friend_visits === undefined) return { seconds: 0n, extraPermille: 0n };
    const f = object(root.friend_visits);
    return {
      seconds: BigInt(natural(f.daily_limit)) * BigInt(Math.ceil(natural(f.invite_duration_ms) / 1000)),
      extraPermille: BigInt(Math.max(0, natural(f.multiplier_permille) - 1000)),
    };
  }
  /** 재료 타이쿤 (4차 병합 3 사용자 결정): the 특제 bonus is paid **only on
   * customer sales** — a product made with special batter or filling sells
   * for `bonus_permille` more each (both: twice that); taps and auto get
   * none. Each special ingredient makes one tub (`portions_per_tub` + the
   * mini-game's bonus portions), each portion makes at most `pieces`
   * products (a mold result or a griddle harvest), each worth at most
   * `pieceBuns` (the dearest base price), which caps the extra over the
   * whole progress. A config without `ingredients` allows no extra. */
  private static premiumLimits(root: Row, pieceBuns: bigint) {
    if (root.ingredients === undefined) return { packCount: 0n, permille: 0n, portions: 0n, pieces: 0n, pieceBuns };
    const i = object(root.ingredients), premium = object(i.premium);
    const pieces = Math.max(natural(object(root.manual_cooking).products_per_completed_result),
      natural(object(root.griddle).products_per_harvest), 1);
    return {
      packCount: BigInt(natural(premium.pack_count)), permille: BigInt(natural(premium.bonus_permille)),
      portions: BigInt(natural(i.portions_per_tub) + natural(i.minigame_bonus_portions_per_tub)),
      pieces: BigInt(pieces), pieceBuns,
    };
  }
  /** 4차 피드백 g6: a completed 도감 cell pays `cell_buns_seconds` of auto
   * production (at least `cell_min_buns`); a cell needs bakes of at least
   * `server_min_ms_per_cell`, and there are five cells per flavor. A
   * collected flavor's gold is `flavor_gold`. */
  private static collectionLimits(root: Row) {
    const rewards = object(root.collection_rewards), recipes = object(root.active_recipes);
    return {
      seconds: BigInt(natural(rewards.cell_buns_seconds)), minimum: decimal(rewards.cell_min_buns),
      gold: natural(rewards.flavor_gold), msPerCell: Math.max(1, natural(rewards.server_min_ms_per_cell)),
      cells: Object.keys(recipes).length * 5, flavors: new Set(Object.keys(recipes)),
    };
  }
  /** 26번 7단계: per KST day at most one 오늘의 주문서 and one attendance
   * stamp pay buns, each `seconds` of the income rate R or at least `min`.
   * R = tap power × `rate_taps_per_second` + auto per second (4차 피드백 g7,
   * the app's `dailyIncomeRate`). */
  private static dailyLimits(daily: Row, root: Row) {
    const order = object(daily.special_order), stamp = object(daily.attendance);
    // 5차 피드백 13: each daily mission without gold pays `mission_buns_rewards`
    // (seconds of R, at least min_buns), once per KST day each.
    let missionSeconds = 0, missionMinimum = 0n;
    if (root.mission_buns_rewards !== undefined) {
      const buns = object(root.mission_buns_rewards), gold = object(root.mission_gold_rewards);
      const count = Object.values(object(object(root.mission_targets).daily))
        .filter((row) => natural(gold[String(object(row).reward_key)]) === 0).length;
      missionSeconds = count * natural(buns.seconds);
      missionMinimum = BigInt(count) * decimal(buns.min_buns);
    }
    return {
      tapsPerSecond: BigInt(natural(daily.rate_taps_per_second)),
      seconds: BigInt(natural(order.reward_seconds) + Math.max(natural(stamp.buns_seconds), natural(stamp.substitute_seconds)) + missionSeconds),
      minimum: decimal(order.min_buns) + (decimal(stamp.min_buns) > decimal(stamp.substitute_min_buns) ? decimal(stamp.min_buns) : decimal(stamp.substitute_min_buns)) + missionMinimum,
      attendanceGold: natural(stamp.gold),
    };
  }
  private skill(id: string): Row { return object(object(object(this.config).skill_purchase).entries)[id] as Row; }
  private premiumItem(id: string): boolean {
    const root = object(this.config);
    return root.ingredients !== undefined && Object.prototype.hasOwnProperty.call(object(object(object(root.ingredients).premium).items), id);
  }
  /** Read outside the transaction: ownership only grows, and a stale read can
   * only make the bound tighter, never looser. */
  private async rates(account: string): Promise<Rates> {
    let tap = 1n, auto = 0n, skills = 0, premium = 0n;
    for (const { id, data } of await this.store.list(`users/${account}/compositeSkills`)) {
      // 재료 타이쿤 C: packs of special ingredients bought (not skills).
      if (id.startsWith("ingredient:")) {
        if (this.premiumItem(id.slice(11))) premium += BigInt(natural(data.owned ?? 0)) * this.limits.premium.packCount;
        continue;
      }
      const row = this.skill(id), owned = natural(data.owned ?? 0);
      if (!row) continue;
      skills += owned;
      if (id.startsWith("tap_")) tap += decimal(row.effect) * BigInt(owned);
      else auto += decimal(row.effect) * BigInt(owned);
    }
    return { tap, auto, skills, premium };
  }
  private checkpointPath(account: string, progress: string) { return plausibilityCheckpointPath(account, progress); }
  private decodeCheckpoint(row: Doc | undefined): Checkpoint | undefined {
    if (!row) return undefined;
    return { ...parseSnapshot(row), atMs: natural(row.atMs), saleEvidence: natural(row.saleEvidence) };
  }
  /** Throws (retryable) when the snapshot is not reachable from the previous
   * checkpoint. Returns the next checkpoint to store in the same transaction. */
  private advance(prev: Checkpoint | undefined, next: ProgressSnapshot, rates: Rates, now: number, saleEvidence = 0): Checkpoint {
    const l = this.limits;
    if (!prev) {
      this.levelsReached(1, next.level, next.taps, next.sales, next.pieces);
      if (next.pieces !== undefined && next.pieces > next.sales * l.salePieces) fail("판매 개수가 판매 기록보다 많습니다.", true);
      if (next.lifetime > l.firstLifetime || next.taps > l.firstTaps || next.sales > l.firstSales) fail("첫 서버 확인의 진행량이 한도를 넘었습니다.");
      return { ...next, atMs: now, saleEvidence };
    }
    if (next.lifetime < prev.lifetime || next.taps < prev.taps || next.sales < prev.sales || next.level < prev.level ||
        (next.pieces !== undefined && prev.pieces !== undefined && next.pieces < prev.pieces)) {
      fail("진행 기록이 이전 서버 확인보다 줄었습니다.", true);
    }
    const pieces = next.pieces !== undefined && prev.pieces !== undefined ? next.pieces - prev.pieces : undefined;
    if (pieces !== undefined && pieces > (next.sales - prev.sales) * l.salePieces) fail("판매 개수가 판매 기록보다 많습니다.", true);
    // The level before the last check may have been partly done then, so
    // only the levels begun after it must be done in full since.
    this.levelsReached(prev.level + 1, next.level, next.taps - prev.taps, next.sales - prev.sales, pieces);
    const elapsedMs = Math.max(0, now - prev.atMs), seconds = BigInt(Math.ceil(elapsedMs / 1000));
    const taps = next.taps - prev.taps, sales = next.sales - prev.sales;
    if (BigInt(taps) > seconds * l.tapsPerSecond + BigInt(l.slackTaps)) fail("탭 증가가 서버 시간 한도를 넘었습니다.");
    if (sales > Math.floor(elapsedMs / l.arrivalMs) + l.slackSales) fail("판매 증가가 서버 시간 한도를 넘었습니다.");
    let rewards = 0n;
    for (let level = prev.level + 1; level <= next.level; level++) rewards += decimal(l.levels[level - 1].buns_reward);
    // The KST days the interval touches, each with one order and one stamp.
    const days = BigInt(Math.floor(elapsedMs / 86400000) + 2);
    const daily = days * (l.daily.seconds * (rates.tap * l.daily.tapsPerSecond + rates.auto) + l.daily.minimum);
    // 4차 피드백 g6: 도감 cells completed in the interval (one per
    // `server_min_ms_per_cell`, plus one, at most every cell there is).
    const cells = BigInt(Math.min(l.collection.cells, Math.floor(elapsedMs / l.collection.msPerCell) + 1));
    const collection = cells * (l.collection.seconds * rates.auto + l.collection.minimum);
    const saleBuns = BigInt(sales) * l.saleBuns;
    const made = BigInt(taps) * rates.tap + seconds * rates.auto + saleBuns;
    // DEC-154: friends' visits double taps and auto for a while each day.
    const boostSeconds = days * l.friend.seconds < seconds ? days * l.friend.seconds : seconds;
    const friend = boostSeconds * (rates.tap * l.tapsPerSecond + rates.auto) * l.friend.extraPermille / 1000n;
    const bound = prev.lifetime + made + this.premiumExtra(saleBuns, rates) + rewards + daily + collection + friend + l.slackBuns;
    if (next.lifetime > bound) fail("붕어빵력 증가가 서버 시간 한도를 넘었습니다.");
    return { ...next, atMs: Math.max(now, prev.atMs), saleEvidence: prev.saleEvidence + saleEvidence };
  }
  /** 재료 타이쿤 (4차 병합 3): the most the 특제 bonus can add to
   * [saleBuns] (the sale proceeds allowed in the interval — taps and auto
   * earn no bonus): twice `bonus_permille` of it (special batter and filling
   * together), and never more than all special ingredients bought could
   * cover (each a tub of portions, each portion `pieces` products of at most
   * `pieceBuns`). 0 without special ingredients. */
  private premiumExtra(saleBuns: bigint, rates: Rates): bigint {
    const p = this.limits.premium;
    if (rates.premium === 0n || p.permille === 0n) return 0n;
    const byTime = saleBuns * 2n * p.permille / 1000n;
    const byStock = rates.premium * p.portions * p.pieces * p.pieceBuns * p.permille / 1000n;
    return byTime < byStock ? byTime : byStock;
  }
  /** 4차 피드백 g9: each level asks for taps and pieces sold in that level
   * (0 again on level-up) and a payment, with no lifetime 붕어빵력 goal.
   * Levels from+1..to must have been reached with [taps] and [pieces]
   * (without pieces, sales of at most `salePieces` each stand in). The
   * 붕어빵력 payment is the app's own currency and is not checked here. */
  private levelsReached(from: number, to: number, taps: number, sales: number, pieces: number | undefined): void {
    let needTaps = 0, needPieces = 0;
    for (let level = from + 1; level <= to; level++) {
      const row = this.limits.levels[level - 1];
      needTaps += natural(row.additional_taps); needPieces += natural(row.additional_sold_pieces);
    }
    const sold = pieces ?? sales * this.limits.salePieces;
    if (taps < needTaps || sold < needPieces) fail("레벨 조건과 진행 기록 불일치", true);
  }
  private stored(c: Checkpoint): Doc {
    return { buns: c.buns.toString(), lifetimeBuns: c.lifetime.toString(), level: c.level, taps: c.taps, sales: c.sales,
      ...(c.pieces === undefined ? {} : { pieces: c.pieces }), atMs: c.atMs, saleEvidence: c.saleEvidence };
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
    if (payload.scope === "attendance") {
      // 26번 7단계: the seventh attendance stamp, one gold.
      if (payload.goal !== "day7" || payload.gold !== this.limits.daily.attendanceGold || Object.keys(payload).length !== 5) fail("출석 보상 근거 오류", true);
      return this.limits.daily.attendanceGold;
    }
    if (payload.scope === "collection") {
      // 4차 피드백 g6: a collected flavor's gold. The server cannot replay the
      // bakes; it pays a known flavor once per account (the mission lock).
      if (typeof payload.goal !== "string" || !this.limits.collection.flavors.has(payload.goal) ||
          payload.gold !== this.limits.collection.gold || Object.keys(payload).length !== 4) fail("도감 완성 보상 근거 오류", true);
      return this.limits.collection.gold;
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
    if (payload.level !== undefined || payload.scope === "collection") return;
    const period = payload.period, grace = this.limits.graceDays * 86400000;
    if (typeof period !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(period)) fail("미션 기간 형식 오류", true);
    const [latest, earliest] = payload.scope === "weekly" ? [kstWeek(now), kstWeek(now - grace)] : [kstDay(now), kstDay(now - grace)];
    if (period > latest || period < earliest) fail("미션 신청 기간이 지났습니다.", true);
    if (payload.scope === "attendance") return;
    const progress = object(payload.progress), value = (key: string) => decimal(progress[key] ?? "0");
    if (value("taps") > BigInt(snapshot.taps) || value("production") > snapshot.lifetime || value("purchases") > BigInt(rates.skills) ||
        value("auto") > rates.auto || value("days") > 7n || value("dailyAll") > 7n) fail("미션 진행량이 서버 확인 진행과 맞지 않습니다.", true);
  }
}
