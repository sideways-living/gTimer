import assert from "node:assert/strict";
import { test } from "node:test";
import { AppleMapsClient, normalizeMapsQuery } from "../src/apple-maps-client.js";

test("exchanges and caches the Apple Maps access token", async () => {
  const requests = [];
  const fetch = async (url, options) => {
    requests.push({ url: String(url), authorization: options.headers.authorization });
    if (String(url).endsWith("/v1/token")) {
      return jsonResponse({ accessToken: "access-token", expiresInSeconds: 1800 });
    }
    return jsonResponse({ results: [{ name: "Melbourne" }] });
  };
  const client = new AppleMapsClient({ authToken: "auth-token", fetch });

  await client.search({ q: "Melbourne" });
  await client.geocode({ q: "Melbourne VIC" });

  assert.equal(requests.filter((request) => request.url.endsWith("/v1/token")).length, 1);
  assert.equal(requests[0].authorization, "Bearer auth-token");
  assert.equal(requests[1].authorization, "Bearer access-token");
});

test("normalizes reverse-geocode coordinates", () => {
  const url = new URL("https://example.test/v1/maps/reverse-geocode?loc=-37.8136,%20144.9631");
  assert.deepEqual(normalizeMapsQuery(url, "reverseGeocode"), {
    loc: "-37.8136,144.9631"
  });
});

function jsonResponse(payload, options = {}) {
  return {
    ok: options.ok ?? true,
    status: options.status ?? 200,
    async json() { return payload; }
  };
}
