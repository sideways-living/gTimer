import { httpError } from "./validation.js";

const MAPS_API_BASE_URL = "https://maps-api.apple.com";
const ACCESS_TOKEN_SAFETY_MARGIN_MS = 60_000;

export class AppleMapsClient {
  constructor(options = {}) {
    this.authToken = options.authToken ?? process.env.APPLE_MAPS_AUTH_TOKEN;
    this.fetch = options.fetch ?? globalThis.fetch;
    this.baseURL = options.baseURL ?? MAPS_API_BASE_URL;
    this.accessToken = null;
    this.accessTokenExpiresAt = 0;
  }

  get isConfigured() {
    return Boolean(this.authToken);
  }

  async search(params) {
    return this.request("/v1/search", params);
  }

  async autocomplete(params) {
    return this.request("/v1/searchAutocomplete", params);
  }

  async geocode(params) {
    return this.request("/v1/geocode", params);
  }

  async reverseGeocode(params) {
    return this.request("/v1/reverseGeocode", params);
  }

  async request(path, params) {
    if (!this.isConfigured) {
      throw httpError(503, "Apple Maps Server API is not configured.");
    }

    const accessToken = await this.getAccessToken();
    const url = new URL(path, this.baseURL);
    for (const [key, value] of Object.entries(params)) {
      if (value != null && value !== "") url.searchParams.set(key, value);
    }

    const response = await this.fetch(url, {
      headers: { authorization: `Bearer ${accessToken}` }
    });
    return readAppleResponse(response);
  }

  async getAccessToken() {
    if (this.accessToken && Date.now() < this.accessTokenExpiresAt - ACCESS_TOKEN_SAFETY_MARGIN_MS) {
      return this.accessToken;
    }

    const response = await this.fetch(new URL("/v1/token", this.baseURL), {
      headers: { authorization: `Bearer ${this.authToken}` }
    });
    const payload = await readAppleResponse(response);
    if (!payload.accessToken || !Number.isFinite(payload.expiresInSeconds)) {
      throw httpError(502, "Apple Maps returned an invalid access-token response.");
    }

    this.accessToken = payload.accessToken;
    this.accessTokenExpiresAt = Date.now() + payload.expiresInSeconds * 1000;
    return this.accessToken;
  }
}

async function readAppleResponse(response) {
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw httpError(502, "Apple Maps returned an unreadable response.");
  }

  if (!response.ok) {
    const status = response.status === 429 ? 429 : 502;
    const message = response.status === 429
      ? "Apple Maps daily request quota has been reached."
      : "Apple Maps request failed.";
    throw httpError(status, message);
  }
  return payload;
}

export function normalizeMapsQuery(url, operation) {
  const allowed = new Set([
    "q", "lang", "limitToCountries", "searchLocation", "searchRegion",
    "searchRegionPriority", "userLocation", "resultTypeFilter", "includePoiCategories",
    "excludePoiCategories", "includeAddressCategories", "excludeAddressCategories"
  ]);
  const params = {};
  for (const [key, value] of url.searchParams) {
    if (allowed.has(key)) params[key] = cleanParameter(value, key);
  }

  if (["search", "autocomplete", "geocode"].includes(operation) && !params.q) {
    throw httpError(400, "q is required.");
  }
  if (operation === "reverseGeocode" && !params.loc) {
    params.loc = cleanCoordinates(url.searchParams.get("loc"), "loc");
  }
  for (const key of ["searchLocation", "userLocation"]) {
    if (params[key]) params[key] = cleanCoordinates(params[key], key);
  }
  return params;
}

function cleanParameter(value, name) {
  const clean = String(value).trim();
  if (!clean || clean.length > 500) throw httpError(400, `${name} is invalid.`);
  return clean;
}

function cleanCoordinates(value, name) {
  const clean = cleanParameter(value ?? "", name);
  const match = clean.match(/^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$/);
  if (!match) throw httpError(400, `${name} must contain latitude,longitude.`);
  const latitude = Number(match[1]);
  const longitude = Number(match[2]);
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw httpError(400, `${name} contains invalid coordinates.`);
  }
  return `${latitude},${longitude}`;
}
