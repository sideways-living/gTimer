import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { pbkdf2Sync, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";

const pbkdf2Iterations = 210_000;
const tokenPrefix = "gtimer_";
const syncTrialDurationDays = 14;

export class AuthStore {
  constructor(options = {}) {
    this.filePath = options.filePath ?? join(options.dataDir ?? join(process.cwd(), "data"), "_auth.json");
    this.lock = Promise.resolve();
  }

  async register({ email, password, deviceName }) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const normalizedEmail = normalizeEmail(email);
      if (state.usersByEmail[normalizedEmail]) {
        throw authError(409, "An account already exists for this email address.");
      }

      const userId = randomUUID();
      const now = new Date().toISOString();
      const user = {
        id: userId,
        email: normalizedEmail,
        password: hashPassword(password),
        plan: "free",
        syncTrialStartedAt: now,
        syncTrialEndsAt: datePlusDays(now, syncTrialDurationDays),
        proUntil: null,
        createdAt: now,
        updatedAt: now
      };
      state.usersByEmail[normalizedEmail] = userId;
      state.users[userId] = user;
      const session = addDeviceSession(state, userId, deviceName);
      await this.#writeState(state);
      return authResponse(user, session);
    });
  }

  async login({ email, password, deviceName }) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const userId = state.usersByEmail[normalizeEmail(email)];
      const user = userId ? state.users[userId] : null;
      if (!user || !verifyPassword(password, user.password)) {
        throw authError(401, "Email or password is incorrect.");
      }

      const now = new Date().toISOString();
      ensureSyncTrial(user, now);
      const session = addDeviceSession(state, user.id, deviceName);
      user.updatedAt = now;
      await this.#writeState(state);
      return authResponse(user, session);
    });
  }

  async authenticateToken(token) {
    if (!token) return null;
    return this.#withLock(async () => {
      const state = await this.#readState();
      const tokenHash = hashToken(token);
      const session = state.sessionsByTokenHash[tokenHash];
      if (!session || session.revokedAt) return null;
      const user = state.users[session.userId];
      if (!user) return null;
      session.lastSeenAt = new Date().toISOString();
      await this.#writeState(state);
      return {
        userId: session.userId,
        hasSyncAccess: hasSyncAccess(user),
        entitlement: entitlementSummary(user)
      };
    });
  }

  async listDevices(userId) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const devices = Object.values(state.devices)
        .filter((device) => device.userId === userId)
        .sort((a, b) => Date.parse(b.lastSeenAt ?? b.createdAt) - Date.parse(a.lastSeenAt ?? a.createdAt))
        .map(publicDevice);
      return { devices };
    });
  }

  async revokeDevice(userId, deviceId) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const device = state.devices[deviceId];
      if (!device || device.userId !== userId) {
        throw authError(404, "Device was not found.");
      }

      const now = new Date().toISOString();
      device.revokedAt = now;
      device.updatedAt = now;
      for (const session of Object.values(state.sessionsByTokenHash)) {
        if (session.deviceId === deviceId && session.userId === userId) {
          session.revokedAt = now;
        }
      }
      await this.#writeState(state);
      return { device: publicDevice(device) };
    });
  }

  async #withLock(operation) {
    const previous = this.lock;
    let release;
    this.lock = new Promise((resolve) => {
      release = resolve;
    });
    await previous;
    try {
      return await operation();
    } finally {
      release();
    }
  }

  async #readState() {
    try {
      const raw = await readFile(this.filePath, "utf8");
      return normalizeState(JSON.parse(raw));
    } catch (error) {
      if (error.code === "ENOENT") return emptyAuthState();
      throw error;
    }
  }

  async #writeState(state) {
    await mkdir(dirname(this.filePath), { recursive: true });
    const tmp = `${this.filePath}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(tmp, `${JSON.stringify(state, null, 2)}\n`, "utf8");
    await rename(tmp, this.filePath);
  }
}

export function cleanAuthRequest(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw authError(400, "Request body must be a JSON object.");
  }

  const email = cleanString(body.email, "email", { required: true, maxLength: 320 }).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw authError(400, "Enter a valid email address.");
  }

  const password = cleanString(body.password, "password", { required: true, maxLength: 512 });
  if (password.length < 8) {
    throw authError(400, "Password must be at least 8 characters.");
  }

  return {
    email,
    password,
    deviceName: cleanString(body.deviceName ?? "gTimer", "deviceName", { maxLength: 128 }) || "gTimer"
  };
}

export function authError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function emptyAuthState() {
  return {
    users: {},
    usersByEmail: {},
    devices: {},
    sessionsByTokenHash: {}
  };
}

function normalizeState(state) {
  const users = state.users ?? {};
  for (const user of Object.values(users)) {
    user.plan ??= "free";
    user.syncTrialStartedAt ??= null;
    user.syncTrialEndsAt ??= null;
    user.proUntil ??= null;
  }

  return {
    users,
    usersByEmail: state.usersByEmail ?? {},
    devices: state.devices ?? {},
    sessionsByTokenHash: state.sessionsByTokenHash ?? {}
  };
}

function normalizeEmail(email) {
  return String(email ?? "").trim().toLowerCase();
}

function cleanString(value, label, options = {}) {
  if (value == null) {
    if (options.required) throw authError(400, `${label} is required.`);
    return "";
  }
  if (typeof value !== "string") throw authError(400, `${label} must be a string.`);
  const cleaned = value.trim();
  if (options.required && !cleaned) throw authError(400, `${label} is required.`);
  if (options.maxLength && cleaned.length > options.maxLength) {
    throw authError(400, `${label} is too long.`);
  }
  return cleaned;
}

function hashPassword(password) {
  const salt = randomBytes(16).toString("hex");
  const hash = pbkdf2Sync(password, salt, pbkdf2Iterations, 32, "sha256").toString("hex");
  return `pbkdf2-sha256$${pbkdf2Iterations}$${salt}$${hash}`;
}

function verifyPassword(password, encoded) {
  const [algorithm, iterationsRaw, salt, expectedHash] = String(encoded ?? "").split("$");
  if (algorithm !== "pbkdf2-sha256") return false;
  const iterations = Number(iterationsRaw);
  if (!Number.isInteger(iterations) || !salt || !expectedHash) return false;
  const actual = pbkdf2Sync(password, salt, iterations, 32, "sha256");
  const expected = Buffer.from(expectedHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function addDeviceSession(state, userId, deviceName) {
  const now = new Date().toISOString();
  const deviceId = randomUUID();
  const token = `${tokenPrefix}${randomBytes(32).toString("base64url")}`;
  const tokenHash = hashToken(token);

  const device = {
    id: deviceId,
    userId,
    name: deviceName,
    createdAt: now,
    updatedAt: now,
    lastSeenAt: now,
    revokedAt: null
  };
  state.devices[deviceId] = device;
  state.sessionsByTokenHash[tokenHash] = {
    userId,
    deviceId,
    createdAt: now,
    lastSeenAt: now,
    revokedAt: null
  };

  return { token, device };
}

function hashToken(token) {
  return pbkdf2Sync(token, "gtimer-sync-token-v1", 1, 32, "sha256").toString("hex");
}

function publicDevice(device) {
  return {
    id: device.id,
    name: device.name,
    createdAt: device.createdAt,
    lastSeenAt: device.lastSeenAt,
    revokedAt: device.revokedAt ?? null
  };
}

function authResponse(user, session) {
  return {
    token: session.token,
    user: {
      id: user.id,
      email: user.email,
      entitlement: entitlementSummary(user)
    },
    device: publicDevice(session.device)
  };
}

function ensureSyncTrial(user, now) {
  if (user.syncTrialStartedAt && user.syncTrialEndsAt) return;
  user.syncTrialStartedAt = now;
  user.syncTrialEndsAt = datePlusDays(now, syncTrialDurationDays);
}

function hasSyncAccess(user) {
  if (user.plan === "pro") return true;
  if (user.proUntil && Date.parse(user.proUntil) > Date.now()) return true;
  if (user.syncTrialEndsAt && Date.parse(user.syncTrialEndsAt) > Date.now()) return true;
  return false;
}

function entitlementSummary(user) {
  return {
    plan: user.plan ?? "free",
    syncTrialStartedAt: user.syncTrialStartedAt ?? null,
    syncTrialEndsAt: user.syncTrialEndsAt ?? null,
    proUntil: user.proUntil ?? null,
    hasSyncAccess: hasSyncAccess(user)
  };
}

function datePlusDays(dateString, days) {
  const date = new Date(dateString);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString();
}
