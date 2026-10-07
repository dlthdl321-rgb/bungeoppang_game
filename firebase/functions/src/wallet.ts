import { createHash } from "node:crypto";
import { Catalog, SpendKind, isConsumable } from "./catalog";
import { Store } from "./store";

// 황금 붕어빵 (paid currency) wallet. The server is the only place that adds
// or spends it: purchases are checked with Google Play before any gold is
// granted, and every spend is recorded with what it bought so a reinstalled
// app can restore its permanent unlocks (see sync).

export class WalletError extends Error {
  constructor(
    readonly code:
      | "invalid-argument"
      | "unknown-product"
      | "not-purchased"
      | "pending"
      | "token-owned-by-other"
      | "insufficient"
      | "already-owned",
    message: string,
  ) {
    super(message);
  }
}

/** The part of the Google Play Developer API the wallet needs. */
export interface PlayPurchases {
  /** purchases.products.get */
  get(productId: string, token: string): Promise<{
    purchaseState: number; // 0 purchased, 1 canceled, 2 pending
    consumptionState: number; // 0 not consumed, 1 consumed
    orderId: string;
  }>;
  /** purchases.products.consume */
  consume(productId: string, token: string): Promise<void>;
}

export interface Grant {
  id: string;
  kind: SpendKind;
  itemId: string;
  consumable: boolean;
  atMs: number;
}

export interface Wallet {
  gold: number;
  grants: Grant[];
}

const requestIdPattern = /^[A-Za-z0-9_-]{8,64}$/;

const userPath = (uid: string) => `users/${uid}`;
const ledgerPath = (uid: string, id: string) => `users/${uid}/ledger/${id}`;
const entitlementPath = (uid: string, kind: SpendKind, itemId: string) =>
  `users/${uid}/entitlements/${kind}_${itemId}`;

const tokenKey = (token: string) => createHash("sha256").update(token).digest("hex");

async function goldOf(store: Store, uid: string): Promise<number> {
  return store.run(async (tx) => Number((await tx.get(userPath(uid)))?.gold ?? 0));
}

/**
 * Checks a Google Play purchase and adds its gold once. A token can only
 * ever be redeemed by the account that first sent it; resending it (for
 * example after a lost response) returns the wallet unchanged.
 */
export async function redeemPurchase(
  store: Store,
  play: PlayPurchases,
  catalog: Catalog,
  uid: string,
  input: { productId?: unknown; purchaseToken?: unknown },
  now: number,
): Promise<{ gold: number; added: number }> {
  const { productId, purchaseToken } = input;
  if (typeof productId !== "string" || typeof purchaseToken !== "string" ||
      purchaseToken.length < 1 || purchaseToken.length > 4096) {
    throw new WalletError("invalid-argument", "productId and purchaseToken are required");
  }
  const product = catalog.products.find((p) => p.id === productId);
  if (!product) throw new WalletError("unknown-product", productId);
  const purchase = await play.get(productId, purchaseToken);
  if (purchase.purchaseState === 2) throw new WalletError("pending", "payment is pending");
  if (purchase.purchaseState !== 0) throw new WalletError("not-purchased", "purchase is not completed");

  const key = tokenKey(purchaseToken);
  const added = await store.run(async (tx) => {
    const existing = await tx.get(`purchases/${key}`);
    if (existing) {
      if (existing.uid !== uid) {
        throw new WalletError("token-owned-by-other", "purchase belongs to another account");
      }
      return 0;
    }
    const user = (await tx.get(userPath(uid))) ?? { gold: 0 };
    const gold = Number(user.gold ?? 0) + product.gold;
    tx.create(`purchases/${key}`, { uid, productId, orderId: purchase.orderId, atMs: now });
    tx.set(userPath(uid), { ...user, gold });
    tx.create(ledgerPath(uid, `purchase_${key.slice(0, 32)}`), {
      type: "purchase", productId, orderId: purchase.orderId, delta: product.gold, atMs: now,
    });
    return product.gold;
  });
  // Consuming acknowledges the purchase and lets the player buy the same
  // pack again. Retried on every resend until Google records it.
  if (purchase.consumptionState === 0) await play.consume(productId, purchaseToken);
  return { gold: await goldOf(store, uid), added };
}

/**
 * Spends gold on one catalog entry. [requestId] is chosen by the app and
 * makes retries safe: the same id never charges twice.
 */
export async function spendGold(
  store: Store,
  catalog: Catalog,
  uid: string,
  input: { requestId?: unknown; kind?: unknown; itemId?: unknown },
  now: number,
): Promise<{ gold: number; grant: Grant }> {
  const { requestId, kind, itemId } = input;
  if (typeof requestId !== "string" || !requestIdPattern.test(requestId) ||
      (kind !== "cosmetic" && kind !== "skill" && kind !== "boost") ||
      typeof itemId !== "string") {
    throw new WalletError("invalid-argument", "requestId, kind and itemId are required");
  }
  const price = catalog.spend[kind][itemId];
  if (price === undefined) throw new WalletError("unknown-product", `${kind}/${itemId}`);
  const id = `spend_${requestId}`;
  return store.run(async (tx) => {
    const user = (await tx.get(userPath(uid))) ?? { gold: 0 };
    const done = await tx.get(ledgerPath(uid, id));
    if (done) {
      if (done.kind !== kind || done.itemId !== itemId) {
        throw new WalletError("invalid-argument", "requestId was used for another item");
      }
      return { gold: Number(user.gold ?? 0), grant: toGrant(id, done) };
    }
    const consumable = isConsumable(kind);
    if (!consumable && (await tx.get(entitlementPath(uid, kind, itemId)))) {
      throw new WalletError("already-owned", `${kind}/${itemId}`);
    }
    const gold = Number(user.gold ?? 0);
    if (gold < price) throw new WalletError("insufficient", "not enough gold");
    const entry = { type: "spend", kind, itemId, delta: -price, consumable, atMs: now };
    tx.set(userPath(uid), { ...user, gold: gold - price });
    tx.create(ledgerPath(uid, id), entry);
    if (!consumable) tx.create(entitlementPath(uid, kind, itemId), { atMs: now, ledgerId: id });
    return { gold: gold - price, grant: toGrant(id, entry) };
  });
}

/** The balance and every grant ever bought, oldest first. */
export async function syncWallet(store: Store, uid: string): Promise<Wallet> {
  const gold = await goldOf(store, uid);
  const grants = (await store.list(`users/${uid}/ledger`))
    .filter((e) => e.data.type === "spend")
    .map((e) => toGrant(e.id, e.data))
    .sort((a, b) => a.atMs - b.atMs || (a.id < b.id ? -1 : 1));
  return { gold, grants };
}

function toGrant(id: string, d: Record<string, unknown>): Grant {
  return {
    id,
    kind: d.kind as SpendKind,
    itemId: String(d.itemId),
    consumable: Boolean(d.consumable),
    atMs: Number(d.atMs),
  };
}
