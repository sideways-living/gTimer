import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  timingSafeEqual
} from "node:crypto";
import * as OTPAuth from "otpauth";

const encryptedValuePrefix = "aes-256-gcm-v1";

export function createTotpEnrollment(email) {
  const secret = new OTPAuth.Secret({ size: 20 }).base32;
  return {
    secret,
    uri: totpFor(email, secret).toString()
  };
}

export function verifyTotp(email, secret, token) {
  const cleaned = String(token ?? "").replace(/\s+/g, "");
  if (!/^\d{6}$/.test(cleaned)) return false;
  return totpFor(email, secret).validate({ token: cleaned, window: 1 }) !== null;
}

export function generateRecoveryCodes(count = 10) {
  return Array.from({ length: count }, () => {
    const raw = randomBytes(6).toString("hex").toUpperCase();
    return `${raw.slice(0, 4)}-${raw.slice(4, 8)}-${raw.slice(8, 12)}`;
  });
}

export function hashRecoveryCode(code) {
  return createHash("sha256")
    .update(normalizeRecoveryCode(code))
    .digest("hex");
}

export function consumeRecoveryCode(code, hashes) {
  const candidate = Buffer.from(hashRecoveryCode(code), "hex");
  const index = hashes.findIndex((hash) => {
    const expected = Buffer.from(hash, "hex");
    return expected.length === candidate.length && timingSafeEqual(expected, candidate);
  });
  if (index < 0) return false;
  hashes.splice(index, 1);
  return true;
}

export function encryptSecret(value, encryptionKey) {
  const key = deriveEncryptionKey(encryptionKey);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [
    encryptedValuePrefix,
    iv.toString("base64url"),
    tag.toString("base64url"),
    encrypted.toString("base64url")
  ].join("$");
}

export function decryptSecret(encoded, encryptionKey) {
  const [prefix, ivRaw, tagRaw, ciphertextRaw] = String(encoded ?? "").split("$");
  if (prefix !== encryptedValuePrefix || !ivRaw || !tagRaw || !ciphertextRaw) {
    throw new Error("Stored account secret is invalid.");
  }
  const decipher = createDecipheriv(
    "aes-256-gcm",
    deriveEncryptionKey(encryptionKey),
    Buffer.from(ivRaw, "base64url")
  );
  decipher.setAuthTag(Buffer.from(tagRaw, "base64url"));
  return Buffer.concat([
    decipher.update(Buffer.from(ciphertextRaw, "base64url")),
    decipher.final()
  ]).toString("utf8");
}

export function requireEncryptionKey(value) {
  if (!String(value ?? "").trim()) {
    const error = new Error("Account security encryption is not configured.");
    error.status = 503;
    throw error;
  }
}

function totpFor(email, secret) {
  return new OTPAuth.TOTP({
    issuer: "gTimer",
    label: String(email ?? "gTimer account"),
    algorithm: "SHA1",
    digits: 6,
    period: 30,
    secret: OTPAuth.Secret.fromBase32(secret)
  });
}

function deriveEncryptionKey(value) {
  requireEncryptionKey(value);
  return createHash("sha256").update(String(value), "utf8").digest();
}

function normalizeRecoveryCode(code) {
  return String(code ?? "").replace(/[^a-zA-Z0-9]/g, "").toUpperCase();
}
