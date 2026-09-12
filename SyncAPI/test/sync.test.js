import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { createServer } from "../src/server.js";
import { FileSyncStore } from "../src/store.js";

test("pushes and pulls dose changes for the authenticated user", async () => {
  await withTestAPI(async ({ baseURL }) => {
    const dose = sampleDose("dose-1", "2026-09-13T08:30:00.000Z");
    const push = await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "iphone",
        changes: { doses: [dose] }
      }
    });

    assert.equal(push.status, 200);
    assert.equal(push.json.cursor, 1);
    assert.equal(push.json.accepted.doses, 1);

    const pull = await requestJSON(`${baseURL}/v1/sync/pull?since=0`, {
      method: "GET",
      token: "token-a"
    });

    assert.equal(pull.status, 200);
    assert.equal(pull.json.cursor, 1);
    assert.equal(pull.json.hasMore, false);
    assert.deepEqual(pull.json.changes.doses, [dose]);
  });
});

test("does not leak changes between users", async () => {
  await withTestAPI(async ({ baseURL }) => {
    await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "iphone",
        changes: { doses: [sampleDose("dose-1", "2026-09-13T08:30:00.000Z")] }
      }
    });

    const pull = await requestJSON(`${baseURL}/v1/sync/pull?since=0`, {
      method: "GET",
      token: "token-b"
    });

    assert.equal(pull.status, 200);
    assert.deepEqual(pull.json.changes.doses, []);
  });
});

test("keeps newer records when an older edit arrives later", async () => {
  await withTestAPI(async ({ baseURL }) => {
    await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "mac",
        changes: { doses: [sampleDose("dose-1", "2026-09-13T09:00:00.000Z", { amount: 3.0 })] }
      }
    });

    const stalePush = await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "iphone",
        changes: { doses: [sampleDose("dose-1", "2026-09-13T08:00:00.000Z", { amount: 1.0 })] }
      }
    });

    assert.equal(stalePush.status, 200);
    assert.equal(stalePush.json.accepted.doses, 0);

    const pull = await requestJSON(`${baseURL}/v1/sync/pull?since=0`, {
      method: "GET",
      token: "token-a"
    });

    assert.equal(pull.json.changes.doses[0].amount, 3.0);
  });
});

test("returns tombstones for deleted records", async () => {
  await withTestAPI(async ({ baseURL }) => {
    const deletedDose = sampleDose("dose-1", "2026-09-13T10:00:00.000Z", {
      deletedAt: "2026-09-13T10:00:00.000Z"
    });

    await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "mac",
        changes: { doses: [deletedDose] }
      }
    });

    const pull = await requestJSON(`${baseURL}/v1/sync/pull?since=0`, {
      method: "GET",
      token: "token-a"
    });

    assert.equal(pull.json.changes.doses[0].deletedAt, "2026-09-13T10:00:00.000Z");
  });
});

test("rejects invalid dose payloads", async () => {
  await withTestAPI(async ({ baseURL }) => {
    const response = await requestJSON(`${baseURL}/v1/sync/push`, {
      method: "POST",
      token: "token-a",
      body: {
        clientId: "iphone",
        changes: {
          doses: [
            {
              id: "bad",
              amount: -1,
              unit: "ml",
              time: "2026-09-13T08:30:00.000Z",
              createdAt: "2026-09-13T08:30:00.000Z",
              updatedAt: "2026-09-13T08:30:00.000Z"
            }
          ]
        }
      }
    });

    assert.equal(response.status, 400);
    assert.match(response.json.error, /amount/);
  });
});

async function withTestAPI(callback) {
  const dataDir = await mkdtemp(join(tmpdir(), "gtimer-sync-api-"));
  const server = createServer({
    store: new FileSyncStore({ dataDir }),
    tokens: {
      "token-a": "user-a",
      "token-b": "user-b"
    }
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const baseURL = `http://127.0.0.1:${address.port}`;

  try {
    await callback({ baseURL });
  } finally {
    await new Promise((resolve) => server.close(resolve));
    await rm(dataDir, { recursive: true, force: true });
  }
}

async function requestJSON(url, options) {
  const response = await fetch(url, {
    method: options.method,
    headers: {
      "authorization": `Bearer ${options.token}`,
      "content-type": "application/json"
    },
    body: options.body ? JSON.stringify(options.body) : undefined
  });

  return {
    status: response.status,
    json: await response.json()
  };
}

function sampleDose(id, updatedAt, overrides = {}) {
  return {
    id,
    amount: 2.8,
    unit: "ml",
    time: "2026-09-13T08:30:00.000Z",
    deviceName: "iPhone",
    notes: "",
    missed: false,
    edited: false,
    earlyBySeconds: null,
    latitude: -37.8136,
    longitude: 144.9631,
    locationName: "Melbourne",
    locationAccuracyMeters: 20,
    locationCapturedAt: "2026-09-13T08:30:00.000Z",
    locationSource: "automatic",
    createdAt: "2026-09-13T08:30:00.000Z",
    updatedAt,
    deletedAt: null,
    ...overrides
  };
}
