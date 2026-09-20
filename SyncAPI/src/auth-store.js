import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { pbkdf2Sync, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse
} from "@simplewebauthn/server";
import {
  consumeRecoveryCode,
  createTotpEnrollment,
  decryptSecret,
  encryptSecret,
  generateRecoveryCodes,
  hashRecoveryCode,
  requireEncryptionKey,
  verifyTotp
} from "./account-security.js";

const pbkdf2Iterations = 210_000;
const tokenPrefix = "gtimer_";
const syncTrialDurationDays = 14;
const ceremonyLifetimeMs = 5 * 60 * 1000;

export class AuthStore {
  constructor(options = {}) {
    this.filePath = options.filePath ?? join(options.dataDir ?? join(process.cwd(), "data"), "_auth.json");
    this.encryptionKey = options.encryptionKey ?? process.env.GTIMER_AUTH_ENCRYPTION_KEY;
    this.rpID = options.rpID ?? process.env.GTIMER_WEBAUTHN_RP_ID ?? "sync.gtimer.app";
    this.origins = normalizeOrigins(options.origins ?? process.env.GTIMER_WEBAUTHN_ORIGINS ?? `https://${this.rpID}`);
    this.lock = Promise.resolve();
  }

  async register({ email, password }) {
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
        syncTrialStartedAt: null,
        syncTrialEndsAt: null,
        proUntil: null,
        createdAt: now,
        updatedAt: now
      };
      state.usersByEmail[normalizedEmail] = userId;
      state.users[userId] = user;
      await this.#writeState(state);
      return authResponse(user);
    });
  }

  async login({ email, password }) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const userId = state.usersByEmail[normalizeEmail(email)];
      const user = userId ? state.users[userId] : null;
      if (!user || !verifyPassword(password, user.password)) {
        throw authError(401, "Email or password is incorrect.");
      }

      const now = new Date().toISOString();
      user.updatedAt = now;
      await this.#writeState(state);
      return authResponse(user, null, securitySummary(user, state.passkeys, state.devices));
    });
  }

  async registerDevice({ email, password, deviceName, deviceKey, platform, totpCode, recoveryCode }) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const userId = state.usersByEmail[normalizeEmail(email)];
      const user = userId ? state.users[userId] : null;
      if (!user || !verifyPassword(password, user.password)) {
        throw authError(401, "Email or password is incorrect.");
      }
      verifyUserSecondFactor(user, { totpCode, recoveryCode }, this.encryptionKey);

      const now = new Date().toISOString();
      ensureSyncTrial(user, now);
      const session = addDeviceSession(state, user.id, deviceName, deviceKey, platform);
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

  async securityStatus(userId) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const user = state.users[userId];
      if (!user) throw authError(404, "Account was not found.");
      return securitySummary(user, state.passkeys, state.devices);
    });
  }

  async beginTotpEnrollment(userId, body) {
    const currentPassword = cleanString(body?.currentPassword, "currentPassword", { required: true, maxLength: 512 });
    return this.#withLock(async () => {
      requireEncryptionKey(this.encryptionKey);
      const state = await this.#readState();
      const user = state.users[userId];
      if (!user || !verifyPassword(currentPassword, user.password)) {
        throw authError(401, "Current password is incorrect.");
      }
      const enrollment = createTotpEnrollment(user.email);
      const enrollmentId = randomUUID();
      state.totpEnrollments[enrollmentId] = {
        userId,
        encryptedSecret: encryptSecret(enrollment.secret, this.encryptionKey),
        expiresAt: new Date(Date.now() + ceremonyLifetimeMs).toISOString()
      };
      pruneExpiredCeremonies(state);
      await this.#writeState(state);
      return {
        enrollmentId,
        secret: enrollment.secret,
        uri: enrollment.uri,
        expiresAt: state.totpEnrollments[enrollmentId].expiresAt
      };
    });
  }

  async confirmTotpEnrollment(userId, body) {
    const enrollmentId = cleanString(body?.enrollmentId, "enrollmentId", { required: true, maxLength: 128 });
    const code = cleanString(body?.code, "code", { required: true, maxLength: 32 });
    return this.#withLock(async () => {
      requireEncryptionKey(this.encryptionKey);
      const state = await this.#readState();
      const user = state.users[userId];
      const enrollment = state.totpEnrollments[enrollmentId];
      delete state.totpEnrollments[enrollmentId];
      if (!user || !enrollment || enrollment.userId !== userId || Date.parse(enrollment.expiresAt) <= Date.now()) {
        await this.#writeState(state);
        throw authError(400, "Authenticator enrollment expired. Start again.");
      }
      const secret = decryptSecret(enrollment.encryptedSecret, this.encryptionKey);
      if (!verifyTotp(user.email, secret, code)) {
        await this.#writeState(state);
        throw authError(401, "Authenticator code is incorrect.");
      }
      const recoveryCodes = generateRecoveryCodes();
      user.totp = {
        encryptedSecret: encryptSecret(secret, this.encryptionKey),
        recoveryCodeHashes: recoveryCodes.map(hashRecoveryCode),
        enabledAt: new Date().toISOString()
      };
      user.updatedAt = new Date().toISOString();
      await this.#writeState(state);
      return { enabled: true, recoveryCodes };
    });
  }

  async disableTotp(userId, body) {
    const currentPassword = cleanString(body?.currentPassword, "currentPassword", { required: true, maxLength: 512 });
    return this.#withLock(async () => {
      const state = await this.#readState();
      const user = state.users[userId];
      if (!user || !verifyPassword(currentPassword, user.password)) {
        throw authError(401, "Current password is incorrect.");
      }
      verifyUserSecondFactor(user, body, this.encryptionKey);
      user.totp = null;
      user.updatedAt = new Date().toISOString();
      await this.#writeState(state);
      return { enabled: false };
    });
  }

  async beginPasskeyRegistration(userId, body) {
    const currentPassword = cleanString(body?.currentPassword, "currentPassword", { required: true, maxLength: 512 });
    const name = cleanString(body?.name ?? "Passkey", "name", { maxLength: 128 }) || "Passkey";
    return this.#withLock(async () => {
      const state = await this.#readState();
      const user = state.users[userId];
      if (!user || !verifyPassword(currentPassword, user.password)) {
        throw authError(401, "Current password is incorrect.");
      }
      const existing = Object.values(state.passkeys).filter((passkey) => passkey.userId === userId && !passkey.revokedAt);
      const options = await generateRegistrationOptions({
        rpName: "gTimer",
        rpID: this.rpID,
        userID: Buffer.from(user.id, "utf8"),
        userName: user.email,
        userDisplayName: user.email,
        attestationType: "none",
        excludeCredentials: existing.map((passkey) => ({ id: passkey.credentialId, transports: passkey.transports })),
        authenticatorSelection: {
          residentKey: "required",
          userVerification: "required"
        },
        supportedAlgorithmIDs: [-7, -257]
      });
      const ceremonyId = randomUUID();
      state.webauthnCeremonies[ceremonyId] = {
        purpose: "registration",
        userId,
        challenge: options.challenge,
        passkeyName: name,
        expiresAt: new Date(Date.now() + ceremonyLifetimeMs).toISOString()
      };
      pruneExpiredCeremonies(state);
      await this.#writeState(state);
      return { ceremonyId, options };
    });
  }

  async finishPasskeyRegistration(userId, body) {
    const ceremonyId = cleanString(body?.ceremonyId, "ceremonyId", { required: true, maxLength: 128 });
    if (!body?.response || typeof body.response !== "object") throw authError(400, "response is required.");
    return this.#withLock(async () => {
      const state = await this.#readState();
      let ceremony;
      try {
        ceremony = consumeWebAuthnCeremony(state, ceremonyId, "registration", userId);
      } catch (error) {
        await this.#writeState(state);
        throw error;
      }
      let verification;
      try {
        verification = await verifyRegistrationResponse({
          response: body.response,
          expectedChallenge: ceremony.challenge,
          expectedOrigin: this.origins,
          expectedRPID: this.rpID,
          requireUserVerification: true,
          supportedAlgorithmIDs: [-7, -257]
        });
      } catch {
        await this.#writeState(state);
        throw authError(401, "Passkey registration could not be verified.");
      }
      if (!verification.verified || !verification.registrationInfo) {
        await this.#writeState(state);
        throw authError(401, "Passkey registration could not be verified.");
      }
      const credential = verification.registrationInfo.credential;
      const now = new Date().toISOString();
      const passkey = {
        id: randomUUID(),
        userId,
        name: ceremony.passkeyName,
        credentialId: credential.id,
        publicKey: Buffer.from(credential.publicKey).toString("base64url"),
        counter: credential.counter,
        transports: body.response.response?.transports ?? credential.transports ?? [],
        deviceType: verification.registrationInfo.credentialDeviceType,
        backedUp: verification.registrationInfo.credentialBackedUp,
        createdAt: now,
        lastUsedAt: null,
        revokedAt: null
      };
      state.passkeys[passkey.id] = passkey;
      await this.#writeState(state);
      return { passkey: publicPasskey(passkey) };
    });
  }

  async beginPasskeyAuthentication(body) {
    const email = cleanString(body?.email, "email", { required: true, maxLength: 320 }).toLowerCase();
    return this.#withLock(async () => {
      const state = await this.#readState();
      const userId = state.usersByEmail[normalizeEmail(email)] ?? null;
      const passkeys = userId
        ? Object.values(state.passkeys).filter((passkey) => passkey.userId === userId && !passkey.revokedAt)
        : [];
      const options = await generateAuthenticationOptions({
        rpID: this.rpID,
        allowCredentials: passkeys.length > 0
          ? passkeys.map((passkey) => ({ id: passkey.credentialId, transports: passkey.transports }))
          : [{ id: randomBytes(32).toString("base64url") }],
        userVerification: "required"
      });
      const ceremonyId = randomUUID();
      state.webauthnCeremonies[ceremonyId] = {
        purpose: "authentication",
        userId,
        challenge: options.challenge,
        expiresAt: new Date(Date.now() + ceremonyLifetimeMs).toISOString()
      };
      pruneExpiredCeremonies(state);
      await this.#writeState(state);
      return { ceremonyId, options };
    });
  }

  async finishPasskeyAuthentication(body) {
    const ceremonyId = cleanString(body?.ceremonyId, "ceremonyId", { required: true, maxLength: 128 });
    const deviceName = cleanString(body?.deviceName ?? "gTimer", "deviceName", { maxLength: 128 }) || "gTimer";
    const deviceKey = cleanString(body?.deviceKey, "deviceKey", { required: true, maxLength: 128 });
    const platform = cleanPlatform(body?.platform);
    if (!body?.response || typeof body.response !== "object") throw authError(400, "response is required.");
    return this.#withLock(async () => {
      const state = await this.#readState();
      let ceremony;
      try {
        ceremony = consumeWebAuthnCeremony(state, ceremonyId, "authentication");
      } catch (error) {
        await this.#writeState(state);
        throw error;
      }
      const passkey = Object.values(state.passkeys).find((candidate) => {
        return candidate.userId === ceremony.userId && candidate.credentialId === body.response.id && !candidate.revokedAt;
      });
      const user = ceremony.userId ? state.users[ceremony.userId] : null;
      if (!user || !passkey) {
        await this.#writeState(state);
        throw authError(401, "Passkey sign-in could not be verified.");
      }
      let verification;
      try {
        verification = await verifyAuthenticationResponse({
          response: body.response,
          expectedChallenge: ceremony.challenge,
          expectedOrigin: this.origins,
          expectedRPID: this.rpID,
          credential: {
            id: passkey.credentialId,
            publicKey: Buffer.from(passkey.publicKey, "base64url"),
            counter: passkey.counter,
            transports: passkey.transports
          },
          requireUserVerification: true
        });
      } catch {
        await this.#writeState(state);
        throw authError(401, "Passkey sign-in could not be verified.");
      }
      if (!verification.verified) {
        await this.#writeState(state);
        throw authError(401, "Passkey sign-in could not be verified.");
      }
      const now = new Date().toISOString();
      passkey.counter = verification.authenticationInfo.newCounter;
      passkey.lastUsedAt = now;
      ensureSyncTrial(user, now);
      const session = addDeviceSession(state, user.id, deviceName, deviceKey, platform);
      user.updatedAt = now;
      await this.#writeState(state);
      return authResponse(user, session, securitySummary(user, state.passkeys, state.devices));
    });
  }

  async listPasskeys(userId) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      return {
        passkeys: Object.values(state.passkeys)
          .filter((passkey) => passkey.userId === userId)
          .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))
          .map(publicPasskey)
      };
    });
  }

  async revokePasskey(userId, passkeyId) {
    return this.#withLock(async () => {
      const state = await this.#readState();
      const passkey = state.passkeys[passkeyId];
      if (!passkey || passkey.userId !== userId) throw authError(404, "Passkey was not found.");
      passkey.revokedAt = new Date().toISOString();
      await this.#writeState(state);
      return { passkey: publicPasskey(passkey) };
    });
  }

  async changePassword(userId, body) {
    const currentPassword = cleanString(body?.currentPassword, "currentPassword", { required: true, maxLength: 512 });
    const newPassword = cleanString(body?.newPassword, "newPassword", { required: true, maxLength: 512 });
    if (newPassword.length < 8) {
      throw authError(400, "New password must be at least 8 characters.");
    }

    return this.#withLock(async () => {
      const state = await this.#readState();
      const user = state.users[userId];
      if (!user || !verifyPassword(currentPassword, user.password)) {
        throw authError(401, "Current password is incorrect.");
      }
      user.password = hashPassword(newPassword);
      user.updatedAt = new Date().toISOString();
      await this.#writeState(state);
      return { updated: true };
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
    totpCode: cleanString(body.totpCode ?? "", "totpCode", { maxLength: 32 }),
    recoveryCode: cleanString(body.recoveryCode ?? "", "recoveryCode", { maxLength: 64 })
  };
}

