import http from "node:http";
import { fileURLToPath } from "node:url";
import { FileSyncStore } from "./store.js";
import { httpError, normalizePullQuery, normalizePushBody } from "./validation.js";

const port = Number(process.env.PORT ?? 8787);
const tokens = loadTokenMap();
const store = new FileSyncStore({ dataDir: process.env.GTIMER_SYNC_DATA_DIR });

export function createServer(options = {}) {
  const activeStore = options.store ?? store;
  const activeTokens = options.tokens ?? tokens;

  return http.createServer(async (request, response) => {
    try {
      await route(request, response, activeStore, activeTokens);
    } catch (error) {
      sendJSON(response, error.status ?? 500, {
        error: error.status ? error.message : "Internal server error."
      });
    }
  });
}

async function route(request, response, activeStore, activeTokens) {
  const url = new URL(request.url ?? "/", "http://localhost");

  if (request.method === "GET" && url.pathname === "/health") {
    sendJSON(response, 200, { status: "ok", service: "gtimer-sync-api" });
    return;
  }

  if (url.pathname.startsWith("/v1/sync/")) {
    const userId = authenticate(request, activeTokens);

    if (request.method === "POST" && url.pathname === "/v1/sync/push") {
      const body = await readJSONBody(request);
      const push = normalizePushBody(body);
      const result = await activeStore.push(userId, push.clientId, push.changes);
      sendJSON(response, 200, result);
      return;
    }

    if (request.method === "GET" && url.pathname === "/v1/sync/pull") {
      const query = normalizePullQuery(url);
      const result = await activeStore.pull(userId, query.since, query.limit);
      sendJSON(response, 200, result);
      return;
    }
  }

  throw httpError(404, "Not found.");
}

function authenticate(request, activeTokens) {
  const authorization = request.headers.authorization ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, "Missing bearer token.");
  }

  const userId = activeTokens[match[1]];
  if (!userId) {
    throw httpError(403, "Invalid bearer token.");
  }
  return userId;
}

async function readJSONBody(request) {
  const chunks = [];
  let size = 0;

  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1_000_000) {
      throw httpError(413, "Request body is too large.");
    }
    chunks.push(chunk);
  }

  if (chunks.length === 0) return {};

  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw httpError(400, "Request body must be valid JSON.");
  }
}

function sendJSON(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  response.end(`${JSON.stringify(payload)}\n`);
}

function loadTokenMap() {
  const raw = process.env.GTIMER_SYNC_TOKENS;
  if (!raw) {
    return { "dev-token": "dev-user" };
  }

  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("Token map must be an object.");
    }
    return parsed;
  } catch (error) {
    console.error(`Invalid GTIMER_SYNC_TOKENS: ${error.message}`);
    process.exit(1);
  }
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  createServer().listen(port, () => {
    console.log(`gTimer Sync API listening on http://localhost:${port}`);
  });
}
