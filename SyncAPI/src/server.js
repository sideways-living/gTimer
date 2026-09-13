import http from "node:http";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { AuthStore, cleanAuthRequest } from "./auth-store.js";
import { FileSyncStore } from "./store.js";
import { httpError, normalizePullQuery, normalizePushBody } from "./validation.js";

loadDotEnv();

const port = Number(process.env.PORT ?? 8787);
const tokens = loadTokenMap();
const authStore = new AuthStore({ dataDir: process.env.GTIMER_SYNC_DATA_DIR });
const store = new FileSyncStore({ dataDir: process.env.GTIMER_SYNC_DATA_DIR });

export function createServer(options = {}) {
  const activeStore = options.store ?? store;
  const activeTokens = options.tokens ?? tokens;
  const activeAuthStore = options.authStore ?? authStore;

  return http.createServer(async (request, response) => {
    try {
      await route(request, response, activeStore, activeTokens, activeAuthStore);
    } catch (error) {
      sendJSON(response, error.status ?? 500, {
        error: error.status ? error.message : "Internal server error."
      });
    }
  });
}

async function route(request, response, activeStore, activeTokens, activeAuthStore) {
  const url = new URL(request.url ?? "/", "http://localhost");

  if (request.method === "GET" && url.pathname === "/health") {
    sendJSON(response, 200, { status: "ok", service: "gtimer-sync-api" });
    return;
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/register") {
    const body = await readJSONBody(request);
    const result = await activeAuthStore.register(cleanAuthRequest(body));
    sendJSON(response, 201, result);
    return;
  }

  if (request.method === "POST" && url.pathname === "/v1/auth/login") {
    const body = await readJSONBody(request);
    const result = await activeAuthStore.login(cleanAuthRequest(body));
    sendJSON(response, 200, result);
    return;
  }

  if (request.method === "GET" && url.pathname === "/v1/auth/devices") {
    const auth = await authenticate(request, activeTokens, activeAuthStore);
    sendJSON(response, 200, await activeAuthStore.listDevices(auth.userId));
    return;
  }

  const revokeMatch = url.pathname.match(/^\/v1\/auth\/devices\/([^/]+)$/);
  if (request.method === "DELETE" && revokeMatch) {
    const auth = await authenticate(request, activeTokens, activeAuthStore);
    sendJSON(response, 200, await activeAuthStore.revokeDevice(auth.userId, decodeURIComponent(revokeMatch[1])));
    return;
  }

  if (url.pathname.startsWith("/v1/sync/")) {
    const auth = await authenticate(request, activeTokens, activeAuthStore);
    if (!auth.hasSyncAccess) {
      throw httpError(402, "Sync trial ended. Activate gTimer Pro to keep syncing.");
    }

    if (request.method === "POST" && url.pathname === "/v1/sync/push") {
      const body = await readJSONBody(request);
      const push = normalizePushBody(body);
      const result = await activeStore.push(auth.userId, push.clientId, push.changes);
      sendJSON(response, 200, result);
      return;
    }

    if (request.method === "GET" && url.pathname === "/v1/sync/pull") {
      const query = normalizePullQuery(url);
      const result = await activeStore.pull(auth.userId, query.since, query.limit);
      sendJSON(response, 200, result);
      return;
    }
  }

  throw httpError(404, "Not found.");
}

async function authenticate(request, activeTokens, activeAuthStore) {
  const authorization = request.headers.authorization ?? "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, "Missing bearer token.");
  }

  const staticUserId = activeTokens[match[1]];
  if (staticUserId) {
    return {
      userId: staticUserId,
      hasSyncAccess: true,
      entitlement: { plan: "development", hasSyncAccess: true }
    };
  }

  const auth = await activeAuthStore.authenticateToken(match[1]);
  if (!auth?.userId) {
    throw httpError(403, "Invalid bearer token.");
  }
  return auth;
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

function loadDotEnv() {
  const envPath = new URL("../.env", import.meta.url);
  if (!existsSync(envPath)) return;

  const lines = readFileSync(envPath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const separator = trimmed.indexOf("=");
    if (separator <= 0) continue;

    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim();
    if (!key || process.env[key] != null) continue;

    process.env[key] = unquoteEnvValue(value);
  }
}

function unquoteEnvValue(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

if (fileURLToPath(import.meta.url) === process.argv[1]) {
  createServer().listen(port, () => {
    console.log(`gTimer Sync API listening on http://localhost:${port}`);
  });
}