export function cleanDeviceAuthRequest(body) {
  const cleaned = cleanAuthRequest(body);
  const deviceKey = cleanString(body.deviceKey, "deviceKey", { required: true, maxLength: 128 });
  return {
    ...cleaned,
    deviceName: cleanString(body.deviceName ?? "gTimer", "deviceName", { maxLength: 128 }) || "gTimer",
    deviceKey,
    platform: cleanPlatform(body.platform)
  };
}

function cleanPlatform(value) {
  const platform = cleanString(value ?? "unknown", "platform", { maxLength: 32 }).toLowerCase();
  return ["macos", "ios", "ipados", "android", "windows", "web"].includes(platform)
    ? platform
    : "unknown";
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
    sessionsByTokenHash: {},
    passkeys: {},
    webauthnCeremonies: {},
    totpEnrollments: {}
  };
}

function normalizeState(state) {
  const users = state.users ?? {};
  for (const user of Object.values(users)) {
    user.plan ??= "free";
    user.syncTrialStartedAt ??= null;
    user.syncTrialEndsAt ??= null;
    user.proUntil ??= null;
    user.totp ??= null;
  }

  return {
    users,
    usersByEmail: state.usersByEmail ?? {},
    devices: state.devices ?? {},
    sessionsByTokenHash: state.sessionsByTokenHash ?? {},
    passkeys: state.passkeys ?? {},
    webauthnCeremonies: state.webauthnCeremonies ?? {},
    totpEnrollments: state.totpEnrollments ?? {}
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

function addDeviceSession(state, userId, deviceName, deviceKey, platform = "unknown") {
  const now = new Date().toISOString();
  let device = Object.values(state.devices).find((candidate) => {
    return candidate.userId === userId &&
      candidate.deviceKey === deviceKey &&
      !candidate.revokedAt;
  });
  if (!device) {
    device = {
      id: randomUUID(),
      userId,
      deviceKey,
      name: deviceName,
      platform,
      createdAt: now,
      updatedAt: now,
      lastSeenAt: now,
      revokedAt: null
    };
    state.devices[device.id] = device;
  } else {
    device.name = deviceName;
    device.platform = platform;
    device.updatedAt = now;
    device.lastSeenAt = now;
  }

  for (const session of Object.values(state.sessionsByTokenHash)) {
    if (session.userId === userId && session.deviceId === device.id && !session.revokedAt) {
      session.revokedAt = now;
    }
  }

  const token = `${tokenPrefix}${randomBytes(32).toString("base64url")}`;
  const tokenHash = hashToken(token);
  state.sessionsByTokenHash[tokenHash] = {
    userId,
    deviceId: device.id,
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
    platform: device.platform ?? "unknown",
    createdAt: device.createdAt,
    lastSeenAt: device.lastSeenAt,
    revokedAt: device.revokedAt ?? null
  };
}

function authResponse(user, session = null, security = null) {
  const response = {
    user: {
      id: user.id,
      email: user.email,
      entitlement: entitlementSummary(user)
    }
  };
  if (security) response.user.security = security;
  if (session) {
    response.token = session.token;
    response.device = publicDevice(session.device);
  }
  return response;
}

function verifyUserSecondFactor(user, body, encryptionKey) {
  if (!user.totp?.encryptedSecret) return;
  requireEncryptionKey(encryptionKey);
  const secret = decryptSecret(user.totp.encryptedSecret, encryptionKey);
  if (verifyTotp(user.email, secret, body?.totpCode)) return;
  if (body?.recoveryCode && consumeRecoveryCode(body.recoveryCode, user.totp.recoveryCodeHashes)) return;
  throw authError(401, "A valid authenticator or recovery code is required.");
}

function securitySummary(user, passkeys = {}, devices = {}) {
  const activePasskeys = Object.values(passkeys).filter((passkey) => passkey.userId === user.id && !passkey.revokedAt);
  const activeDevices = Object.values(devices).filter((device) => device.userId === user.id && !device.revokedAt);
  return {
    totpEnabled: Boolean(user.totp?.encryptedSecret),
    recoveryCodesRemaining: user.totp?.recoveryCodeHashes?.length ?? 0,
    passkeyCount: activePasskeys.length,
    activeDeviceCount: activeDevices.length
  };
}

function publicPasskey(passkey) {
  return {
    id: passkey.id,
    name: passkey.name,
    createdAt: passkey.createdAt,
    lastUsedAt: passkey.lastUsedAt ?? null,
    deviceType: passkey.deviceType,
    backedUp: Boolean(passkey.backedUp),
    revokedAt: passkey.revokedAt ?? null
  };
}

function consumeWebAuthnCeremony(state, ceremonyId, purpose, userId = undefined) {
  const ceremony = state.webauthnCeremonies[ceremonyId];
  delete state.webauthnCeremonies[ceremonyId];
  if (!ceremony || ceremony.purpose !== purpose || Date.parse(ceremony.expiresAt) <= Date.now()) {
    throw authError(400, "Passkey request expired. Start again.");
  }
  if (userId !== undefined && ceremony.userId !== userId) {
    throw authError(403, "Passkey request does not belong to this account.");
  }
  return ceremony;
}

function pruneExpiredCeremonies(state) {
  const now = Date.now();
  for (const [id, ceremony] of Object.entries(state.webauthnCeremonies)) {
    if (Date.parse(ceremony.expiresAt) <= now) delete state.webauthnCeremonies[id];
  }
  for (const [id, enrollment] of Object.entries(state.totpEnrollments)) {
    if (Date.parse(enrollment.expiresAt) <= now) delete state.totpEnrollments[id];
  }
}

function normalizeOrigins(value) {
  const values = Array.isArray(value) ? value : String(value).split(",");
  return values.map((origin) => String(origin).trim()).filter(Boolean);
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
