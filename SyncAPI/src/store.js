import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createHash } from "node:crypto";
import { acceptedCounts, emptyChanges } from "./validation.js";

const collections = ["doses", "settings", "savedLocations", "profiles"];

export class FileSyncStore {
  constructor(options = {}) {
    this.dataDir = options.dataDir ?? join(process.cwd(), "data");
    this.locks = new Map();
  }

  async push(userId, clientId, changes) {
    return this.#withUserLock(userId, async () => {
      const state = await this.#readState(userId);
      const accepted = acceptedCounts();

      for (const collection of collections) {
        for (const record of changes[collection]) {
          const existing = state.records[collection][record.id];
          if (existing && Date.parse(existing.updatedAt) > Date.parse(record.updatedAt)) {
            continue;
          }

          state.cursor += 1;
          const syncedRecord = {
            ...record,
            _sync: {
              seq: state.cursor,
              clientId,
              syncedAt: new Date().toISOString()
            }
          };
          state.records[collection][record.id] = syncedRecord;
          accepted[collection] += 1;
        }
      }

      await this.#writeState(userId, state);
      return { cursor: state.cursor, accepted };
    });
  }

  async pull(userId, since, limit) {
    return this.#withUserLock(userId, async () => {
      const state = await this.#readState(userId);
      const changes = emptyChanges();
      const flattened = [];

      for (const collection of collections) {
        for (const record of Object.values(state.records[collection])) {
          if ((record._sync?.seq ?? 0) > since) {
            flattened.push({ collection, record });
          }
        }
      }

      flattened.sort((a, b) => (a.record._sync?.seq ?? 0) - (b.record._sync?.seq ?? 0));
      const page = flattened.slice(0, limit);

      for (const item of page) {
        const { _sync, ...record } = item.record;
        changes[item.collection].push(record);
      }

      const lastSeq = page.at(-1)?.record._sync?.seq ?? since;
      return {
        cursor: lastSeq,
        hasMore: flattened.length > page.length,
        changes
      };
    });
  }

  async #withUserLock(userId, operation) {
    const previous = this.locks.get(userId) ?? Promise.resolve();
    let release;
    const current = new Promise((resolve) => {
      release = resolve;
    });
    this.locks.set(userId, previous.then(() => current));

    await previous;
    try {
      return await operation();
    } finally {
      release();
      if (this.locks.get(userId) === current) {
        this.locks.delete(userId);
      }
    }
  }

  async #readState(userId) {
    const file = this.#fileForUser(userId);
    try {
      const raw = await readFile(file, "utf8");
      return normalizeState(JSON.parse(raw));
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      return normalizeState({});
    }
  }

  async #writeState(userId, state) {
    const file = this.#fileForUser(userId);
    await mkdir(dirname(file), { recursive: true });
    const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(tmp, `${JSON.stringify(state, null, 2)}\n`, "utf8");
    await rename(tmp, file);
  }

  #fileForUser(userId) {
    const safeName = createHash("sha256").update(userId).digest("hex");
    return join(this.dataDir, `${safeName}.json`);
  }
}

function normalizeState(input) {
  const state = {
    cursor: Number.isInteger(input.cursor) && input.cursor >= 0 ? input.cursor : 0,
    records: input.records && typeof input.records === "object" ? input.records : {}
  };

  for (const collection of collections) {
    if (!state.records[collection] || typeof state.records[collection] !== "object") {
      state.records[collection] = {};
    }
  }

  return state;
}
