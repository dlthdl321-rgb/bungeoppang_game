import { cleanName, readProfile } from "./friends";
import { publicPlayerId } from "./invites";
import { Doc, MemoryStore, Store } from "./store";

// The game's own online ranking: three boards of each player's best score,
// kept at rankings/{board}/entries/{uid}. Only these functions read or write
// them (firestore.rules). Scores travel as decimal strings because they go up
// to 2^63-1, beyond what a JSON number holds exactly; `score` is stored as a
// number for ordering and `scoreText` keeps the exact value.

// Mirrors lib/ranking_config.dart; test/stage16_kakao_ranking_test.dart
// checks that the two agree.
export const rankingBoards = ["bestAutoRate", "lifetime", "bestCombo"] as const;
export type Board = (typeof rankingBoards)[number];
export const rankingScoreMax = 9223372036854775807n;
export const rankingSubmitMinGapMs = 60000;
export const rankingTopCount = 100;
export const rankingGrowthSlack = 10;
export const rankingGrowthPerHour = 10;
export const rankingGrowthFloor: Record<Board, bigint> = {
  bestAutoRate: 1000000n,
  lifetime: 1000000000n,
  bestCombo: 1000n,
};

export class RankingError extends Error {
  constructor(readonly code: "invalid-argument" | "too-soon" | "implausible", message: string) {
    super(message);
  }
}

/** Ordered reads Firestore does with queries; tests use [memoryRankingQueries]. */
export interface RankingQueries {
  /** Best [limit] entries: score high to low, earlier record first on ties. */
  top(board: Board, limit: number): Promise<Array<{ id: string; data: Doc }>>;
  /** How many entries score strictly higher (a count() aggregation). */
  countAbove(board: Board, score: number): Promise<number>;
}

const entryPath = (board: Board, uid: string) => `rankings/${board}/entries/${uid}`;
const isBoard = (x: unknown): x is Board => rankingBoards.includes(x as Board);

function parseScore(raw: unknown): bigint {
  let value: bigint;
  if (typeof raw === "string" && /^[0-9]{1,19}$/.test(raw)) {
    value = BigInt(raw);
  } else if (typeof raw === "number" && Number.isSafeInteger(raw) && raw >= 0) {
    value = BigInt(raw);
  } else {
    throw new RankingError("invalid-argument", "scores must be whole numbers");
  }
  if (value > rankingScoreMax) throw new RankingError("invalid-argument", "score too large");
  return value;
}

/**
 * The most a best score may reach [elapsedMs] after the previous best
 * [previous]: small scores always pass (early play moves fast), and beyond
 * that a score may grow rankingGrowthSlack times at once plus
 * rankingGrowthPerHour times per hour since the previous record.
 */
export function plausible(board: Board, previous: bigint, next: bigint, elapsedMs: number): boolean {
  const floor = rankingGrowthFloor[board];
  if (next <= floor) return true;
  const base = previous > floor ? previous : floor;
  const hours = Math.max(0, elapsedMs) / (60 * 60 * 1000);
  const limit = rankingGrowthSlack * Math.pow(rankingGrowthPerHour, hours);
  if (!Number.isFinite(limit) || limit >= 1e30) return true;
  const scale = 1000000n;
  return next * scale <= base * BigInt(Math.floor(limit * Number(scale)));
}

/**
 * Keeps each board's best: a lower or equal score changes nothing but the
 * name and look shown. Refused while the last call is under
 * rankingSubmitMinGapMs old, or when a score jumps implausibly.
 */
export async function submit(store: Store, uid: string, input: Record<string, unknown>, now: number) {
  const scores = new Map<Board, bigint>();
  for (const board of rankingBoards) {
    if (input[board] !== undefined) scores.set(board, parseScore(input[board]));
  }
  if (scores.size === 0) throw new RankingError("invalid-argument", "no scores");
  return store.run(async (tx) => {
    const last = await tx.get(`rankingSubmits/${uid}`);
    if (last && now - Number(last.atMs) < rankingSubmitMinGapMs) {
      throw new RankingError("too-soon", "ranking submitted too often");
    }
    const profile = await readProfile(tx, uid);
    const previous = new Map<Board, Doc | undefined>();
    for (const board of scores.keys()) previous.set(board, await tx.get(entryPath(board, uid)));
    const name = cleanName(profile.name);
    const look = (profile.look as Record<string, string> | undefined) ?? {};
    const best: Record<string, string> = {};
    const writes: Array<[string, Doc]> = [];
    for (const [board, score] of scores) {
      const old = previous.get(board);
      const oldScore = old ? BigInt(String(old.scoreText)) : 0n;
      if (old && !plausible(board, oldScore, score, now - Number(old.updatedAt))) {
        throw new RankingError("implausible", `${board} grew implausibly`);
      }
      if (score > oldScore) {
        writes.push([entryPath(board, uid),
          { score: Number(score), scoreText: score.toString(), name, look, updatedAt: now }]);
        best[board] = score.toString();
      } else if (old) {
        writes.push([entryPath(board, uid), { ...old, name, look }]);
        best[board] = oldScore.toString();
      }
    }
    for (const [path, data] of writes) tx.set(path, data);
    tx.set(`rankingSubmits/${uid}`, { atMs: now });
    return { best };
  });
}

/** The top rankingTopCount of [board] and my own rank and score. */
export async function top(store: Store, queries: RankingQueries, uid: string, input: { board?: unknown }) {
  const { board } = input;
  if (!isBoard(board)) throw new RankingError("invalid-argument", "unknown board");
  const rows = await queries.top(board, rankingTopCount);
  const myId = publicPlayerId(uid);
  let rank = 0;
  let previousScore: string | undefined;
  const entries = rows.map((row, i) => {
    const score = String(row.data.scoreText);
    // Equal scores share a rank (1, 2, 2, 4), as the count() for "me" does.
    if (score !== previousScore) rank = i + 1;
    previousScore = score;
    const playerId = publicPlayerId(row.id);
    return {
      rank, playerId, score,
      name: cleanName(row.data.name),
      look: (row.data.look as Record<string, string> | undefined) ?? {},
      me: playerId === myId,
    };
  });
  const mine = await store.run((tx) => tx.get(entryPath(board, uid)));
  const me = mine
    ? { rank: (await queries.countAbove(board, Number(mine.score))) + 1, score: String(mine.scoreText) }
    : null;
  return { board, entries, me };
}

/** [RankingQueries] over a [MemoryStore], for tests. */
export function memoryRankingQueries(store: MemoryStore): RankingQueries {
  const all = (board: Board) => store.list(`rankings/${board}/entries`);
  return {
    async top(board, limit) {
      return (await all(board))
        .sort((a, b) => Number(b.data.score) - Number(a.data.score) ||
          Number(a.data.updatedAt) - Number(b.data.updatedAt))
        .slice(0, limit);
    },
    async countAbove(board, score) {
      return (await all(board)).filter((e) => Number(e.data.score) > score).length;
    },
  };
}
