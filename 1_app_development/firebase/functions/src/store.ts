// Minimal transactional document store. Production uses Firestore
// (firestoreStore in index.ts); tests use MemoryStore. Paths are
// slash-separated Firestore document paths such as "users/abc".

export type Doc = Record<string, unknown>;

export interface Tx {
  get(path: string): Promise<Doc | undefined>;
  /** Fails the transaction if the document already exists. */
  create(path: string, data: Doc): void;
  set(path: string, data: Doc): void;
}

export interface Store {
  run<T>(fn: (tx: Tx) => Promise<T>): Promise<T>;
  /** Documents directly under a collection path, ordered by id. */
  list(collection: string): Promise<Array<{ id: string; data: Doc }>>;
}

export class AlreadyExists extends Error {}

/** In-memory store with all-or-nothing transactions, for tests. */
export class MemoryStore implements Store {
  readonly docs = new Map<string, Doc>();

  async run<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    const writes = new Map<string, { data: Doc; create: boolean }>();
    const tx: Tx = {
      get: async (path) => {
        // Firestore rejects reads after the first write in a transaction.
        if (writes.size > 0) throw new Error(`read after write: ${path}`);
        const doc = this.docs.get(path);
        return doc === undefined ? undefined : structuredClone(doc);
      },
      create: (path, data) => writes.set(path, { data, create: true }),
      set: (path, data) => writes.set(path, { data, create: false }),
    };
    const result = await fn(tx);
    for (const [path, w] of writes) {
      if (w.create && this.docs.has(path)) throw new AlreadyExists(path);
    }
    for (const [path, w] of writes) this.docs.set(path, structuredClone(w.data));
    return result;
  }

  async list(collection: string) {
    const prefix = `${collection}/`;
    return [...this.docs.entries()]
      .filter(([p]) => p.startsWith(prefix) && !p.slice(prefix.length).includes("/"))
      .map(([p, data]) => ({ id: p.slice(prefix.length), data: structuredClone(data) }))
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  }
}
