#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$API_DIR/.env"

cd "$API_DIR"

printf 'Paste the Apple Maps server token, then press Enter. The token will stay hidden.\n'
IFS= read -r -s -p 'Apple Maps token: ' APPLE_MAPS_TOKEN
printf '\n'

if [[ -z "$APPLE_MAPS_TOKEN" ]]; then
  printf 'No token was entered. Nothing was changed.\n' >&2
  exit 1
fi

export APPLE_MAPS_TOKEN ENV_FILE
node <<'NODE'
const fs = require("node:fs");

const token = process.env.APPLE_MAPS_TOKEN.trim();
const parts = token.split(".");
if (parts.length !== 3) throw new Error("The value is not a three-part JWT.");

const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
if (!String(payload.scope ?? "").split(/\s+/).includes("server_api")) {
  throw new Error("The token does not include the server_api scope.");
}
if (!Number.isFinite(payload.exp) || payload.exp * 1000 <= Date.now()) {
  throw new Error("The token is already expired or has no valid expiry.");
}

const path = process.env.ENV_FILE;
let contents = fs.existsSync(path) ? fs.readFileSync(path, "utf8") : "";
const entry = `APPLE_MAPS_AUTH_TOKEN=${token}`;
contents = /^APPLE_MAPS_AUTH_TOKEN=.*$/m.test(contents)
  ? contents.replace(/^APPLE_MAPS_AUTH_TOKEN=.*$/m, entry)
  : `${contents.trimEnd()}\n${entry}\n`;

fs.writeFileSync(path, contents, { mode: 0o600 });
fs.chmodSync(path, 0o600);
console.log(`Token scope verified. Token expires ${new Date(payload.exp * 1000).toISOString()}.`);
NODE
unset APPLE_MAPS_TOKEN

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

APPLE_RESPONSE="$(mktemp)"
APPLE_STATUS="$(curl --silent --show-error --output "$APPLE_RESPONSE" --write-out '%{http_code}' \
  -H "Authorization: Bearer $APPLE_MAPS_AUTH_TOKEN" \
  https://maps-api.apple.com/v1/token)"

APPLE_STATUS="$APPLE_STATUS" APPLE_RESPONSE="$APPLE_RESPONSE" node <<'NODE'
const fs = require("node:fs");
const status = Number(process.env.APPLE_STATUS);
const body = JSON.parse(fs.readFileSync(process.env.APPLE_RESPONSE, "utf8"));
if (status !== 200 || typeof body.accessToken !== "string") {
  throw new Error(`Apple rejected the Maps token with HTTP ${status}.`);
}
console.log(`Apple Maps token exchange succeeded. Access token lifetime: ${body.expiresInSeconds} seconds.`);
NODE

pm2 startOrReload ecosystem.config.cjs --env production --update-env
pm2 save

curl --fail --silent --show-error http://127.0.0.1:8787/health
printf '\n'
curl --fail --silent --show-error https://sync.gtimer.app/health
printf '\nApple Maps Server API setup completed successfully.\n'
