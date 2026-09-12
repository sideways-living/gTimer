const syncCollections = ["doses", "settings", "savedLocations", "profiles"];

export function emptyChanges() {
  return {
    doses: [],
    settings: [],
    savedLocations: [],
    profiles: []
  };
}

export function acceptedCounts() {
  return {
    doses: 0,
    settings: 0,
    savedLocations: 0,
    profiles: 0
  };
}

export function normalizePushBody(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw httpError(400, "Request body must be a JSON object.");
  }

  const clientId = cleanString(body.clientId, "clientId", { required: true, maxLength: 128 });
  const inputChanges = body.changes && typeof body.changes === "object" ? body.changes : {};
  const changes = emptyChanges();

  for (const collection of syncCollections) {
    const value = inputChanges[collection] ?? [];
    if (!Array.isArray(value)) {
      throw httpError(400, `changes.${collection} must be an array.`);
    }
    changes[collection] = value.map((record) => normalizeRecord(collection, record));
  }

  return { clientId, changes };
}

export function normalizePullQuery(url) {
  const sinceRaw = url.searchParams.get("since") ?? "0";
  const limitRaw = url.searchParams.get("limit") ?? "200";
  const since = Number(sinceRaw);
  const limit = Number(limitRaw);

  if (!Number.isInteger(since) || since < 0) {
    throw httpError(400, "since must be a non-negative integer cursor.");
  }

  if (!Number.isInteger(limit) || limit < 1 || limit > 500) {
    throw httpError(400, "limit must be an integer between 1 and 500.");
  }

  return { since, limit };
}

export function normalizeRecord(collection, record) {
  if (!record || typeof record !== "object" || Array.isArray(record)) {
    throw httpError(400, `${collection} entries must be objects.`);
  }

  const normalized = { ...record };
  normalized.id = cleanString(record.id, `${collection}.id`, { required: true, maxLength: 128 });
  normalized.createdAt = cleanISODate(record.createdAt, `${collection}.createdAt`, { required: true });
  normalized.updatedAt = cleanISODate(record.updatedAt, `${collection}.updatedAt`, { required: true });
  normalized.deletedAt = cleanISODate(record.deletedAt, `${collection}.deletedAt`, { required: false });

  if (normalized.deletedAt && Date.parse(normalized.deletedAt) < Date.parse(normalized.updatedAt)) {
    normalized.updatedAt = normalized.deletedAt;
  }

  switch (collection) {
    case "doses":
      validateDose(normalized);
      break;
    case "settings":
      normalized.key = cleanString(record.key, "settings.key", { required: true, maxLength: 128 });
      break;
    case "savedLocations":
      validateSavedLocation(normalized);
      break;
    case "profiles":
      validateProfile(normalized);
      break;
  }

  return normalized;
}

export function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function validateDose(record) {
  const amount = Number(record.amount);
  if (!Number.isFinite(amount) || amount < 0) {
    throw httpError(400, "doses.amount must be a non-negative number.");
  }
  record.amount = amount;
  record.unit = cleanString(record.unit, "doses.unit", { required: true, maxLength: 16 });
  record.time = cleanISODate(record.time, "doses.time", { required: true });
  record.deviceName = cleanString(record.deviceName ?? "", "doses.deviceName", { maxLength: 128 });
  record.notes = cleanString(record.notes ?? "", "doses.notes", { maxLength: 4000 });
  record.missed = Boolean(record.missed);
  record.edited = Boolean(record.edited);
  record.earlyBySeconds = optionalNumber(record.earlyBySeconds, "doses.earlyBySeconds", { min: 0 });
  record.latitude = optionalNumber(record.latitude, "doses.latitude", { min: -90, max: 90 });
  record.longitude = optionalNumber(record.longitude, "doses.longitude", { min: -180, max: 180 });
  record.locationName = optionalString(record.locationName, "doses.locationName", { maxLength: 512 });
  record.locationAccuracyMeters = optionalNumber(record.locationAccuracyMeters, "doses.locationAccuracyMeters", { min: 0 });
  record.locationCapturedAt = cleanISODate(record.locationCapturedAt, "doses.locationCapturedAt", { required: false });
  record.locationSource = optionalString(record.locationSource, "doses.locationSource", { maxLength: 64 });
}

function validateSavedLocation(record) {
  record.name = cleanString(record.name, "savedLocations.name", { required: true, maxLength: 512 });
  record.address = optionalString(record.address, "savedLocations.address", { maxLength: 1000 });
  record.latitude = optionalNumber(record.latitude, "savedLocations.latitude", { min: -90, max: 90 });
  record.longitude = optionalNumber(record.longitude, "savedLocations.longitude", { min: -180, max: 180 });
  record.source = optionalString(record.source, "savedLocations.source", { maxLength: 64 });
}

function validateProfile(record) {
  record.displayName = optionalString(record.displayName, "profiles.displayName", { maxLength: 256 });
  record.email = optionalString(record.email, "profiles.email", { maxLength: 320 });
  record.photoURL = optionalString(record.photoURL, "profiles.photoURL", { maxLength: 2048 });
}

function cleanString(value, label, options = {}) {
  const required = options.required ?? false;
  const maxLength = options.maxLength ?? 1000;

  if (value == null) {
    if (required) throw httpError(400, `${label} is required.`);
    return "";
  }
  if (typeof value !== "string") {
    throw httpError(400, `${label} must be a string.`);
  }
  const cleaned = value.trim();
  if (required && cleaned.length === 0) {
    throw httpError(400, `${label} is required.`);
  }
  if (cleaned.length > maxLength) {
    throw httpError(400, `${label} is too long.`);
  }
  return cleaned;
}

function optionalString(value, label, options = {}) {
  if (value == null) return null;
  return cleanString(value, label, options);
}

function cleanISODate(value, label, options = {}) {
  const required = options.required ?? false;
  if (value == null || value === "") {
    if (required) throw httpError(400, `${label} is required.`);
    return null;
  }
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw httpError(400, `${label} must be an ISO-8601 date string.`);
  }
  return new Date(value).toISOString();
}

function optionalNumber(value, label, options = {}) {
  if (value == null || value === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw httpError(400, `${label} must be a number.`);
  }
  if (options.min != null && number < options.min) {
    throw httpError(400, `${label} must be at least ${options.min}.`);
  }
  if (options.max != null && number > options.max) {
    throw httpError(400, `${label} must be at most ${options.max}.`);
  }
  return number;
}
